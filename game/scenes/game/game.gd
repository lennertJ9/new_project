extends Node
class_name Game

#preload van world
const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")
const PLAYER_INPUT_TIMEOUT_MSEC: int = 250
const PLAYER_STATE_SEND_INTERVAL: float = 1.0 / 20.0

@export var skip_menu_for_debug: bool = false
@export var debug_world_seed: int = 12345


@onready var world_container: Node2D = $WorldContainer

@onready var main_menu: Control = $Interface/MainMenu
@onready var loading_screen: Control = $Interface/LoadingScreen
@onready var in_game_menu: Control = $Interface/InGameMenu

const PLAYER_INPUT_SEND_INTERVAL: float = 1.0 / 30.0 # hoevaak client zijn inputs verzend

var active_world: World
var is_starting_world: bool = false # geeft aan dat de wereld starting/loading is
var pending_world_join_data: WorldJoinData
var pending_world_snapshot_data: WorldSaveData
var pending_join_player_data: PlayerSaveData
var session_players_by_peer_id: Dictionary[int, SessionPlayer] = {}

var local_movement_input: Vector2 = Vector2.ZERO
var next_player_input_sequence: int = 0
var player_input_send_timer: float = 0.0

var player_state_send_timer: float = 0.0

var next_player_state_sequence: int = 0
var latest_received_player_snapshots_by_peer_id: Dictionary[int, PlayerSnapshot] = {}


func _ready() -> void:
	NetworkManager.session_approved_by_host.connect(_on_session_approved_by_host)
	NetworkManager.packet_received.connect(_on_network_packet_received)
	
	NetworkManager.host_started.connect(_on_host_started)
	NetworkManager.remote_peer_disconnected.connect(_on_remote_peer_disconnected)
	
	in_game_menu.multiplayer_requested.connect(_on_multiplayer_toggle)
	main_menu.world_start_requested.connect(start_world)
	main_menu.world_join_requested.connect(_on_world_join_requested)
	main_menu.show()
	loading_screen.hide()
	in_game_menu.hide()
	
	if OS.is_debug_build() and skip_menu_for_debug:
		start_new_debug_world()



func _physics_process(delta: float) -> void:
	if NetworkManager.is_client():
		_send_local_player_input_if_due(delta)

	if NetworkManager.is_host():
		_simulate_remote_client_players()
		_send_player_states_if_due(delta)


func start_new_debug_world() -> void:
	var world_data: WorldSaveData = WorldSaveData.create_new(debug_world_seed)
	var player_data: PlayerSaveData = PlayerSaveData.create_new()

	var start_data: WorldStartData = WorldStartData.create(world_data, player_data)

	start_world(start_data)


# start een lokale wereld
func start_world(start_data: WorldStartData) -> void:
	if is_starting_world:
		return

	is_starting_world = true
	main_menu.hide()
	loading_screen.show()

	
	var world: World = WORLD_SCENE.instantiate() as World
	if world == null:
		is_starting_world = false
		return

	active_world = world
	world_container.add_child(active_world)

	# wachten totdat de wereld geladen is
	await active_world.initialize(start_data)

	active_world.player.movement_input_sampled.connect(_on_local_movement_input_sampled)

	if NetworkManager.is_host():
		_register_host_session_player()

	loading_screen.hide()
	
	if NetworkManager.is_client():
		_send_client_world_ready()
	
	is_starting_world = false



func _on_local_movement_input_sampled(movement_input: Vector2) -> void:
	local_movement_input = movement_input







func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if active_world != null and not is_starting_world:
			if in_game_menu.visible:
				in_game_menu.hide()
			else:
				in_game_menu.show()




############## NETWORK CODE ########################################################################
#region Netwerk

