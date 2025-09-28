extends RefCounted
class_name Chunk

var data: Dictionary[Vector2i, Dictionary]
var index: Vector2i


func _init(tiles: Dictionary[Vector2i, Dictionary]) -> void:
	
	data = tiles
