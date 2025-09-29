extends RefCounted
class_name Chunk

var data: Dictionary[Vector2i, Dictionary]
var index: Vector2i
var loaded: bool = false
var last_accessed: float


func _init(tiles: Dictionary[Vector2i, Dictionary]) -> void:
	
	data = tiles
