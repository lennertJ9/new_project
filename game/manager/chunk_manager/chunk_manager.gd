extends Node2D


@export var player: Node2D
@export var noise_tex: NoiseTexture2D
var noise: Noise

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer

var render_distance: int = 5

var generated_chunks: Dictionary[Vector2i, Chunk]
var loaded_chunks: Array[Chunk]

var chunks_to_generate: Dictionary[Vector2i, Chunk]
var chunks_to_autotile: Array[Chunk]
var chunks_to_load: Array[Chunk]
var chunks_to_unload: Array[Chunk]

var chunk_check_interval: float = 0.99
var chunk_load_interval: float = 0.002
var chunk_unload_interval: float = 0.002


var chunk_check_timer: float = 0
var chunk_load_timer: float = 0
var chunk_unload_timer: float = 0

var thread_chunk_generator: Thread = Thread.new()
var thread_chunk_autotiler: Thread = Thread.new()


var tile_lookup: Dictionary[int, Vector2i] = { #bitmask: atlas_position }
	193: Vector2i(2,2),
	199: Vector2i(1,2),
	7: Vector2i(0,2),
	16: Vector2i(4,0),
	241: Vector2i(2,1),
	255: Vector2i(1,1),
	31: Vector2i(0,1),
	17: Vector2i(4,1),
	28: Vector2i(0,0),
	124: Vector2i(1,0),
	112: Vector2i(2,0),
	1: Vector2i(4,2),
	4: Vector2i(0,4),
	68: Vector2i(1,4),
	128: Vector2i(2,4),
	0: Vector2i(4,4),
	76: Vector2i(1,4),
	92: Vector2i(8,0),
	159: Vector2i(0,1),
	15: Vector2i(0,2),
	223: Vector2(8,1),
	63: Vector2i(0,1),
	127: Vector2i(8,2),
	30: Vector2i(0,0),
	120: Vector2i(2,0),
	253: Vector2i(6,2),
	240: Vector2i(2,0),
	207: Vector2i(1,2),
	231: Vector2i(1,2),
	247: Vector2i(6,1),
	227: Vector2i(2,2),
	195: Vector2i(2,2),
	23: Vector2i(6,3),
	3: Vector2i(4,2),
	135: Vector2i(0,2),
	143: Vector2i(0,2),
	191: Vector2i(0,1),
	62: Vector2i(0,0),
	126: Vector2i(1,0),
	252: Vector2i(1,0),
	248: Vector2i(2,0),
	24: Vector2i(4,0),
	29: Vector2i(6,4),
	209: Vector2i(8,3),
	129: Vector2i(4,2),
	116: Vector2i(6,0),
	108: Vector2i(1,4),
	243: Vector2i(2,1),
	249: Vector2i(2,1),
	113: Vector2i(8,4),
	49: Vector2i(4,1),
	145: Vector2i(4,1),
	25: Vector2i(4,1),
	19: Vector2i(4,1),
	14: Vector2i(0,4),
	95: Vector2i(12,2),
	215: Vector2i(12,1),
	131: Vector2i(4,2),
	225: Vector2i(2,2),
	48: Vector2i(4,0),
	71: Vector2i(2,6),
	6: Vector2i(0,4),
	197: Vector2i(0,6),
	196: Vector2i(1,4),
	70: Vector2i(1,4),
	
	12: Vector2i(0,4),
	96: Vector2i(2,4),
	251: Vector2i(2,2),
	
	
}



func _ready() -> void:
	thread_chunk_generator.start(chunk_generator)
	thread_chunk_autotiler.start(chunk_autotiler)
	
	player = get_tree().get_first_node_in_group("world").camera
	noise = noise_tex.noise



func _process(delta: float) -> void:
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



func chunk_generator():
	while true:
		OS.delay_msec(15)
		if not chunks_to_generate.is_empty():
			var chunk: Chunk = chunks_to_generate.values()[0]
			var chunk_pos = chunk.position
			
			var i = 0
			for y in range(16):
				for x in range(16):
					
					var global_pos = chunk.position * 16 + Vector2i(x,y)
					var walls_atlas_id = 0
					var random = noise.get_noise_2dv(global_pos)
					var wall_id: int
					if random > 0.1:
						wall_id = 1 << 16 # dirt wall
					else:
						wall_id = 0
					
					var atlas_coord = Vector2i(2,2)
					var atlas_id = 0
					var ground_data = (atlas_coord.x << 8) | atlas_coord.y
					
					chunk.ground_layer[i] = ground_data
					chunk.wall_layer[i] = wall_id
					i += 1
			generated_chunks[chunk.position] = chunk # eerst autotile dan pas in generated chunks
			chunks_to_autotile.append(chunk)
			chunk.is_generated = true
			chunks_to_generate.erase(chunk_pos)



