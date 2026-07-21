extends Node2D
class_name World

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D



@onready var player: Player = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var projectiles: Node2D = $Projectiles


@export var enemy_scene: PackedScene

var active_world_data: WorldSaveData
var active_player_data: Array[PlayerSaveData] = []

var debug_mode: bool = false

var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array

var save_interval: float = 3
var save_timer: float


func _ready() -> void:
	player.configure_world(chunk_manager, projectiles)
	player.set_controls_enabled(false)

	var a_star_manager: Node = get_node_or_null("/root/AStarManager")
	if a_star_manager != null and a_star_manager.has_method("configure"):
		a_star_manager.configure(chunk_manager)



func _process(delta: float) -> void:
	if NetworkManager.is_client():
		return
	save_timer += delta
	if save_timer > save_interval:
		save_timer = 0
		save_active_state()



func save_active_state():
	
	var player_data: PlayerSaveData = active_player_data[0]
	player_data.set_position_for_world(active_world_data.world_id, player.global_position)
	
	SaveService.save_player(active_player_data[0])
	SaveService.save_world(active_world_data)



func initialize(start_data: WorldStartData) -> void:
	active_world_data = start_data.world_data
	active_player_data = start_data.players_data
	apply_first_player_save_data()

	chunk_manager.start_world(active_world_data)
	await chunk_manager.initial_area_loaded

	player.set_controls_enabled(true)



func apply_first_player_save_data() -> void:
	if active_player_data.is_empty():
		return

	var first_player_data: PlayerSaveData = active_player_data[0]
	player.global_position = first_player_data.get_position_for_world(active_world_data.world_id, active_world_data.spawn_position)
