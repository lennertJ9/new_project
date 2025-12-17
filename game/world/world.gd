extends Node2D

@export var noise_tex: NoiseTexture2D
@export var camera: Camera2D


@onready var label: Label = $CanvasLayer/Label # fps lable

# -------------- networking -------------------- #
@export var player_scene: PackedScene
@onready var player_manager = $PlayerManager
# ---------------------------------------------- #


var shadow_grass_tiles: Array[Vector2i]
var wall_tiles: Array[Vector2i]
var width: int = 250
var height: int = 250
var values: Array



func _ready() -> void:
	NetworkManager.server_created.connect(create_spawn_manager) 


func _process(delta: float) -> void:
	label.text = str(Engine.get_frames_per_second())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("join_server"):
		NetworkManager.create_client()
	
	if event.is_action_pressed("create_server"):
		NetworkManager.create_server()
	
	if event.is_action_pressed("debug"):
		_send_test_message.rpc("hello there")


@rpc("any_peer", "call_remote")
func _send_test_message(message: String):
	print("message [%s] received on peer [%s], from peer [%s]." % 
	[message, 
	get_tree().get_multiplayer().get_unique_id(),
	get_tree().get_multiplayer().get_remote_sender_id()])


func create_spawn_manager():
	var spawn_manager_scene = load("res://multiplayer/spawn_manager.tscn")
	var spawn_manager = spawn_manager_scene.instantiate()
	spawn_manager.player_scene = player_scene
	add_child(spawn_manager)
