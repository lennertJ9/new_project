extends RefCounted
class_name Chunk

var position: Vector2i
var global_position: Vector2i 



var wall_id_layer: PackedByteArray
var ground_id_layer: PackedByteArray
var cliff_id_layer: PackedByteArray

# Health is only relevant for walls, but keeping it per tile makes it save-ready
# and avoids a Dictionary allocation for every damaged wall.
var wall_health_layer: PackedInt32Array

# ongebruikt  ongebruikt   tile_x       tile_y    --> 32 bit int
# 00000000    00000000     00000000     00000000
var wall_atlas_coords: PackedInt32Array
var ground_atlas_coords: PackedInt32Array
var cliff_atlas_coords: PackedInt32Array



var state: ChunkState = ChunkState.EMPTY
enum ChunkState {
	EMPTY,
	QUEUED_GENERATE,
	GENERATING,
	DATA_READY,
	WAITING_FOR_NEIGHBOURS,
	QUEUED_AUTOTILE,
	AUTOTILING,
	QUEUED_LOAD,
	LOADED,
	UNLOADED,
	QUEUED_UNLOAD,
}

enum TileLayer {
	GROUND,
	WALL,
	CLIFF,
}

var last_accessed: float


# ----- AStar ----- # 
var a_star_id: int # een "start" id. 0,256,512,...
var a_star_is_ready: bool # als point generated en connected zijn

# ----- Neighbour Data ----- # 
var is_neigbhoured
var neighbours: Array




func _init(pos: Vector2i) -> void:
	
	
	wall_id_layer.resize(256)
	ground_id_layer.resize(256)
	cliff_id_layer.resize(256)
	wall_health_layer.resize(256)
	
	wall_atlas_coords.resize(256)
	ground_atlas_coords.resize(256)
	cliff_atlas_coords.resize(256)
	
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
