extends MultiplayerSpawner

@export var player: PackedScene



func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)



func _on_peer_connected(id: int):
	if not multiplayer.is_server():
		return
	
	var player: Node = player.instantiate()
	player.name = str(id)
	
	get_node(spawn_path).call_deferred("add_child", player)
	
