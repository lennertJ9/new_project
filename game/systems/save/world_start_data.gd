class_name WorldStartData
extends RefCounted


var world_data: WorldSaveData
var local_player_data: PlayerSaveData





static func create(
	world_data_to_start: WorldSaveData,
	local_player_data_to_start: PlayerSaveData
) -> WorldStartData:
	var start_data: WorldStartData = WorldStartData.new()
	start_data.world_data = world_data_to_start
	start_data.local_player_data = local_player_data_to_start
	return start_data
