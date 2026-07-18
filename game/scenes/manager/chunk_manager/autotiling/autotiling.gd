extends Node
class_name autotiler


var chunks_to_autotile: Dictionary[Vector2i, Chunk]
var autotiled_chunks : Array[Chunk]


var thread_chunk_autotiler: Thread = Thread.new()
var cpu_autotile_delay: int = 25

var chunk_manager_node: ChunkManager
var lifecycle_mutex: Mutex = Mutex.new()
var worker_running: bool = false

var wall_tile_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
var ground_tile_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]

var autotile_mutex := Mutex.new()

# -------------- LOOKUP TABLES -------------------------------------#
var tile_lookup: Dictionary[int, Vector2i] = { #bitmask: atlas_position }
	0: Vector2i(4,4),
	1: Vector2i(4,2),
	3: Vector2i(4,2),
	4: Vector2i(0,4),
	5: Vector2i(0,8),
	6: Vector2i(0,4),
	7: Vector2i(0,2),
	12: Vector2i(0,4),
	14: Vector2i(0,4),
	15: Vector2i(0,2),
	16: Vector2i(4,0),
	17: Vector2i(4,1),
	19: Vector2i(4,1),
	20: Vector2i(10,3),
	21: Vector2i(6,5),
	23: Vector2i(6,3),
	24: Vector2i(4,0),
	25: Vector2i(4,1),
	28: Vector2i(0,0),
	29: Vector2i(6,4),
	30: Vector2i(0,0),
	31: Vector2i(0,1),
	48: Vector2i(4,0),
	49: Vector2i(4,1),
	54: Vector2i(10,3),
	56: Vector2i(4,0),
	60: Vector2i(0,0),
	62: Vector2i(0,0),
	63: Vector2i(0,1),
	64: Vector2i(2,4),
	65: Vector2i(2,8),
	68: Vector2i(1,4),
	70: Vector2i(1,4),
	71: Vector2i(2,6),
	76: Vector2i(1,4),
	79: Vector2i(2,6),
	80: Vector2i(12,3),
	81: Vector2i(8,6),
	84: Vector2i(12,0),
	92: Vector2i(8,0),
	95: Vector2i(12,2),
	96: Vector2i(2,4),
	97: Vector2i(2,8),
	100: Vector2i(1,4),
	102: Vector2i(1,4),
	108: Vector2i(1,4),
	112: Vector2i(2,0),
	113: Vector2i(8,4),
	115: Vector2i(8,4),
	116: Vector2i(6,0),
	119: Vector2i(6,6),
	120: Vector2i(2,0),
	124: Vector2i(1,0),
	125: Vector2i(10,1), 
	126: Vector2i(1,0),
	127: Vector2i(8,2),
	128: Vector2i(2,4),
	129: Vector2i(4,2),
	131: Vector2i(4,2),
	135: Vector2i(0,2),
	143: Vector2i(0,2),
	145: Vector2i(4,1),
	156: Vector2i(0,0),
	159: Vector2i(0,1),
	185: Vector2i(4,1),
	191: Vector2i(0,1),
	192: Vector2i(2,4),
	193: Vector2i(2,2),
	195: Vector2i(2,2),
	196: Vector2i(1,4),
	197: Vector2i(0,6),
	198: Vector2i(1,4),
	199: Vector2i(1,2),
	203: Vector2i(2,2),
	207: Vector2i(1,2),
	209: Vector2i(8,3),
	211: Vector2i(8,3),
	215: Vector2i(12,1),
	221: Vector2i(8,6),
	223: Vector2(8,1),
	224: Vector2i(2,4),
	225: Vector2i(2,2),
	227: Vector2i(2,2),
	229: Vector2i(0,6),
	231: Vector2i(1,2),
	239: Vector2i(1,2),
	240: Vector2i(2,0),
	241: Vector2i(2,1),
	243: Vector2i(2,1),
	244: Vector2i(6,0),
	245: Vector2i(10,2),
	247: Vector2i(6,1),
	248: Vector2i(2,0),
	249: Vector2i(2,1),
	251: Vector2i(2,1),
	252: Vector2i(1,0),
	253: Vector2i(6,2),
	254: Vector2i(1,0),
	255: Vector2i(1,1),

}
var tile_lookup_ground: Dictionary[int, Dictionary] = {
	0: {Vector2i(5,5): 100},
	1: {Vector2i(5,3): 100},
	2: {Vector2i(0,5): 100},
	3: {Vector2i(0,3): 100},
	4: {Vector2i(5,0): 100},
	5: {Vector2i(5,2): 100},
	6: {Vector2i(0,0): 100},
	7: {Vector2i(0,2): 100},
	8: {Vector2i(3,5): 100},
	9: {Vector2i(3,3): 100},
	10: {Vector2i(2,5): 100},
	11: {Vector2i(2,3): 100},
	12: {Vector2i(3,0): 100},
	13: {Vector2i(3,2): 100},
	14: {Vector2i(2,0): 100},
	15: {Vector2i(2,2): 90, Vector2i(9,2): 10},
}
# ------------------------------------------------------------------#



