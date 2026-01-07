extends Node2D


var next_available_id: int # een waarde van een nog niet gebruikte a_star_id
var AStar: AStar2D = AStar2D.new()


func _ready() -> void:
	ChunkManager.autotiling.chunk_autotiled.connect(on_chunk_autotiled) # pas bij autotiled want da weet ik dat de chunk buren aanwezig zijn


func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id


func on_chunk_autotiled(chunk: Chunk):
	generate_a_star_points(chunk.position, chunk.a_star_id)
	

func generate_a_star_points(position: Vector2i, chunk_id: int):
	var start_position = position * 256
	var id = chunk_id
	var id_array: Array
	# hier is een bug, de posities zijn local en niet global
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			AStar.add_point(id, Vector2i(x,y))
			id_array.append(id)
			id += 1
	connect_AStar_center(id_array, chunk_id)


func connect_AStar_center(id_array: Array, chunk_id):
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
	
	var test_path = AStar.get_point_path(id_array[17], id_array[18])
	print(test_path)
