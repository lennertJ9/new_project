extends Node
class_name Game


const WORLD_SCENE: PackedScene = preload("uid://bt2absuqhkyvq")


@export var skip_menu_for_debug: bool = false
@export var debug_world_seed: int = 12345


@onready var world_container: Node2D = $WorldContainer

@onready var main_menu: Control = $Interface/MainMenu
@onready var loading_screen: Control = $Interface/LoadingScreen


var active_world: World
var is_starting_world: bool = false


func _ready() -> void:
	main_menu.show()
	loading_screen.hide()
	
	if OS.is_debug_build() and skip_menu_for_debug:
		start_new_debug_world()


func start_new_debug_world() -> void:
	var save_game: SaveGameData = SaveGameData.create_new(debug_world_seed)
	start_world(save_game)


func start_world(save_game: SaveGameData) -> void:
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

	await active_world.initialize(save_game)

	loading_screen.hide()
	is_starting_world = false
