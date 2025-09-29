extends Node2D

# BUG DAT BIJ DE GENERATED CHUNKS DE - COORDS NIET WERKEN OOKAL GEEF JE ALS PARAMTER EEN NEGATIEVE COORD. WSS OMDAT IK DEZE 2 PARAMETERS VAN ELKAAR AFTREK EN DAN DE ABS NEEM
var chunk_list: Dictionary[Vector2i, Chunk]
var active_chunks: Dictionary[Vector2i, Chunk]

var load_interval: float = 0.0
var load_distance: int = 1
var unactive_chunk_timer: float = 0.15

@export var player_pos_or_camera: Camera2D


var ground: TileMapLayer
var walls: TileMapLayer 

func _ready() -> void:
	ground = get_node("/root/World/Ground")
	walls = get_node("/root/World/Walls")
	player_pos_or_camera = get_node("/root/World/Camera2D")
	
	generate_chunks(Vector2i(-20,-20), Vector2i(20,20))
	
	#for chunk in chunk_list:
		#load_chunk(chunk)



func _process(delta: float) -> void:
	load_interval += delta
	if load_interval > unactive_chunk_timer:
		load_interval = 0.0
		update_loaded_chunks()



func load_chunk(start: Vector2i, end: Vector2i):
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var chunk_coords = Vector2i(x,y)
			var chunk: Chunk = chunk_list[chunk_coords]
			if not chunk.loaded:
				chunk.last_accessed = Time.get_ticks_msec() / 1000
				chunk.loaded = true
				active_chunks[chunk_coords] = chunk
				for tile_x in range(16):
					for tile_y in range(16):
						ground.set_cell(chunk_coords * 16 + Vector2i(tile_x,tile_y), 0, chunk_list[chunk_coords].data[Vector2i(tile_x,tile_y)]["ground"])
						walls.set_cell(chunk_coords * 16 + Vector2i(tile_x,tile_y), 0, chunk_list[chunk_coords].data[Vector2i(tile_x,tile_y)]["walls"])
			else:
				chunk.last_accessed = Time.get_ticks_msec() / 1000



func unload_chunk(chunk_coords: Vector2i):
	chunk_list[chunk_coords].loaded = false
	for tile_x in range(16):
		for tile_y in range(16):
			ground.erase_cell(chunk_coords * 16 + Vector2i(tile_x, tile_y))


func update_loaded_chunks():
	var player_chunk_pos: Vector2i = floor(player_pos_or_camera.global_position / 256) 
	var start_load: Vector2i = player_chunk_pos - Vector2i(load_distance, load_distance)
	var end_load: Vector2i = player_chunk_pos + Vector2i(load_distance, load_distance)
	
	load_chunk(start_load, end_load)
	for chunk_coord in active_chunks:
		if ((Time.get_ticks_msec() / 1000) - active_chunks[chunk_coord].last_accessed > 1 ):
			unload_chunk(chunk_coord) 



func generate_chunks(start: Vector2i, end: Vector2i):
	var amount = (start - end).abs()
	for y in range(amount.y):
		for x in range(amount.x):
			var chunk_coords = Vector2i(x,y)
			var tiles: Dictionary[Vector2i, Dictionary]
			
			for tile_x in range(16):
				for tile_y in range(16):
					tiles[Vector2i(tile_x, tile_y)] = {"ground": Vector2i(2, 15), "walls": Vector2i(0,7)}
			var chunk = Chunk.new(tiles)
			chunk_list[chunk_coords] = chunk



func _draw() -> void:
	var chunk_pixel_size = 256
	z_index = 100
	for x in range(-10240,10240, chunk_pixel_size):
		for y in range(-10240,10240, chunk_pixel_size):
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.5), false, 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
			
