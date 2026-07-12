class_name PlayerSaveData
extends RefCounted


const FORMAT_VERSION: int = 1

var format_version: int = FORMAT_VERSION
var character_id: String = ""
var character_name: String = "New Character"
var health: int = 100
var max_health: int = 100

# A character can remember a different location in every world.
var last_position_by_world: Dictionary[String, Vector2] = {}


static func create_new() -> PlayerSaveData:
	var player_data: PlayerSaveData = PlayerSaveData.new()
	player_data.character_id = "character_%s" % Time.get_ticks_usec()
	return player_data


func get_position_for_world(world_id: String, fallback_position: Vector2) -> Vector2:
	if last_position_by_world.has(world_id):
		return last_position_by_world[world_id]

	return fallback_position


func set_position_for_world(world_id: String, position: Vector2) -> void:
	last_position_by_world[world_id] = position



func to_dictionary() -> Dictionary:
	return {
		"format_version": format_version,
		"character_id": character_id,
		"character_name": character_name,
		"health": health,
		"max_health": max_health,
		"last_position_by_world": last_position_by_world.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> PlayerSaveData:
	var player_data: PlayerSaveData = PlayerSaveData.new()

	player_data.format_version = int(data.get("format_version", FORMAT_VERSION))
	player_data.character_id = str(data.get("character_id", ""))
	player_data.character_name = str(data.get("character_name", "New Character"))
	player_data.health = int(data.get("health", 100))
	player_data.max_health = int(data.get("max_health", 100))

	var saved_positions: Variant = data.get("last_position_by_world", {})
	if saved_positions is Dictionary:
		for raw_world_id in saved_positions:
			if not raw_world_id is String:
				continue

			var raw_position: Variant = saved_positions[raw_world_id]
			if not raw_position is Vector2:
				continue

			var world_id: String = raw_world_id
			var position: Vector2 = raw_position
			player_data.last_position_by_world[world_id] = position

	return player_data
