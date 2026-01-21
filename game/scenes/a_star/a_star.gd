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

var chunks_to_AStar: Array[Chunk]


var thread_point_generator: Thread = Thread.new() # deze thread generate points
var thread_point_connect: Thread = Thread.new() # deze thread legt astar connecties


func _ready() -> void:
	thread_point_generator.start(astar_point_generator)
	ChunkManager.chunk_deloaded.connect(on_chunk_deload)
	ChunkManager.neighbours_checked.connect(on_neighbours_checked)



func on_chunk_deload(chunk):
	remove_a_star_points(chunk)





func on_neighbours_checked(chunk):
	chunks_to_AStar.append(chunk)



func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id



func get_astar_path(start_pos, end_pos):
	#var start_pos: Vector2i = Vector2i(8,8)
	#var end_pos: Vector2i = Vector2i(24,8)
	
	var start_id = AStar.get_closest_point(start_pos)
	var end_id = AStar.get_closest_point(end_pos)
	
	var path = AStar.get_point_path(AStar.get_closest_point(start_pos), AStar.get_closest_point(end_pos))
	return path
	#print("path: ",path)
	#print("start_id: ", start_id)
	#print("end_id: ", end_id)
	#print("--------------------")


func astar_point_generator():
	while true:
		OS.delay_msec(200)
		if not chunks_to_AStar.is_empty():
			for i in range(chunks_to_AStar.size() - 1, -1, -1): # reverse loop voor item deletion
				var chunk = chunks_to_AStar[i]
				generate_a_star_points(chunk)
				connect_AStar_center(chunk)
				connect_AStar_edges(chunk)
				
				chunks_to_AStar.remove_at(i)



func generate_a_star_points(chunk: Chunk):
	var start_position: Vector2i = chunk.position * 256 # convert chunk position naar global position
	var id: int= chunk.a_star_id
	var i: int  = 0
	
	#toevoegen van alle points in chunk
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			if chunk.walkable[i]:
				AStar.add_point(id, start_position + Vector2i(x,y) + offset)
			id += 1
			i += 1


func remove_a_star_points(chunk: Chunk):
	var id = chunk.a_star_id
	for y in range(16):
		for x in range(16):
			if AStar.has_point(id):
				AStar.remove_point(id)
			id += 1
	chunk.is_Astar_ready = false


func connect_AStar_center(chunk: Chunk):
	var id: int
	for y in range(1, 15):
		for x in range(1, 15): 
			id = y * 16 + x + chunk.a_star_id
			if AStar.has_point(id):
				connect_AStar_points(id, id - 16)
				connect_AStar_points(id, id - 15)
				connect_AStar_points(id, id + 1)
				connect_AStar_points(id, id + 17)
				connect_AStar_points(id, id + 16)
				connect_AStar_points(id, id + 15)
				connect_AStar_points(id, id - 1)
				connect_AStar_points(id, id - 17)


