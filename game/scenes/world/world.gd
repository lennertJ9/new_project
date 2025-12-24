extends Node2D

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D

var b = 1
@onready var label: Label = $CanvasLayer/Label # fps lable
@onready var player_manager: Node2D = $PlayerManager

# -------------- networking -------------------- #


# ---------------------------------------------- #


var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array



func _process(delta: float) -> void:
	label.text = str(Engine.get_frames_per_second())
