class_name WorldJoinData
extends RefCounted


const NETWORK_PROTOCOL_VERSION: int = 1


var protocol_version: int = NETWORK_PROTOCOL_VERSION
var world_id: String = ""
var world_seed: int = 0
var world_name: String = ""
var spawn_position: Vector2 = Vector2.ZERO


static func from_world_save_data(world_data: WorldSaveData) -> WorldJoinData:
	var join_data: WorldJoinData = WorldJoinData.new()
	join_data.world_id = world_data.world_id
	join_data.world_seed = world_data.world_seed
	join_data.world_name = world_data.world_name
	join_data.spawn_position = world_data.spawn_position
	return join_data


func to_dictionary() -> Dictionary:
	return {
		"protocol_version": protocol_version,
		"world_id": world_id,
		"world_seed": world_seed,
		"world_name": world_name,
		"spawn_position": spawn_position,
	}


static func from_dictionary(data: Dictionary) -> WorldJoinData:
	if data.get("protocol_version") is not int:
		return null

	if data.get("protocol_version") != NETWORK_PROTOCOL_VERSION:
		return null

	if data.get("world_id") is not String:
		return null

	if data.get("world_id").is_empty():
		return null

	if data.get("world_seed") is not int:
		return null

	if data.get("world_name") is not String:
		return null

	if data.get("spawn_position") is not Vector2:
		return null

	var join_data: WorldJoinData = WorldJoinData.new()
	join_data.world_id = data["world_id"]
	join_data.world_seed = data["world_seed"]
	join_data.world_name = data["world_name"]
	join_data.spawn_position = data["spawn_position"]
	return join_data



func to_initial_world_save_data() -> WorldSaveData:
	var world_data: WorldSaveData = WorldSaveData.new()
	world_data.world_id = world_id
	world_data.world_seed = world_seed
	world_data.world_name = world_name
	world_data.spawn_position = spawn_position
	return world_data
