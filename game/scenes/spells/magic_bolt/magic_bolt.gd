extends Area2D


var speed: int = 100
var direction: Vector2 

@onready var shapecast: ShapeCast2D = $ShapeCast2D


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	



func _on_body_entered(body: Node2D) -> void:
	var point = shapecast.get_collision_point(0)
	var normal = shapecast.get_collision_normal(0)
	print("collided on: ", point)
	temp_kill_wall(point, normal)
	queue_free()


func temp_kill_wall(_point, _normal):
	var chunkmanager_node: ChunkManager = get_node("/root/World/ChunkManager")
	
	var point = shapecast.get_collision_point(0)
	var normal = shapecast.get_collision_normal(0)
	point -= normal * 0.01
	chunkmanager_node.damage_wall(point)
