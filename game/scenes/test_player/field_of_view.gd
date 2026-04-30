extends Node2D

@export var player: CharacterBody2D

var shadow_layer: TileMapLayer
var wall_layer: TileMapLayer
var debug_layer: TileMapLayer


var timer: float = 0
var radius_x = 16
var radius_y = 16


# lijst van alle zichtbare tiles
var visible_tiles: Dictionary
var visible_tiles_old:  Dictionary
var edge_tiles: Dictionary

var matching_tiles: Dictionary[Vector2i, Array] = {
	Vector2i(4,2): [Vector2i(2,2)]
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
	


func _process(delta: float) -> void:
	timer += delta
	if timer > 0.25:
		timer = 0
		calculate_fov()
	

# bug met player coords, deze moeten nog omgezet worden van global naar local tile coords (denk ik)
func calculate_fov():
	edge_tiles.clear()
	visible_tiles.clear()
	check_old_shadows()
	
	var edge_points: Array
	var player_tile_pos = shadow_layer.local_to_map(player.global_position)
	var player_x = player_tile_pos.x
	var player_y = player_tile_pos.y
	
	for x in range(-radius_x, radius_x + 1):
		edge_points.append(Vector2i(player_x + x, player_y - radius_y))
		edge_points.append(Vector2i(player_x + x, player_y + radius_y))
	
	for y in range(-radius_y, radius_y + 1):
		edge_points.append(Vector2i(player_x - radius_x, player_y + y))
		edge_points.append(Vector2i(player_x + radius_x, player_y + y))

	for point in edge_points:
		bresenham_line(player_tile_pos, point)
	
	visible_tiles_old = visible_tiles.duplicate()
	calculate_edge_tiles()


func bresenham_line(start: Vector2i, end: Vector2i):
	var x0 = start.x
	var y0 = start.y
	var x1 = end.x
	var y1 = end.y
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	
	var err = dx - dy
	
	while true:
		if not is_in_ellipse(Vector2i(x0, y0), start):
			break
		
		if wall_layer.get_cell_source_id(Vector2i(x0, y0)) != -1:
			if not visible_tiles.has(Vector2i(x0, y0)):
				visible_tiles[Vector2i(x0, y0)] = 1
				shadow_layer.erase_cell(Vector2i(x0, y0))
			break
		
		if not visible_tiles.has(Vector2i(x0, y0)):
			visible_tiles[Vector2i(x0, y0)] = 1
			shadow_layer.erase_cell(Vector2i(x0, y0))
		
		
		if not visible_tiles.has(Vector2i(x0, y0 -1)):
			visible_tiles[Vector2i(x0, y0 -1)] = 1
			shadow_layer.erase_cell(Vector2i(x0, y0 -1))
		
		
		if not visible_tiles.has(Vector2i(x0 +1, y0)):
			visible_tiles[Vector2i(x0 +1, y0)] = 1
			shadow_layer.erase_cell(Vector2i(x0 +1, y0))
		
			
		
		if not visible_tiles.has(Vector2i(x0, y0 +1)):
			visible_tiles[Vector2i(x0, y0 +1)] = 1
			shadow_layer.erase_cell(Vector2i(x0, y0 +1))
		
		
		if not visible_tiles.has(Vector2i(x0 -1, y0)):
			visible_tiles[Vector2i(x0 -1, y0)] = 1
			shadow_layer.erase_cell(Vector2i(x0 -1, y0))
		#
		#
		###
		#if not visible_tiles.has(Vector2i(x0 +1, y0 -1)):
			#visible_tiles[Vector2i(x0 +1, y0 -1)] = 1
			#shadow_layer.erase_cell(Vector2i(x0 +1, y0 -1))
		#
		#if not visible_tiles.has(Vector2i(x0 +1, y0 +1)):
			#visible_tiles[Vector2i(x0 +1, y0 +1)] = 1
			#shadow_layer.erase_cell(Vector2i(x0 +1, y0 +1))
		#
		#if not visible_tiles.has(Vector2i(x0 -1, y0 -1)):
			#visible_tiles[Vector2i(x0 -1, y0 -1)] = 1
			#shadow_layer.erase_cell(Vector2i(x0 -1, y0 -1))
		#
		#if not visible_tiles.has(Vector2i(x0 -1, y0 +1)):
			#visible_tiles[Vector2i(x0 -1, y0 +1)] = 1
			#shadow_layer.erase_cell(Vector2i(x0 -1, y0 +1))
		

		if x0 == x1 and y0 == y1:
			break
		
		var e2 = err * 2
		
		if e2 > -dy:
			err -= dy
			x0 += sx
		
		if e2 < dx:
			err += dx
			y0 += sy
	


## deze functie zorgt dat shadows geupdate worden
func check_old_shadows(): 
	for tile_pos in visible_tiles_old.keys():
		if not visible_tiles.has(tile_pos):
			shadow_layer.set_cell(tile_pos, 1, Vector2i(1,1))



func is_in_ellipse(pos: Vector2i, center: Vector2i) -> bool:
	var dx = pos.x - center.x
	var dy = pos.y - center.y
	
	return (dx * dx) * (radius_y * radius_y) + (dy * dy) * (radius_x * radius_x) < (radius_x * radius_x) * (radius_y * radius_y)


func calculate_edge_tiles():
	for tile in visible_tiles.keys():
		
		if not visible_tiles.has(Vector2i(tile.x, tile.y - 1)) and not edge_tiles.has(Vector2i(tile.x, tile.y - 1)):
			edge_tiles[tile] = 1
		if not visible_tiles.has(Vector2i(tile.x + 1, tile.y)) and not edge_tiles.has(Vector2i(tile.x + 1, tile.y)):
			edge_tiles[tile] = 1
		if not visible_tiles.has(Vector2i(tile.x, tile.y + 1)) and not edge_tiles.has(Vector2i(tile.x, tile.y + 1)):
			edge_tiles[tile] = 1
		if not visible_tiles.has(Vector2i(tile.x - 1, tile.y)) and not edge_tiles.has(Vector2i(tile.x - 1, tile.y)):
			edge_tiles[tile] = 1
	
	if get_node("/root/World").debug_mode:
		for tile in edge_tiles:
			shadow_layer.set_cell(tile, 2, Vector2i(0,2))


#momenteel ongebruikt
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
		print(pos)
		if visible_tiles.has(pos):
			print("is visble")
		print("---------------")
