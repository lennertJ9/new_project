extends RefCounted
class_name NavigationMap

## Dit is gedeelde navigatiedata, geen A*-graph. Elke geladen chunk krijgt
## precies 256 kostenwaarden. De eigen A*-zoeker komt pas in een volgende stap.

const TILE_DATABASE := preload("res://systems/tiles/tile_database.gd")
const CHUNK_SIZE: int = 16
const CELL_COUNT: int = CHUNK_SIZE * CHUNK_SIZE

const COST_UNAVAILABLE: int = -1
const COST_BLOCKED: int = 0

var costs_by_chunk: Dictionary[Vector2i, PackedByteArray] = {}
var revision: int = 0



func rebuild_chunk(chunk: Chunk) -> void:
	var costs: PackedByteArray = PackedByteArray()
	costs.resize(CELL_COUNT)

	for local_index: int in range(CELL_COUNT):
		costs[local_index] = calculate_chunk_cell_cost(chunk, local_index)

	costs_by_chunk[chunk.position] = costs
	revision += 1



func remove_chunk(chunk_position: Vector2i) -> void:
	if not costs_by_chunk.erase(chunk_position):
		return

	revision += 1



func refresh_chunk_cell(chunk: Chunk, local_index: int) -> void:
	if not costs_by_chunk.has(chunk.position):
		return

	if local_index < 0 or local_index >= CELL_COUNT:
		return

	var costs: PackedByteArray = costs_by_chunk[chunk.position]
	var new_cost: int = calculate_chunk_cell_cost(chunk, local_index)
	if costs[local_index] == new_cost:
		return

	costs[local_index] = new_cost
	costs_by_chunk[chunk.position] = costs
	revision += 1



## return cost van een tile, 0 = geen data | -1 = muur, cliff, niet passable
func get_tile_cost(tile_position: Vector2i) -> int:
	var chunk_position: Vector2i = Vector2i(
		floori(float(tile_position.x) / float(CHUNK_SIZE)),
		floori(float(tile_position.y) / float(CHUNK_SIZE))
	)
	if not costs_by_chunk.has(chunk_position):
		return COST_UNAVAILABLE

	var local_position: Vector2i = Vector2i(
		posmod(tile_position.x, CHUNK_SIZE),
		posmod(tile_position.y, CHUNK_SIZE)
	)
	var local_index: int = local_position.y * CHUNK_SIZE + local_position.x
	var costs: PackedByteArray = costs_by_chunk[chunk_position]
	return costs[local_index]



func calculate_chunk_cell_cost(chunk: Chunk, local_index: int) -> int:
	var wall_id: int = chunk.wall_id_layer[local_index]
	if wall_id != 0:
		var wall_definition: WallTileDefinition = TILE_DATABASE.get_wall(wall_id)
		if wall_definition == null or wall_definition.blocks_movement:
			return COST_BLOCKED

	if chunk.cliff_id_layer[local_index] != 0:
		return COST_BLOCKED

	var ground_id: int = chunk.ground_id_layer[local_index]
	var ground_definition: GroundTileDefinition = TILE_DATABASE.get_ground(ground_id)
	if ground_definition == null or not ground_definition.is_walkable:
		return COST_BLOCKED

	return clampi(ground_definition.movement_cost, 1, 255)



func clear() -> void:
	if costs_by_chunk.is_empty():
		return

	costs_by_chunk.clear()
	revision += 1
