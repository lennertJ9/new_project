extends Node2D


@onready var data_layer: TileMapLayer = $DataLayer
@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer

const TILE_MASK = 0xFFFF
const ATLAS_MASK = 0xFF


const ATLAS_SHIFT = 16
@export var bit: int



func _ready() -> void:
	generate_chunk(Vector2i(0,0))


func generate_chunk(chunk_pos: Vector2i):
	var chunk = Chunk.new(chunk_pos)
	var i = 0
	for y in range(16):
		for x in range(16):
			# noise calcs op te tile te zetten
			chunk.ground_layer[i] # = hier een int met nodige data
			var tile_id
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
	
