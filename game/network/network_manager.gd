extends Node

var player_scene: PackedScene
signal server_created
signal client_created

const SERVER_PORT: int = 25001
var is_hosting_game = false


func create_server():
	var is_hosting_game = true
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	enet_network_peer.create_server(SERVER_PORT)
	get_tree().get_multiplayer().multiplayer_peer = enet_network_peer
	server_created.emit()
	print("server created")


func create_client(host_ip: String = "localhost", host_port: int = SERVER_PORT):
	var is_hosting_game = false
	_setup_client_connection_signals()
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	enet_network_peer.create_client(host_ip, host_port)
	get_tree().get_multiplayer().multiplayer_peer = enet_network_peer
	client_created.emit()
	print("client peer created")


func _setup_client_connection_signals():
	if not get_tree().get_multiplayer().server_disconnected.is_connected(on_server_disconnected):
		get_tree().get_multiplayer().server_disconnected.connect(on_server_disconnected)


func on_server_disconnected():
	print("server disconnected")
	get_tree().get_multiplayer().multiplayer_peer = null
