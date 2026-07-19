extends Node



const SAVE_ROOT_PATH: String = "user://saves"
const WORLDS_DIRECTORY_PATH: String = SAVE_ROOT_PATH + "/worlds"
const PLAYERS_DIRECTORY_PATH: String = SAVE_ROOT_PATH + "/players"




func _ready() -> void:
	ensure_save_directories()




# maken van de folder waar de saves van world en speler in komen te staan
func ensure_save_directories() -> void:
	DirAccess.make_dir_recursive_absolute(WORLDS_DIRECTORY_PATH)
	DirAccess.make_dir_recursive_absolute(PLAYERS_DIRECTORY_PATH)


func get_world_save_path(world_id: String) -> String:
	return WORLDS_DIRECTORY_PATH.path_join(world_id + ".save")



func get_player_save_path(character_id: String) -> String:
	return PLAYERS_DIRECTORY_PATH.path_join(character_id + ".save")


# opslaan van de properties van de world naar een file
func save_world(world_data: WorldSaveData) -> Error:
	if world_data.world_id.is_empty():
		return ERR_INVALID_PARAMETER

	var save_path: String = get_world_save_path(world_data.world_id)
	var save_dictionary: Dictionary = world_data.to_dictionary()

	return write_save_file_safely(save_path, save_dictionary)



# opslaan van de properties van de player naar een file (zoals position op worldID)
func save_player(player_data: PlayerSaveData) -> Error:
	if player_data.character_id.is_empty():
		return ERR_INVALID_PARAMETER

	var save_path: String = get_player_save_path(player_data.character_id)
	var save_dictionary: Dictionary = player_data.to_dictionary()

	return write_save_file_safely(save_path, save_dictionary)



func write_save_file_safely(save_path: String, save_dictionary: Dictionary) -> Error:
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)

	if file == null:
		return FileAccess.get_open_error()

	file.store_var(save_dictionary)
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		return write_error

	if FileAccess.file_exists(save_path):
		var backup_error: Error = DirAccess.rename_absolute(save_path, backup_path)

		if backup_error != OK:
			return backup_error

	var replace_error: Error = DirAccess.rename_absolute(temporary_path, save_path)

	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, save_path)

		return replace_error

	return OK
	


# laad het worldsavedata vanuit een file/dictionary om een wereld te kunnen starten/loaden 
func load_world(world_id: String) -> WorldSaveData:
	if world_id.is_empty():
		return null

	var world_path: String = get_world_save_path(world_id)
	var world_data: WorldSaveData = _try_load_world_from_path(world_path, world_id)

	if world_data != null:
		return world_data
	
	print("error in save file!")
	var backup_path: String = world_path + ".bak"
	return _try_load_world_from_path(backup_path, world_id)



func load_player(character_id: String) -> PlayerSaveData:
	if character_id.is_empty():
		return null

	var player_path: String = get_player_save_path(character_id)
	var player_data: PlayerSaveData = _try_load_player_from_path(player_path, character_id)

	if player_data != null:
		return player_data

	var backup_path: String = player_path + ".bak"
	return _try_load_player_from_path(backup_path, character_id)



func create_and_save_new_world(new_world_seed: int, world_name: String) -> WorldSaveData:
	var clean_world_name: String = world_name.strip_edges()
	if clean_world_name.is_empty():
		return null

	var world_data: WorldSaveData = WorldSaveData.create_new(new_world_seed, clean_world_name)

	save_world(world_data)
	

	return world_data



func create_and_save_new_player(character_name: String) -> PlayerSaveData:
	var clean_character_name: String = character_name.strip_edges()

	if clean_character_name.is_empty():
		return null

	var player_data: PlayerSaveData = PlayerSaveData.create_new()
	player_data.character_name = clean_character_name

	var save_error: Error = save_player(player_data)
	if save_error != OK:
		return null

	return player_data


