extends Node2D

@export var noise_tex: NoiseTexture2D


@onready var walls: TileMapLayer = $Walls
@onready var ground: TileMapLayer = $Ground


@onready var label: Label = $CanvasLayer/Label


var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array



func _process(delta: float) -> void:
	label.text = str(Engine.get_frames_per_second())
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var mouse_pos = walls.local_to_map(get_global_mouse_position())
		
		
		#tile_map_layer.set_cell(mouse_pos, 1,Vector2(9,5))
		update_tile(mouse_pos)


func update_tile(pos: Vector2i):
	#walls.set_cells_terrain_connect([pos], 0, 0, false)
	print(walls.get_cell_atlas_coords(pos))
	
