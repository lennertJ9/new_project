class_name WorldStartData
extends RefCounted


var world_data: WorldSaveData
var players_data: Array[PlayerSaveData] = []





static func create(world_data_to_start: WorldSaveData, players_to_start: Array[PlayerSaveData]) -> WorldStartData:
	var start_data: WorldStartData = WorldStartData.new()
	start_data.world_data = world_data_to_start
	start_data.players_data = players_to_start
	return start_data
