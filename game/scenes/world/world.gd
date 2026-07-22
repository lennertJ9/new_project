extends Node2D
class_name World

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D
@export var enemy_scene: PackedScene


@onready var player: Player = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var projectiles: Node2D = $Projectiles
@onready var remote_players: Node2D = $RemotePlayers

const PLAYER_SCENE = preload("uid://bnr7g5ndf57a")

var remote_players_by_peer_id: Dictionary[int, Player] = {}
var active_world_data: WorldSaveData
var local_player_data: PlayerSaveData

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
	if active_world_data == null or local_player_data == null:
		return

	local_player_data.set_position_for_world(
		active_world_data.world_id,
		player.global_position
	)
	
	SaveService.save_player(local_player_data)
	SaveService.save_world(active_world_data)



func initialize(start_data: WorldStartData) -> void:
	active_world_data = start_data.world_data
	local_player_data = start_data.local_player_data
	apply_local_player_save_data()

	chunk_manager.start_world(active_world_data)
	await chunk_manager.initial_area_loaded

	player.set_controls_enabled(true)



func apply_local_player_save_data() -> void:
	if local_player_data == null:
		return

	player.global_position = local_player_data.get_position_for_world(
		active_world_data.world_id,
		active_world_data.spawn_position
	)



func spawn_remote_player(peer_id: int, spawn_position: Vector2) -> Player:
	if remote_players_by_peer_id.has(peer_id):
		return remote_players_by_peer_id[peer_id]

	var remote_player: Player = PLAYER_SCENE.instantiate() as Player

	var remote_camera: Camera2D = remote_player.get_node_or_null("Camera2D") as Camera2D

	if remote_camera != null:
		remote_camera.enabled = false

	remote_player.set_controls_enabled(false)

	remote_players.add_child(remote_player)

	remote_player.configure_world(chunk_manager, projectiles)
	remote_player.global_position = spawn_position
	remote_players_by_peer_id[peer_id] = remote_player

	print("Remote speler voor peer %d gespawned." % peer_id)

	return remote_player



func despawn_remote_player(peer_id: int) -> void:
	if not remote_players_by_peer_id.has(peer_id):
		return

	var remote_player: Player = remote_players_by_peer_id[peer_id]

	remote_players_by_peer_id.erase(peer_id)

	if remote_player != null:
		remote_player.queue_free()

	print("Remote speler voor peer %d verwijderd." % peer_id)
