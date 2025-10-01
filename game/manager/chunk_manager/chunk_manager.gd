extends Node2D

var thread: Thread

var generated_chunks: Dictionary[Vector2i, Chunk] = {}  # chunks die al generated zijn geweest
var active_chunks: Dictionary[Vector2i, Chunk] = {}     # chunks die loaded zijn

var load_interval: float = 0.025
var chunk_check_interval: float = 1.0

var load_interval_time: float 
var chunk_check_interval_time: float

var load_distance: int = 2
var unactive_chunk_timer: float = 0.3


@export var player_pos_or_camera: Camera2D

var chunks_to_generate: Array[Chunk] = []
var chunks_to_load: Array[Vector2i] = []
var chunks_to_unload: Array[Vector2i] = []

var ground: TileMapLayer
var walls: TileMapLayer 

@export var noise_tex: NoiseTexture2D 


func _ready() -> void:
	ground = get_node("/root/World/Ground")
	walls = get_node("/root/World/Walls")
	player_pos_or_camera = get_node("/root/World/Camera2D")



func _process(delta: float) -> void:
	load_interval_time += delta
	chunk_check_interval_time += delta
	
	if load_interval_time > load_interval:
		load_interval_time = 0.0
		load_chunk()
		generate_chunk_v2()
		
	if chunk_check_interval_time > chunk_check_interval:
		update_chunks()



func load_chunk():
	if not chunks_to_load.is_empty():
		print("load chunk: ", chunks_to_load.pop_front())



func unload_chunk(chunk_pos: Vector2i):
	print("unload")
	var dict_ground: Dictionary[Vector2i, Vector2i]
	var dict_walls: Dictionary[Vector2i, Vector2i]
	
	for tile_x in range(16):
		for tile_y in range(16):
			dict_ground[Vector2i(tile_x, tile_y)] = ground.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
			dict_walls[Vector2i(tile_x, tile_y)] = walls.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
	generated_chunks[chunk_pos].ground_layer = dict_ground
	generated_chunks[chunk_pos].wall_layer = dict_walls
	
	var chunk: Chunk = generated_chunks[chunk_pos]
	chunk.loaded = false
	
	for tile_x in range(16):
		for tile_y in range(16):
			ground.erase_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y))
			walls.erase_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y))
	active_chunks.erase(chunk_pos)



func generate_chunk_v2():
	if not chunks_to_generate.is_empty():
		print("generate")
		var chunk: Chunk = chunks_to_generate.pop_front()
		chunk.loaded = true
		chunk.last_accessed = Time.get_ticks_msec() / 1000
		active_chunks[chunk.position] = chunk
		
		var noise = noise_tex.noise
		for x in range(16):
			for y in range(16):
				var world_pos = chunk.position * 16 + Vector2i(x,y)
				var value = noise.get_noise_2d(world_pos.x, world_pos.y)
				
				chunk.ground_layer[Vector2i(world_pos.x,world_pos.y)] = Vector2i(1,6)
				ground.set_cell(Vector2i(world_pos), 0, chunk.ground_layer[Vector2i(world_pos.x,world_pos.y)])
				if value > 0.0:
					chunk.wall_layer[Vector2i(world_pos.x,world_pos.y)] = Vector2i(1,6)
		
		walls.set_cells_terrain_connect(chunk.wall_layer.keys(), 0, 0, false)
		for cell_x in range(16):
			for cell_y in range(16):
				var world_pos = chunk.position * 16 + Vector2i(cell_x, cell_y)
				chunk.wall_layer[world_pos] = walls.get_cell_atlas_coords(world_pos)



func update_chunks():
	var player_chunk_pos: Vector2i = floor(player_pos_or_camera.global_position / 256) 
	var start_pos: Vector2i = player_chunk_pos - Vector2i(load_distance, load_distance)
	var end_pos: Vector2i = player_chunk_pos + Vector2i(load_distance, load_distance)
	
	for chunk_x in range(start_pos.x, end_pos.x +1):
		for chunk_y in range(start_pos.y, end_pos.y+1):
			var chunk_pos: Vector2i = Vector2i(chunk_x, chunk_y)
			
			
			if generated_chunks.has(chunk_pos) and not generated_chunks[chunk_pos].loaded:
				chunks_to_load.append(chunk_pos)
			
			if not generated_chunks.has(chunk_pos):
				var chunk: Chunk = Chunk.new(chunk_pos)
				generated_chunks[chunk_pos] = chunk
				chunks_to_generate.append(chunk)
				
			generated_chunks[Vector2i(chunk_x, chunk_y)].last_accessed = Time.get_ticks_msec() / 1000
			
	
	for chunk_coord in active_chunks.keys():
		if ((Time.get_ticks_msec() / 1000) - active_chunks[chunk_coord].last_accessed > 4 ):
			unload_chunk(chunk_coord) 





func _draw() -> void:
	var chunk_pixel_size = 256
	
	z_index = 100
	for x in range(-1600,1600, chunk_pixel_size):
		for y in range(-1600,1600, chunk_pixel_size):
			
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
	
