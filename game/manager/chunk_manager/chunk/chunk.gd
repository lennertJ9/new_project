extends RefCounted
class_name Chunk

var data: Dictionary[Vector2i, Dictionary]
var index: Vector2i
var loaded: bool = false
var last_accessed: float

var ground_layer: Dictionary[Vector2i, Vector2i]
var wall_layer: Dictionary[Vector2i, Vector2i]


func _init(dict_ground: Dictionary[Vector2i, Vector2i], dict_walls: Dictionary[Vector2i, Vector2i]) -> void:
	last_accessed = Time.get_ticks_msec() / 1000
	ground_layer = dict_ground
	wall_layer = dict_walls
	loaded = true
