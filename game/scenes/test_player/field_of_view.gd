extends Node2D

@export var player: CharacterBody2D

var shadow_layer: TileMapLayer
var wall_layer: TileMapLayer
var debug_layer: TileMapLayer



var timer: float = 0
var fov_width_radius = 18 # momenteel is dit de width
var fov_height_radius = 14

var tiles_to_process: Dictionary
var tiles_to_process_copy: Dictionary

# lijst van alle zichtbare tiles
var visible_tiles: Dictionary
var visible_tiles_old:  Dictionary
var edge_fov_walls: Dictionary

## deze lookup is voor het type shadow, maar ik denk dat het momenteel ongebruikt is, 
## omdat visible muren nu geen aangepaste shadows hebben wanneer ze zichtbaar zijn
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

var shadow_edge_lookup: Dictionary[int, Vector2i] = {
	
	224: Vector2i(1,1),
	248: Vector2i(1,2),
	56: Vector2i(2,2),
	227: Vector2i(1,0),
	131: Vector2i(2,0),
	143: Vector2i(3,0),
	14: Vector2i(3,1),
	62: Vector2i(3,2),
	
	232: Vector2i(3,2),
	240: Vector2i(1,2),
	32: Vector2i(6,0),
	96: Vector2i(1,1),
	112: Vector2i(1,2),
	120: Vector2i(1,2),
	
	225: Vector2i(1,0),
	128: Vector2i(6,2),
	192: Vector2i(1,1),
	193: Vector2i(1,0),
	195: Vector2i(1,0),
	
	135: Vector2i(3,0),
	2: Vector2i(4,2),
	7: Vector2i(3,0),
	15: Vector2i(3,0),
	6: Vector2i(3,1),
	
	30: Vector2i(3,2),
	8: Vector2i(4,0),
	12: Vector2i(3,1),
	40: Vector2i(3,2),
	28: Vector2i(3,2),
	60: Vector2i(3,2),
	
	3: Vector2i(2,0),
	129: Vector2i(2,0),
	
	24: Vector2i(2,2),
	48: Vector2i(2,2),
	
	
	
}


func _ready() -> void:
	shadow_layer = get_node("/root/World/ChunkManager").shadow_layer
	wall_layer = get_node("/root/World/ChunkManager").wall_layer
	debug_layer = get_node("/root/World/ChunkManager").debug_layer
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
	
	if get_node("/root/World/ChunkManager").generated_chunks.has(floor(player_pos / 256)):
		var current_chunk: Chunk = get_node("/root/World/ChunkManager").generated_chunks[floor(player_pos / 256)]
	
		
		tiles_to_process[global_tile_pos] = 1
		visible_tiles[global_tile_pos] = 1
		#tiles_to_process.append(Vector2i(global_tile_pos.x + 1, global_tile_pos.y))
		#tiles_to_process.append(Vector2i(global_tile_pos.x - 1, global_tile_pos.y))
		
		for distance in fov_width_radius:
			for tile in tiles_to_process.keys():
				
				if calculate_in_shape(tile):
					shadow_layer.erase_cell(tile)
					
					process_tile(Vector2i(tile.x, tile.y -1), distance)
					process_tile(Vector2i(tile.x +1, tile.y), distance)
					process_tile(Vector2i(tile.x, tile.y +1), distance)
					process_tile(Vector2i(tile.x -1 , tile.y), distance)
					
					process_tile(Vector2i(tile.x +1, tile.y -1), distance)
					process_tile(Vector2i(tile.x +1, tile.y +1), distance)
					process_tile(Vector2i(tile.x -1, tile.y +1), distance)
					process_tile(Vector2i(tile.x -1, tile.y -1), distance)
				else:
					
					tiles_to_process_copy[tile] = 1
					visible_tiles[tile] = 1
			
			
			tiles_to_process = tiles_to_process_copy.duplicate()
			if distance == fov_width_radius - 1:
				calculate_edge(tiles_to_process_copy)
			tiles_to_process_copy.clear()
				
		tiles_to_process.clear()
		
	check_old_shadows()
	visible_tiles_old = visible_tiles.duplicate()
	debug_stuff()



