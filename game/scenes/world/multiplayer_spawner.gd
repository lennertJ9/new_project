extends MultiplayerSpawner

@export var player_scene: PackedScene
@export var camera_scene: PackedScene



func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	NetworkManager.server_started.connect(_on_server_started)


# peer toevoegen bij de server
func _on_peer_connected(id: int):
	if not multiplayer.is_server():
		return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	
	get_node(spawn_path).call_deferred("add_child", player)


# speler van de server toevoegen
func _on_server_started(peer_id: int):
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	
	var camera = player.camera_scene.instantiate()
	player.add_child(camera)
	
	get_node("/root/World/ChunkManager").player = player
	get_node("/root/World/ChunkManager").set_process(true)
	get_node(spawn_path).call_deferred("add_child", player)
