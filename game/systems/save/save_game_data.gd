extends RefCounted
class_name SaveGameData


const FORMAT_VERSION: int = 1

var format_version: int = FORMAT_VERSION
var world_seed: int = 0

var player_data: Array[Dictionary] = []


# Alleen chunks die later door gameplay gewijzigd zijn.
var modified_chunks: Dictionary[Vector2i, Dictionary] = {}


static func create_new(new_world_seed: int) -> SaveGameData:
	var save_game: SaveGameData = SaveGameData.new()
	
	save_game.world_seed = new_world_seed
	
	var first_player_data: Dictionary = {
		"player_id":0,
		"position": Vector2(200,0)
	}
	save_game.player_data.append(first_player_data)
	return save_game
