extends RefCounted
class_name Chunk

var position: Vector2i
var global_position: Vector2i 



var wall_id_layer: PackedByteArray
var ground_id_layer: PackedByteArray

# ongebruikt  ongebruikt   tile_x       tile_y    --> 32 bit int
# 00000000    00000000     00000000     00000000
var wall_atlas_coords: PackedInt32Array
var ground_atlas_coords: PackedInt32Array

# ------ states ------- #        
var is_generated: bool
var is_autotiled: bool
var is_Astar_ready: bool
var is_loaded: bool
var is_queued_load: bool
var is_queued_unload: bool


var last_accessed: float


# ----- features ----- # 
var has_cliffs: bool = false
var max_health = 100

# ----- AStar ----- # 
var a_star_id: int # een "start" id. 0,256,512,...
var a_star_is_ready: bool # als point generated en connected zijn

# ----- Neighbour Data ----- # 
var is_neigbhoured
var neighbours: Array




func _init(pos: Vector2i) -> void:
	is_autotiled = false
	is_queued_unload = false
	is_generated = false
	is_neigbhoured = false
	
	ground_id_layer.resize(256)
	wall_id_layer.resize(256)
	ground_atlas_coords.resize(256)
	wall_atlas_coords.resize(256)
	
	neighbours.resize(8)
	position = pos
	global_position = pos * 16
	



func pack_atlas(pos: Vector2i) -> int:
	return (pos.x << 8) | pos.y


func unpack_atlas(packed: int) -> Vector2i:
	return Vector2i((packed >> 8) & 0xFF,packed & 0xFF)




func index_to_xy(index: int):
	var x = index % 16
	var y = int(index/16)
	return Vector2i(x,y)


func local_vector_to_index(vector: Vector2i)-> int:
	return vector.y * 16 + vector.x
