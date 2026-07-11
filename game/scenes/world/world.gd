extends Node2D
class_name World

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D


@onready var label: Label = $CanvasLayer/Label # fps lable
@onready var player: Player = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var projectiles: Node2D = $Projectiles


@export var enemy_scene: PackedScene

var active_save_game: SaveGameData

var debug_mode: bool = false

var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array


func _ready() -> void:
	player.configure_world(chunk_manager, projectiles)
	player.set_controls_enabled(false)

	var a_star_manager: Node = get_node_or_null("/root/AStarManager")
	if a_star_manager != null and a_star_manager.has_method("configure"):
		a_star_manager.configure(chunk_manager)


#func _process(delta: float) -> void:
	#label.text = str(Engine.get_frames_per_second())


func initialize(save_game: SaveGameData) -> void:
	active_save_game = save_game
	apply_player_save_data(save_game)

	chunk_manager.start_world(save_game.world_seed)
	await chunk_manager.initial_area_loaded

	player.set_controls_enabled(true)


func apply_player_save_data(save_game: SaveGameData) -> void:
	if save_game.player_data.is_empty():
		return

	var first_player_data: Dictionary = save_game.player_data[0]
	if not first_player_data.has("position"):
		return

	var saved_position: Variant = first_player_data["position"]
	if saved_position is Vector2:
		player.global_position = saved_position
	elif saved_position is Vector2i:
		player.global_position = Vector2(float(saved_position.x), float(saved_position.y))



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		enemy.global_position = get_global_mouse_position()
		add_child(enemy)
