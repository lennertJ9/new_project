extends Node2D


var chunk_list: Dictionary[Vector2i, Chunk]
@export var player_pos_or_camera: Camera2D

var ground: TileMapLayer
var walls: TileMapLayer 

func _ready() -> void:
	ground = get_node("/root/World/Ground")
	walls = get_node("/root/World/Walls")
	
	player_pos_or_camera = get_node("/root/World/Camera2D")
	generate_chunks(Vector2i(2,5))
	
	print(chunk_list[Vector2i(0,0)].data[Vector2i(0,0)])
	for chunk in chunk_list:
		
		load_chunk(chunk)
	

func generate_random_chunk(chunk_global_x, chunk_global_y):
	var dict: Dictionary[Vector2i, Dictionary]
	
	for x in 16:
		for y in 16:
			dict[Vector2i(x,y)] = {"ground": Vector2i(2,15), "walls": Vector2i(0,7)}
		
	var chunk = Chunk.new(dict)
	chunk_list[Vector2i(chunk_global_x, chunk_global_y)] = chunk
	


func load_chunk(chunk_coords: Vector2i):
	
	for x in range(16):
		for y in range(16):
			
			print(chunk_list[Vector2i(0,0)].data[Vector2i(0,0)])
			ground.set_cell(chunk_coords * 16 + Vector2i(x,y), 0, chunk_list[chunk_coords].data[Vector2i(x,y)]["ground"])
			walls.set_cell(chunk_coords * 16 + Vector2i(x,y), 0, chunk_list[chunk_coords].data[Vector2i(x,y)]["walls"])
		



func generate_chunks(end: Vector2i):
	for y in range(end.y+1):
		for x in range(end.x +1):
			var chunk_coords = Vector2i(x,y)
			var tiles: Dictionary[Vector2i, Dictionary]
			
			for tile_x in range(16):
				for tile_y in range(16):
					tiles[Vector2i(tile_x, tile_y)] = {"ground": Vector2i(2, 15), "walls": Vector2i(0,7)}
			var chunk = Chunk.new(tiles)
			chunk_list[chunk_coords] = chunk
