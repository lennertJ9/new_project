extends Node
class_name PathfindingService

var chunk_manager: ChunkManager
var navigation_map: NavigationMap = NavigationMap.new()

const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]
const DIAGONAL_COST_MULTIPLIER: float = 1.41421356
const MAXIMUM_G_SCORE: int = 2_147_483_647





## initialiseerd de pathfinding service
func configure(source_chunk_manager: ChunkManager) -> void:
	if chunk_manager == source_chunk_manager:
		return

	disconnect_from_chunk_manager()
	navigation_map.clear()

	chunk_manager = source_chunk_manager

	for chunk: Chunk in chunk_manager.loaded_chunks:
		navigation_map.rebuild_chunk(chunk)

	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	chunk_manager.tile_changed.connect(_on_tile_changed)



func disconnect_from_chunk_manager() -> void:
	if chunk_manager == null:
		return

	if chunk_manager.chunk_loaded.is_connected(_on_chunk_loaded):
		chunk_manager.chunk_loaded.disconnect(_on_chunk_loaded)

	if chunk_manager.chunk_unloaded.is_connected(_on_chunk_unloaded):
		chunk_manager.chunk_unloaded.disconnect(_on_chunk_unloaded)

	if chunk_manager.tile_changed.is_connected(_on_tile_changed):
		chunk_manager.tile_changed.disconnect(_on_tile_changed)

	chunk_manager = null


func _on_chunk_loaded(chunk: Chunk) -> void:
	navigation_map.rebuild_chunk(chunk)


func _on_chunk_unloaded(chunk: Chunk) -> void:
	navigation_map.remove_chunk(chunk.position)



func _on_tile_changed(tile_change: WorldTileChange) -> void:
	var chunk_position: Vector2i = chunk_manager.get_chunk_position_from_tile(tile_change.tile_position)
	if not chunk_manager.generated_chunks.has(chunk_position):
		return

	var chunk: Chunk = chunk_manager.generated_chunks[chunk_position]
	var local_position: Vector2i = chunk_manager.get_local_tile_position(tile_change.tile_position)
	var local_index: int = chunk.local_vector_to_index(local_position)

	navigation_map.refresh_chunk_cell(chunk, local_index)



#region astar

func find_tile_path(start_tile: Vector2i, goal_tile: Vector2i, max_searched_tiles: int = 4096) -> Array[Vector2i]:
	if max_searched_tiles <= 0:
		return []

	if navigation_map.get_tile_cost(start_tile) <= 0:
		return []
	if navigation_map.get_tile_cost(goal_tile) <= 0:
		return []

	if start_tile == goal_tile:
		return [start_tile]

	var open_tiles: Array[Vector2i] = [start_tile]             # tiles to process door A*
	var open_tile_lookup: Dictionary[Vector2i, bool] = {}      # dictionary van open tiles, ik denk voor lookup
	var closed_tiles: Dictionary[Vector2i, bool] = {}          # onderzichte tiles, deze moeten niet opnieuw onderzocht worden
	var came_from: Dictionary[Vector2i, Vector2i] = {}         # bewaard de route. huidige tile: vorige tile
	var g_scores: Dictionary[Vector2i, int] = {}               # totale cost van de route
	var f_scores: Dictionary[Vector2i, int] = {}               # g_score + geschatte resterende kost tot het doel

	open_tile_lookup[start_tile] = true
	g_scores[start_tile] = 0
	f_scores[start_tile] = _estimate_remaining_cost(start_tile, goal_tile)

	var searched_tile_count: int = 0

	while not open_tiles.is_empty():
		var current_tile: Vector2i = _take_lowest_f_score_tile(open_tiles, f_scores)
		open_tile_lookup.erase(current_tile)

		if current_tile == goal_tile:
			return _reconstruct_path(came_from, goal_tile)

		closed_tiles[current_tile] = true
		searched_tile_count += 1

		if searched_tile_count >= max_searched_tiles:
			return []

		var current_g_score: int = g_scores[current_tile]

		for neighbour_offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour_tile: Vector2i = current_tile + neighbour_offset

			if closed_tiles.has(neighbour_tile):
				continue

			var move_cost: int = _get_move_cost(current_tile, neighbour_offset)
			if move_cost <= 0:
				continue

			var tentative_g_score: int = current_g_score + move_cost
			var known_g_score: int = g_scores.get(neighbour_tile, MAXIMUM_G_SCORE)

			if tentative_g_score >= known_g_score:
				continue

			came_from[neighbour_tile] = current_tile
			g_scores[neighbour_tile] = tentative_g_score
			f_scores[neighbour_tile] = (tentative_g_score + _estimate_remaining_cost(neighbour_tile, goal_tile))

			if not open_tile_lookup.has(neighbour_tile):
				open_tiles.append(neighbour_tile)
				open_tile_lookup[neighbour_tile] = true

	return []


							   # 0,0                        # 0,0 : 5
func _take_lowest_f_score_tile(open_tiles: Array[Vector2i], f_scores: Dictionary[Vector2i, int]) -> Vector2i:
	var lowest_index: int = 0
	var lowest_f_score: int = f_scores[open_tiles[0]]

	for index: int in range(1, open_tiles.size()):
		var candidate_tile: Vector2i = open_tiles[index]
		var candidate_f_score: int = f_scores[candidate_tile]

		if candidate_f_score < lowest_f_score:
			lowest_index = index
			lowest_f_score = candidate_f_score

	return open_tiles.pop_at(lowest_index)



## returnt de cost van current tile + offset (dus van de neighbour). bv: dirt ground = 10
func _get_move_cost(current_tile: Vector2i, neighbour_offset: Vector2i) -> int:
	var neighbour_tile: Vector2i = current_tile + neighbour_offset
	var destination_cost: int = navigation_map.get_tile_cost(neighbour_tile)
	
	if destination_cost <= 0:
		return 0

	var is_diagonal: bool = (neighbour_offset.x != 0 and neighbour_offset.y != 0)
	if not is_diagonal:
		return destination_cost

	var horizontal_tile: Vector2i = current_tile + Vector2i(neighbour_offset.x, 0)
	var vertical_tile: Vector2i = current_tile + Vector2i(0, neighbour_offset.y)

	if navigation_map.get_tile_cost(horizontal_tile) <= 0:
		return 0

	if navigation_map.get_tile_cost(vertical_tile) <= 0:
		return 0

	return roundi(destination_cost * DIAGONAL_COST_MULTIPLIER)



## maakt schatting zonder rekening te houden met obstacles, een rechte lijn van start naar end path
func _estimate_remaining_cost(from_tile: Vector2i, goal_tile: Vector2i) -> int:
	var horizontal_distance: int = absi(goal_tile.x - from_tile.x)
	var vertical_distance: int = absi(goal_tile.y - from_tile.y)

	return maxi(horizontal_distance, vertical_distance)



## maakt een reconstructie van came_from om zo het path naar de eindbstemming terug te geven.
func _reconstruct_path(came_from: Dictionary[Vector2i, Vector2i], goal_tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal_tile]
	var current_tile: Vector2i = goal_tile

	while came_from.has(current_tile):
		current_tile = came_from[current_tile]
		path.append(current_tile)

	path.reverse()
	return path


#endregion
