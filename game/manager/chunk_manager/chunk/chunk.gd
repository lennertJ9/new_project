extends RefCounted
class_name Chunk

var data: Dictionary[Vector2i, Dictionary]
var position: Vector2i
var last_accessed: float
var is_loaded: bool = false
var is_generating: bool 


var ground_layer: Dictionary[Vector2i, Vector2i]
var wall_layer: Dictionary[Vector2i, Vector2i]




func _init(pos: Vector2i) -> void:
	position = pos
	is_generating = true
