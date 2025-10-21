extends RefCounted
class_name Chunk
# ongebruikt  atlas ID    tile_x       tile_y    --> 32 bit int
# 00000000    00000000    00000000    00000000
var position: Vector2i

var ground_layer: PackedInt32Array 
var wall_layer: PackedInt32Array

var is_generated: bool




func _init(pos: Vector2i) -> void:
	is_generated = false
	ground_layer.resize(256)
	wall_layer.resize(256)
	position = pos
	


func get_tile_coord(packed: int) -> Vector2i:
	var x = packed & 0xFF
	var y = packed >> 8 & 0xFF
	return Vector2i(x,y)



func get_atlas_id(packed: int) -> int:
	return 0
	#return (packed >> ATLAS_SHIFT) & ATLAS_MASK



func index_to_xy(index: int):
	var x = index % 16
	var y = int(index/16)
	return Vector2i(x,y)