func configure(chunk_manager: ChunkManager) -> void:
	chunk_manager_node = chunk_manager


func start_worker() -> void:
	if is_worker_running():
		return

	set_worker_running(true)
	thread_chunk_autotiler.start(chunk_autotiler)


func stop_worker() -> void:
	if not is_worker_running():
		return

	set_worker_running(false)
	if thread_chunk_autotiler.is_started():
		thread_chunk_autotiler.wait_to_finish()


func _exit_tree() -> void:
	stop_worker()


func set_worker_running(value: bool) -> void:
	lifecycle_mutex.lock()
	worker_running = value
	lifecycle_mutex.unlock()


func is_worker_running() -> bool:
	lifecycle_mutex.lock()
	var running: bool = worker_running
	lifecycle_mutex.unlock()
	return running



func chunk_autotiler():
	while is_worker_running():
		OS.delay_msec(cpu_autotile_delay)
		if not is_worker_running():
			break

		var chunk: Chunk = null

		autotile_mutex.lock()
		if not chunks_to_autotile.is_empty():
			var chunk_pos: Vector2i = chunks_to_autotile.keys()[0]
			chunk = chunks_to_autotile[chunk_pos]
			chunks_to_autotile.erase(chunk_pos)
		autotile_mutex.unlock()

		if chunk == null:
			continue

		chunk_manager_node.world_data_mutex.lock()
		chunk.state = Chunk.ChunkState.AUTOTILING

		var chunk_pos := chunk.position
		for y in range(16):
			for x in range(16):
				var tile := Vector2i(x, y) + chunk_pos * 16
				autotile_wall_tile(tile)
				autotile_ground_tile(tile)
				autotile_cliff_tile(tile)
		chunk_manager_node.world_data_mutex.unlock()

		autotile_mutex.lock()
		autotiled_chunks.append(chunk)
		autotile_mutex.unlock()



func pick_tile_variant(bitmask):
	var dict = tile_lookup_ground[bitmask]
	dict.sort()
	
	var sum: int = 0
	var random = randi_range(0,99) # ik denk verschillend bij seeds maar opzich geen probleem
	
	for key in dict:
		sum += dict[key]
		if sum > random:
			return key



func get_id(layer: Chunk.TileLayer, tile: Vector2i) -> int:
	var chunk_pos := get_chunk_pos(tile)
	if not chunk_manager_node.generated_chunks.has(chunk_pos):
		return 0

	var local_pos := get_chunk_local_tile_pos(tile)
	var index := get_chunk_local_index(local_pos)
	var chunk: Chunk = chunk_manager_node.generated_chunks[chunk_pos]

	match layer:
		Chunk.TileLayer.GROUND:
			return chunk.ground_id_layer[index]
		Chunk.TileLayer.WALL:
			return chunk.wall_id_layer[index]
		Chunk.TileLayer.CLIFF:
			return chunk.cliff_id_layer[index]

	return 0



func set_atlas(layer: Chunk.TileLayer, tile: Vector2i, atlas_pos: Vector2i) -> void:
	var chunk_pos := get_chunk_pos(tile)
	if not chunk_manager_node.generated_chunks.has(chunk_pos):
		return

	var local_pos := get_chunk_local_tile_pos(tile)
	var index := get_chunk_local_index(local_pos)
	var chunk: Chunk = chunk_manager_node.generated_chunks[chunk_pos]

	match layer:
		Chunk.TileLayer.GROUND:
			chunk.ground_atlas_coords[index] = chunk.pack_atlas(atlas_pos)
		Chunk.TileLayer.WALL:
			chunk.wall_atlas_coords[index] = chunk.pack_atlas(atlas_pos)
		Chunk.TileLayer.CLIFF:
			chunk.cliff_atlas_coords[index] = chunk.pack_atlas(atlas_pos)



