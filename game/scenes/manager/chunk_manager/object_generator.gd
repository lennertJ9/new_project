extends Node

@export var noise_tex: NoiseTexture2D
var noise: Noise

var number_generator: RandomNumberGenerator


func _ready() -> void:
	noise = noise_tex.noise
	number_generator = RandomNumberGenerator.new()
	number_generator.seed = owner.noise_tex.noise.seed


#func generate_trees2(chunk: Chunk):
	#var id: int
	#var i: int = 0
	#for y in range(16):
		#for x in range(16):
			#
			#var position = chunk.position * 16 + Vector2i(x,y)
			#var noise_value = noise.get_noise_2dv(position)
			#if noise_value > 0.5 and chunk.wall_layer[i] >> 16 == 0:
				##chunk.wall_layer[i] = tile_id << 16 | 3 << 8 | 0
				#id = 1 << 16 | 0 << 8 | 0
				#chunk.object_layer[i] = id
				#chunk.walkable[i] = 0
			#i += 1


func generate_trees(chunk: Chunk):
	
	var cells = [0,0,0,0]
	for cell_y in range(1, 16 , 3):
		for cell_x in range(1, 16 , 3):
			var position = Vector2i(cell_x, cell_y) + chunk.global_position
			
			cells[0] = cell_y * 16 + cell_x
			cells[1] = cell_y * 16 + (cell_x + 1)
			cells[2] = (cell_y + 1) * 16 + cell_x
			cells[3] = (cell_y + 1) * 16 + (cell_x + 1)
			var random = number_generator.randi_range(0,3) 
			var noise_value = noise.get_noise_2dv(position)
			if noise_value > 0.3 and chunk.wall_layer[cells[random]] >> 16 == 0 and chunk.ground_layer[cells[random]] >> 16 != 0:
				var random_int = randi_range(0,2) * 3
				var id = 1 << 16 | random_int << 8 | 0
				chunk.object_layer[cells[random]] = id
