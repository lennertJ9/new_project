extends Node2D



@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer



var generated_chunks: Array[Chunk]



func _ready() -> void:
	generate_chunk(Vector2i(0,0))
	load_chunk(generated_chunks[0])



func generate_chunk(chunk_pos: Vector2i):
	var chunk = Chunk.new(chunk_pos)
	chunk.position = chunk_pos
	var i = 0
	for y in range(16):
		for x in range(16):
			var atlas_coord = Vector2i(2,2)
			var atlas_id = 0
			var data = atlas_coord.y << 8 | atlas_coord.x
			chunk.ground_layer[i] = data
			i += 1
	generated_chunks.append(chunk)



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



func _draw() -> void:
	var chunk_pixel_size = 256
	
	z_index = 100
	for x in range(-1280,1280, chunk_pixel_size):
		for y in range(-1280,1280, chunk_pixel_size):
			
			draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.2), false, 1.)
			draw_string(ThemeDB.fallback_font, Vector2(x,y + 16), str(Vector2(x / 256,y / 256)))
	
