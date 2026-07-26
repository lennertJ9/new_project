extends Node
class_name Game

#preload van world
const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")
const PLAYER_INPUT_TIMEOUT_MSEC: int = 250
const PLAYER_STATE_SEND_INTERVAL: float = 1.0 / 20.0
const WORLD_CATCH_UP_BATCH_LIMIT: int = 128

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

var host_world_revision: int = 0
var host_world_change_log: Array[Dictionary] = []
var host_snapshot_revision_by_peer_id: Dictionary[int, int] = {}
var host_sync_target_revision_by_peer_id: Dictionary[int, int] = {}
var host_world_live_peer_ids: Dictionary[int, bool] = {}

var client_snapshot_revision: int = -1
var client_last_applied_world_revision: int = -1
var client_world_sync_complete: bool = false
var client_gameplay_ready: bool = false

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
	if NetworkManager.is_client() and client_gameplay_ready:
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
	active_world.chunk_manager.wall_destroyed.connect(_on_host_wall_destroyed)

	if NetworkManager.is_host():
		_register_host_session_player()

	if NetworkManager.is_client():
		_send_client_world_loaded()
	else:
		loading_screen.hide()
	
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

		NetworkProtocol.MessageType.CLIENT_WORLD_LOADED:
			if NetworkManager.is_host():
				_handle_client_world_loaded(from_peer_id, payload)

		NetworkProtocol.MessageType.WORLD_CATCH_UP:
			if NetworkManager.is_client():
				_handle_world_catch_up(from_peer_id, payload)

		NetworkProtocol.MessageType.WORLD_SYNC_COMPLETE:
			if NetworkManager.is_client():
				_handle_world_sync_complete(from_peer_id, payload)
				
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
		
		NetworkProtocol.MessageType.WORLD_TILES_CHANGED:
			if NetworkManager.is_client():
				_handle_world_tiles_changed(from_peer_id, payload)



func _reset_host_world_sync_state() -> void:
	host_world_revision = 0
	host_world_change_log.clear()
	host_snapshot_revision_by_peer_id.clear()
	host_sync_target_revision_by_peer_id.clear()
	host_world_live_peer_ids.clear()



func _reset_client_world_sync_state() -> void:
	pending_world_join_data = null
	pending_world_snapshot_data = null
	client_snapshot_revision = -1
	client_last_applied_world_revision = -1
	client_world_sync_complete = false
	client_gameplay_ready = false



func _cleanup_host_peer_world_sync(peer_id: int) -> void:
	host_snapshot_revision_by_peer_id.erase(peer_id)
	host_sync_target_revision_by_peer_id.erase(peer_id)
	host_world_live_peer_ids.erase(peer_id)
	_trim_host_world_change_log()



# Het tijdelijke log bewaart alleen revisies die minstens één ladende client
# nog nodig kan hebben. Live clients ontvangen wijzigingen betrouwbaar direct.
func _trim_host_world_change_log() -> void:
	if host_snapshot_revision_by_peer_id.is_empty():
		host_world_change_log.clear()
		return

	var oldest_snapshot_revision: int = host_world_revision

	for snapshot_revision: int in host_snapshot_revision_by_peer_id.values():
		oldest_snapshot_revision = mini(oldest_snapshot_revision, snapshot_revision)

	while not host_world_change_log.is_empty():
		var oldest_batch: Dictionary = host_world_change_log[0]
		var oldest_batch_revision: int = int(oldest_batch.get("revision", -1))

		if oldest_batch_revision > oldest_snapshot_revision:
			break

		host_world_change_log.pop_front()



func _on_multiplayer_toggle(enabled: bool):
	if enabled:
		var host_error = NetworkManager.start_host()
		if host_error != OK:
			print("host starten mislukt:", error_string(host_error))
			return
		
		print("host gestart op %d." % NetworkManager.DEFAULT_PORT)



# uitgevoerd wanneer de server start
func _on_host_started() -> void:
	_reset_host_world_sync_state()
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

	_cleanup_host_peer_world_sync(peer_id)

	if not session_players_by_peer_id.has(peer_id):
		return

	session_players_by_peer_id.erase(peer_id)
	if active_world != null:
		active_world.despawn_remote_player(peer_id)

	_send_player_despawn_to_remaining_clients(peer_id)

	print("Sessiespeler van peer %d verwijderd." % peer_id)



