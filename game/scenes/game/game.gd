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


func _ready() -> void:
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
