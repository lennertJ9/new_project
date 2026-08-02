extends Resource
class_name GroundTileDefinition

## tile_id moet overeenkomen met de waarde in Chunk.ground_id_layer.
## ID 0 blijft gereserveerd voor een lege, niet-begaanbare tile.

@export_category("Identity")
@export var tile_id: int = 0
@export var display_name: String = ""

@export_category("Navigation")
@export var is_walkable: bool = true
@export_range(1, 255, 1) var movement_cost: int = 10
