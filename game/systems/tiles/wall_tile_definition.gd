extends Resource
class_name WallTileDefinition

## tile_id moet overeenkomen met de waarde in Chunk.wall_id_layer.
## ID 0 blijft gereserveerd voor geen muur.

@export_category("Identity")
@export var tile_id: int = 0
@export var display_name: String = ""

@export_category("Navigation")
@export var blocks_movement: bool = true

@export_category("Destruction")
@export var max_health: int = 100
@export var damageable: bool = true
## Wordt als vaste vermindering van elke damage-hit gebruikt.
@export var damage_resistance: int = 0
