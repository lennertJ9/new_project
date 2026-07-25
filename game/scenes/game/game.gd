extends Node
class_name Game

#preload van world
const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")



@export var skip_menu_for_debug: bool = false
@export var debug_world_seed: int = 12345


@onready var world_container: Node2D = $WorldContainer

@onready var main_menu: Control = $Interface/MainMenu
@onready var loading_screen: Control = $Interface/LoadingScreen
@onready var in_game_menu: Control = $Interface/InGameMenu


var active_world: World
var is_starting_world: bool = false # geeft aan dat de wereld starting/loading is
var pending_world_join_data: WorldJoinData
var pending_world_snapshot_data: WorldSaveData
var pending_join_player_data: PlayerSaveData
var session_players_by_peer_id: Dictionary[int, SessionPlayer] = {}



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

	await active_world.initialize(start_data)

	if NetworkManager.is_host():
		_register_host_session_player()

	loading_screen.hide()
	
	if NetworkManager.is_client():
		_send_client_world_ready()
	
	is_starting_world = false


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
		active_world.player.global_position
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
		spawn_position
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

	var spawn_position: Vector2 = session_player.world_position

	if session_player.peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
		spawn_position = active_world.player.global_position

	session_player.world_position = spawn_position

	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.PLAYER_SPAWN,
		{
			"peer_id": session_player.peer_id,
			"character_id": session_player.character_id,
			"character_name": session_player.character_name,
			"position": spawn_position,
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

	print("Remote speler ontvangen: peer %d (%s)." % [spawned_peer_id, raw_character_name])



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



#endregion
