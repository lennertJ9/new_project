extends MultiplayerSpawner

@export var player_scene: PackedScene



func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	NetworkManager.server_started.connect(_on_server_started)



func _on_peer_connected(id: int): # alleen voor de clients
	if not multiplayer.is_server():
		return
	
	var player: Node = player_scene.instantiate()
	player.name = str(id)
	
	get_node(spawn_path).call_deferred("add_child", player)


func _on_server_started(peer_id):
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	
	get_node(spawn_path).call_deferred("add_child", player)
