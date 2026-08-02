extends Resource
class_name TileCatalog

## Deze Resource is de bewerkbare catalogus. De dictionaries zijn alleen een
## runtime-index, zodat gameplay snel en via stabiele tile-ID's kan opzoeken.

@export_category("Ground tiles")
@export var ground_tiles: Array[GroundTileDefinition] = []

@export_category("Wall tiles")
@export var wall_tiles: Array[WallTileDefinition] = []

var ground_by_id: Dictionary[int, GroundTileDefinition] = {}
var wall_by_id: Dictionary[int, WallTileDefinition] = {}
var lookup_is_ready: bool = false


func get_ground(tile_id: int) -> GroundTileDefinition:
	ensure_lookup()
	return ground_by_id.get(tile_id)


func get_wall(tile_id: int) -> WallTileDefinition:
	ensure_lookup()
	return wall_by_id.get(tile_id)


func rebuild_lookup() -> PackedStringArray:
	ground_by_id.clear()
	wall_by_id.clear()

	var validation_errors: PackedStringArray = PackedStringArray()
	index_ground_tiles(validation_errors)
	index_wall_tiles(validation_errors)

	lookup_is_ready = true
	return validation_errors


func ensure_lookup() -> void:
	if lookup_is_ready:
		return

	rebuild_lookup()


func index_ground_tiles(validation_errors: PackedStringArray) -> void:
	for definition: GroundTileDefinition in ground_tiles:
		if definition == null:
			validation_errors.append("De ground-catalogus bevat een lege entry.")
			continue

		if definition.tile_id <= 0:
			validation_errors.append(
				"Ground '%s' gebruikt ongeldige tile_id %d. ID 0 is gereserveerd."
				% [definition.display_name, definition.tile_id]
			)
			continue

		if ground_by_id.has(definition.tile_id):
			validation_errors.append(
				"Ground tile_id %d is meer dan één keer gedefinieerd."
				% definition.tile_id
			)
			continue

		ground_by_id[definition.tile_id] = definition


func index_wall_tiles(validation_errors: PackedStringArray) -> void:
	for definition: WallTileDefinition in wall_tiles:
		if definition == null:
			validation_errors.append("De wall-catalogus bevat een lege entry.")
			continue

		if definition.tile_id <= 0:
			validation_errors.append(
				"Wall '%s' gebruikt ongeldige tile_id %d. ID 0 is gereserveerd."
				% [definition.display_name, definition.tile_id]
			)
			continue

		if wall_by_id.has(definition.tile_id):
			validation_errors.append(
				"Wall tile_id %d is meer dan één keer gedefinieerd."
				% definition.tile_id
			)
			continue

		wall_by_id[definition.tile_id] = definition
