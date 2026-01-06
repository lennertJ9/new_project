extends Node2D


var next_available_id: int # een waarde van een nog niet gebruikte a_star_id
var AStar: AStar2D = AStar2D.new()


func _ready() -> void:
	ChunkManager.chunk_generated.connect(on_chunk_generated)


func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id


func on_chunk_generated(chunk: Chunk):
	generate_a_star_points(chunk.position, chunk.a_star_id)



func generate_a_star_points(position: Vector2i, chunk_id: int):
	var start_position = position * 256
	var id = chunk_id
	
	for y in range(0, 256, 16):
		for x in range(0, 256, 16):
			AStar.add_point(id, Vector2i(x,y))
			id += 1
