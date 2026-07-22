class_name SessionPlayer
extends RefCounted

var peer_id: int = 0
var character_id: String = ""
var character_name: String = ""
var world_position: Vector2 = Vector2.ZERO
var player_save_data: PlayerSaveData


static func create(new_peer_id: int, new_character_id: String, new_character_name: String, new_world_position: Vector2) -> SessionPlayer:
	var session_player: SessionPlayer = SessionPlayer.new()

	session_player.peer_id = new_peer_id
	session_player.character_id = new_character_id
	session_player.character_name = new_character_name
	session_player.world_position = new_world_position

	return session_player
