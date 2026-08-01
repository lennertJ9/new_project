extends Area2D
class_name MagicBolt


signal projectile_impacted(projectile_id: int)


var projectile_id: int = -1
var speed: int = 100
var direction: Vector2 = Vector2.ZERO
@export var damage: int = 100
var chunk_manager: ChunkManager
var is_authoritative: bool = false

@onready var shapecast: ShapeCast2D = $ShapeCast2D


func configure(
	new_projectile_id: int,
	spawn_position: Vector2,
	spawn_direction: Vector2,
	chunk_manager_reference: ChunkManager,
	should_apply_world_damage: bool
) -> void:
	projectile_id = new_projectile_id
	global_position = spawn_position
	direction = spawn_direction.normalized()
	chunk_manager = chunk_manager_reference
	is_authoritative = should_apply_world_damage

	if not is_authoritative:
		monitoring = false
		monitorable = false
		shapecast.enabled = false


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta




func _on_body_entered(_body: Node2D) -> void:
	if not is_authoritative:
		return

	var hit_position := global_position
	if shapecast.is_colliding():
		var normal := shapecast.get_collision_normal(0)
		hit_position = shapecast.get_collision_point(0) - normal * 0.01

	if chunk_manager != null:
		chunk_manager.damage_wall(hit_position, damage)

	projectile_impacted.emit(projectile_id)
	queue_free()
