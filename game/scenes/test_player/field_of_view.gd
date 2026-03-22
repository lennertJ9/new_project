extends Node

@export var player: CharacterBody2D

var tilemap: TileMapLayer


var timer: float = 0
var fov_distance = 8

func _ready() -> void:
	tilemap = ChunkManager.shadow_layer
	


func _process(delta: float) -> void:
	timer += delta
	if timer > 0.05:
		timer = 0
		calculate_fov()


func calculate_fov():
	var player_pos: Vector2i = player.global_position
	var global_tile_pos = tilemap.local_to_map(player_pos)
	
	
	
	if ChunkManager.generated_chunks.has(floor(player_pos / 256)):
		
		var current_chunk: Chunk = ChunkManager.generated_chunks[floor(player_pos / 256)]
	
		var tiles_to_process: Array
		var tiles_to_process_copy: Array
		tiles_to_process.append(global_tile_pos)
		
		
		for distance in fov_distance:
			for tile in tiles_to_process:
				tilemap.erase_cell(tile)
				
				
				tiles_to_process_copy.append(Vector2(tile.x, tile.y + 1))
				tiles_to_process_copy.append(Vector2(tile.x + 1, tile.y))
				tiles_to_process_copy.append(Vector2(tile.x, tile.y - 1))
				tiles_to_process_copy.append(Vector2(tile.x - 1, tile.y))
			
			tiles_to_process = tiles_to_process_copy.duplicate()
			tiles_to_process_copy.clear()
