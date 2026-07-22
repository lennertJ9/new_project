class_name MainMenu
extends Control

signal world_start_requested(start_data: WorldStartData)
signal world_join_requested(address: String, host_port: int, player_data: PlayerSaveData)

const HOME_SCREEN_SCENE: PackedScene = preload("uid://cb7pcw12vunvp")
const WORLD_SELECTION_SCREEN = preload("uid://nx0iq8j06dlb")
const PLAYER_SELECTION_SCREEN = preload("uid://rnkcqd175wv4")
const JOIN_WORLD_MENU = preload("uid://4lk3t2dcysgd")



@onready var screen_container: Control = $ScreenContainer

var current_screen: Control
var selected_world: WorldSaveData

var pending_join_address: String = ""
var pending_join_port: int = 0


func _ready() -> void:
	show_home_screen()


# openen van home screen (start game, join game & settings)
func show_home_screen() -> void:
	var home_screen: HomeScreen = show_screen(HOME_SCREEN_SCENE) as HomeScreen
	home_screen.start_game_requested.connect(show_world_selection)
	home_screen.join_game_requested.connect(show_join_world_selection)


#openen van world selection screen
func show_world_selection() -> void:
	var world_screen: WorldSelectionScreen = show_screen(WORLD_SELECTION_SCREEN) as WorldSelectionScreen
	world_screen.world_selected.connect(_on_world_selected)
	world_screen.back_requested.connect(show_home_screen)



func show_join_world_selection() -> void:
	var join_world_screen: JoinWorldScreen = show_screen(JOIN_WORLD_MENU) as JoinWorldScreen
	join_world_screen.world_join_requested.connect(_on_join_world_requested)


# openen van player selection screen
func show_player_selection() -> void:
	var player_screen: PlayerSelectionScreen = show_screen(PLAYER_SELECTION_SCREEN) as PlayerSelectionScreen

	player_screen.player_selected.connect(_on_player_selected)
	
	if pending_join_address.is_empty():
		player_screen.back_requested.connect(show_world_selection)
	else:
		player_screen.back_requested.connect(show_join_world_selection)



# elke wereld in dit menu is een knop
func _on_world_selected(world_data: WorldSaveData) -> void:
	selected_world = world_data
	show_player_selection()


# elke player in dit menu is een knop
func _on_player_selected(player_data: PlayerSaveData) -> void:
	if not pending_join_address.is_empty():
		var address: String = pending_join_address
		var host_port: int = pending_join_port

		pending_join_address = ""
		pending_join_port = 0

		world_join_requested.emit(address, host_port, player_data)
		return

	var start_data: WorldStartData = WorldStartData.create(
		selected_world,
		player_data
	)

	world_start_requested.emit(start_data)



func _on_join_world_requested(address: String, host_port: int) -> void:
	pending_join_address = address
	pending_join_port = host_port
	show_player_selection()



# deze functie bepaald welke ui te tonen
func show_screen(screen_scene: PackedScene) -> Control:
	if current_screen != null:
		current_screen.queue_free()

	current_screen = screen_scene.instantiate() as Control
	screen_container.add_child(current_screen)

	return current_screen
