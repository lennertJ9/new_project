extends RefCounted
class_name Chunk
# ongebruikt  atlas ID    tile_x       tile_y    --> 32 bit int
# 00000000    00000000    00000000    00000000
var position: Vector2i

var ground_layer: PackedInt32Array 
var wall_layer: PackedInt32Array

const TILE_MASK = 0xFFFF
const ATLAS_MASK = 0xFF

const ATLAS_SHIFT = 16



func _init(pos: Vector2i) -> void:
	ground_layer.resize(256)
	wall_layer.resize(256)
	position = pos
	


func get_tile_id(packed: int):
	return packed & TILE_MASK



func get_atlas_id(packed: int):
	return (packed >> ATLAS_SHIFT) & ATLAS_MASK



func index_to_xy(index: int):
	var x = index % 16
	var y = int(index/16)
	return Vector2i(x,y)