func connect_AStar_edges(chunk: Chunk):
	var top_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(0,-1)].a_star_id 
	var top_right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,-1)].a_star_id 
	var right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,0)].a_star_id 
	var bottom_right_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(1,1)].a_star_id
	var bottom_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(0,1)].a_star_id 
	var bottom_left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,1)].a_star_id 
	var left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,0)].a_star_id 
	var top_left_AStar_id = ChunkManager.generated_chunks[chunk.position + Vector2i(-1,-1)].a_star_id 
	var id: int
	var secondary_id: int
	
	# top
	for x in range(1,15):
		id = x + chunk.a_star_id
		if AStar.has_point(id):
			secondary_id = 240 + x + top_AStar_id 
			connect_AStar_points(id, secondary_id)
			connect_AStar_points(id, secondary_id + 1)
			connect_AStar_points(id, id + 1)
			connect_AStar_points(id, id + 17)
			connect_AStar_points(id, id + 16)
			connect_AStar_points(id, id + 15)
			connect_AStar_points(id, id - 1)
			connect_AStar_points(id, secondary_id - 1)
	
	# bottom
	for x in range(1,15):
		id = 240 + x + chunk.a_star_id
		if AStar.has_point(id):
			secondary_id = x + bottom_AStar_id
			
			connect_AStar_points(id, id - 16)
			connect_AStar_points(id, id - 15)
			connect_AStar_points(id, id + 1)
			connect_AStar_points(id, secondary_id + 1)
			connect_AStar_points(id, secondary_id)
			connect_AStar_points(id, secondary_id - 1)
			connect_AStar_points(id, id - 1)
			connect_AStar_points(id, id - 17)
	
	# left
	for y in range(1,15):
		id =  y * 16 + chunk.a_star_id
		if AStar.has_point(id):
			secondary_id = 15 + y * 16 + left_AStar_id
			
			connect_AStar_points(id, id - 16)
			connect_AStar_points(id, id - 15)
			connect_AStar_points(id, id + 1)
			connect_AStar_points(id, id + 17)
			connect_AStar_points(id, id + 16)
			connect_AStar_points(id, secondary_id - 16)
			connect_AStar_points(id, secondary_id)
			connect_AStar_points(id, secondary_id + 16)
	
	# right
	for y in range(1,15):
		id = 15 + y * 16 + chunk.a_star_id
		if AStar.has_point(id):
			secondary_id = y * 16 + right_AStar_id
			connect_AStar_points(id, id - 1)
			connect_AStar_points(id, id - 16)
			connect_AStar_points(id, secondary_id + 16)
			connect_AStar_points(id, secondary_id)
			connect_AStar_points(id, secondary_id - 16)
			connect_AStar_points(id, id + 16)
			connect_AStar_points(id, id + 15)
			connect_AStar_points(id, id - 17)
	

	# connect top right edge | hardcoded omdat dit 1 tile is
	if AStar.has_point(chunk.a_star_id + 15):
		id = chunk.a_star_id + 15
		connect_AStar_points(id, top_AStar_id + 255)
		connect_AStar_points(id, top_right_AStar_id + 240)
		connect_AStar_points(id, right_AStar_id + 0)
		connect_AStar_points(id, right_AStar_id + 16)
		connect_AStar_points(id, id + 16)
		connect_AStar_points(id, id + 15)
		connect_AStar_points(id, id -1)
		connect_AStar_points(id, top_AStar_id + 254)
	
	# connect bottom right edge
	if AStar.has_point(chunk.a_star_id + 255):
		id = chunk.a_star_id + 255
		connect_AStar_points(id, id - 16)
		connect_AStar_points(id, right_AStar_id + 224)
		connect_AStar_points(id, right_AStar_id + 240)
		connect_AStar_points(id, bottom_right_AStar_id + 0)
		connect_AStar_points(id, bottom_AStar_id + 15)
		connect_AStar_points(id, bottom_AStar_id + 14)
		connect_AStar_points(id, id -1)
		connect_AStar_points(id, id - 17)
	
	# connect bottom left edge
	if AStar.has_point(chunk.a_star_id + 240):
		id = chunk.a_star_id + 240
		connect_AStar_points(id, id - 16)
		connect_AStar_points(id, id - 15)
		connect_AStar_points(id, id + 1)
		connect_AStar_points(id, bottom_AStar_id + 1)
		connect_AStar_points(id, bottom_AStar_id + 0)
		connect_AStar_points(id, bottom_left_AStar_id + 15)
		connect_AStar_points(id, left_AStar_id + 255)
		connect_AStar_points(id, left_AStar_id + 239)
	
	# connect top left edge
	if AStar.has_point(chunk.a_star_id + 0):
		id = chunk.a_star_id + 0
		connect_AStar_points(id, top_AStar_id + 240)
		connect_AStar_points(id, top_AStar_id + 241)
		connect_AStar_points(id, id + 1)
		connect_AStar_points(id, id + 17)
		connect_AStar_points(id, id + 16)
		connect_AStar_points(id, left_AStar_id + 31)
		connect_AStar_points(id, left_AStar_id + 15)
		connect_AStar_points(id, top_left_AStar_id + 255)



func connect_AStar_points(id1: int, id2: int):
	if AStar.has_point(id2):
		AStar.connect_points(id1, id2, false)
	
