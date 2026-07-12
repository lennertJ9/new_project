## idee voor later:
##
## tilemappattern
## tijdens het generaten per chunk een tilemappattern maken
## tijdens het laden is set_cell nietmeer nodig omdat we gwn een tilemappattern inladen
##

extends Node2D
class_name ChunkManager

const WALL_DATABASE := preload("res://scenes/tile_database/wall_database.gd")
const CHUNK_SIZE := 16
const CHUNK_PIXEL_SIZE: int = CHUNK_SIZE * 16
const GENERATION_PADDING: int = 1


signal chunk_deloaded
signal neighbours_checked
signal wall_damaged(tile_position: Vector2i, remaining_health: int)
signal wall_destroyed(tile_position: Vector2i, wall_id: int)
signal initial_area_loaded


@export var player: CharacterBody2D

# NOISES -----------------------------------#
@export var noise_tex: NoiseTexture2D
@export var noise_tex_cliff: NoiseTexture2D
var noise: FastNoiseLite
var noise_cliff: FastNoiseLite

# ---------------------- #

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var object_layer: TileMapLayer = $ObjectLayer
@onready var cliff_layer: TileMapLayer = $CliffLayer



@onready var debug_layer: TileMapLayer = $DebugLayer


@onready var autotiling: autotiler = $Autotiling
@onready var object_generator: Node = $ObjectGenerator


var render_distance: int = 3
var cpu_generator_delay: int = 25
var cpu_load_delay: int = 25

#-------------- Chunks  --------------------#
var generated_chunks: Dictionary[Vector2i, Chunk] # pure data, deze chunks zijn niet perse autotiled
var loaded_chunks: Array[Chunk] # loaded chunks, actief en autotiled
# --> nieuwe aanpak, generated chunks worden hierin gezet, hierdoor loopen, if alle 8 buren: append naar chunks_to_autotile

#-------------- Chunk die processed moeten worden  --------------------#
var chunks_to_data_generate: Dictionary[Vector2i, Chunk] # chunks die data generated moeten worden 
var data_generated_chunks: Array[Chunk]

var chunks_to_autotile: Dictionary[Vector2i, Chunk] # chunks die autotiled moeten worden en waarvan alle 8 buren aanwezig zijn
var autotiled_chunks: Array[Chunk]

var neighbourless_chunks: Array[Vector2i] # positions van generated chunks die mogelijks niet alle 8 buren hebben om geautotiled te worden
var neigbhoured_chunks: Array[Chunk]

var chunks_to_load: Array[Chunk] # chunks die loaded moeten worden, deze zijn autotiled
var chunks_to_unload: Array[Chunk] # chunks die unloaded moeten worden

var generation_mutex := Mutex.new()
var world_data_mutex := Mutex.new()
var lifecycle_mutex := Mutex.new()

var is_world_running: bool = false
var initial_area_is_loaded: bool = false


# ------------- Check Timers --------------#
var chunk_check_interval: float = 0.2
var chunk_load_interval: float = 0.002
var chunk_unload_interval: float = 0.002

var chunk_check_timer: float = 0
var chunk_load_timer: float = 0
var chunk_unload_timer: float = 0

# -------------- threads ------------------------------------------- #
var thread_chunk_generator: Thread = Thread.new()
# ------------------------------------------------------------------ #

										 #top          #top-right      #right         #bottom-right   #bottom         #bottom-left     #left          #top-left
var chunk_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), 
										Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1),  
  
]



func _ready() -> void:
	set_process(false)
	noise = noise_tex.noise as FastNoiseLite
	noise_cliff = noise_tex_cliff.noise as FastNoiseLite
	autotiling.configure(self)


func start_world(world_seed: int) -> void:
	if is_running():
		return

	noise.seed = world_seed
	noise_cliff.seed = world_seed + 1
	initial_area_is_loaded = false

	set_running(true)
	autotiling.start_worker()
	thread_chunk_generator.start(chunk_generator)
	set_process(true)
	chunk_check()


func shutdown() -> void:
	if not is_running():
		return

	set_process(false)
	set_running(false)
	autotiling.stop_worker()

	if thread_chunk_generator.is_started():
		thread_chunk_generator.wait_to_finish()


func _exit_tree() -> void:
	shutdown()


func set_running(value: bool) -> void:
	lifecycle_mutex.lock()
	is_world_running = value
	lifecycle_mutex.unlock()


func is_running() -> bool:
	lifecycle_mutex.lock()
	var running: bool = is_world_running
	lifecycle_mutex.unlock()
	return running



