extends CharacterBody2D


var speed: int = 80

var path: PackedVector2Array
var is_moving: bool


func _physics_process(delta: float) -> void:
	if path.is_empty():
		return
	
	velocity = position.direction_to(path[0]) * speed
	move_and_slide()
	
	if is_arrived():
		path.remove_at(0)


func is_arrived():
	if position.distance_to(path[0]) < 1:
		return true
	else:
		return false


func get_AStar_path(start_pos, end_pos):
	path = AStarManager.get_astar_path(start_pos, end_pos)
	print(path)


func _on_timer_timeout() -> void:
	get_AStar_path(global_position, get_global_mouse_position())
