extends Node2D

#tijdens generation een chunk property maken: packedintarray[0|1] 1 = walkable, 0 = not walkable
# astar generation voorzien in chunk rendering pipeline 
# (ergens na chunk data generation, best na autotiling want die chunks hebben alle 8 buren?) 
#-> die functie die checkt voor autotiling, 
#dus als de buren er zijn, deze algemeen noemen, en dan if true aan een lijst toevoegen chunks_to_astar

# aanpassingen nodig -> astars points alleen toevoegen op walkable tiles
# diagonaal niet verbinden als een wall of object dit zou blokkeren (deels)
#

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
	connect_AStar_edges(chunk)
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
	var id: int
	
	for y in range(1, 15):
		for x in range(1, 15): 
			id = y * 16 + x + chunk.a_star_id
			AStar.connect_points(id, id - 16, false) # top
			AStar.connect_points(id, id - 15, false)
			AStar.connect_points(id, id + 1, false) # right
			AStar.connect_points(id, id + 17, false)
			AStar.connect_points(id, id + 16, false) # bottom
			AStar.connect_points(id, id + 15, false)
			AStar.connect_points(id, id - 1, false) # left
			AStar.connect_points(id, id - 17, false)



func connect_AStar_edges(chunk: Chunk):
	var top_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(0,1)].a_star_id 
	var top_right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,1)].a_star_id 
	var right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,0)].a_star_id 
	var bottom_right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1, -1)].a_star_id
	var bottom_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(0, -1)].a_star_id 
	var bottom_left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,-1)].a_star_id 
	var left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,0)].a_star_id 
	var top_left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,1)].a_star_id 
	var id: int
	var secondary_id: int
	
	# top
	for x in range(1,15):
		id = x + chunk.a_star_id
		secondary_id = 240 + x + top_AStar_id 
		AStar.connect_points(id, secondary_id, false)
		AStar.connect_points(id, secondary_id + 1, false)
		AStar.connect_points(id, id + 1, false)
		AStar.connect_points(id, id + 17, false)
		AStar.connect_points(id, id + 16, false)
		AStar.connect_points(id, id + 15, false)
		AStar.connect_points(id, id - 1, false)
		AStar.connect_points(id, secondary_id - 1, false)
	
	# bottom
	for x in range(1,15):
		id = 240 + x + chunk.a_star_id
		secondary_id = x + bottom_AStar_id
		AStar.connect_points(id, id - 16, false)
		AStar.connect_points(id, id - 15, false)
		AStar.connect_points(id, id + 1, false)
		AStar.connect_points(id, secondary_id + 1, false)
		AStar.connect_points(id, secondary_id, false)
		AStar.connect_points(id, secondary_id - 1, false)
		AStar.connect_points(id, id - 1, false)
		AStar.connect_points(id, id - 17, false)

	# left
	for y in range(1,15):
		id =  y * 16 + chunk.a_star_id
		secondary_id = 15 + y * 16 + left_AStar_id
		AStar.connect_points(id, id - 16, false)
		AStar.connect_points(id, id - 15, false)
		AStar.connect_points(id, id + 1, false)
		AStar.connect_points(id, id + 17, false)
		AStar.connect_points(id, id + 16, false)
		AStar.connect_points(id, secondary_id - 16, false)
		AStar.connect_points(id, secondary_id, false)
		AStar.connect_points(id, secondary_id + 16, false)


	# right
	for y in range(1,15):
		id = 15 + y * 16 + chunk.a_star_id
		secondary_id = y * 16 + left_AStar_id
		AStar.connect_points(id, id - 16, false)
		AStar.connect_points(id, secondary_id + 16, false)
		AStar.connect_points(id, secondary_id, false)
		AStar.connect_points(id, secondary_id - 16, false)
		AStar.connect_points(id, id + 16, false)
		AStar.connect_points(id, id + 15, false)
		AStar.connect_points(id, id - 1, false)
		AStar.connect_points(id, id - 17, false)




func get_astar_path():
	var start_pos: Vector2i = Vector2i(248,24)
	var end_pos: Vector2i = Vector2i(248,40)
	
	var start_id = AStar.get_closest_point(start_pos)
	var end_id = AStar.get_closest_point(end_pos)
	
	var path = AStar.get_point_path(AStar.get_closest_point(start_pos), AStar.get_closest_point(end_pos))
	print("path: ",path)
	print("start_id: ", start_id)
	print("end_id: ", end_id)
	print("--------------------")
