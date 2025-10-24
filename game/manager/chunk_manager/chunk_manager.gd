extends Node2D


@export var player: Node2D

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer

var render_distance: int = 2

var generated_chunks: Dictionary[Vector2i, Chunk]
var active_chunks: Array[Chunk]

var chunks_to_generate: Dictionary[Vector2i, Chunk]
var chunks_to_load: Dictionary[Vector2i, Chunk]
var chunks_to_unload: Dictionary[Vector2i, Chunk]

# 
var chunk_check_interval: float = 2
var chunk_load_interval: float = 0.2

var chunk_check_timer: float = 0
var chunk_load_timer: float = 0

var thread_chunk_generator: Thread = Thread.new()



func _ready() -> void:
	
	thread_chunk_generator.start(chunk_generator)
	#thread_chunk_loader.start(chunk_loader) # geen scene tree bewerkingen doen via thread :(
	player = get_tree().get_first_node_in_group("world").camera


func _process(delta: float) -> void:
	chunk_check_timer += delta
	chunk_load_timer += delta
	
	if chunk_check_timer > chunk_check_interval:
		chunk_check()
		chunk_check_timer = 0
		
	if chunk_load_timer > chunk_load_interval:
		chunk_loader()
		chunk_load_timer = 0

func chunk_generator():
	while true:
		OS.delay_msec(100)
		if not chunks_to_generate.is_empty():
			var chunk: Chunk = chunks_to_generate.values()[0]
			var chunk_pos = chunk.position
			
			var i = 0
			for y in range(16):
				for x in range(16):
					var atlas_coord = Vector2i(2,2)
					var atlas_id = 0
					var data = atlas_coord.y << 8 | atlas_coord.x
					chunk.ground_layer[i] = data
					i += 1
			generated_chunks[chunk.position] = chunk
			chunk.is_generated = true
			chunks_to_generate.erase(chunk_pos)



func chunk_loader():
	if not chunks_to_load.is_empty():
		print("loading")
		var chunk: Chunk = chunks_to_load.values()[0]
		var i = 0
		for x_pos in range(16):
			for y_pos in range(16):
				ground_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 0, Vector2i(2,2) )
		chunk.is_loaded = true
		chunks_to_load.erase(chunk.position)
			# load chunks from chunks to load
			


func chunk_check():
	print("check")
	var player_chunk_coord = floor(player.global_position / 256)
	var start_coord: Vector2 = player_chunk_coord - Vector2(render_distance, render_distance) 
	var end_coord: Vector2 = player_chunk_coord + Vector2(render_distance, render_distance) 
	
	for coord_x in range(start_coord.x, end_coord.x + 1):
		for coord_y in range(start_coord.y, end_coord.y + 1):
			var chunk_pos = Vector2i(coord_x, coord_y)
			
			if generated_chunks.has(chunk_pos) and not generated_chunks[chunk_pos].is_loaded:
				chunks_to_load[chunk_pos] = generated_chunks[chunk_pos]
				# load
				
			else:
				if not chunks_to_generate.has(chunk_pos) and not generated_chunks.has(chunk_pos):
					chunks_to_generate[chunk_pos] = Chunk.new(chunk_pos)
					
					
			
			


#func generate_chunk(chunk_pos: Vector2i):
	#var chunk = Chunk.new(chunk_pos)
	#chunk.position = chunk_pos
	#var i = 0
	#for y in range(16):
		#for x in range(16):
			#var atlas_coord = Vector2i(2,2)
			#var atlas_id = 0
			#var data = atlas_coord.y << 8 | atlas_coord.x
			#chunk.ground_layer[i] = data
			#i += 1
	#generated_chunks[chunk_pos] = chunk



func load_chunk(chunk: Chunk):
	var i = 0
	for x in range(16):
		for y in range(16):
			var chunk_data = chunk.ground_layer[i]
			ground_layer.set_cell(chunk.position * 16 + Vector2i(x,y), 0, chunk.get_tile_coord(chunk_data))
			#ground_layer.set_cell(chunk.position * 16 + Vector2i(x,y), 0, Vector2i(2,2))
			i += 1
			








func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var local_pos = ground_layer.local_to_map(get_global_mouse_position())
		
		print(ground_layer.get_cell_atlas_coords(local_pos))



#func _draw() -> void:
	#var chunk_pixel_size = 256
	#
	#z_index = 5
	#for x in range(-1280,1280, chunk_pixel_size):
		#for y in range(-1280,1280, chunk_pixel_size):
			#
			#draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			#draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
	#
