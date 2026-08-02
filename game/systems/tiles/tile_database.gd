extends RefCounted
class_name TileDatabase

## De catalogus blijft een Resource die je in de Inspector bewerkt. Deze class
## is alleen de kleine, centrale toegangspoort voor gameplaycode.

const CATALOG: TileCatalog = preload("res://data/tiles/tile_catalog.tres")


static func get_ground(tile_id: int) -> GroundTileDefinition:
	return CATALOG.get_ground(tile_id)


static func get_wall(tile_id: int) -> WallTileDefinition:
	return CATALOG.get_wall(tile_id)


static func validate_catalog() -> PackedStringArray:
	return CATALOG.rebuild_lookup()
