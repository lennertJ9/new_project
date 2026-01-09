extends Node2D


var next_available_id: int # een waarde van een nog niet gebruikte a_star_id
var AStar: AStar2D = AStar2D.new()

var offset: Vector2i = Vector2i(8,8)

func _ready() -> void:
	ChunkManager.autotiling.chunk_autotiled.connect(on_chunk_autotiled) # pas bij autotiled want da weet ik dat de chunk buren aanwezig zijn
	ChunkManager.chunk_generated.connect(on_chunk_generated)


func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id



func on_chunk_generated(chunk: Chunk):
	generate_a_star_points(chunk.position, chunk.a_star_id)



func on_chunk_autotiled(chunk: Chunk):
	connect_AStar_center(chunk)
	connect_AStar_edge(chunk)
	get_astar_path()



func generate_a_star_points(chunk_pos: Vector2i, chunk_Astar_id: int):
	var start_position = chunk_pos * 256 # convert chunk position naar global position
	var id = chunk_Astar_id
	
	#toevoegen van alle points in chunk
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			AStar.add_point(id, start_position + Vector2i(x,y) + offset)
			id += 1


# connecting logic moet aangepast worden omdat om de 2x2 connecties maken eigenlijk niet alles tiles verbind
func connect_AStar_center(chunk: Chunk):
	print("star id? ",chunk.a_star_id)
	var index: int = chunk.a_star_id + 17 # 17 is het begin van 'de center'
	
	for y in range(1, 14, 2):
		for x in range(1, 14, 2): # id = 17
			AStar.connect_points(index, index - 16) # top
			AStar.connect_points(index, index - 15)
			AStar.connect_points(index, index + 1) # right
			AStar.connect_points(index, index + 17)
			AStar.connect_points(index, index + 16) # bottom
			AStar.connect_points(index, index + 15)
			AStar.connect_points(index, index - 1) # left
			AStar.connect_points(index, index - 17)
			index += 2
			# id = + 14 = 31
		index += 18


func connect_AStar_edge(chunk: Chunk):
	var right_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,0)].a_star_id + 16
	var bottom_right_neighbour_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1, -1)].a_star_id
	var bottom_id = ChunkManager.generated_chunks[chunk.position + Vector2i(0, -1)].a_star_id + 1
	var id: int
	
	#connect right to left edge
	id = chunk.a_star_id + 31
	for i in range(1,7):
		AStar.connect_points(id, id - 16)
		AStar.connect_points(id, right_id - 16)
		AStar.connect_points(id, right_id)
		AStar.connect_points(id, right_id + 16)
		AStar.connect_points(id, id + 16)
		
		AStar.connect_points(id, id + 15)
		AStar.connect_points(id, id - 1)
		AStar.connect_points(id, id - 17)
		id += 32
		right_id += 32
	
	#connect bottom to upper edge
	id = chunk.a_star_id + 241
	for i in range(1,7):
		AStar.connect_points(id, id - 16)
		AStar.connect_points(id, id - 15)
		AStar.connect_points(id, id + 1)
		AStar.connect_points(id, bottom_id + 1)
		AStar.connect_points(id, bottom_id)
		AStar.connect_points(id, bottom_id - 1)
		AStar.connect_points(id, id - 1)
		AStar.connect_points(id, id - 17)
		
		id += 2
		bottom_id += 2



func get_astar_path():
	
	var start_pos: Vector2i = Vector2i(8,8)
	var end_pos: Vector2i = Vector2i(24,8)
	
	var start_id = AStar.get_closest_point(start_pos)
	var end_id = AStar.get_closest_point(end_pos)
	
	var path = AStar.get_point_path(AStar.get_closest_point(start_pos), AStar.get_closest_point(end_pos))
	print("path: ",path)
	print("start_id: ", start_id)
	print("end_id: ", end_id)
	print("--------------------")