func autotile_wall_tile(tile: Vector2i) -> void:
	var center_id := get_id(Chunk.TileLayer.WALL, tile)
	if center_id == 0:
		return

	var bitmask := calculate_wall_bitmask(tile, center_id)
	set_atlas(Chunk.TileLayer.WALL, tile, tile_lookup.get(bitmask, Vector2i(3, 0)))



func autotile_ground_tile(tile: Vector2i) -> void:
	var center_id := get_id(Chunk.TileLayer.GROUND, tile)
	if center_id == 0:
		return

	var bitmask := calculate_ground_bitmask(tile, center_id)
	set_atlas(Chunk.TileLayer.GROUND, tile, pick_tile_variant(bitmask))



func autotile_cliff_tile(tile: Vector2i) -> void:
	var cliff_id := get_id(Chunk.TileLayer.CLIFF, tile)
	if cliff_id == 0:
		set_atlas(Chunk.TileLayer.CLIFF, tile, Vector2i(2, 0))
		return

	if get_id(Chunk.TileLayer.GROUND, tile + Vector2i(0, -1)) != 0:
		set_atlas(Chunk.TileLayer.CLIFF, tile, Vector2i(0, 0))
	elif get_id(Chunk.TileLayer.GROUND, tile + Vector2i(0, -2)) != 0:
		set_atlas(Chunk.TileLayer.CLIFF, tile, Vector2i(0, 1))
	elif get_id(Chunk.TileLayer.GROUND, tile + Vector2i(0, -3)) != 0:
		set_atlas(Chunk.TileLayer.CLIFF, tile, Vector2i(0, 2))
	else:
		set_atlas(Chunk.TileLayer.CLIFF, tile, Vector2i(2, 0))



func get_chunk_pos(tile: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(tile.x) / 16.0),
		floori(float(tile.y) / 16.0)
	)



func get_chunk_local_tile_pos(tile: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(tile.x, 16),
		posmod(tile.y, 16)
	)



func get_chunk_local_index(local_tile: Vector2i) -> int:
	return local_tile.y * 16 + local_tile.x



func calculate_wall_bitmask(tile: Vector2i, center_id: int) -> int:
	var bitmask := 0

	var top := get_id(Chunk.TileLayer.WALL, tile + Vector2i(0, -1)) == center_id
	var right := get_id(Chunk.TileLayer.WALL, tile + Vector2i(1, 0)) == center_id
	var bottom := get_id(Chunk.TileLayer.WALL, tile + Vector2i(0, 1)) == center_id
	var left := get_id(Chunk.TileLayer.WALL, tile + Vector2i(-1, 0)) == center_id

	if top:
		bitmask |= 1
	if top and right and get_id(Chunk.TileLayer.WALL, tile + Vector2i(1, -1)) == center_id:
		bitmask |= 2
	if right:
		bitmask |= 4
	if right and bottom and get_id(Chunk.TileLayer.WALL, tile + Vector2i(1, 1)) == center_id:
		bitmask |= 8
	if bottom:
		bitmask |= 16
	if bottom and left and get_id(Chunk.TileLayer.WALL, tile + Vector2i(-1, 1)) == center_id:
		bitmask |= 32
	if left:
		bitmask |= 64
	if left and top and get_id(Chunk.TileLayer.WALL, tile + Vector2i(-1, -1)) == center_id:
		bitmask |= 128

	return bitmask



func calculate_ground_bitmask(tile: Vector2i, center_id: int) -> int:
	var bitmask := 0

	if is_ground_connected(tile + Vector2i(0, -1), center_id):
		bitmask |= 1
	if is_ground_connected(tile + Vector2i(1, 0), center_id):
		bitmask |= 2
	if is_ground_connected(tile + Vector2i(0, 1), center_id):
		bitmask |= 4
	if is_ground_connected(tile + Vector2i(-1, 0), center_id):
		bitmask |= 8

	return bitmask



func is_ground_connected(tile: Vector2i, center_id: int) -> bool:
	return (
		get_id(Chunk.TileLayer.GROUND, tile) == center_id
		and get_id(Chunk.TileLayer.WALL, tile) == 0
	)