func get_saved_worlds() -> Array[WorldSaveData]:
	var saved_worlds: Array[WorldSaveData] = []

	var directory: DirAccess = DirAccess.open(WORLDS_DIRECTORY_PATH)
	if directory == null:
		return saved_worlds
	
	var file_names: PackedStringArray = directory.get_files()

	for file_name: String in file_names:
		if file_name.get_extension() != "save":
			continue

		var world_id: String = file_name.get_basename()
		var world_data: WorldSaveData = load_world(world_id)

		if world_data != null:
			saved_worlds.append(world_data)

	return saved_worlds



func get_saved_players() -> Array[PlayerSaveData]:
	var saved_players: Array[PlayerSaveData] = []

	var directory: DirAccess = DirAccess.open(PLAYERS_DIRECTORY_PATH)
	if directory == null:
		return saved_players
	
	var file_names: PackedStringArray = directory.get_files()

	for file_name: String in file_names:
		if file_name.get_extension() != "save":
			continue

		var player_id: String = file_name.get_basename()
		var player_data: PlayerSaveData = load_player(player_id)

		if player_data != null:
			saved_players.append(player_data)

	return saved_players



# heleboel checks als save bestand in orde is
func _try_load_world_from_path(world_path: String, expected_world_id: String) -> WorldSaveData:
	# 1. Bestaat en opent het bestand?
	if not FileAccess.file_exists(world_path):
		return null
	
	var file: FileAccess = FileAccess.open(world_path, FileAccess.READ)
	if file == null:
		return null
	
	# 2. Kan Godot de binaire Variant volledig lezen?
	var raw_world_data: Variant = file.get_var()
	var read_error: Error = file.get_error()
	file.close()
	
	if read_error != OK:
		return null
	
	# 3. Was het opgeslagen object werkelijk een Dictionary?
	if raw_world_data is not Dictionary:
		return null
	
	var world_dictionary: Dictionary = raw_world_data
	
	if world_dictionary.get("format_version") is not int:
		return null
	
	if world_dictionary.get("format_version") != WorldSaveData.FORMAT_VERSION:
		return null
	
	if world_dictionary.get("world_id") is not String:
		return null
	
	if world_dictionary.get("world_id") != expected_world_id:
		return null
	
	if world_dictionary.get("world_seed") is not int:
		return null
	
	if world_dictionary.get("world_name") is not String:
		return null
	
	if world_dictionary.get("spawn_position") is not Vector2:
		return null
		
	if world_dictionary.get("modified_wall_ids") is not Dictionary:
		return null

	if world_dictionary.get("modified_ground_ids") is not Dictionary:
		return null

	if world_dictionary.get("modified_cliff_ids") is not Dictionary:
		return null
	
	return WorldSaveData.from_dictionary(world_dictionary)


func _try_load_player_from_path(player_path: String, expected_character_id: String) -> PlayerSaveData:
	if not FileAccess.file_exists(player_path):
		return null

	var file: FileAccess = FileAccess.open(player_path, FileAccess.READ)
	if file == null:
		return null

	var raw_player_data: Variant = file.get_var()
	var read_error: Error = file.get_error()
	file.close()

	if read_error != OK:
		return null

	if raw_player_data is not Dictionary:
		return null

	var player_dictionary: Dictionary = raw_player_data

	if player_dictionary.get("format_version") is not int:
		return null

	if player_dictionary.get("format_version") != PlayerSaveData.FORMAT_VERSION:
		return null

	if player_dictionary.get("character_id") is not String:
		return null

	if player_dictionary.get("character_id") != expected_character_id:
		return null

	if player_dictionary.get("character_name") is not String:
		return null

	if player_dictionary.get("health") is not int:
		return null

	if player_dictionary.get("max_health") is not int:
		return null

	if player_dictionary.get("last_position_by_world") is not Dictionary:
		return null

	return PlayerSaveData.from_dictionary(player_dictionary)
