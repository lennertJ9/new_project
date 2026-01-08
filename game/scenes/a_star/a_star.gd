extends Node2D


var next_available_id: int # een waarde van een nog niet gebruikte a_star_id
var AStar: AStar2D = AStar2D.new()

var offset: Vector2i = Vector2i(8,8)

func _ready() -> void:
	ChunkManager.autotiling.chunk_autotiled.connect(on_chunk_autotiled) # pas bij autotiled want da weet ik dat de chunk buren aanwezig zijn


func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id


func on_chunk_autotiled(chunk: Chunk):
	generate_a_star_points(chunk.position, chunk.a_star_id)


func generate_a_star_points(chunk_pos: Vector2i, chunk_Astar_id: int):
	var start_position = chunk_pos * 256 # convert chunk position naar global position
	var id = chunk_Astar_id
	var id_array: Array # array van alle point ID's
	
	#toevoegen van alle points in chunk
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			AStar.add_point(id, start_position + Vector2i(x,y) + offset)
			id_array.append(id)
			id += 1
	connect_AStar_center(id_array)
	connect_AStar_edge(id_array, chunk_pos)



func connect_AStar_center(id_array: Array):
	var index: int = id_array[17] # 17 is het begin van 'de center'
	for y in range(1, 14, 2):
		for x in range(1, 14, 2):
			AStar.connect_points(index, index - 16)
			AStar.connect_points(index, index - 15)
			AStar.connect_points(index, index + 1)
			AStar.connect_points(index, index + 17)
			
			AStar.connect_points(index, index + 16)
			AStar.connect_points(index, index + 15)
			AStar.connect_points(index, index - 1)
			AStar.connect_points(index, index - 17)
	
	#var test_path = AStar.get_point_path(id_array[17], id_array[18])
	#print(test_path)
	
	
func connect_AStar_edge(id_array: Array, chunk_pos: Vector2i):
	var right_neighbour_id = ChunkManager.generated_chunks[chunk_pos + Vector2i(1,0)].a_star_id
	var bottom_right_neighbour_id = ChunkManager.generated_chunks[chunk_pos + Vector2i(1, -1)].a_star_id
	var bottom_neighbour_id = ChunkManager.generated_chunks[chunk_pos + Vector2i(0, -1)].a_star_id
	
	# connect right edge
	var id: int = id_array[31]
	var right_id = right_neighbour_id
	for i in range(1,7):
		AStar.connect_points(id, right_neighbour_id)
		AStar.connect_points(id, right_neighbour_id)
		AStar.connect_points(id, right_neighbour_id)
		AStar.connect_points(id, right_neighbour_id)
		id += 32
		right_neighbour_id += 32
	
	#connect left edge
	id = id_array[241]
	for i in range(1,7):
		AStar.connect_points(id, right_neighbour_id)
		id += 32
		right_neighbour_id += 32
