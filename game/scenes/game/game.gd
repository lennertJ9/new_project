extends Node
class_name Game

#preload van world
const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")

@export var skip_menu_for_debug: bool = false
@export var debug_world_seed: int = 12345


@onready var world_container: Node2D = $WorldContainer
@onready var world_sync: WorldSync = $WorldSync
@onready var player_sync: PlayerSync = $PlayerSync
@onready var projectile_sync: ProjectileSync = $ProjectileSync

@onready var main_menu: Control = $Interface/MainMenu
@onready var loading_screen: Control = $Interface/LoadingScreen
@onready var in_game_menu: Control = $Interface/InGameMenu

var active_world: World
var is_starting_world: bool = false # geeft aan dat de wereld starting/loading is


func _ready() -> void:
	NetworkManager.session_approved_by_host.connect(_on_session_approved_by_host)
	NetworkManager.packet_received.connect(_on_network_packet_received)
	
	NetworkManager.host_started.connect(world_sync.on_host_started)
	NetworkManager.host_started.connect(player_sync.on_host_started)
	NetworkManager.host_started.connect(projectile_sync.on_host_started)
	NetworkManager.remote_peer_disconnected.connect(world_sync.on_remote_peer_disconnected)
	NetworkManager.remote_peer_disconnected.connect(player_sync.on_remote_peer_disconnected)
	world_sync.client_world_start_requested.connect(_on_client_world_start_requested)
	world_sync.client_world_ready.connect(player_sync.register_client_session)
	player_sync.local_player_ready.connect(_on_local_player_ready)
	
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

	# wachten totdat de wereld geladen is
	await active_world.initialize(start_data)

	world_sync.set_active_world(active_world)
	player_sync.set_active_world(active_world)
	projectile_sync.set_active_world(active_world)

	if NetworkManager.is_client():
		world_sync.notify_client_world_loaded()
	else:
		loading_screen.hide()
	
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
	if world_sync.handle_network_packet(from_peer_id, message_type, payload):
		return

	if player_sync.handle_network_packet(from_peer_id, message_type, payload):
		return

	projectile_sync.handle_network_packet(from_peer_id, message_type, payload)


func _on_multiplayer_toggle(enabled: bool):
	if enabled:
		var host_error = NetworkManager.start_host()
		if host_error != OK:
			print("host starten mislukt:", error_string(host_error))
			return
		
		print("host gestart op %d." % NetworkManager.DEFAULT_PORT)

# dit word uitgevoerd als je op de knop een wereld knop duwt
func _on_world_join_requested(address: String, host_port: int, player_data: PlayerSaveData) -> void:
	player_sync.prepare_for_client_join()
	world_sync.begin_join(address, host_port, player_data)



# word uitgevoerd door een joinende client nadat de server de sessie goedkeurd
func _on_session_approved_by_host() -> void:
	world_sync.request_world_join_data()

# WorldSync validated the snapshot and supplies the exact WorldStartData. Game
# remains responsible for creating the World scene and its UI lifecycle.
func _on_client_world_start_requested(start_data: WorldStartData) -> void:
	if active_world != null or is_starting_world:
		return

	print("Client start de ontvangen wereld.")
	start_world(start_data)


func _on_local_player_ready() -> void:
	loading_screen.hide()

#endregion
