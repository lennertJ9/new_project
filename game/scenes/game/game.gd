extends Node
class_name Game

#preload van world
const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")


@export var skip_menu_for_debug: bool = false
@export var debug_world_seed: int = 12345


@onready var world_container: Node2D = $WorldContainer

@onready var main_menu: Control = $Interface/MainMenu
@onready var loading_screen: Control = $Interface/LoadingScreen


var active_world: World
var is_starting_world: bool = false
var pending_world_join_data: WorldJoinData
var pending_world_snapshot_data: WorldSaveData

func _ready() -> void:
	NetworkManager.session_approved_by_host.connect(_on_session_approved_by_host)
	NetworkManager.packet_received.connect(_on_network_packet_received)
	
	main_menu.world_start_requested.connect(start_world)
	main_menu.show()
	loading_screen.hide()
	
	if OS.is_debug_build() and skip_menu_for_debug:
		start_new_debug_world()


func start_new_debug_world() -> void:
	var world_data: WorldSaveData = WorldSaveData.create_new(debug_world_seed)
	var player_data: PlayerSaveData = PlayerSaveData.create_new()
	var players_to_start: Array[PlayerSaveData] = [player_data]

	var start_data: WorldStartData = WorldStartData.create(world_data, players_to_start)

	start_world(start_data)



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

	loading_screen.hide()
	is_starting_world = false



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



# de server verstuurt world snapshot naar de peer
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


#endregion
