extends Area2D
class_name MagicBolt


var speed: int = 100
var direction: Vector2 
@export var damage: int = 100
var chunk_manager: ChunkManager

@onready var shapecast: ShapeCast2D = $ShapeCast2D


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	



func _on_body_entered(_body: Node2D) -> void:
	var hit_position := global_position
	if shapecast.is_colliding():
		var normal := shapecast.get_collision_normal(0)
		hit_position = shapecast.get_collision_point(0) - normal * 0.01

	if chunk_manager != null:
		chunk_manager.damage_wall(hit_position, damage)
	queue_free()
