extends Node
class_name PlayerSync


const PLAYER_INPUT_TIMEOUT_MSEC: int = 250
const PLAYER_INPUT_SEND_INTERVAL: float = 1.0 / 30.0
const PLAYER_STATE_SEND_INTERVAL: float = 1.0 / 20.0
const BASIC_WALL_DAMAGE: int = 30


signal local_player_ready


var active_world: World
var session_players_by_peer_id: Dictionary[int, SessionPlayer] = {}

var client_gameplay_ready: bool = false
var local_movement_input: Vector2 = Vector2.ZERO
var next_player_input_sequence: int = 0
var player_input_send_timer: float = 0.0

var player_state_send_timer: float = 0.0
var next_player_state_sequence: int = 0
var latest_received_player_snapshots_by_peer_id: Dictionary[int, PlayerSnapshot] = {}


func _physics_process(delta: float) -> void:
	if NetworkManager.is_client() and client_gameplay_ready:
		_send_local_player_input_if_due(delta)

	if NetworkManager.is_host():
		_simulate_remote_client_players()
		_send_player_states_if_due(delta)




func set_active_world(world: World) -> void:
	if active_world == world:
		return

	_disconnect_from_active_world()
	active_world = world

	if active_world == null:
		return

	active_world.player.movement_input_sampled.connect(_on_local_movement_input_sampled)
	active_world.player.wall_damage_requested.connect(_on_local_wall_damage_requested)
	_register_host_session_player()


func clear_active_world() -> void:
	_disconnect_from_active_world()
	active_world = null


