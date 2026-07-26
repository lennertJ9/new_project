class_name WorldTileChange
extends RefCounted


var tile_position: Vector2i = Vector2i.ZERO
var layer: int = Chunk.TileLayer.WALL
var tile_id: int = 0


static func create(new_tile_position: Vector2i, new_layer: int, new_tile_id: int) -> WorldTileChange:
	var tile_change: WorldTileChange = WorldTileChange.new()

	tile_change.tile_position = new_tile_position
	tile_change.layer = new_layer
	tile_change.tile_id = new_tile_id

	return tile_change


func to_dictionary() -> Dictionary:
	return {
		"tile_position": tile_position,
		"layer": layer,
		"tile_id": tile_id,
	}


static func from_dictionary(data: Dictionary) -> WorldTileChange:
	var raw_tile_position: Variant = data.get("tile_position")
	var raw_layer: Variant = data.get("layer")
	var raw_tile_id: Variant = data.get("tile_id")

	if not raw_tile_position is Vector2i:
		return null

	if not raw_layer is int:
		return null

	if not raw_tile_id is int or raw_tile_id < 0:
		return null

	return create(raw_tile_position, raw_layer, raw_tile_id)