func _process(delta: float) -> void:
	if not is_running():
		return

	process_data_generated_chunks()
	process_autotiled_chunks()
	chunk_check_timer += delta
	chunk_load_timer += delta
	chunk_unload_timer += delta
	
	if chunk_check_timer > chunk_check_interval:
		chunk_check()
		chunk_check_timer = 0
		
	if chunk_load_timer > chunk_load_interval:
		chunk_loader()
		chunk_load_timer = 0
	
	if chunk_unload_timer > chunk_unload_interval:
		chunk_unloader()
		chunk_unload_timer = 0

	if not initial_area_is_loaded and are_visible_chunks_loaded():
		initial_area_is_loaded = true
		initial_area_loaded.emit()


func process_data_generated_chunks():
	var results: Array[Chunk] = []

	generation_mutex.lock()
	results = data_generated_chunks.duplicate()
	data_generated_chunks.clear()
	generation_mutex.unlock()

	if results.is_empty():
		return

	world_data_mutex.lock()
	for chunk in results:
		generated_chunks[chunk.position] = chunk
		chunk.state = Chunk.ChunkState.WAITING_FOR_NEIGHBOURS
		neighbourless_chunks.append(chunk.position)
	world_data_mutex.unlock()
	chunk_neighbour_checker()



func process_autotiled_chunks() -> void:
	var results: Array[Chunk] = []

	autotiling.autotile_mutex.lock()
	results = autotiling.autotiled_chunks.duplicate()
	autotiling.autotiled_chunks.clear()
	autotiling.autotile_mutex.unlock()

	if results.is_empty():
		return

	for chunk in results:
		chunk.state = Chunk.ChunkState.UNLOADED



func chunk_neighbour_checker():
	var ready_to_autotile: Array[Chunk] = []

	world_data_mutex.lock()
	for i in range(neighbourless_chunks.size() - 1, -1, -1):
		var chunk_pos = neighbourless_chunks[i]
		var is_neighboured = true

		for offset in chunk_neighbours:
			if not generated_chunks.has(chunk_pos + offset):
				is_neighboured = false
				break

		if is_neighboured:
			var chunk = generated_chunks[chunk_pos]
			chunk.state = Chunk.ChunkState.QUEUED_AUTOTILE
			ready_to_autotile.append(chunk)
			neighbourless_chunks.remove_at(i)
	world_data_mutex.unlock()

	if ready_to_autotile.is_empty():
		return

	autotiling.autotile_mutex.lock()
	for chunk in ready_to_autotile:
		autotiling.chunks_to_autotile[chunk.position] = chunk
	autotiling.autotile_mutex.unlock()



func chunk_generator():
	while is_running():
		OS.delay_msec(cpu_generator_delay)
		if not is_running():
			break

		var chunk: Chunk = null

		generation_mutex.lock()

		if not chunks_to_data_generate.is_empty():
			var chunk_pos: Vector2i = chunks_to_data_generate.keys()[0]
			chunk = chunks_to_data_generate[chunk_pos]
			chunks_to_data_generate.erase(chunk_pos)

		generation_mutex.unlock()

		if chunk == null:
			continue

		chunk.state = Chunk.ChunkState.GENERATING

		var i: int = 0
		for y in range(16):
			for x in range(16):
				var global_pos = chunk.position * 16 + Vector2i(x, y)
				var random = noise.get_noise_2dv(global_pos)

				if random > 0.1:
					chunk.wall_id_layer[i] = 1

				chunk.ground_id_layer[i] = 2
				i += 1

		generate_cliffs(chunk)

		chunk.state = Chunk.ChunkState.DATA_READY

		generation_mutex.lock()
		data_generated_chunks.append(chunk)
		generation_mutex.unlock()







func chunk_loader():
	if not chunks_to_load.is_empty():
		var chunk: Chunk = chunks_to_load.pop_front()
		var i = 0
		
		for y_pos in range(16):
			for x_pos in range(16):
				
				
				var tile_pos := Vector2i(x_pos, y_pos) + chunk.position * CHUNK_SIZE

				if chunk.wall_id_layer[i] != 0:
					wall_layer.set_cell(tile_pos, chunk.wall_id_layer[i], chunk.unpack_atlas(chunk.wall_atlas_coords[i]))
				else:
					wall_layer.erase_cell(tile_pos)
				
				if chunk.cliff_id_layer[i] != 0:
					cliff_layer.set_cell(tile_pos, chunk.cliff_id_layer[i], chunk.unpack_atlas(chunk.cliff_atlas_coords[i]))
				else:
					cliff_layer.erase_cell(tile_pos)
				
				if chunk.ground_id_layer[i] != 0:
					ground_layer.set_cell(tile_pos, chunk.ground_id_layer[i], chunk.unpack_atlas(chunk.ground_atlas_coords[i]))
				else:
					ground_layer.erase_cell(tile_pos)
				i += 1
		
		chunk.state = Chunk.ChunkState.LOADED
		loaded_chunks.append(chunk)