func process_tile(tile: Vector2i, distance): 
	# als "tile" geen muur is:
	if not tiles_to_process_copy.has(tile) and not wall_layer.get_cell_tile_data(tile) and not visible_tiles.has(tile):
		tiles_to_process_copy[tile] = 1
		
		if not visible_tiles.has(tile):
			visible_tiles[tile] = 1
		
	# als "tile" == wall 
	else:
		if not visible_tiles.has(tile) and wall_layer.get_cell_tile_data(tile):
			visible_tiles[tile] = 1
			shadow_layer.erase_cell(tile)



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
	var bitmask: int 
	var edge_walls: Dictionary
	for tile in _tiles_to_process.keys():
		bitmask = 0
		if not visible_tiles.has(Vector2i(tile.x, tile.y -1)):
			bitmask += 1
		if wall_layer.get_cell_tile_data(Vector2i(tile.x, tile.y -1)):
			edge_walls[Vector2i(tile.x, tile.y -1)] = 1
			
			
			
		if not visible_tiles.has(Vector2i(tile.x +1, tile.y )):
			bitmask += 4
		if wall_layer.get_cell_tile_data(Vector2i(tile.x +1, tile.y )):
			edge_walls[Vector2i(tile.x +1, tile.y )] = 1
			
			
			
		if not visible_tiles.has(Vector2i(tile.x , tile.y +1)):
			bitmask += 16
		if wall_layer.get_cell_tile_data(Vector2i(tile.x , tile.y +1)):
			edge_walls[Vector2i(tile.x , tile.y +1)] = 1
			
			
			
		if not visible_tiles.has(Vector2i(tile.x -1, tile.y)):
			bitmask += 64
		if wall_layer.get_cell_tile_data(Vector2i(tile.x -1, tile.y)):
			edge_walls[Vector2i(tile.x -1, tile.y)] = 1
			
		
		
		if not visible_tiles.has(Vector2i(tile.x +1, tile.y -1)):
			bitmask += 2
		if not visible_tiles.has(Vector2i(tile.x +1, tile.y +1)):
			bitmask += 8
		if not visible_tiles.has(Vector2i(tile.x -1, tile.y +1)):
			bitmask += 32
		if not visible_tiles.has(Vector2i(tile.x -1, tile.y -1)):
			bitmask += 128
		
		if shadow_edge_lookup.has(bitmask):
			var atlas_coords = shadow_edge_lookup[bitmask]
			
			shadow_layer.set_cell(Vector2i(tile.x, tile.y), 2, atlas_coords)
		else:
			shadow_layer.set_cell(Vector2i(tile.x, tile.y), 2, Vector2i(0,2))
		
	for wall_tile in edge_walls.keys():
		var wall_bitmask = calculate_bitmask(wall_tile)
		if shadow_edge_lookup.has(wall_bitmask):
			var atlas_coord = shadow_edge_lookup[wall_bitmask]
			shadow_layer.set_cell(wall_tile, 2, atlas_coord)
		else:
			shadow_layer.set_cell(wall_tile, 2, Vector2i(0,2))



func calculate_bitmask(_tile: Vector2i) -> int:
	var bitmask: int 

	if not visible_tiles.has(Vector2i(_tile.x, _tile.y -1)):
		bitmask += 1
	if not visible_tiles.has(Vector2i(_tile.x +1, _tile.y )):
		bitmask += 4
	if not visible_tiles.has(Vector2i(_tile.x , _tile.y +1)):
		bitmask += 16
	if not visible_tiles.has(Vector2i(_tile.x -1, _tile.y)):
		bitmask += 64
	
	if not visible_tiles.has(Vector2i(_tile.x +1, _tile.y -1)):
		bitmask += 2
	if not visible_tiles.has(Vector2i(_tile.x +1, _tile.y +1)):
		bitmask += 8
	if not visible_tiles.has(Vector2i(_tile.x -1, _tile.y +1)):
		bitmask += 32
	if not visible_tiles.has(Vector2i(_tile.x -1, _tile.y -1)):
		bitmask += 128
	

	return bitmask


func debug_stuff():
	debug_layer.clear()
	if get_node("/root/World").debug_mode:
		for tile in visible_tiles.keys():
			debug_layer.set_cell(tile,0, Vector2.ZERO)
		



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		
		var pos = shadow_layer.local_to_map(get_global_mouse_position())
		if calculate_in_shape(pos):
			print("in range")
		else:
			print("not in range")
			
		if visible_tiles.has(pos):
			print("visible ")
		else:
			print("not visible")
		print("tile: ", pos)
		if edge_fov_walls.has(pos):
			print(pos, " in lijst")
		else:
			print(pos, " niet in lijst")
		print("-------------------")