func _on_network_packet_received(from_peer_id: int, message_type: int, payload: Dictionary) -> void:
	var role: String = "host" if NetworkManager.is_host() else "client"
	match message_type:
		NetworkProtocol.MessageType.REQUEST_WORLD_JOIN_DATA:
			if NetworkManager.is_host():
				_handle_world_join_data_request(from_peer_id)

		NetworkProtocol.MessageType.WORLD_JOIN_DATA:
			if NetworkManager.is_client():
				_handle_world_join_data(from_peer_id, payload)
				
		NetworkProtocol.MessageType.REQUEST_WORLD_SNAPSHOT:
			if NetworkManager.is_host():
				_handle_world_snapshot_request(from_peer_id)

		NetworkProtocol.MessageType.WORLD_SNAPSHOT:
			if NetworkManager.is_client():
				_handle_world_snapshot(from_peer_id, payload)
				
		NetworkProtocol.MessageType.CLIENT_WORLD_READY:
			if NetworkManager.is_host():
				_handle_client_world_ready(from_peer_id, payload)
				
		NetworkProtocol.MessageType.PLAYER_SPAWN:
			if NetworkManager.is_client():
				_handle_player_spawn(from_peer_id, payload)
				
		NetworkProtocol.MessageType.PLAYER_DESPAWN:
			if NetworkManager.is_client():
				_handle_player_despawn(from_peer_id, payload)
		NetworkProtocol.MessageType.PLAYER_INPUT:
			if NetworkManager.is_host():
				_handle_player_input(from_peer_id, payload)
		NetworkProtocol.MessageType.PLAYER_STATE:
			if NetworkManager.is_client():
				_handle_player_state(from_peer_id, payload)



func _on_multiplayer_toggle(enabled: bool):
	if enabled:
		var host_error = NetworkManager.start_host()
		if host_error != OK:
			print("host starten mislukt:", error_string(host_error))
			return
		
		print("host gestart op %d." % NetworkManager.DEFAULT_PORT)



# uitgevoerd wanneer de server start
func _on_host_started() -> void:
	_register_host_session_player()



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
		host_player_data.character_name,
	)
	host_session_player.player_save_data = host_player_data
	
	session_players_by_peer_id[host_peer_id] = host_session_player

	print("Hostspeler geregistreerd als sessiespeler.")



func _on_remote_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return

	if not session_players_by_peer_id.has(peer_id):
		return

	session_players_by_peer_id.erase(peer_id)
	if active_world != null:
		active_world.despawn_remote_player(peer_id)

	_send_player_despawn_to_remaining_clients(peer_id)

	print("Sessiespeler van peer %d verwijderd." % peer_id)



# dit word uitgevoerd als je op de knop een wereld knop duwt
func _on_world_join_requested(address: String, host_port: int, player_data: PlayerSaveData) -> void:
	pending_join_player_data = player_data

	var join_error: Error = NetworkManager.join_host(address, host_port)

	if join_error != OK:
		pending_join_player_data = null
		print("Joinen van wereld mislukt: %s" % error_string(join_error))



# word uitgevoerd door een joinende client nadat de server de sessie goedkeurd
func _on_session_approved_by_host() -> void:
	if not NetworkManager.is_client():
		return

	var request_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_WORLD_JOIN_DATA,
		{},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if request_error != OK:
		print("Werelddata aanvragen mislukt: %s" % error_string(request_error))
		return

	print("Client vraagt werelddata op.")



# de server verstuurt WorldJoinData naar de peer
func _handle_world_join_data_request(from_peer_id: int) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return
	if active_world == null or active_world.active_world_data == null:
		print("Host heeft geen actieve wereld om te versturen.")
		return

	var join_data: WorldJoinData = WorldJoinData.from_world_save_data(active_world.active_world_data)

	var send_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_JOIN_DATA,
		{"world": join_data.to_dictionary()},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print("WorldJoinData versturen mislukt: %s" % error_string(send_error))
		return

	print("WorldJoinData verstuurd naar peer %d." % from_peer_id)



