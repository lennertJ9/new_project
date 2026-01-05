extends Node2D


var next_available_id: int # een waarde van een nog niet gebruikte a_star_id


func _ready() -> void:
	ChunkManager.chunk_generated.connect(on_chunk_generated)


func get_a_star_id() -> int:
	var id = next_available_id
	next_available_id += 256
	return id


func on_chunk_generated(chunk: Chunk):
	generate_a_star_points(chunk.position)



func generate_a_star_points(position: Vector2i):
	pass
