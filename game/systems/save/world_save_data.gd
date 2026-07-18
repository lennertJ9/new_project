class_name WorldSaveData
extends RefCounted


const FORMAT_VERSION: int = 1

var format_version: int = FORMAT_VERSION
var world_id: String = ""
var world_seed: int = 0
var world_name: String = "New World"
var spawn_position: Vector2 = Vector2(-200.0, 0.0)

# Only chunks changed by gameplay need to be persisted later.
var modified_wall_ids: Dictionary[Vector2i, Dictionary] = {}
var modified_ground_ids: Dictionary[Vector2i, Dictionary] = {}
var modified_cliff_ids: Dictionary[Vector2i, Dictionary] = {}


static func create_new(new_world_seed: int, new_world_name: String = "new world") -> WorldSaveData:
	var world_data: WorldSaveData = WorldSaveData.new()
	world_data.world_id = "world_%s_%s" % [new_world_seed, Time.get_ticks_usec()]
	world_data.world_seed = new_world_seed
	world_data.world_name = new_world_name
	return world_data


func to_dictionary() -> Dictionary:
	return {
		"format_version": format_version,
		"world_id": world_id,
		"world_seed": world_seed,
		"world_name": world_name,
		"spawn_position": spawn_position,
		"modified_wall_ids": modified_wall_ids.duplicate(true),
		"modified_ground_ids": modified_ground_ids.duplicate(true),
		"modified_cliff_ids": modified_cliff_ids.duplicate(true)
	}



# Bouwt bestaande werelddata opnieuw op uit een opgeslagen dictionary.
static func from_dictionary(data: Dictionary) -> WorldSaveData:
	var world_data: WorldSaveData = WorldSaveData.new()

	world_data.format_version = int(data.get("format_version", FORMAT_VERSION))
	world_data.world_id = str(data.get("world_id", ""))
	world_data.world_name = str(data.get("world_name", "new world"))
	world_data.world_seed = int(data.get("world_seed", 0))

	var saved_spawn_position: Variant = data.get(
		"spawn_position",
		world_data.spawn_position
	)
	
	if saved_spawn_position is Vector2:
		world_data.spawn_position = saved_spawn_position

	var saved_modified_wall_ids: Dictionary = data.get("modified_wall_ids", {})
	var saved_modified_ground_ids: Dictionary = data.get("modified_ground_ids", {})
	var saved_modified_cliff_ids: Dictionary = data.get("modified_cliff_ids", {})

	world_data.modified_wall_ids.assign(saved_modified_wall_ids)
	world_data.modified_ground_ids.assign(saved_modified_ground_ids)
	world_data.modified_cliff_ids.assign(saved_modified_cliff_ids)

	return world_data