# chunk worden geload wanneer: in generated lijst | niet al loaded of queued voor loading zijn | autotiled zijn 
func chunk_check() -> void:
	if player == null:
		return

	var player_chunk_position: Vector2i = get_player_chunk_position()
	var data_generation_distance: int = render_distance + GENERATION_PADDING

	queue_missing_chunk_data(player_chunk_position, data_generation_distance)
	queue_chunks_for_load(player_chunk_position, render_distance)
	queue_expired_chunks_for_unload()


func get_player_chunk_position() -> Vector2i:
	return Vector2i(
		floori(player.global_position.x / float(CHUNK_PIXEL_SIZE)),
		floori(player.global_position.y / float(CHUNK_PIXEL_SIZE))
	)


func queue_missing_chunk_data(center_chunk_position: Vector2i, distance: int) -> void:
	world_data_mutex.lock()
	generation_mutex.lock()

	for x in range(center_chunk_position.x - distance, center_chunk_position.x + distance + 1):
		for y in range(center_chunk_position.y - distance, center_chunk_position.y + distance + 1):
			var chunk_position: Vector2i = Vector2i(x, y)
			if generated_chunks.has(chunk_position):
				continue
			if chunks_to_data_generate.has(chunk_position):
				continue

			var chunk: Chunk = Chunk.new(chunk_position)
			chunk.state = Chunk.ChunkState.QUEUED_GENERATE
			chunks_to_data_generate[chunk_position] = chunk

	generation_mutex.unlock()
	world_data_mutex.unlock()


func queue_chunks_for_load(center_chunk_position: Vector2i, distance: int) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	world_data_mutex.lock()
	for x in range(center_chunk_position.x - distance, center_chunk_position.x + distance + 1):
		for y in range(center_chunk_position.y - distance, center_chunk_position.y + distance + 1):
			var chunk_position: Vector2i = Vector2i(x, y)
			if not generated_chunks.has(chunk_position):
				continue

			var chunk: Chunk = generated_chunks[chunk_position]
			if chunk.state == Chunk.ChunkState.AUTOTILED or chunk.state == Chunk.ChunkState.UNLOADED:
				chunk.state = Chunk.ChunkState.QUEUED_LOAD
				chunks_to_load.append(chunk)

			chunk.last_accessed = current_time
	world_data_mutex.unlock()


func queue_expired_chunks_for_unload() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	for i in range(loaded_chunks.size() - 1, -1, -1):
		var chunk: Chunk = loaded_chunks[i]
		var seconds_since_access: float = current_time - chunk.last_accessed
		if seconds_since_access <= 2.0:
			continue
		if chunk.state == Chunk.ChunkState.QUEUED_UNLOAD:
			continue

		chunk.state = Chunk.ChunkState.QUEUED_UNLOAD
		chunks_to_unload.append(chunk)
		loaded_chunks.remove_at(i)


func are_visible_chunks_loaded() -> bool:
	if player == null:
		return false

	var player_chunk_position: Vector2i = get_player_chunk_position()

	world_data_mutex.lock()
	for x in range(player_chunk_position.x - render_distance, player_chunk_position.x + render_distance + 1):
		for y in range(player_chunk_position.y - render_distance, player_chunk_position.y + render_distance + 1):
			var chunk_position: Vector2i = Vector2i(x, y)
			if not generated_chunks.has(chunk_position):
				world_data_mutex.unlock()
				return false

			var chunk: Chunk = generated_chunks[chunk_position]
			if chunk.state != Chunk.ChunkState.LOADED:
				world_data_mutex.unlock()
				return false
	world_data_mutex.unlock()

	return true



func chunk_unloader():
	if not chunks_to_unload.is_empty():
		var chunk = chunks_to_unload.pop_front()
		for x in range(16):
			for y in range(16):
				var tile_pos = (chunk.position * 16) + Vector2i(x,y)
				ground_layer.erase_cell(tile_pos)
				wall_layer.erase_cell(tile_pos)
				cliff_layer.erase_cell(tile_pos)
		chunk.state = chunk.ChunkState.UNLOADED
		chunk_deloaded.emit(chunk)



func generate_cliffs(chunk: Chunk):
	var i = 0
	for y in range(16):
		for x in range(16):
			var global_pos = chunk.position * 16 + Vector2i(x,y)
			var random = noise_cliff.get_noise_2dv(global_pos)
			if random > 0.18 and chunk.wall_id_layer[i] == 0:
				chunk.ground_id_layer[i] = 0
				chunk.cliff_id_layer[i] = 1
				
			i += 1



