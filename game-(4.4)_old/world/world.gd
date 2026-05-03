extends Node2D

@export var noise_tex: NoiseTexture2D

@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var walls: TileMapLayer = $Walls



var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array

func _ready() -> void:
	walls.set_cells_terrain_connect([Vector2(20,20)],0,0, false)
	
	var noise: Noise = noise_tex.noise
	for y in width:
		for x in height:
			var value = noise.get_noise_2d(x,y)
			values.append(value)
			
			if value > 0.0:
				tile_map_layer.set_cell(Vector2(x,y),0,Vector2(9,6))
				
			if value < -0.0:
				wall_tiles.append(Vector2i(x,y))
	
	
	walls.set_cells_terrain_connect(wall_tiles,0,0)
	print("max ", values.max())
	print("min ", values.min())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var mouse_pos = walls.local_to_map(get_global_mouse_position())
		print(mouse_pos)
		
		#tile_map_layer.set_cell(mouse_pos, 1,Vector2(9,5))
		update_tile(mouse_pos)
		

func update_tile(pos: Vector2i):
	walls.set_cells_terrain_connect([pos], 0, 0, false)
	