# de client ontvangt het WorldJoinData packet
func _handle_world_join_data(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	var raw_world_data: Variant = payload.get("world")
	if not raw_world_data is Dictionary:
		return

	var join_data: WorldJoinData = WorldJoinData.from_dictionary(raw_world_data)
	if join_data == null:
		print("Ontvangen WorldJoinData is ongeldig.")
		return

	pending_world_join_data = join_data
	_request_world_snapshot()
	
	print(
		"Wereld ontvangen: %s | seed: %d | spawn: %s"
		% [join_data.world_name,join_data.world_seed,join_data.spawn_position,]
		)



# na het ontvangen van join data verzoekt de client de world snapshot
func _request_world_snapshot() -> void:
	var request_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_WORLD_SNAPSHOT,
		{},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if request_error != OK:
		print("Wereldsnapshot aanvragen mislukt: %s" % error_string(request_error))
		return

	print("Client vraagt wereldsnapshot op.")



# de server verstuurt world snapshot/WorldSaveData dictionary naar de client
func _handle_world_snapshot_request(from_peer_id: int) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		print("Host heeft geen actieve wereldsnapshot.")
		return

	var world_snapshot: Dictionary = active_world.active_world_data.to_dictionary()

	var send_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_SNAPSHOT,
		{"world_snapshot": world_snapshot},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print("Wereldsnapshot versturen mislukt: %s" % error_string(send_error))
		return

	print("Wereldsnapshot verstuurd naar peer %d." % from_peer_id)



# ontvangen door clients, de payload is de worldsavedata dictionary 
func _handle_world_snapshot(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if pending_world_join_data == null:
		print("Wereldsnapshot ontvangen vóór WorldJoinData.")
		return

	var raw_snapshot: Variant = payload.get("world_snapshot")
	if not raw_snapshot is Dictionary:
		print("Ontvangen wereldsnapshot is geen Dictionary.")
		return

	if raw_snapshot.get("format_version") != WorldSaveData.FORMAT_VERSION:
		print("Wereldsnapshot heeft een onjuiste save-versie.")
		return

	var snapshot_data: WorldSaveData = WorldSaveData.from_dictionary(raw_snapshot)

	if snapshot_data.world_id.is_empty():
		print("Wereldsnapshot heeft geen world_id.")
		return

	if snapshot_data.world_id != pending_world_join_data.world_id:
		print("Wereldsnapshot hoort niet bij de eerder ontvangen wereldheader.")
		return

	pending_world_snapshot_data = snapshot_data

	print(
		"Wereldsnapshot ontvangen: %d gewijzigde muurchunks, %d grondchunks, %d cliffchunks."
		% [
			snapshot_data.modified_wall_ids.size(),
			snapshot_data.modified_ground_ids.size(),
			snapshot_data.modified_cliff_ids.size(),
		]
	)
	_start_received_world()



# deze start een wereld ontvangen van het netwerk (de clients)
func _start_received_world() -> void:
	if pending_world_snapshot_data == null:
		return

	if active_world != null or is_starting_world:
		return
		
	if pending_join_player_data == null:
		print("Geen speler geselecteerd voor deze join.")
		return

	var start_data: WorldStartData = WorldStartData.create(
		pending_world_snapshot_data,
		pending_join_player_data
	)

	print("Client start de ontvangen wereld.")
	start_world(start_data)



# client send dit packet als zijn world geladen is
func _send_client_world_ready() -> void:
	if active_world == null or active_world.local_player_data == null:
		return

	var player_data: PlayerSaveData = active_world.local_player_data

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.CLIENT_WORLD_READY,
		{
			"player_save": player_data.to_dictionary(),
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("CLIENT_WORLD_READY versturen mislukt: %s" % error_string(send_error))
		return

	print("Client meldt dat zijn wereld klaar is.")



# server behandeld het packet dat de client send als zijn world ingeladen is
func _handle_client_world_ready(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if session_players_by_peer_id.has(from_peer_id):
		return

	var raw_player_save: Variant = payload.get("player_save")

	if not raw_player_save is Dictionary:
		print("CLIENT_WORLD_READY bevat geen PlayerSaveData.")
		return

	var player_save_dictionary: Dictionary = raw_player_save

	if player_save_dictionary.get("format_version") != PlayerSaveData.FORMAT_VERSION:
		print("CLIENT_WORLD_READY bevat een onjuiste PlayerSaveData-versie.")
		return

	var player_save_data: PlayerSaveData = PlayerSaveData.from_dictionary(player_save_dictionary)

	if player_save_data.character_id.is_empty():
		print("CLIENT_WORLD_READY bevat geen character_id.")
		return

	var spawn_position: Vector2 = player_save_data.get_position_for_world(
		active_world.active_world_data.world_id,
		active_world.active_world_data.spawn_position
	)

	var session_player: SessionPlayer = SessionPlayer.create(
		from_peer_id,
		player_save_data.character_id,
		player_save_data.character_name,
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



# Stuurt alle spelers die de host kent naar één net gejointe client.
func _send_all_session_player_spawns_to(target_peer_id: int) -> void:
	for session_player: SessionPlayer in session_players_by_peer_id.values():
		_send_player_spawn(target_peer_id, session_player)



# Vertelt elke bestaande client dat er één nieuwe speler is bijgekomen.
func _announce_session_player_to_other_clients(new_session_player: SessionPlayer) -> void:
	for target_session_player: SessionPlayer in session_players_by_peer_id.values():
		var target_peer_id: int = target_session_player.peer_id

		# Peer 1 is de host zelf: die heeft deze remote speler al lokaal aangemaakt.
		if target_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			continue

		# De joinende client kreeg zichzelf al via de eerste functie.
		if target_peer_id == new_session_player.peer_id:
			continue

		_send_player_spawn(target_peer_id, new_session_player)



func _send_player_spawn(target_peer_id: int, session_player: SessionPlayer) -> void:
	if not NetworkManager.is_host():
		return

	if active_world == null:
		return

	var player_to_spawn: Player = active_world.get_player_for_peer(session_player.peer_id)

	if player_to_spawn == null:
		print("Kan PLAYER_SPAWN niet sturen: speler bestaat niet voor peer %d." % session_player.peer_id)
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



# word uitgevoerd na send player spawn
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

	var cached_snapshot: PlayerSnapshot = (latest_received_player_snapshots_by_peer_id[peer_id])
	
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

	# De host mag nooit onze lokale speler verwijderen.
	if despawned_peer_id == NetworkManager.get_local_peer_id():
		return

	active_world.despawn_remote_player(despawned_peer_id)

	print("Host verwijderde remote speler van peer %d." % despawned_peer_id)




func _send_player_despawn_to_remaining_clients(despawned_peer_id: int) -> void:
	for target_session_player: SessionPlayer in session_players_by_peer_id.values():
		var target_peer_id: int = target_session_player.peer_id

		# De host heeft zijn remote player al zelf verwijderd.
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

	var did_input_change: bool = (session_player.latest_movement_input != movement_input)

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
		var time_since_last_input_msec: int = (current_time_msec - session_player.last_input_received_time_msec)

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

			# De host heeft zijn eigen officiële wereld al lokaal.
			if target_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
				continue

			_send_player_state(target_peer_id, state_session_player, next_player_state_sequence)



## verstuurt PLAYER_STATE packet:  state_sequence | peer_id | global_position
func _send_player_state(target_peer_id: int, state_session_player: SessionPlayer, state_sequence: int) -> void:
	if active_world == null:
		return

	var state_player: Player = active_world.get_player_for_peer(state_session_player.peer_id)

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
		var previous_snapshot: PlayerSnapshot = (latest_received_player_snapshots_by_peer_id[received_snapshot.peer_id])

		if received_snapshot.state_sequence <= previous_snapshot.state_sequence:
			return

	var is_first_snapshot_for_peer: bool = (not latest_received_player_snapshots_by_peer_id.has(received_snapshot.peer_id))

	latest_received_player_snapshots_by_peer_id[received_snapshot.peer_id] = received_snapshot

	if is_first_snapshot_for_peer:
		print("Eerste PLAYER_STATE ontvangen voor peer %d." % received_snapshot.peer_id)

	if received_snapshot.peer_id == NetworkManager.get_local_peer_id():
		active_world.reconcile_local_player_position(received_snapshot.world_position)
		return

	active_world.apply_remote_player_snapshot(received_snapshot)






#endregion
