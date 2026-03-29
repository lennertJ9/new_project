extends Node

@export var player: CharacterBody2D

var shadow_layer: TileMapLayer
var wall_layer: TileMapLayer


var timer: float = 0
var fov_distance = 16

var tiles_to_process: Array
var tiles_to_process_copy: Array

var shadow_lookup: Dictionary[Vector2i, Array] = {
	Vector2i(1,2): [Vector2i(1,2)],
	Vector2i(2,2): [Vector2i(2,2)],
	Vector2i(6,1): [Vector2i(6,1)],
	
}



func _ready() -> void:
	shadow_layer = ChunkManager.shadow_layer
	wall_layer = ChunkManager.wall_layer


func _process(delta: float) -> void:
	timer += delta
	if timer > 0.5:
		timer = 0
		calculate_fov()


func calculate_fov():
	var player_pos: Vector2i = player.global_position
	var global_tile_pos = shadow_layer.local_to_map(player_pos)
	
	if ChunkManager.generated_chunks.has(floor(player_pos / 256)):
		var current_chunk: Chunk = ChunkManager.generated_chunks[floor(player_pos / 256)]
	
		tiles_to_process.append(global_tile_pos)
		
		
		for distance in fov_distance:
			for tile in tiles_to_process:
				shadow_layer.erase_cell(tile)
				process_tile(Vector2i(tile.x, tile.y - 1))
				process_tile(Vector2i(tile.x + 1, tile.y))
				process_tile(Vector2i(tile.x, tile.y + 1))
				process_tile(Vector2i(tile.x - 1, tile.y))
				
				#if not wall_layer.get_cell_tile_data(Vector2i(tile.x, tile.y - 1)) and not tiles_to_process_copy.has(Vector2i(tile.x, tile.y - 1)):
					#tiles_to_process_copy.append(Vector2i(tile.x, tile.y - 1))
				#else:
					#var atlas_coords = wall_layer.get_cell_atlas_coords(Vector2i(tile.x, tile.y - 1))
					#
					#if shadow_lookup.has(atlas_coords):
						#shadow_layer.set_cell(Vector2i(tile.x, tile.y - 1),1, atlas_coords)
				#
				#
				#if not wall_layer.get_cell_tile_data(Vector2i(tile.x + 1, tile.y)) and not tiles_to_process_copy.has(Vector2i(tile.x + 1, tile.y)):
					#tiles_to_process_copy.append(Vector2i(tile.x + 1, tile.y))
				#else:
					#var atlas_coords = wall_layer.get_cell_atlas_coords(Vector2i(tile.x + 1, tile.y))
					#
					#if shadow_lookup.has(atlas_coords):
						#shadow_layer.set_cell(Vector2i(tile.x + 1, tile.y),1, atlas_coords)
					#
				#if not wall_layer.get_cell_tile_data(Vector2i(tile.x, tile.y + 1)) and not tiles_to_process_copy.has(Vector2i(tile.x, tile.y + 1)):
					#tiles_to_process_copy.append(Vector2i(tile.x, tile.y + 1))
				#else:
					#var atlas_coords = wall_layer.get_cell_atlas_coords(Vector2i(tile.x, tile.y + 1))
					#
					#if shadow_lookup.has(atlas_coords):
						#shadow_layer.set_cell(Vector2i(tile.x, tile.y + 1),1, atlas_coords)
				#
				#if not wall_layer.get_cell_tile_data(Vector2i(tile.x - 1, tile.y)) and not tiles_to_process_copy.has(Vector2i(tile.x - 1, tile.y)):
					#tiles_to_process_copy.append(Vector2i(tile.x - 1, tile.y))
				#else:
					#var atlas_coords = wall_layer.get_cell_atlas_coords(Vector2i(tile.x - 1, tile.y))
					#
					#if shadow_lookup.has(atlas_coords):
						#shadow_layer.set_cell(Vector2i(tile.x - 1, tile.y),1, atlas_coords)
			
			tiles_to_process = tiles_to_process_copy.duplicate()
			tiles_to_process_copy.clear()
		tiles_to_process.clear()




func process_tile(tile: Vector2i):
	if not wall_layer.get_cell_tile_data(Vector2i(tile.x, tile.y)) and not tiles_to_process_copy.has(Vector2i(tile.x, tile.y)):
		tiles_to_process_copy.append(Vector2i(tile.x, tile.y))
	else:
		var atlas_coords = wall_layer.get_cell_atlas_coords(Vector2i(tile.x, tile.y ))
		if shadow_lookup.has(atlas_coords):
			shadow_layer.set_cell(Vector2i(tile.x, tile.y),1, atlas_coords)
