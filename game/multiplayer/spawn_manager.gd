class_name SpawnManager
extends Node


@onready var spawn_path: Node2D = get_tree().current_scene.get_node("%PlayerManager")
@export var player_scene: PackedScene



func _ready() -> void:
	get_tree().get_multiplayer().peer_connected.connect(on_peer_connected)
	get_tree().get_multiplayer().peer_disconnected.connect(on_peer_disconnected)
	add_player_to_game(1)


func on_peer_connected(network_id):
	print("peer connected: %s" % network_id)
	add_player_to_game(network_id)


func on_peer_disconnected(network_id):
	print("peer disconnected: %s" % network_id)


func add_player_to_game(network_id: int):
	var player_to_add = player_scene.instantiate()
	player_to_add.name = str(network_id)
	player_to_add.set_multiplayer_authority(1)
	spawn_path.add_child(player_to_add)
