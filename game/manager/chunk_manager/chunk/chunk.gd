extends RefCounted
class_name Chunk
# ongebruikt  tile ID    tile_x       tile_y    --> 32 bit int
# 00000000    00000000   00000000     00000000
var position: Vector2i

var ground_layer: PackedInt32Array 
var wall_layer: PackedInt32Array

var is_generated: bool
var is_loaded: bool
var is_queued_unload: bool

# ----- autotile ----- #
var is_autotiled: bool

var is_autotiled_top: bool
var is_autotiled_top_right: bool
var is_autotiled_right: bool
var is_autotiled_bottom_right: bool
var is_autotiled_bottom: bool
var is_autotiled_bottom_left: bool
var is_autotiled_left: bool
var is_autotiled_top_left: bool


var is_autotiled_inner: bool
var autotiled_bitmask: int # 511 -> alles autotiled

var last_accessed: float
  


func _init(pos: Vector2i) -> void:
	is_autotiled = false
	is_queued_unload = false
	is_generated = false
	ground_layer.resize(256)
	wall_layer.resize(256)
	position = pos
	
	var is_autotiled_top = false
	var is_autotiled_top_right = false
	var is_autotiled_right = false
	var is_autotiled_bottom_right = false
	var is_autotiled_bottom = false
	var is_autotiled_bottom_left = false
	var is_autotiled_left = false
	var is_autotiled_top_left = false
	


func get_tile_coord(packed: int) -> Vector2i:
	var x = (packed >> 8) & 0xFF
	var y = packed & 0xFF
	return Vector2i(x,y)



func get_atlas_id(packed: int) -> int:
	return 0
	#return (packed >> ATLAS_SHIFT) & ATLAS_MASK



func index_to_xy(index: int):
	var x = index % 16
	var y = int(index/16)
	return Vector2i(x,y)
