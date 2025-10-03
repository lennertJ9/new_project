extends Node2D

var thread: Thread

var generated_chunks: Dictionary[Vector2i, Chunk] = {}  # chunks die al generated zijn geweest
var active_chunks: Dictionary[Vector2i, Chunk] = {}     # chunks die loaded zijn

var process_chunk_interval: float = 0.005 # verwerking van de chunk arrays
var update_chunk_interval: float = 0.5 # checks van de arrays

var process_chunk_interval_time: float = 0.0
var update_chunk_interval_time: float = 0.0

var load_distance: int = 12
#var unactive_chunk_timer: float = 0.3
var chunk_life_time: int = 0.5

@export var player_pos_or_camera: Camera2D

var chunks_to_generate: Array[Chunk] = []
var chunks_to_load: Array[Chunk] = []
var chunks_to_unload: Array[Chunk] = []
var recently_generated: Array[Chunk] = []

var ground: TileMapLayer
var walls: TileMapLayer 

@export var noise_tex: NoiseTexture2D 


func _ready() -> void:
	ground = get_node("/root/World/Ground")
	walls = get_node("/root/World/Walls")
	player_pos_or_camera = get_node("/root/World/Camera2D")



func _process(delta: float) -> void:
	process_chunk_interval_time += delta
	update_chunk_interval_time += delta
	
	if process_chunk_interval_time > process_chunk_interval:
		process_chunk_interval_time = 0.0
		load_chunk()
		generate_chunk_v2()
		unload_chunk()
		#fix_terrain() - lijkt toch niet te werken
		
	if update_chunk_interval_time > update_chunk_interval:
		update_chunk_interval_time = 0.0
		update_chunks()



func update_chunks():
	var player_chunk_pos: Vector2i = floor(player_pos_or_camera.global_position / 256) 
	var start_pos: Vector2i = player_chunk_pos - Vector2i(load_distance, load_distance)
	var end_pos: Vector2i = player_chunk_pos + Vector2i(load_distance, load_distance)
	
	for chunk_x in range(start_pos.x, end_pos.x +1):
		for chunk_y in range(start_pos.y, end_pos.y+1):
			var chunk_pos: Vector2i = Vector2i(chunk_x, chunk_y) # start array van chunks in de buurt van player
			
			
			if not generated_chunks.has(chunk_pos): # lijst van chunk te generaten
				var chunk: Chunk = Chunk.new(chunk_pos)
				generated_chunks[chunk_pos] = chunk
				chunks_to_generate.append(chunk)
			
			if not chunks_to_load.has(generated_chunks[chunk_pos]) and generated_chunks[chunk_pos] and not generated_chunks[chunk_pos].is_loaded and not generated_chunks[chunk_pos].is_generating :
				chunks_to_load.append(generated_chunks[chunk_pos])
			
			generated_chunks[chunk_pos].last_accessed = Time.get_ticks_msec() / 1000
	
	
	var current_time = Time.get_ticks_msec() / 1000
	for chunk: Chunk in active_chunks.values():
		if current_time - chunk.last_accessed > chunk_life_time and not chunk.is_generating and not chunks_to_unload.has(chunk):
			chunks_to_unload.append(chunk)
			print("append to unload")



func load_chunk():
	if not chunks_to_load.is_empty():
		print("load")
		var chunk: Chunk = chunks_to_load.pop_front()
		chunk.is_loaded = true
		active_chunks[chunk.position] = chunk
		
		# loading ground
		for x in range(16):
			for y in range(16):
				ground.set_cell(chunk.position * 16 + Vector2i(x,y), 0, chunk.ground_layer[chunk.position * 16 + Vector2i(x,y)])
		
		
		
		# loading walls
		
				
		
		walls.set_cells_terrain_connect(chunk.wall_layer.keys(), 0, 0, false)



func unload_chunk():
	if not chunks_to_unload.is_empty():
		print("unload")
		var chunk: Chunk = chunks_to_unload.pop_front()
		for tile_x in range(16):
			for tile_y in range(16):
				ground.erase_cell(chunk.position * 16 + Vector2i(tile_x, tile_y))
				walls.erase_cell(chunk.position * 16 + Vector2i(tile_x, tile_y))
		chunk.is_loaded = false
		active_chunks.erase(chunk.position)



func generate_chunk_v2():
	if not chunks_to_generate.is_empty():
		print("generate")
		
		var chunk: Chunk = chunks_to_generate.pop_front()
		
		var noise = noise_tex.noise
		for x in range(16):
			for y in range(16):
				var world_pos = chunk.position * 16 + Vector2i(x,y)
				var value = noise.get_noise_2d(world_pos.x, world_pos.y)
				
				chunk.ground_layer[Vector2i(world_pos.x,world_pos.y)] = Vector2i(1,6)
				ground.set_cell(Vector2i(world_pos), 0, chunk.ground_layer[Vector2i(world_pos.x,world_pos.y)])
				if value > 0.0:
					chunk.wall_layer[Vector2i(world_pos.x,world_pos.y)] = Vector2i(2,2)
					
		walls.set_cells_terrain_connect(chunk.wall_layer.keys(), 0, 0, true)
		#for tile_pos in chunk.wall_layer.keys():
			#chunk.wall_layer[tile_pos] = walls.get_cell_atlas_coords(tile_pos)
		
		chunk.last_accessed = Time.get_ticks_msec() / 1000
		chunk.is_generating = false
		chunk.is_loaded = true
		active_chunks[chunk.position] = chunk









func _draw() -> void:
	var chunk_pixel_size = 256
	
	z_index = 100
	for x in range(-1280,1280, chunk_pixel_size):
		for y in range(-1280,1280, chunk_pixel_size):
			
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
	
