extends Node2D


var chunk_list: Dictionary[Vector2i, Chunk]
var active_chunks: Dictionary[Vector2i, Chunk]

var load_interval: float = 0.0
var load_distance: int = 4
var unactive_chunk_timer: float = 0.15

@export var player_pos_or_camera: Camera2D


var ground: TileMapLayer
var walls: TileMapLayer 

@export var noise_tex: NoiseTexture2D 


func _ready() -> void:
	ground = get_node("/root/World/Ground")
	walls = get_node("/root/World/Walls")
	player_pos_or_camera = get_node("/root/World/Camera2D")
	
	var noise = noise_tex.noise
	for x in noise_tex.get_height():
		for y in noise_tex.get_width():
			pass



func _process(delta: float) -> void:
	load_interval += delta
	if load_interval > unactive_chunk_timer:
		load_interval = 0.0
		update_loaded_chunks()



func load_chunk(chunk_pos: Vector2i):
	var chunk: Chunk = chunk_list[chunk_pos]
	active_chunks[chunk_pos] = chunk
	
	
	for tile_x in range(16):
		for tile_y in range(16):
			ground.set_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y), 0, chunk.ground_layer[Vector2i(tile_x, tile_y)])
			walls.set_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y), 0, chunk.wall_layer[Vector2i(tile_x, tile_y)])



func unload_chunk(chunk_pos: Vector2i):
	var dict_ground: Dictionary[Vector2i, Vector2i]
	var dict_walls: Dictionary[Vector2i, Vector2i]
	
	for tile_x in range(16):
		for tile_y in range(16):
			dict_ground[Vector2i(tile_x, tile_y)] = ground.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
			dict_walls[Vector2i(tile_x, tile_y)] = walls.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
	chunk_list[chunk_pos].ground_layer = dict_ground
	chunk_list[chunk_pos].wall_layer = dict_walls
	
	var chunk: Chunk = chunk_list[chunk_pos]
	chunk.loaded = false
	
	for tile_x in range(16):
		for tile_y in range(16):
			ground.erase_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y))
			walls.erase_cell(chunk_pos * 16 + Vector2i(tile_x, tile_y))
	active_chunks.erase(chunk_pos)
	
	



func generate_chunk(chunk_pos: Vector2i):
	var dict_ground: Dictionary[Vector2i, Vector2i]
	var dict_walls: Dictionary[Vector2i, Vector2i]
			
	for tile_x in range(16):
		for tile_y in range(16):
			
			dict_ground[Vector2i(chunk_pos.x * 16 + tile_x, chunk_pos.y * 16 + tile_y)] = Vector2.ZERO
			
			if noise_tex.noise.get_noise_2d(tile_x + chunk_pos.x * 16,tile_y + chunk_pos.y * 16) < 0:
				dict_walls[Vector2i(chunk_pos.x * 16 + tile_x, chunk_pos.y * 16 + tile_y)] = Vector2.ZERO
	ground.set_cells_terrain_connect(dict_ground.keys(), 0, 0, false)
	walls.set_cells_terrain_connect(dict_walls.keys(), 0, 0, false)
	
	
	#for tile_x in range(16):
		#for tile_y in range(16):
			#dict_ground[Vector2i(tile_x, tile_y)] = ground.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
			#dict_walls[Vector2i(tile_x, tile_y)] = walls.get_cell_atlas_coords(chunk_pos * 16 + Vector2i(tile_x, tile_y))
					
	
	var chunk = Chunk.new(dict_ground, dict_walls)
	active_chunks[chunk_pos] = chunk
	chunk_list[chunk_pos] = chunk




func update_loaded_chunks():
	var player_chunk_pos: Vector2i = floor(player_pos_or_camera.global_position / 256) 
	var start_pos: Vector2i = player_chunk_pos - Vector2i(load_distance, load_distance)
	var end_pos: Vector2i = player_chunk_pos + Vector2i(load_distance, load_distance)
	
	for chunk_x in range(start_pos.x, end_pos.x + 1):
		for chunk_y in range(start_pos.y, end_pos.y + 1):
			var chunk_pos = Vector2i(chunk_x, chunk_y)
			
			
			if not chunk_list.has(chunk_pos):
				generate_chunk(chunk_pos)
				print("generate", chunk_list[chunk_pos])
				
			elif not chunk_list[chunk_pos].loaded: 
				load_chunk(chunk_pos)
				print("load", chunk_list[chunk_pos])
			chunk_list[chunk_pos].last_accessed = Time.get_ticks_msec() / 1000
			chunk_list[chunk_pos].loaded = true
	
	for chunk_coord in active_chunks.keys():
		if ((Time.get_ticks_msec() / 1000) - active_chunks[chunk_coord].last_accessed > 4 ):
			unload_chunk(chunk_coord) 
			








func _draw() -> void:
	var chunk_pixel_size = 256
	z_index = 100
	for x in range(-10240,10240, chunk_pixel_size):
		for y in range(-10240,10240, chunk_pixel_size):
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
	