# dit word uitgevoerd als je op de knop een wereld knop duwt
func _on_world_join_requested(address: String, host_port: int, player_data: PlayerSaveData) -> void:
	_reset_client_world_sync_state()
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

	var snapshot_revision: int = host_world_revision
	var world_snapshot: Dictionary = active_world.active_world_data.to_dictionary()

	host_snapshot_revision_by_peer_id[from_peer_id] = snapshot_revision
	host_sync_target_revision_by_peer_id.erase(from_peer_id)
	host_world_live_peer_ids.erase(from_peer_id)
	_trim_host_world_change_log()

	var send_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_SNAPSHOT,
		{
			"world_snapshot": world_snapshot,
			"snapshot_revision": snapshot_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		host_snapshot_revision_by_peer_id.erase(from_peer_id)
		_trim_host_world_change_log()
		print("Wereldsnapshot versturen mislukt: %s" % error_string(send_error))
		return

	print(
		"Wereldsnapshot op revisie %d verstuurd naar peer %d."
		% [snapshot_revision, from_peer_id]
	)



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

	var raw_snapshot_revision: Variant = payload.get("snapshot_revision")
	if not raw_snapshot_revision is int or raw_snapshot_revision < 0:
		print("Ontvangen wereldsnapshot heeft geen geldige revisie.")
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

	client_snapshot_revision = raw_snapshot_revision
	client_last_applied_world_revision = raw_snapshot_revision
	client_world_sync_complete = false
	pending_world_snapshot_data = snapshot_data

	print(
		"Wereldsnapshot R%d ontvangen: %d gewijzigde muurchunks, %d grondchunks, %d cliffchunks."
		% [
			client_snapshot_revision,
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



# De client meldt eerst alleen dat de lokale wereld vanuit het snapshot bestaat.
# De host stuurt daarna alle revisies die tijdens het laden zijn ontstaan.
func _send_client_world_loaded() -> void:
	if active_world == null or client_snapshot_revision < 0:
		return

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.CLIENT_WORLD_LOADED,
		{
			"snapshot_revision": client_snapshot_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("CLIENT_WORLD_LOADED versturen mislukt: %s" % error_string(send_error))
		return

	print("Client meldt dat snapshot R%d lokaal geladen is." % client_snapshot_revision)



# De host stuurt de ontbrekende revisies en zet de peer daarna over op de
# betrouwbare live-worldstream. Alle berichten gebruiken hetzelfde world-kanaal.
func _handle_client_world_loaded(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if session_players_by_peer_id.has(from_peer_id):
		return

	if not host_snapshot_revision_by_peer_id.has(from_peer_id):
		print("Peer %d meldde WORLD_LOADED zonder actief snapshot." % from_peer_id)
		return

	var raw_snapshot_revision: Variant = payload.get("snapshot_revision")
	if not raw_snapshot_revision is int or raw_snapshot_revision < 0:
		print("CLIENT_WORLD_LOADED bevat geen geldige snapshotrevisie.")
		return

	var expected_snapshot_revision: int = host_snapshot_revision_by_peer_id[from_peer_id]
	var received_snapshot_revision: int = raw_snapshot_revision

	if received_snapshot_revision != expected_snapshot_revision:
		print(
			"Peer %d laadde snapshot R%d, maar host verwacht R%d."
			% [from_peer_id, received_snapshot_revision, expected_snapshot_revision]
		)
		return

	var sync_target_revision: int = host_world_revision

	if not _send_world_catch_up(
		from_peer_id,
		expected_snapshot_revision,
		sync_target_revision
	):
		return

	var complete_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_SYNC_COMPLETE,
		{
			"world_revision": sync_target_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if complete_error != OK:
		print("WORLD_SYNC_COMPLETE versturen mislukt: %s" % error_string(complete_error))
		return

	# Vanaf dit punt komen nieuwe wijzigingen ná SYNC_COMPLETE op hetzelfde
	# betrouwbare kanaal terecht, dus de client kan geen revisie overslaan.
	host_sync_target_revision_by_peer_id[from_peer_id] = sync_target_revision
	host_world_live_peer_ids[from_peer_id] = true
	host_snapshot_revision_by_peer_id.erase(from_peer_id)
	_trim_host_world_change_log()

	print(
		"Catch-up R%d..R%d verstuurd naar peer %d."
		% [expected_snapshot_revision + 1, sync_target_revision, from_peer_id]
	)



func _send_world_catch_up(
	target_peer_id: int,
	after_revision: int,
	through_revision: int
) -> bool:
	var packet_batches: Array[Dictionary] = []

	for logged_batch: Dictionary in host_world_change_log:
		var batch_revision: int = int(logged_batch.get("revision", -1))

		if batch_revision <= after_revision or batch_revision > through_revision:
			continue

		packet_batches.append(logged_batch.duplicate(true))

		if packet_batches.size() >= WORLD_CATCH_UP_BATCH_LIMIT:
			if not _send_world_catch_up_packet(target_peer_id, packet_batches):
				return false
			packet_batches.clear()

	if not packet_batches.is_empty():
		if not _send_world_catch_up_packet(target_peer_id, packet_batches):
			return false

	return true



func _send_world_catch_up_packet(
	target_peer_id: int,
	batches: Array[Dictionary]
) -> bool:
	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.WORLD_CATCH_UP,
		{
			"batches": batches,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print("WORLD_CATCH_UP versturen mislukt: %s" % error_string(send_error))
		return false

	return true



# Pas na WORLD_SYNC_COMPLETE bevestigt de client dat hij gameplay-ready is.
func _send_client_world_ready() -> bool:
	if active_world == null or active_world.local_player_data == null:
		return false

	if client_last_applied_world_revision < 0:
		return false

	var player_data: PlayerSaveData = active_world.local_player_data

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.CLIENT_WORLD_READY,
		{
			"player_save": player_data.to_dictionary(),
			"world_revision": client_last_applied_world_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("CLIENT_WORLD_READY versturen mislukt: %s" % error_string(send_error))
		return false

	print(
		"Client meldt dat wereldrevisie R%d klaar is."
		% client_last_applied_world_revision
	)
	return true



# Server behandelt de definitieve ready-bevestiging na de catch-up.
func _handle_client_world_ready(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if session_players_by_peer_id.has(from_peer_id):
		return

	if not host_world_live_peer_ids.has(from_peer_id):
		print("CLIENT_WORLD_READY ontvangen voordat de worldstream live was.")
		return

	if not host_sync_target_revision_by_peer_id.has(from_peer_id):
		print("CLIENT_WORLD_READY ontvangen zonder syncdoel.")
		return

	var raw_world_revision: Variant = payload.get("world_revision")
	if not raw_world_revision is int or raw_world_revision < 0:
		print("CLIENT_WORLD_READY bevat geen geldige wereldrevisie.")
		return

	var expected_world_revision: int = host_sync_target_revision_by_peer_id[from_peer_id]
	var received_world_revision: int = raw_world_revision

	if received_world_revision != expected_world_revision:
		print(
			"Peer %d bevestigde R%d, maar host verwachtte R%d."
			% [from_peer_id, received_world_revision, expected_world_revision]
		)
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
	host_sync_target_revision_by_peer_id.erase(from_peer_id)

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
		active_world.player.set_controls_enabled(true)
		client_gameplay_ready = true
		loading_screen.hide()
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



## Bij een vernietigde muur registreert de host één nieuwe wereldrevisie.
func _on_host_wall_destroyed(tile_position: Vector2i, _destroyed_wall_id: int) -> void:
	if not NetworkManager.is_host():
		return

	var tile_change: WorldTileChange = WorldTileChange.create(tile_position, Chunk.TileLayer.WALL, 0)
	var tile_changes: Array[WorldTileChange] = [tile_change]

	_broadcast_world_tile_changes(tile_changes)



## Logt de wijziging voor ladende peers en stuurt ze direct naar live peers.
func _broadcast_world_tile_changes(tile_changes: Array[WorldTileChange]) -> void:
	if not NetworkManager.is_host():
		return

	if tile_changes.is_empty():
		return

	var serialized_changes: Array[Dictionary] = []

	for tile_change: WorldTileChange in tile_changes:
		serialized_changes.append(tile_change.to_dictionary())

	host_world_revision += 1
	var change_revision: int = host_world_revision
	var logged_batch: Dictionary = {
		"revision": change_revision,
		"changes": serialized_changes.duplicate(true),
	}

	host_world_change_log.append(logged_batch)
	_trim_host_world_change_log()

	for target_peer_id: int in host_world_live_peer_ids.keys():
		_send_live_world_tile_changes(
			target_peer_id,
			change_revision,
			serialized_changes
		)



func _send_live_world_tile_changes(
	target_peer_id: int,
	change_revision: int,
	serialized_changes: Array[Dictionary]
) -> void:
	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.WORLD_TILES_CHANGED,
		{
			"revision": change_revision,
			"changes": serialized_changes,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print(
			"WORLD_TILES_CHANGED R%d versturen mislukt: %s."
			% [change_revision, error_string(send_error)]
		)



func _handle_world_catch_up(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_batches: Variant = payload.get("batches")
	if not raw_batches is Array or raw_batches.is_empty():
		return

	for raw_batch: Variant in raw_batches:
		if not raw_batch is Dictionary:
			print("WORLD_CATCH_UP bevat een ongeldige batch.")
			return

		var batch: Dictionary = raw_batch
		var raw_revision: Variant = batch.get("revision")

		if not raw_revision is int or raw_revision < 0:
			print("WORLD_CATCH_UP bevat een ongeldige revisie.")
			return

		if not _apply_client_world_change_batch(
			raw_revision,
			batch.get("changes")
		):
			return



func _handle_world_sync_complete(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null or client_snapshot_revision < 0:
		return

	var raw_world_revision: Variant = payload.get("world_revision")
	if not raw_world_revision is int or raw_world_revision < 0:
		print("WORLD_SYNC_COMPLETE bevat geen geldige revisie.")
		return

	var sync_revision: int = raw_world_revision

	if sync_revision != client_last_applied_world_revision:
		print(
			"World-sync heeft een revisiegat: client staat op R%d, host eindigt op R%d."
			% [client_last_applied_world_revision, sync_revision]
		)
		return

	if _send_client_world_ready():
		client_world_sync_complete = true



## Uitgevoerd bij het ontvangen van een live WORLD_TILES_CHANGED-packet.
func _handle_world_tiles_changed(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_revision: Variant = payload.get("revision")
	if not raw_revision is int or raw_revision < 0:
		print("WORLD_TILES_CHANGED bevat geen geldige revisie.")
		return

	_apply_client_world_change_batch(raw_revision, payload.get("changes"))



func _apply_client_world_change_batch(
	change_revision: int,
	raw_changes: Variant
) -> bool:
	if active_world == null:
		return false

	# Absolute tile-state mag bij een herhaald betrouwbaar packet veilig worden
	# genegeerd wanneer deze revisie al verwerkt is.
	if change_revision <= client_last_applied_world_revision:
		return true

	var expected_revision: int = client_last_applied_world_revision + 1

	if change_revision != expected_revision:
		print(
			"World-change revisiegat: verwacht R%d, ontving R%d."
			% [expected_revision, change_revision]
		)
		return false

	if not raw_changes is Array or raw_changes.is_empty():
		print("World-change R%d bevat geen wijzigingen." % change_revision)
		return false

	var tile_changes: Array[WorldTileChange] = []

	for raw_change: Variant in raw_changes:
		if not raw_change is Dictionary:
			return false

		var change_dictionary: Dictionary = raw_change
		var tile_change: WorldTileChange = WorldTileChange.from_dictionary(change_dictionary)

		if tile_change == null:
			return false

		tile_changes.append(tile_change)

	for tile_change: WorldTileChange in tile_changes:
		var applied: bool = active_world.chunk_manager.apply_world_tile_change(tile_change)

		if not applied:
			print(
				"Niet-ondersteunde world tile change ontvangen voor laag %d."
				% tile_change.layer
			)
			return false

	client_last_applied_world_revision = change_revision
	return true



#endregion