func handle_network_packet(from_peer_id: int, message_type: int, payload: Dictionary) -> bool:
	match message_type:
		NetworkProtocol.MessageType.PLAYER_SPAWN:
			if NetworkManager.is_client():
				_handle_player_spawn(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.PLAYER_DESPAWN:
			if NetworkManager.is_client():
				_handle_player_despawn(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.PLAYER_INPUT:
			if NetworkManager.is_host():
				_handle_player_input(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.REQUEST_DAMAGE_WALL:
			if NetworkManager.is_host():
				_handle_wall_damage_request(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.PLAYER_STATE:
			if NetworkManager.is_client():
				_handle_player_state(from_peer_id, payload)
			return true

	return false


func on_host_started() -> void:
	_register_host_session_player()


func on_remote_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return

	if not session_players_by_peer_id.has(peer_id):
		return

	session_players_by_peer_id.erase(peer_id)

	if active_world != null:
		active_world.despawn_remote_player(peer_id)

	_send_player_despawn_to_remaining_clients(peer_id)
	print("Sessiespeler van peer %d verwijderd." % peer_id)


# Called immediately before a client begins a new join flow.
func prepare_for_client_join() -> void:
	client_gameplay_ready = false
	local_movement_input = Vector2.ZERO
	next_player_input_sequence = 0
	player_input_send_timer = 0.0
	latest_received_player_snapshots_by_peer_id.clear()



# WorldSync only emits this after it has validated the world revision and the
# incoming PlayerSaveData. PlayerSync now owns the session and Player node.
func register_client_session(from_peer_id: int, player_save_data: PlayerSaveData) -> void:
	if not NetworkManager.is_host():
		return

	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if session_players_by_peer_id.has(from_peer_id):
		return

	var spawn_position: Vector2 = player_save_data.get_position_for_world(
		active_world.active_world_data.world_id,
		active_world.active_world_data.spawn_position
	)

	var session_player: SessionPlayer = SessionPlayer.create(
		from_peer_id,
		player_save_data.character_id,
		player_save_data.character_name
	)
	session_player.player_save_data = player_save_data
	session_players_by_peer_id[from_peer_id] = session_player

	print(
		"Sessiespeler toegevoegd: peer %d bestuurt %s."
		% [from_peer_id, player_save_data.character_name]
	)

	active_world.spawn_remote_player(from_peer_id, spawn_position)
	_send_all_session_player_spawns_to(from_peer_id)
	_announce_session_player_to_other_clients(session_player)


func _disconnect_from_active_world() -> void:
	if active_world == null:
		return

	if active_world.player.movement_input_sampled.is_connected(_on_local_movement_input_sampled):
		active_world.player.movement_input_sampled.disconnect(_on_local_movement_input_sampled)

	if active_world.player.wall_damage_requested.is_connected(_on_local_wall_damage_requested):
		active_world.player.wall_damage_requested.disconnect(_on_local_wall_damage_requested)



func _on_local_movement_input_sampled(movement_input: Vector2) -> void:
	local_movement_input = movement_input


func _on_local_wall_damage_requested(world_position: Vector2) -> void:
	if NetworkManager.is_client():
		if client_gameplay_ready:
			_request_wall_damage_from_host(world_position)
		return

	_apply_authoritative_wall_damage(world_position)



func _request_wall_damage_from_host(world_position: Vector2) -> void:
	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_DAMAGE_WALL,
		{
			"world_position": world_position,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("REQUEST_DAMAGE_WALL versturen mislukt: %s." % error_string(send_error))


func _handle_wall_damage_request(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if not session_players_by_peer_id.has(from_peer_id):
		return

	var raw_world_position: Variant = payload.get("world_position")
	if not raw_world_position is Vector2:
		return

	_apply_authoritative_wall_damage(raw_world_position)


func _apply_authoritative_wall_damage(world_position: Vector2) -> void:
	if active_world == null or active_world.chunk_manager == null:
		return

	active_world.chunk_manager.damage_wall(world_position, BASIC_WALL_DAMAGE)


func _register_host_session_player() -> void:
	if not NetworkManager.is_host():
		return

	if active_world == null or active_world.local_player_data == null:
		return

	var host_peer_id: int = MultiplayerPeer.TARGET_PEER_SERVER
	if session_players_by_peer_id.has(host_peer_id):
		return

	var host_player_data: PlayerSaveData = active_world.local_player_data
	var host_session_player: SessionPlayer = SessionPlayer.create(
		host_peer_id,
		host_player_data.character_id,
		host_player_data.character_name
	)
	host_session_player.player_save_data = host_player_data
	session_players_by_peer_id[host_peer_id] = host_session_player

	print("Hostspeler geregistreerd als sessiespeler.")


func _send_all_session_player_spawns_to(target_peer_id: int) -> void:
	for session_player: SessionPlayer in session_players_by_peer_id.values():
		_send_player_spawn(target_peer_id, session_player)


func _announce_session_player_to_other_clients(
	new_session_player: SessionPlayer
) -> void:
	for target_session_player: SessionPlayer in session_players_by_peer_id.values():
		var target_peer_id: int = target_session_player.peer_id

		# Peer 1 is the host: it already created this remote player locally.
		if target_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			continue

		# The joining client already received itself in the full spawn list.
		if target_peer_id == new_session_player.peer_id:
			continue

		_send_player_spawn(target_peer_id, new_session_player)


func _send_player_spawn(target_peer_id: int, session_player: SessionPlayer) -> void:
	if not NetworkManager.is_host():
		return

	if active_world == null:
		return

	var player_to_spawn: Player = active_world.get_player_for_peer(
		session_player.peer_id
	)
	if player_to_spawn == null:
		print(
			"Kan PLAYER_SPAWN niet sturen: speler bestaat niet voor peer %d."
			% session_player.peer_id
		)
		return

	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.PLAYER_SPAWN,
		{
			"peer_id": session_player.peer_id,
			"character_id": session_player.character_id,
			"character_name": session_player.character_name,
			"position": player_to_spawn.global_position,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("PLAYER_SPAWN versturen mislukt: %s" % error_string(send_error))


func _handle_player_spawn(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_peer_id: Variant = payload.get("peer_id")
	var raw_character_id: Variant = payload.get("character_id")
	var raw_character_name: Variant = payload.get("character_name")
	var raw_position: Variant = payload.get("position")

	if not raw_peer_id is int or raw_peer_id <= 0:
		return

	if not raw_character_id is String or raw_character_id.is_empty():
		return

	if not raw_character_name is String:
		return

	if not raw_position is Vector2:
		return

	var spawned_peer_id: int = raw_peer_id
	var spawn_position: Vector2 = raw_position

	if spawned_peer_id == NetworkManager.get_local_peer_id():
		active_world.player.global_position = spawn_position
		active_world.player.set_controls_enabled(true)
		client_gameplay_ready = true
		local_player_ready.emit()
		print("Host bepaalde mijn spawnpositie: %s." % spawn_position)
		return

	active_world.spawn_remote_player(spawned_peer_id, spawn_position)
	_apply_cached_remote_player_state(spawned_peer_id)
	print("Remote speler ontvangen: peer %d (%s)." % [spawned_peer_id, raw_character_name])


func _apply_cached_remote_player_state(peer_id: int) -> void:
	if active_world == null:
		return

	if peer_id == NetworkManager.get_local_peer_id():
		return

	if not latest_received_player_snapshots_by_peer_id.has(peer_id):
		return

	var cached_snapshot: PlayerSnapshot = latest_received_player_snapshots_by_peer_id[
		peer_id
	]
	active_world.apply_remote_player_snapshot(cached_snapshot)


func _handle_player_despawn(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_peer_id: Variant = payload.get("peer_id")
	if not raw_peer_id is int or raw_peer_id <= 0:
		return

	var despawned_peer_id: int = raw_peer_id
	if despawned_peer_id == NetworkManager.get_local_peer_id():
		return

	active_world.despawn_remote_player(despawned_peer_id)
	print("Host verwijderde remote speler van peer %d." % despawned_peer_id)


func _send_player_despawn_to_remaining_clients(despawned_peer_id: int) -> void:
	for target_session_player: SessionPlayer in session_players_by_peer_id.values():
		var target_peer_id: int = target_session_player.peer_id

		if target_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			continue

		var send_error: Error = NetworkManager.send_packet(
			target_peer_id,
			NetworkProtocol.MessageType.PLAYER_DESPAWN,
			{
				"peer_id": despawned_peer_id,
			},
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetworkProtocol.CHANNEL_CONTROL
		)

		if send_error != OK:
			print("PLAYER_DESPAWN versturen mislukt: %s." % error_string(send_error))


func _handle_player_input(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if not session_players_by_peer_id.has(from_peer_id):
		return

	var raw_sequence: Variant = payload.get("sequence")
	var raw_movement_input: Variant = payload.get("movement_input")

	if not raw_sequence is int:
		return

	if not raw_movement_input is Vector2:
		return

	var input_sequence: int = raw_sequence
	var movement_input: Vector2 = raw_movement_input.limit_length(1.0)
	var session_player: SessionPlayer = session_players_by_peer_id[from_peer_id]

	if input_sequence <= session_player.last_received_input_sequence:
		return

	session_player.last_received_input_sequence = input_sequence
	session_player.latest_movement_input = movement_input
	session_player.last_input_received_time_msec = Time.get_ticks_msec()


func _send_player_input() -> void:
	next_player_input_sequence += 1

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.PLAYER_INPUT,
		{
			"sequence": next_player_input_sequence,
			"movement_input": local_movement_input,
		},
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		NetworkProtocol.CHANNEL_MOVEMENT
	)

	if send_error != OK:
		print("PLAYER_INPUT versturen mislukt: %s." % error_string(send_error))


func _send_local_player_input_if_due(delta: float) -> void:
	if active_world == null:
		return

	player_input_send_timer += delta
	if player_input_send_timer < PLAYER_INPUT_SEND_INTERVAL:
		return

	player_input_send_timer = 0.0
	_send_player_input()


func _simulate_remote_client_players() -> void:
	if active_world == null:
		return

	var current_time_msec: int = Time.get_ticks_msec()

	for session_player: SessionPlayer in session_players_by_peer_id.values():
		if session_player.peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			continue

		var remote_player: Player = active_world.get_remote_player(session_player.peer_id)
		if remote_player == null:
			continue

		if not active_world.is_remote_player_simulation_ready(session_player.peer_id):
			continue

		var movement_input: Vector2 = session_player.latest_movement_input
		var time_since_last_input_msec: int = (
			current_time_msec - session_player.last_input_received_time_msec
		)

		if time_since_last_input_msec > PLAYER_INPUT_TIMEOUT_MSEC:
			movement_input = Vector2.ZERO

		remote_player.simulate_movement(movement_input)


func _send_player_states_if_due(delta: float) -> void:
	if active_world == null:
		return

	player_state_send_timer += delta
	if player_state_send_timer < PLAYER_STATE_SEND_INTERVAL:
		return

	player_state_send_timer = 0.0
	next_player_state_sequence += 1

	for state_session_player: SessionPlayer in session_players_by_peer_id.values():
		for target_session_player: SessionPlayer in session_players_by_peer_id.values():
			var target_peer_id: int = target_session_player.peer_id

			if target_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
				continue

			_send_player_state(
				target_peer_id,
				state_session_player,
				next_player_state_sequence
			)


func _send_player_state(
	target_peer_id: int,
	state_session_player: SessionPlayer,
	state_sequence: int
) -> void:
	if active_world == null:
		return

	var state_player: Player = active_world.get_player_for_peer(
		state_session_player.peer_id
	)
	if state_player == null:
		return

	var player_snapshot: PlayerSnapshot = PlayerSnapshot.create(
		state_sequence,
		state_session_player.peer_id,
		state_player.global_position,
		state_player.get_network_movement_velocity(),
		state_player.get_facing_direction()
	)

	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.PLAYER_STATE,
		player_snapshot.to_dictionary(),
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		NetworkProtocol.CHANNEL_MOVEMENT
	)

	if send_error != OK:
		print("PLAYER_STATE versturen mislukt: %s." % error_string(send_error))


func _handle_player_state(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var received_snapshot: PlayerSnapshot = PlayerSnapshot.from_dictionary(payload)
	if received_snapshot == null:
		return

	if latest_received_player_snapshots_by_peer_id.has(received_snapshot.peer_id):
		var previous_snapshot: PlayerSnapshot = (
			latest_received_player_snapshots_by_peer_id[received_snapshot.peer_id]
		)

		if received_snapshot.state_sequence <= previous_snapshot.state_sequence:
			return

	var is_first_snapshot_for_peer: bool = (
		not latest_received_player_snapshots_by_peer_id.has(received_snapshot.peer_id)
	)
	latest_received_player_snapshots_by_peer_id[received_snapshot.peer_id] = received_snapshot

	if is_first_snapshot_for_peer:
		print("Eerste PLAYER_STATE ontvangen voor peer %d." % received_snapshot.peer_id)

	if received_snapshot.peer_id == NetworkManager.get_local_peer_id():
		active_world.reconcile_local_player_position(received_snapshot.world_position)
		return

	active_world.apply_remote_player_snapshot(received_snapshot)
