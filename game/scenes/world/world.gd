extends Node2D

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D


@onready var label: Label = $CanvasLayer/Label # fps lable


@export var enemy_scene: PackedScene

var debug_mode: bool = false



var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array



func _process(delta: float) -> void:
	label.text = str(Engine.get_frames_per_second())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		enemy.global_position = get_global_mouse_position()
		add_child(enemy)
