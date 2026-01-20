extends RefCounted
class_name Chunk
# ongebruikt  tile ID    tile_x       tile_y    --> 32 bit int
# 00000000    00000000   00000000     00000000
var position: Vector2i
var global_position: Vector2i 
var walkable: PackedInt32Array

# ------ layers ----- #
var ground_layer: PackedInt32Array 
var wall_layer: PackedInt32Array
var object_layer: PackedInt32Array

# ------ states ------- #
var status: int # 10001 -> load chunk ###  generated | loaded | queued_load | queud_unload | astar_ready          
var is_generated: bool
var is_loaded: bool
var is_queued_load: bool
var is_queued_unload: bool
var is_Astar_ready: bool
var last_accessed: float


# ----- autotile ----- # 
var is_autotiled: bool

# ----- AStar ----- # 
var a_star_id: int # een "start" id. 0,256,512,...
var a_star_is_ready: bool # als point generated en connected zijn


func _init(pos: Vector2i) -> void:
	is_autotiled = false
	is_queued_unload = false
	is_generated = false
	walkable.resize(256)
	ground_layer.resize(256)
	wall_layer.resize(256)
	object_layer.resize(256)
	position = pos
	global_position = pos * 16



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
