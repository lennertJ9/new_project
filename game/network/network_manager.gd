extends Node

signal server_started


const IP_ADDRESS: String = "localhost"
const PORT: int = 25001

var peer: ENetMultiplayerPeer
var is_server: bool = false




func start_server():
	is_server = true
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	server_started.emit(get_multiplayer_authority())



func start_client():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
