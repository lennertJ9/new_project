extends Node

@export var player: CharacterBody2D

var shadow_layer: TileMapLayer
var wall_layer: TileMapLayer


var timer: float = 0
var fov_distance = 12

func _ready() -> void:
	shadow_layer = ChunkManager.shadow_layer
	wall_layer = ChunkManager.wall_layer


func _process(delta: float) -> void:
	timer += delta
	if timer > 0.25:
		timer = 0
		calculate_fov()


func calculate_fov():
	var player_pos: Vector2i = player.global_position
	var global_tile_pos = shadow_layer.local_to_map(player_pos)
	
	if ChunkManager.generated_chunks.has(floor(player_pos / 256)):
		
		var current_chunk: Chunk = ChunkManager.generated_chunks[floor(player_pos / 256)]
	
		var tiles_to_process: Array
		var tiles_to_process_copy: Array
		tiles_to_process.append(global_tile_pos)
		var checked = false
		
		for distance in fov_distance:
			for tile in tiles_to_process:
				shadow_layer.erase_cell(tile)
				
				if not wall_layer.get_cell_tile_data(Vector2(tile.x, tile.y + 1)) and not tiles_to_process_copy.has(Vector2(tile.x, tile.y + 1)):
					tiles_to_process_copy.append(Vector2(tile.x, tile.y + 1))
					
				if not wall_layer.get_cell_tile_data(Vector2(tile.x + 1, tile.y)) and not tiles_to_process_copy.has(Vector2(tile.x + 1, tile.y)):
					tiles_to_process_copy.append(Vector2(tile.x + 1, tile.y))
					
				if not wall_layer.get_cell_tile_data(Vector2(tile.x, tile.y - 1)) and not tiles_to_process_copy.has(Vector2(tile.x, tile.y - 1)):
					tiles_to_process_copy.append(Vector2(tile.x, tile.y - 1))
					
				if not wall_layer.get_cell_tile_data(Vector2(tile.x - 1, tile.y)) and not tiles_to_process_copy.has(Vector2(tile.x - 1, tile.y)):
					tiles_to_process_copy.append(Vector2(tile.x - 1, tile.y))
			
			
			if not checked:
				print(tiles_to_process)
				print("---------------------------")
			
			tiles_to_process = tiles_to_process_copy.duplicate()
			
			tiles_to_process_copy.clear()
		checked = true
