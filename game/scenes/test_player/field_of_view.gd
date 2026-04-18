extends Node

@export var player: CharacterBody2D

var shadow_layer: TileMapLayer
var wall_layer: TileMapLayer


var timer: float = 0
var fov_width_radius = 16 # momenteel is dit de width
var fov_height_radius = 12

var tiles_to_process: Dictionary
var tiles_to_process_copy: Dictionary

# lijst van alle zichtbare tiles
var visible_tiles: Dictionary
var visible_tiles_old:  Dictionary

var shadow_lookup: Dictionary[Vector2i, Array] = {
	Vector2i(1,2): [Vector2i(1,2)],
	Vector2i(2,2): [Vector2i(2,2)],
	Vector2i(6,1): [Vector2i(6,1)],
	Vector2i(2,1): [Vector2i(2,1)],
	Vector2i(1,0): [Vector2i(1,0)],
	Vector2i(2,0): [Vector2i(2,0)],
	Vector2i(0,1): [Vector2i(0,1)],
	Vector2i(0,0): [Vector2i(0,0)],
	Vector2i(0,2): [Vector2i(0,2)],
	Vector2i(8,1): [Vector2i(8,1)],
	
	Vector2i(0,4): [Vector2i(0,4)],
	Vector2i(1,4): [Vector2i(0,4)],
	Vector2i(2,4): [Vector2i(0,4)],
	
	Vector2i(6,2): [Vector2i(0,2)],
	Vector2i(8,2): [Vector2i(0,2)],
	
	Vector2i(10,2): [Vector2i(10,2)],
	Vector2i(12,2): [Vector2i(12,2)],
	
	Vector2i(4,0): [Vector2i(4,0)],
	Vector2i(4,1): [Vector2i(4,1)],
	Vector2i(4,2): [Vector2i(4,2)],
	
	Vector2i(10,1): [Vector2i(10,1)],
}



func _ready() -> void:
	shadow_layer = ChunkManager.shadow_layer
	wall_layer = ChunkManager.wall_layer
	calculate_in_shape(Vector2i(16,0))


func _process(delta: float) -> void:
	timer += delta
	if timer > 0.9:
		timer = 0
		calculate_fov()
	


func calculate_fov():
	visible_tiles.clear()
	var player_pos: Vector2i = player.global_position
	var global_tile_pos = shadow_layer.local_to_map(player_pos)
	
	if ChunkManager.generated_chunks.has(floor(player_pos / 256)):
		var current_chunk: Chunk = ChunkManager.generated_chunks[floor(player_pos / 256)]
	
		
		tiles_to_process[global_tile_pos] = 1
		visible_tiles[global_tile_pos] = 1
		#tiles_to_process.append(Vector2i(global_tile_pos.x + 1, global_tile_pos.y))
		#tiles_to_process.append(Vector2i(global_tile_pos.x - 1, global_tile_pos.y))
		
		for distance in fov_width_radius:
			for tile in tiles_to_process.keys():
				
				if calculate_in_shape(tile):
					shadow_layer.erase_cell(tile)
					
					process_tile(Vector2i(tile.x, tile.y -1))
					process_tile(Vector2i(tile.x +1, tile.y))
					process_tile(Vector2i(tile.x, tile.y +1))
					process_tile(Vector2i(tile.x -1 , tile.y))
					
					process_tile(Vector2i(tile.x +1, tile.y -1))
					process_tile(Vector2i(tile.x +1, tile.y +1))
					process_tile(Vector2i(tile.x -1, tile.y +1))
					process_tile(Vector2i(tile.x -1, tile.y -1))
			
			tiles_to_process = tiles_to_process_copy.duplicate()
			if distance == fov_height_radius - 1:
				calculate_edge(tiles_to_process_copy)
			tiles_to_process_copy.clear()
				
		tiles_to_process.clear()
		
	check_old_shadows()
	visible_tiles_old = visible_tiles.duplicate()



func process_tile(tile: Vector2i): 
	# als "tile" geen muur is:
	if not tiles_to_process_copy.has(tile) and not wall_layer.get_cell_tile_data(tile) and not visible_tiles.has(tile):
		tiles_to_process_copy[tile] = 1
		if not visible_tiles.has(tile):
			visible_tiles[tile] = 1
		
	# als "tile" == wall 
	else:
		shadow_layer.erase_cell(tile )
		visible_tiles[tile] = 1


## deze functie zorgt dat shadows geupdate worden
func check_old_shadows(): 
	for tile_pos in visible_tiles_old.keys():
		if not visible_tiles.has(tile_pos):
			shadow_layer.set_cell(tile_pos, 1, Vector2i(1,1))
		





# shape van een ovaal
func calculate_in_shape(position: Vector2i):
	var dx = position.x - floor(get_tree().get_first_node_in_group("player").global_position.x / 16)
	var dy = position.y - floor(get_tree().get_first_node_in_group("player").global_position.y / 16)
	
	if pow(dx, 2) / pow(fov_width_radius,2) + pow(dy, 2) / pow(fov_height_radius,2) < 1:
		return true
		
	else:
		return false


func calculate_edge(_tiles_to_process: Dictionary):
	#print(_tiles_to_process)
	#print("------------")
	pass