func global_to_chunk_local(global_pos: Vector2):
	var tile_pos := Vector2i(
		floori(global_pos.x / 16.0),
		floori(global_pos.y / 16.0)
	)
	var chunk_local_pos = Vector2i(
		posmod(tile_pos.x, CHUNK_SIZE),
		posmod(tile_pos.y, CHUNK_SIZE)
		)
	return chunk_local_pos



func damage_wall(world_position: Vector2, damage: int = 40) -> bool:
	var tile_position: Vector2i = wall_layer.local_to_map(wall_layer.to_local(world_position))
	return damage_wall_tile(tile_position, damage)


func damage_wall_tile(tile_position: Vector2i, damage: int) -> bool:
	if damage <= 0:
		return false

	var dirty_tiles := get_wall_dirty_tiles(tile_position)
	var destroyed_wall_id := 0

	world_data_mutex.lock()
	var chunk_position := get_chunk_position_from_tile(tile_position)
	if not generated_chunks.has(chunk_position):
		world_data_mutex.unlock()
		return false

	var chunk: Chunk = generated_chunks[chunk_position]
	var local_position := get_local_tile_position(tile_position)
	var local_index := chunk.local_vector_to_index(local_position)
	var wall_id := chunk.wall_id_layer[local_index]
	if wall_id == 0:
		world_data_mutex.unlock()
		return false

	var wall_stats: Dictionary = WALL_DATABASE.WALL_STATS.get(wall_id, {})
	if wall_stats.is_empty() or not wall_stats.get("damageable", false):
		world_data_mutex.unlock()
		return false

	var current_health := chunk.wall_health_layer[local_index]
	if current_health == 0:
		current_health = int(wall_stats.get("max_health", 0))

	current_health -= damage
	if current_health > 0:
		chunk.wall_health_layer[local_index] = current_health
		world_data_mutex.unlock()
		wall_damaged.emit(tile_position, current_health)
		return true

	chunk.wall_id_layer[local_index] = 0
	chunk.wall_health_layer[local_index] = 0
	destroyed_wall_id = wall_id

	# Only the destroyed tile and its neighbours can have a changed bitmask.
	for dirty_tile in dirty_tiles:
		autotiling.autotile_wall_tile(dirty_tile)
		autotiling.autotile_ground_tile(dirty_tile)
	world_data_mutex.unlock()

	refresh_wall_tiles(dirty_tiles)
	refresh_ground_tiles(dirty_tiles)
	wall_destroyed.emit(tile_position, destroyed_wall_id)

	return true


func get_chunk_position_from_tile(tile_position: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(tile_position.x) / CHUNK_SIZE),
		floori(float(tile_position.y) / CHUNK_SIZE)
	)


func get_local_tile_position(tile_position: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(tile_position.x, CHUNK_SIZE),
		posmod(tile_position.y, CHUNK_SIZE)
	)


func get_wall_dirty_tiles(center_tile: Vector2i) -> Array[Vector2i]:
	var dirty_tiles: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			dirty_tiles.append(center_tile + Vector2i(x, y))
	return dirty_tiles


func refresh_wall_tiles(tile_positions: Array[Vector2i]) -> void:
	world_data_mutex.lock()
	for tile_position in tile_positions:
		var chunk_position := get_chunk_position_from_tile(tile_position)
		if not generated_chunks.has(chunk_position):
			continue

		var chunk: Chunk = generated_chunks[chunk_position]
		if chunk.state != Chunk.ChunkState.LOADED:
			continue

		var index := chunk.local_vector_to_index(get_local_tile_position(tile_position))
		var wall_id := chunk.wall_id_layer[index]
		if wall_id == 0:
			wall_layer.erase_cell(tile_position)
		else:
			wall_layer.set_cell(tile_position, wall_id, chunk.unpack_atlas(chunk.wall_atlas_coords[index]))
	world_data_mutex.unlock()


func refresh_ground_tiles(tile_positions: Array[Vector2i]) -> void:
	world_data_mutex.lock()
	for tile_position in tile_positions:
		var chunk_position := get_chunk_position_from_tile(tile_position)
		if not generated_chunks.has(chunk_position):
			continue

		var chunk: Chunk = generated_chunks[chunk_position]
		if chunk.state != Chunk.ChunkState.LOADED:
			continue

		var index := chunk.local_vector_to_index(get_local_tile_position(tile_position))
		var ground_id := chunk.ground_id_layer[index]
		if ground_id == 0:
			ground_layer.erase_cell(tile_position)
		else:
			ground_layer.set_cell(tile_position, ground_id, chunk.unpack_atlas(chunk.ground_atlas_coords[index]))
	world_data_mutex.unlock()
