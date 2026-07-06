## idee voor later:
##
## tilemappattern
## tijdens het generaten per chunk een tilemappattern maken
## tijdens het laden is set_cell nietmeer nodig omdat we gwn een tilemappattern inladen
##

extends Node2D
class_name ChunkManager

signal chunk_generated
signal chunk_deloaded
signal neighbours_checked


@export var player: CharacterBody2D

# NOISES -----------------------------------#
@export var noise_tex: NoiseTexture2D
@export var noise_tex_cliff: NoiseTexture2D
var noise: Noise
var noise_cliff: Noise

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

# ------------- Check Timers --------------#
var chunk_check_interval: float = 0.2
var chunk_load_interval: float = 0.002
var chunk_unload_interval: float = 0.002

var chunk_check_timer: float = 0
var chunk_load_timer: float = 0
var chunk_unload_timer: float = 0

# -------------- threads ------------------------------------------- #
var thread_chunk_generator: Thread = Thread.new()
var thread_chunk_autotiler: Thread = Thread.new()
var thread_neighbour_checker: Thread = Thread.new()
# ------------------------------------------------------------------ #

										 #top          #top-right      #right         #bottom-right   #bottom         #bottom-left     #left          #top-left
var chunk_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), 
										Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1),  
  
]



func _ready() -> void:
	await get_tree().physics_frame
	set_process(true)
	thread_chunk_generator.start(chunk_generator)
	
	
	#player = get_tree().get_first_node_in_group("world").camera
	noise = noise_tex.noise
	noise_cliff = noise_tex_cliff.noise



func _process(delta: float) -> void:
	process_data_generated_chunks()
	
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


func process_data_generated_chunks():
	var results: Array[Chunk] = []

	generation_mutex.lock()
	results = data_generated_chunks.duplicate()
	data_generated_chunks.clear()
	generation_mutex.unlock()

	for chunk in results:
		generated_chunks[chunk.position] = chunk
		chunk.state = Chunk.ChunkState.WAITING_FOR_NEIGHBOURS
		chunk.is_generated = true
		neighbourless_chunks.append(chunk.position)
	chunk_neighbour_checker()


func chunk_neighbour_checker():
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
			autotiling.chunks_to_autotile[chunk_pos] = chunk
			neighbourless_chunks.remove_at(i)



func chunk_generator():
	while true:
		OS.delay_msec(cpu_generator_delay)

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
				
				
				if chunk.wall_id_layer[i]: # omdat niet elke x,y een wall heeft, anders overal muur
					wall_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 1, chunk.unpack_atlas(chunk.wall_atlas_coords[i])) 
				
				if chunk.cliff_id_layer[i]:
					cliff_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 1, chunk.unpack_atlas(chunk.cliff_atlas_coords[i]))
				
				ground_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, chunk.ground_id_layer[i],chunk.unpack_atlas(chunk.ground_atlas_coords[i]))
				i += 1
				
		chunk.is_loaded = true
		chunk.is_queued_load = false
		loaded_chunks.append(chunk)


# chunk worden geload wanneer: in generated lijst | niet al loaded of queued voor loading zijn | autotiled zijn 
func chunk_check():
	var player_chunk_coord = floor(player.global_position / 256)
	var start_coord: Vector2 = player_chunk_coord - Vector2(render_distance, render_distance) 
	var end_coord: Vector2 = player_chunk_coord + Vector2(render_distance, render_distance) 
	
	for coord_x in range(start_coord.x, end_coord.x + 1):
		for coord_y in range(start_coord.y, end_coord.y + 1):
			var chunk_pos = Vector2i(coord_x, coord_y)
			
			if generated_chunks.has(chunk_pos):
				var chunk: Chunk = generated_chunks[chunk_pos]
				if not chunk.is_loaded and not chunk.is_queued_load and chunk.is_autotiled:
					generated_chunks[chunk_pos].is_queued_load = true
					chunks_to_load.append(generated_chunks[chunk_pos])
			
			else:
				generation_mutex.lock()
				if not chunks_to_data_generate.has(chunk_pos) and not generated_chunks.has(chunk_pos):
					chunks_to_data_generate[chunk_pos] = Chunk.new(chunk_pos)
					# GENERATING CHUNK
					
				generation_mutex.unlock()
					
			if generated_chunks.has(chunk_pos):
				generated_chunks[chunk_pos].last_accessed = Time.get_ticks_msec() / 1000
				# SET CHUNK TIMER
	
	for chunk in loaded_chunks:
		if (Time.get_ticks_msec() /1000) - chunk.last_accessed > 2 and not chunk.is_queued_unload:
			chunk.is_queued_unload = true
			chunks_to_unload.append(chunk)
			# verwijderen van chunk met call defered?
			
			loaded_chunks.erase.call_deferred(chunk)



func chunk_unloader():
	if not chunks_to_unload.is_empty():
		var chunk = chunks_to_unload.pop_front()
		for x in range(16):
			for y in range(16):
				var tile_pos = (chunk.position * 16) + Vector2i(x,y)
				ground_layer.erase_cell(tile_pos)
				wall_layer.erase_cell(tile_pos)
		chunk.is_queued_unload = false
		chunk.is_loaded = false
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
	var tile_pos = global_pos / 16
	var chunk_local_pos = Vector2i(
		posmod(tile_pos.x, 16),
		posmod(tile_pos.y, 16)
		)
	return chunk_local_pos



func damage_wall(global_pos: Vector2):
	var chunk_pos = floor(global_pos / 256)
	
	var global_tile_pos = floor(global_pos / 16)
	
	
	print(global_tile_pos)
	
	var chunk = generated_chunks[chunk_pos]
	var chunk_local_tile_pos = global_to_chunk_local(global_pos)
	var local_index = chunk.local_vector_to_index(chunk_local_tile_pos)
	var wall_type_id = 1
	
	var damage = 40
	print("local index: ", local_index)
	if chunk.wall_health.has(local_index):
		chunk.wall_health[local_index] -=  damage
		if chunk.wall_health[local_index] < 0:
			wall_layer.erase_cell(global_tile_pos)
			print("al damaged")
	else:
		print("eerste damage")
		chunk.wall_health[local_index] = chunk.max_health - damage
		if chunk.wall_health[local_index] < 0:
			wall_layer.erase_cell(global_tile_pos)