func chunk_autotiler():
	while true:
		OS.delay_msec(15)
		if not chunks_to_autotile.is_empty():
			var chunk: Chunk = chunks_to_autotile.pop_front()
			
			var top: int
			var bottom:int
			var left: int
			var right:int
			for x in range(16): # zet de indexen van alle tiles aan de boven en onder rand van een chunk op 0 (niet laden)
				top = 0 * 16 + x
				bottom = 15 * 16 + x
				chunk.wall_layer[top] = 0
				chunk.wall_layer[bottom] = 0
				
			for y in range(16): # zet de indexen van alle tiles aan de linker en rechter rand van een chunk op 0 (niet laden)
				left =  y * 16 + 0
				right = y * 16 + 15
				chunk.wall_layer[left] = 0
				chunk.wall_layer[right] = 0
			
			
			for y in range(1, 15): # loops over de inner tiles
				for x in range(1, 15):
					var i = y * 16 + x
					
					var bitmask: int = 0
					var tile_id = chunk.wall_layer[i] >> 16 #omdat tile id 16 bits links staat
					
					if tile_id != 0:
						#print(chunk.wall_layer[i] >> 16)
						if chunk.wall_layer[i - 16] >> 16 == tile_id:
							print(chunk.wall_layer[i - 16])
							print("i +1")
							bitmask += 1
						if chunk.wall_layer[i - 15] >> 16 == tile_id:
							bitmask += 2
						if chunk.wall_layer[i + 1] >> 16 == tile_id:
							bitmask += 4
						if chunk.wall_layer[i + 17] >> 16 == tile_id:
							bitmask += 8
						if chunk.wall_layer[i + 16] >> 16 == tile_id:
							bitmask += 16
						if chunk.wall_layer[i + 15] >> 16 == tile_id:
							bitmask += 32
						if chunk.wall_layer[i - 1] >> 16 == tile_id:
							bitmask += 64
						if chunk.wall_layer[i - 17] >> 16 == tile_id:
							bitmask += 128
							
						print("i: ", i," bitmask: ",bitmask)
						print('-----------------------------')
						#print("i: ", i ,"  bitmask:  ",bitmask)
						if tile_lookup.has(bitmask):
							var atlas_pos = tile_lookup[bitmask]
							
							chunk.wall_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
						else:
							chunk.wall_layer[i] = tile_id << 16 | 3 << 8 | 0
			
			
			
			chunk.is_autotiled = true
			chunks_to_load.append(chunk)




func chunk_loader():
	if not chunks_to_load.is_empty():
		print("loading")
		var chunk: Chunk = chunks_to_load.pop_front()
		var i = 0
		
		for y_pos in range(16):
			for x_pos in range(16):
				
				ground_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 0, Vector2i(2,2))
				if chunk.wall_layer[i] > 65000:
					wall_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 0, chunk.get_tile_coord(chunk.wall_layer[i])) 
				i += 1
		chunk.is_loaded = true
		#chunks_to_load.erase(chunk.position)
		loaded_chunks.append(chunk)



func chunk_check():
	#print("check")
	var player_chunk_coord = floor(player.global_position / 256)
	var start_coord: Vector2 = player_chunk_coord - Vector2(render_distance, render_distance) 
	var end_coord: Vector2 = player_chunk_coord + Vector2(render_distance, render_distance) 
	
	for coord_x in range(start_coord.x, end_coord.x + 1):
		for coord_y in range(start_coord.y, end_coord.y + 1):
			var chunk_pos = Vector2i(coord_x, coord_y)
			
			if generated_chunks.has(chunk_pos) and not generated_chunks[chunk_pos].is_loaded and generated_chunks[chunk_pos].is_autotiled:
				chunks_to_load.append(generated_chunks[chunk_pos])
				# LOADING CHUNK
				
			else:
				if not chunks_to_generate.has(chunk_pos) and not generated_chunks.has(chunk_pos):
					chunks_to_generate[chunk_pos] = Chunk.new(chunk_pos)
					# GENERATING CHUNK
					
					
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


#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("left_click"):
		#var local_pos = ground_layer.local_to_map(get_global_mouse_position())
		#
		#print(generated_chunks[Vector2i(0,0)].ground_layer)



func _draw() -> void:
	var chunk_pixel_size = 256
	
	z_index = 5
	for x in range(-1280,1280, chunk_pixel_size):
		for y in range(-1280,1280, chunk_pixel_size):
			
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			draw_string(ThemeDB.fallback_font, Vector2(x,y ), str(Vector2(x / 256,y / 256)))
	for x in range(-320,320, 16):
		for y in range(-320,320, 16):
			
			draw_rect(Rect2(Vector2(x,y), Vector2(16,16)), Color(1,0,0,0.05), false, 1.)
			
	
