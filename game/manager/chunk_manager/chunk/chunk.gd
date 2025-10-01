extends RefCounted
class_name Chunk

var data: Dictionary[Vector2i, Dictionary]
var position: Vector2i
var loaded: bool = false
var last_accessed: float

var ground_layer: Dictionary[Vector2i, Vector2i]
var wall_layer: Dictionary[Vector2i, Vector2i]




func _init(pos: Vector2i) -> void:
	position = pos
	last_accessed = Time.get_ticks_msec() / 1000
	loaded = true
