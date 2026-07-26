class_name SessionPlayer
extends RefCounted

var peer_id: int = 0
var character_id: String = ""
var character_name: String = ""
var player_save_data: PlayerSaveData

var latest_movement_input: Vector2 = Vector2.ZERO
var last_received_input_sequence: int = -1
var last_input_received_time_msec: int = 0



static func create(new_peer_id: int, new_character_id: String, new_character_name: String) -> SessionPlayer:
	var session_player: SessionPlayer = SessionPlayer.new()

	session_player.peer_id = new_peer_id
	session_player.character_id = new_character_id
	session_player.character_name = new_character_name
	

	return session_player
