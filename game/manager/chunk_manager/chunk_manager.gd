extends Node2D


@export var player: Node2D
@export var noise_tex: NoiseTexture2D
var noise: Noise

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer

var render_distance: int = 3

#-------------- Chunks  --------------------#
var generated_chunks: Dictionary[Vector2i, Chunk] # pure data, deze chunks zijn niet perse autotiled
var loaded_chunks: Array[Chunk] # loaded chunks, actief en autotiled
# --> nieuwe aanpak, generated chunks worden hierin gezet, hierdoor loopen, if alle 8 buren: append naar chunks_to_autotile

#-------------- Chunk die processed moeten worden  --------------------#
var chunks_to_generate: Dictionary[Vector2i, Chunk] # chunks die generated moeten worden -> puur data generatie, met tile ID
var chunks_to_autotile: Dictionary[Vector2i, Chunk] # chunks die autotiled moeten worden en waarvan alle 8 buren aanwezig zijn
var unautotiled_chunks_positions: Array[Vector2i] # positions van generated chunks die mogelijks niet alle 8 buren hebben om geautotiled te worden
var chunks_to_load: Array[Chunk] # chunks die loaded moeten worden, deze zijn autotiled
var chunks_to_unload: Array[Chunk] # chunks die unloaded moeten worden

# ------------- Check Timers --------------#
var chunk_check_interval: float = 0.5
var chunk_load_interval: float = 0.002
var chunk_unload_interval: float = 0.002


var chunk_check_timer: float = 0
var chunk_load_timer: float = 0
var chunk_unload_timer: float = 0

var thread_chunk_generator: Thread = Thread.new()
var thread_chunk_autotiler: Thread = Thread.new()
var thread_chunk_autotiler_availabilitychecker: Thread = Thread.new()

										 #top          #top-right      #right         #bottom-right   #bottom         #bottom-left     #left          #top-left
var chunk_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1),  
  
]



var tile_lookup: Dictionary[int, Vector2i] = { #bitmask: atlas_position }
	193: Vector2i(2,2),
	199: Vector2i(1,2),
	7: Vector2i(0,2),
	16: Vector2i(4,0),
	241: Vector2i(2,1),
	255: Vector2i(1,1),
	31: Vector2i(0,1),
	17: Vector2i(4,1),
	28: Vector2i(0,0),
	124: Vector2i(1,0),
	112: Vector2i(2,0),
	1: Vector2i(4,2),
	4: Vector2i(0,4),
	68: Vector2i(1,4),
	128: Vector2i(2,4),
	0: Vector2i(4,4),
	76: Vector2i(1,4),
	92: Vector2i(8,0),
	159: Vector2i(0,1),
	15: Vector2i(0,2),
	223: Vector2(8,1),
	63: Vector2i(0,1),
	127: Vector2i(8,2),
	30: Vector2i(0,0),
	120: Vector2i(2,0),
	253: Vector2i(6,2),
	240: Vector2i(2,0),
	207: Vector2i(1,2),
	231: Vector2i(1,2),
	247: Vector2i(6,1),
	227: Vector2i(2,2),
	195: Vector2i(2,2),
	23: Vector2i(6,3),
	3: Vector2i(4,2),
	135: Vector2i(0,2),
	143: Vector2i(0,2),
	191: Vector2i(0,1),
	62: Vector2i(0,0),
	126: Vector2i(1,0),
	252: Vector2i(1,0),
	248: Vector2i(2,0),
	24: Vector2i(4,0),
	29: Vector2i(6,4),
	209: Vector2i(8,3),
	129: Vector2i(4,2),
	116: Vector2i(6,0),
	108: Vector2i(1,4),
	243: Vector2i(2,1),
	249: Vector2i(2,1),
	113: Vector2i(8,4),
	49: Vector2i(4,1),
	145: Vector2i(4,1),
	25: Vector2i(4,1),
	19: Vector2i(4,1),
	14: Vector2i(0,4),
	95: Vector2i(12,2),
	215: Vector2i(12,1),
	131: Vector2i(4,2),
	225: Vector2i(2,2),
	48: Vector2i(4,0),
	71: Vector2i(2,6),
	6: Vector2i(0,4),
	197: Vector2i(0,6),
	196: Vector2i(1,4),
	70: Vector2i(1,4),
	12: Vector2i(0,4),
	96: Vector2i(2,4),
	251: Vector2i(2,1),
	100: Vector2i(1,4),
	64: Vector2i(2,4),
	192: Vector2i(2,4),
	60: Vector2i(0,0),
	5: Vector2i(0,8),
	65: Vector2i(3,8),
	198: Vector2i(1,4),
	21: Vector2i(6,5),
	81: Vector2i(8,6),
	224: Vector2i(2,4),
	239: Vector2i(1,2),
	119: Vector2i(6,6),
	221: Vector2i(8,6),
	125: Vector2i(10,1), 
	56: Vector2i(4,0),
	254: Vector2i(1,0),
	185: Vector2i(4,1),
	211: Vector2i(8,3),
	244: Vector2i(6,0),
	102: Vector2i(1,4),
	79: Vector2i(2,6),
	245: Vector2i(10,2),
	229: Vector2i(0,6),
	84: Vector2i(12,1),
	203: Vector2i(2,2),
	156: Vector2i(0,0),
	115: Vector2i(8,4),
	54: Vector2i(10,3),
	97: Vector2i(2,8),
}

var tile_lookup_ground: Dictionary[int, Vector2i] = {
	0: Vector2i(2,2),
	1: Vector2i(5,3),
	2: Vector2i(0,5),
	3: Vector2i(0,3),
	4: Vector2i(5,0),
	5: Vector2i(5,2),
	6: Vector2i(0,0),
	7: Vector2i(0,2),
	8: Vector2i(3,5),
	9: Vector2i(3,3),
	10: Vector2i(2,5),
	11: Vector2i(2,3),
	12: Vector2i(3,0),
	13: Vector2i(3,2),
	14: Vector2i(2,0),
	15: Vector2i(2,2),
}



func _ready() -> void:
	thread_chunk_generator.start(chunk_generator)
	thread_chunk_autotiler.start(chunk_autotiler)
	thread_chunk_autotiler_availabilitychecker.start(chunk_autotiler_availabilitychecker)
	
	player = get_tree().get_first_node_in_group("world").camera
	noise = noise_tex.noise
	var test = 131100
	



func _process(delta: float) -> void:
	chunk_check_timer += delta
	chunk_load_timer += delta
	chunk_unload_timer += delta
	
	if chunk_check_timer > chunk_check_interval:
		chunk_check()
		chunk_check_timer = 0
		
	if chunk_load_timer > chunk_load_interval:
		chunk_loader()
		chunk_load_timer = 0
	
	if chunk_unload_timer > chunk_unload_interval:
		chunk_unloader()
		chunk_unload_timer = 0



func chunk_generator():
	while true:
		OS.delay_msec(50)
		if not chunks_to_generate.is_empty():
			
			var chunk: Chunk = chunks_to_generate.values()[0]
			var chunk_pos = chunk.position
			
			var i = 0
			for y in range(16):
				for x in range(16):
					
					var global_pos = chunk.position * 16 + Vector2i(x,y)
					var walls_atlas_id = 0
					var random = noise.get_noise_2dv(global_pos)
					var wall_id: int
					var ground_id: int
					if random > 0.1:
						wall_id = 1 << 16 # dirt wall
					else:
						wall_id = 0
					
					# dark grass
					if random < -0.08:
						ground_id = 2 << 16
					else:
						ground_id = 1 << 16
						
					
					var atlas_coord = Vector2i(2,2)
					var atlas_id = 0
					var ground_data = (atlas_coord.x << 8) | atlas_coord.y
					
					chunk.ground_layer[i] = ground_id
					chunk.wall_layer[i] = wall_id
					i += 1
					
			generated_chunks[chunk.position] = chunk # eerst autotile dan pas in generated chunks
			
			unautotiled_chunks_positions.append(chunk_pos) 
			chunk.is_generated = true
			chunks_to_generate.erase(chunk_pos)


func chunk_autotiler_availabilitychecker():
	while true:
		OS.delay_msec(200)
		
		for i in range(unautotiled_chunks_positions.size() - 1, -1, -1):
			var is_neighboured = true
			var chunk_pos = unautotiled_chunks_positions[i]
			
			for neigbour in chunk_neighbours:
				if not generated_chunks.has(chunk_pos + neigbour):
					is_neighboured = false
					break
			if is_neighboured:
				chunks_to_autotile[chunk_pos] = generated_chunks[chunk_pos]
				unautotiled_chunks_positions.remove_at(i)



func chunk_autotiler():
	while true:
		OS.delay_msec(50)
		if not chunks_to_autotile.is_empty():
			
			var chunk: Chunk = chunks_to_autotile.values()[0]
			var chunk_pos = chunk.position
			var bitmask: int = 0
			var tile_id: int = 0
			
			# ----------------- INNER ------------------------------------#
			autotile_inner(chunk)
			autotile_inner_ground(chunk)
			
			# ----------------- SIDES--------------------------------#
			var top_chunk: Chunk = generated_chunks[chunk_pos - Vector2i(0,1)]
			autotile_top(chunk, top_chunk)
			autotile_top_ground(chunk, top_chunk)

			var right_chunk: Chunk = generated_chunks[chunk_pos + Vector2i(1,0)]
			autotile_right(chunk, right_chunk)
			autotile_right_ground(chunk, right_chunk)
			
			var bottom_chunk: Chunk = generated_chunks[chunk_pos + Vector2i(0,1)]
			autotile_bottom(chunk, bottom_chunk)
			autotile_bottom_ground(chunk, bottom_chunk)
			
			var left_chunk: Chunk = generated_chunks[chunk_pos - Vector2i(1,0)]
			autotile_left(chunk, left_chunk)
			autotile_left_ground(chunk, left_chunk)
			
			# ----------------- EDGES ------------------------------------#
			autotile_top_right(chunk, generated_chunks[chunk_pos + Vector2i(0,-1)], generated_chunks[chunk_pos + Vector2i(1,-1)], generated_chunks[chunk_pos + Vector2i(1,0)])
			autotile_top_right_ground(chunk, top_chunk, right_chunk)
			
			autotile_bottom_right(chunk, generated_chunks[chunk_pos + Vector2i(1,0)], generated_chunks[chunk_pos + Vector2i(1,1)], generated_chunks[chunk_pos + Vector2i(0,1)])
			autotile_bottom_right_ground(chunk, right_chunk, bottom_chunk)
			
			autotile_bottom_left(chunk, generated_chunks[chunk_pos + Vector2i(0,1)], generated_chunks[chunk_pos + Vector2i(-1,1)], generated_chunks[chunk_pos + Vector2i(-1,0)])
			autotile_bottom_left_ground(chunk, bottom_chunk, left_chunk)
			
			autotile_top_left(chunk, generated_chunks[chunk_pos + Vector2i(0,-1)], generated_chunks[chunk_pos + Vector2i(-1,0)], generated_chunks[chunk_pos + Vector2i(-1,-1)])
			autotile_top_left_ground(chunk, top_chunk, left_chunk)


			chunk.autotile_flag = 1000
			chunks_to_autotile.erase(chunk.position)




#region autotiling
# optimalisatie ok
func autotile_inner(chunk: Chunk):
	var bitmask: int = 0 # bitmask van tile variant
	var tile_id: int = 0
	var i: int = 0
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	for y in range(1, 15): # loops over de inner tiles
		for x in range(1, 15):
			i = y * 16 + x
			bitmask = 0
			tile_id = chunk.wall_layer[i] >> 16 #omdat tile id 16 bits links staat
	
			# orthogalen #
			if tile_id != 0:
				if chunk.wall_layer[i - 16] >> 16 == tile_id: # top
					bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
					orthogonal |= 1
				if chunk.wall_layer[i + 1] >> 16 == tile_id: # right
					bitmask |= 4
					orthogonal |= 2
				if chunk.wall_layer[i + 16] >> 16 == tile_id: # bottoms
					bitmask |= 16
					orthogonal |= 4
				if chunk.wall_layer[i - 1] >> 16 == tile_id: # left
					bitmask |= 64
					orthogonal |= 8
				
			# diagonalen #
				if orthogonal & 0b0011:  # upper right
					if chunk.wall_layer[i - 15] >> 16 == tile_id:
						bitmask |= 2
				if orthogonal & 0b0110:
					if chunk.wall_layer[i + 17] >> 16 == tile_id:
						bitmask |= 8
				if orthogonal & 0b1100:
					if chunk.wall_layer[i + 15] >> 16 == tile_id:
						bitmask |= 32
				if orthogonal & 0b1001:
					if chunk.wall_layer[i - 17] >> 16 == tile_id:
						bitmask |= 128
			
			
				if tile_lookup.has(bitmask):
					var atlas_pos = tile_lookup[bitmask]
					chunk.wall_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
				else:
					chunk.wall_layer[i] = tile_id << 16 | 3 << 8 | 0
	
	chunk.autotile_flag |= 1 << 8
	chunk.is_autotiled_inner = true


# optimalisatie ok
func autotile_top(chunk: Chunk, top_chunk: Chunk):
	var bitmask: int
	var tile_id: int
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	for i in range(1,15): # bitmask calculatie voor TOP
		bitmask = 0
		tile_id = chunk.wall_layer[i] >> 16
		orthogonal = 0 
		
		# orthogalen #
		if tile_id != 0:
			if top_chunk.wall_layer[i + 240] >> 16 == tile_id: # top
				bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
				orthogonal |= 1
			if chunk.wall_layer[i + 1] >> 16 == tile_id: # right
				bitmask |= 4
				orthogonal |= 2
			if chunk.wall_layer[i + 16] >> 16 == tile_id: # bottoms
				bitmask |= 16
				orthogonal |= 4
			if chunk.wall_layer[i - 1] >> 16 == tile_id: # left
				bitmask |= 64
				orthogonal |= 8
			
		# diagonalen #
			if orthogonal & 0b0011:  # upper right
				if top_chunk.wall_layer[i + 241] >> 16 == tile_id:
					bitmask |= 2
			if orthogonal & 0b0110:
				if chunk.wall_layer[i + 17] >> 16 == tile_id:
					bitmask |= 8
			if orthogonal & 0b1100:
				if chunk.wall_layer[i + 15] >> 16 == tile_id:
					bitmask |= 32
			if orthogonal & 0b1001:
				if top_chunk.wall_layer[i + 239] >> 16 == tile_id:
					bitmask |= 128
		
			if tile_lookup.has(bitmask):
				var atlas_pos = tile_lookup[bitmask]
				chunk.wall_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.wall_layer[i] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_top = true
	chunk.autotile_flag |= 1 << 0



# optimalisatie ok
func autotile_bottom(chunk: Chunk, bottom_chunk: Chunk):
	var bitmask = 0
	var tile_id: int
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	for i in range(1,15): 
		tile_id = chunk.wall_layer[i + 240] >> 16 
		bitmask = 0
		orthogonal = 0

		# orthogalen #
		if tile_id != 0:
			if chunk.wall_layer[i + 240 - 16] >> 16 == tile_id: # top
				bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
				orthogonal |= 1
			if chunk.wall_layer[i + 240 + 1] >> 16 == tile_id: # right
				bitmask |= 4
				orthogonal |= 2
			if bottom_chunk.wall_layer[i] >> 16 == tile_id: # bottoms
				bitmask |= 16
				orthogonal |= 4
			if chunk.wall_layer[i + 240 - 1] >> 16 == tile_id: # left
				bitmask |= 64
				orthogonal |= 8
			
		# diagonalen #
			if orthogonal & 0b0011:  # upper right
				if chunk.wall_layer[i + 240 - 15] >> 16 == tile_id:
					bitmask |= 2
			if orthogonal & 0b0110:
				if bottom_chunk.wall_layer[i + 1] >> 16 == tile_id:
					bitmask |= 8
			if orthogonal & 0b1100:
				if bottom_chunk.wall_layer[i - 1] >> 16 == tile_id:
					bitmask |= 32
			if orthogonal & 0b1001:
				if chunk.wall_layer[i + 240 - 17] >> 16 == tile_id:
					bitmask |= 128
	
			if tile_lookup.has(bitmask):
				var atlas_pos = tile_lookup[bitmask]
				chunk.wall_layer[i + 240] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.wall_layer[i + 240] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_bottom = true
	chunk.autotile_flag |= 1 << 4 



# optimalisatie ok
func autotile_right(chunk: Chunk, right_chunk: Chunk):
	var bitmask: int
	var tile_id: int
	var index: int
	var orthogonal: int
	
	for i in range(1,15): 
		index = 15 + i * 16
		bitmask = 0
		tile_id = chunk.wall_layer[index] >> 16 
		# orthogalen #
		if tile_id != 0:
			if chunk.wall_layer[index - 16] >> 16 == tile_id: # top
				bitmask |= 1 
				orthogonal |= 1
			if right_chunk.wall_layer[index - 15] >> 16 == tile_id: # right
				bitmask |= 4
				orthogonal |= 2
			if chunk.wall_layer[index + 16] >> 16 == tile_id: # bottoms
				bitmask |= 16
				orthogonal |= 4
			if chunk.wall_layer[index - 1] >> 16 == tile_id: # left
				bitmask |= 64
				orthogonal |= 8
			
			# diagonalen #
			if orthogonal & 0b0011:  # upper right
				if right_chunk.wall_layer[index - 31] >> 16 == tile_id:
					bitmask |= 2
			if orthogonal & 0b0110:
				if right_chunk.wall_layer[index + 1] >> 16 == tile_id:
					bitmask |= 8
			if orthogonal & 0b1100:
				if chunk.wall_layer[index + 15] >> 16 == tile_id:
					bitmask |= 32
			if orthogonal & 0b1001:
				if chunk.wall_layer[index - 17] >> 16 == tile_id:
					bitmask |= 128
		
	
			if tile_lookup.has(bitmask):
				var atlas_pos = tile_lookup[bitmask]
				chunk.wall_layer[index] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.wall_layer[index] = tile_id << 16 | 3 << 8 | 0
	
	chunk.autotile_flag |= 1 << 2 
	chunk.is_autotiled_right = true


# optimalisatie ok
func autotile_left(chunk: Chunk, left_chunk: Chunk):
	var bitmask: int
	var tile_id: int
	var index: int
	var orthogonal: int
	
	for i in range(1,15): 
		index =  i * 16
		bitmask = 0
		tile_id = chunk.wall_layer[index] >> 16 
		
		if tile_id != 0:
			if chunk.wall_layer[index - 16] >> 16 == tile_id: # top
				bitmask |= 1 
				orthogonal |= 1
			if chunk.wall_layer[index + 1] >> 16 == tile_id: # right
				bitmask |= 4
				orthogonal |= 2
			if chunk.wall_layer[index + 16] >> 16 == tile_id: # bottoms
				bitmask |= 16
				orthogonal |= 4
			if left_chunk.wall_layer[index + 15] >> 16 == tile_id: # left
				bitmask |= 64
				orthogonal |= 8
			
			# diagonalen #
			if orthogonal & 0b0011:  # upper right
				if chunk.wall_layer[index - 15] >> 16 == tile_id:
					bitmask |= 2
			if orthogonal & 0b0110:
				if chunk.wall_layer[index + 17] >> 16 == tile_id:
					bitmask |= 8
			if orthogonal & 0b1100:
				if left_chunk.wall_layer[index + 31] >> 16 == tile_id:
					bitmask |= 32
			if orthogonal & 0b1001:
				if left_chunk.wall_layer[index - 1] >> 16 == tile_id:
					bitmask |= 128
			
			if tile_lookup.has(bitmask):
				var atlas_pos = tile_lookup[bitmask]
				chunk.wall_layer[index] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.wall_layer[index] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_left = true
	chunk.autotile_flag |= 1 << 6 


# optimalisatie ok
func autotile_top_right(chunk: Chunk, top_chunk: Chunk, top_right_chunk: Chunk, right_chunk: Chunk):
	var bitmask: int
	var tile_id = chunk.wall_layer[15] >> 16
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	if tile_id != 0:
		# orthogonalen buren #
		if top_chunk.wall_layer[255] >> 16 == tile_id: # top
			bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
			orthogonal |= 1
		if right_chunk.wall_layer[0] >> 16 == tile_id: # right
			bitmask |= 4
			orthogonal |= 2
		if chunk.wall_layer[31] >> 16 == tile_id: # bottoms
			bitmask |= 16
			orthogonal |= 4
		if chunk.wall_layer[14] >> 16 == tile_id: # left
			bitmask |= 64
			orthogonal |= 8
			
		# diagonalen buren #
		if orthogonal & 0b0011:  # upper right
			if top_right_chunk.wall_layer[240] >> 16 == tile_id:
				bitmask |= 2
		if orthogonal & 0b0110: 
			if right_chunk.wall_layer[16] >> 16 == tile_id:
				bitmask |= 8
		if orthogonal & 0b1100:
			if chunk.wall_layer[30] >> 16 == tile_id:
				bitmask |= 32
		if orthogonal & 0b1001:
			if top_chunk.wall_layer[254] >> 16 == tile_id:
				bitmask |= 128
	
	
	if tile_lookup.has(bitmask):
		var atlas_pos = tile_lookup[bitmask]
		chunk.wall_layer[15] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
	else:
		chunk.wall_layer[15] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_top_right = true
	chunk.autotile_flag |= 1 << 1 
	


# optimalisatie ok
func autotile_bottom_right(chunk: Chunk, right_chunk: Chunk, bottom_right_chunk: Chunk, bottom_chunk: Chunk):
	var bitmask: int
	var tile_id: int = chunk.wall_layer[255] >> 16
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	if tile_id != 0:
		# orthogonalen buren #
		if chunk.wall_layer[239] >> 16 == tile_id: # top
			bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
			orthogonal |= 1
		if right_chunk.wall_layer[240] >> 16 == tile_id: # right
			bitmask |= 4
			orthogonal |= 2
		if bottom_chunk.wall_layer[15] >> 16 == tile_id: # bottoms
			bitmask |= 16
			orthogonal |= 4
		if chunk.wall_layer[254] >> 16 == tile_id: # left
			bitmask |= 64
			orthogonal |= 8
			
		# diagonalen buren #
		if orthogonal & 0b0011:  # upper right
			if right_chunk.wall_layer[224] >> 16 == tile_id:
				bitmask |= 2
		if orthogonal & 0b0110: 
			if bottom_right_chunk.wall_layer[0] >> 16 == tile_id:
				bitmask |= 8
		if orthogonal & 0b1100:
			if bottom_chunk.wall_layer[14] >> 16 == tile_id:
				bitmask |= 32
		if orthogonal & 0b1001:
			if chunk.wall_layer[238] >> 16 == tile_id:
				bitmask |= 128
	
	
	if tile_lookup.has(bitmask):
		var atlas_pos = tile_lookup[bitmask]
		chunk.wall_layer[255] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
	else:
		chunk.wall_layer[255] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_bottom_right = true
	chunk.autotile_flag |= 1 << 3



# optimalisatie ok
func autotile_bottom_left(chunk: Chunk, bottom_chunk: Chunk, bottom_left_chunk: Chunk, left_chunk: Chunk):
	var bitmask: int 
	var tile_id: int = chunk.wall_layer[240] >> 16
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	if tile_id != 0:
		# orthogonalen buren #
		if chunk.wall_layer[224] >> 16 == tile_id: # top
			bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
			orthogonal |= 1
		if chunk.wall_layer[241] >> 16 == tile_id: # right
			bitmask |= 4
			orthogonal |= 2
		if bottom_chunk.wall_layer[0] >> 16 == tile_id: # bottoms
			bitmask |= 16
			orthogonal |= 4
		if left_chunk.wall_layer[255] >> 16 == tile_id: # left
			bitmask |= 64
			orthogonal |= 8
			
		# diagonalen buren #
		if orthogonal & 0b0011:  # upper right
			if chunk.wall_layer[225] >> 16 == tile_id:
				bitmask |= 2
		if orthogonal & 0b0110: 
			if bottom_chunk.wall_layer[1] >> 16 == tile_id:
				bitmask |= 8
		if orthogonal & 0b1100:
			if bottom_left_chunk.wall_layer[15] >> 16 == tile_id:
				bitmask |= 32
		if orthogonal & 0b1001:
			if left_chunk.wall_layer[239] >> 16 == tile_id:
				bitmask |= 128
	
	if tile_lookup.has(bitmask):
		var atlas_pos = tile_lookup[bitmask]
		#atlas_pos = Vector2i(3,0)
		chunk.wall_layer[240] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
	else:
		chunk.wall_layer[240] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_bottom_left = true
	chunk.autotile_flag |= 1 << 5




func autotile_top_left(chunk: Chunk, top_chunk: Chunk, left_chunk: Chunk, top_left_chunk: Chunk):
	var bitmask: int
	var tile_id: int = chunk.wall_layer[0] >> 16
	var orthogonal: int # bitmask als rand buren wel of niet bestaan
	
	if tile_id != 0:
		# orthogonalen buren #
		if top_chunk.wall_layer[240] >> 16 == tile_id: # top
			bitmask |= 1 # vervangen door bitmask |= 1 denk ik?
			orthogonal |= 1
		if chunk.wall_layer[1] >> 16 == tile_id: # right
			bitmask |= 4
			orthogonal |= 2
		if chunk.wall_layer[16] >> 16 == tile_id: # bottoms
			bitmask |= 16
			orthogonal |= 4
		if left_chunk.wall_layer[15] >> 16 == tile_id: # left
			bitmask |= 64
			orthogonal |= 8
			
		# diagonalen buren #
		if orthogonal & 0b0011:  # upper right
			if top_chunk.wall_layer[241] >> 16 == tile_id:
				bitmask |= 2
		if orthogonal & 0b0110: 
			if chunk.wall_layer[17] >> 16 == tile_id:
				bitmask |= 8
		if orthogonal & 0b1100:
			if left_chunk.wall_layer[31] >> 16 == tile_id:
				bitmask |= 32
		if orthogonal & 0b1001:
			if top_left_chunk.wall_layer[255] >> 16 == tile_id:
				bitmask |= 128
	
	
	if tile_lookup.has(bitmask):
		var atlas_pos = tile_lookup[bitmask]
		chunk.wall_layer[0] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
	else:
		chunk.wall_layer[0] = tile_id << 16 | 3 << 8 | 0
	
	chunk.is_autotiled_top_left = true
	chunk.autotile_flag |= 1 << 7
	

#endregion



#region autotiling ground

func autotile_inner_ground(chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	var i: int
	
	for y in range(1,15):
		for x in range(1,15):
			i = y * 16 + x
			bitmask = 0
			tile_id = chunk.ground_layer[i] >> 16
			
			if tile_id != 0: # 0 -> geen tile
				if chunk.ground_layer[i - 16] >> 16 == tile_id and chunk.wall_layer[i - 16] >> 16 == 0: # UP
					bitmask |= 1
				if chunk.ground_layer[i + 1] >> 16 == tile_id and chunk.wall_layer[i + 1] >> 16 == 0: # RIGHT
					bitmask |= 2
				if chunk.ground_layer[i + 16] >> 16 == tile_id and chunk.wall_layer[i + 16] >> 16 == 0: # BOTTOM
					bitmask |= 4
				if chunk.ground_layer[i - 1] >> 16 == tile_id and chunk.wall_layer[i - 1] >> 16 == 0: # LEFT
					bitmask |= 8
				
				if tile_lookup_ground.has(bitmask):
					var atlas_pos = tile_lookup_ground[bitmask]
					chunk.ground_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
				else:
					chunk.ground_layer[i] = tile_id << 16 | 8 << 8 | 0


func autotile_top_ground(chunk: Chunk, top_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	for i in range(1,15):
		
		bitmask = 0
		tile_id = chunk.ground_layer[i] >> 16
		
		if tile_id != 0: # 0 -> geen tile
			if top_chunk.ground_layer[i + 240] >> 16 == tile_id and top_chunk.wall_layer[i + 240] >> 16 == 0: # UP
				bitmask |= 1
			if chunk.ground_layer[i + 1] >> 16 == tile_id and chunk.wall_layer[i + 1] >> 16 == 0: # RIGHT
				bitmask |= 2
			if chunk.ground_layer[i + 16] >> 16 == tile_id and chunk.wall_layer[i + 16] >> 16 == 0: # BOTTOM
				bitmask |= 4
			if chunk.ground_layer[i - 1] >> 16 == tile_id and chunk.wall_layer[i - 1] >> 16 == 0: # LEFT
				bitmask |= 8
			
			if tile_lookup_ground.has(bitmask):
				var atlas_pos = tile_lookup_ground[bitmask]
				chunk.ground_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.ground_layer[i] = tile_id << 16 | 8 << 8 | 0



func autotile_right_ground(chunk: Chunk, right_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	var index: int
	
	for i in range(1,15):
		index = 15 + i * 16
		bitmask = 0
		tile_id = chunk.ground_layer[index] >> 16
		
		if tile_id != 0: # 0 -> geen tile
			if chunk.ground_layer[index - 16] >> 16 == tile_id and chunk.wall_layer[index - 16] >> 16 == 0: # UP
				bitmask |= 1
			if right_chunk.ground_layer[index - 15] >> 16 == tile_id and right_chunk.wall_layer[index - 15] >> 16 == 0: # RIGHT
				bitmask |= 2
			if chunk.ground_layer[index + 16] >> 16 == tile_id and chunk.wall_layer[index + 16] >> 16 == 0: # BOTTOM
				bitmask |= 4
			if chunk.ground_layer[index - 1] >> 16 == tile_id and chunk.wall_layer[index - 1] >> 16 == 0: # LEFT
				bitmask |= 8
			
			if tile_lookup_ground.has(bitmask):
				var atlas_pos = tile_lookup_ground[bitmask]
				chunk.ground_layer[index] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.ground_layer[index] = tile_id << 16 | 8 << 8 | 0



func autotile_bottom_ground(chunk: Chunk, bottom_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	for i in range(1,15):
		
		bitmask = 0
		tile_id = chunk.ground_layer[i + 240] >> 16
		
		if tile_id != 0: # 0 -> geen tile
			if chunk.ground_layer[i + 240 - 16] >> 16 == tile_id and chunk.wall_layer[i + 240 - 16] >> 16 == 0: # UP
				bitmask |= 1
			if chunk.ground_layer[i + 240 + 1] >> 16 == tile_id and chunk.wall_layer[i + 240 + 1] >> 16 == 0: # RIGHT
				bitmask |= 2
			if bottom_chunk.ground_layer[i] >> 16 == tile_id and bottom_chunk.wall_layer[i] >> 16 == 0: # BOTTOM
				bitmask |= 4
			if chunk.ground_layer[i + 240 - 1] >> 16 == tile_id and chunk.wall_layer[i + 240 - 1] >> 16 == 0: # LEFT
				bitmask |= 8
			
			if tile_lookup_ground.has(bitmask):
				var atlas_pos = tile_lookup_ground[bitmask]
				chunk.ground_layer[i + 240] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.ground_layer[i + 240] = tile_id << 16 | 8 << 8 | 0



func autotile_left_ground(chunk: Chunk, left_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	var index: int
	
	for i in range(1,15):
		index =  i * 16
		bitmask = 0
		tile_id = chunk.ground_layer[index] >> 16
		
		if tile_id != 0: # 0 -> geen tile
			if chunk.ground_layer[index - 16] >> 16 == tile_id and chunk.wall_layer[index - 16] >> 16 == 0: # UP
				bitmask |= 1
			if chunk.ground_layer[index + 1] >> 16 == tile_id and chunk.wall_layer[index + 1] >> 16 == 0: # RIGHT
				bitmask |= 2
			if chunk.ground_layer[index + 16] >> 16 == tile_id and chunk.wall_layer[index + 16] >> 16 == 0: # BOTTOM
				bitmask |= 4
			if left_chunk.ground_layer[index + 15] >> 16 == tile_id and left_chunk.wall_layer[index + 15] >> 16 == 0: # LEFT
				bitmask |= 8
			
			if tile_lookup_ground.has(bitmask):
				var atlas_pos = tile_lookup_ground[bitmask]
				chunk.ground_layer[index] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
			else:
				chunk.ground_layer[index] = tile_id << 16 | 8 << 8 | 0



func autotile_top_right_ground(chunk: Chunk, top_chunk: Chunk, right_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	bitmask = 0
	tile_id = chunk.ground_layer[15] >> 16
	
	if tile_id != 0: # 0 -> geen tile
		if top_chunk.ground_layer[255] >> 16 == tile_id and top_chunk.wall_layer[255] >> 16 == 0: # UP
			bitmask |= 1
		if right_chunk.ground_layer[0] >> 16 == tile_id and right_chunk.wall_layer[0] >> 16 == 0: # RIGHT
			bitmask |= 2
		if chunk.ground_layer[31] >> 16 == tile_id and chunk.wall_layer[31] >> 16 == 0: # BOTTOM
			bitmask |= 4
		if chunk.ground_layer[14] >> 16 == tile_id and chunk.wall_layer[14] >> 16 == 0: # LEFT
			bitmask |= 8

		if tile_lookup_ground.has(bitmask):
			var atlas_pos = tile_lookup_ground[bitmask]
			chunk.ground_layer[15] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
		else:
			chunk.ground_layer[15] = tile_id << 16 | 8 << 8 | 0



func autotile_bottom_right_ground(chunk: Chunk, right_chunk: Chunk, bottom_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	bitmask = 0
	tile_id = chunk.ground_layer[255] >> 16
	
	if tile_id != 0: # 0 -> geen tile
		if chunk.ground_layer[239] >> 16 == tile_id and chunk.wall_layer[239] >> 16 == 0: # UP
			bitmask |= 1
		if right_chunk.ground_layer[240] >> 16 == tile_id and right_chunk.wall_layer[240] >> 16 == 0: # RIGHT
			bitmask |= 2
		if bottom_chunk.ground_layer[15] >> 16 == tile_id and bottom_chunk.wall_layer[15] >> 16 == 0: # BOTTOM
			bitmask |= 4
		if chunk.ground_layer[254] >> 16 == tile_id and chunk.wall_layer[254] >> 16 == 0: # LEFT
			bitmask |= 8

		if tile_lookup_ground.has(bitmask):
			var atlas_pos = tile_lookup_ground[bitmask]
			chunk.ground_layer[255] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
		else:
			chunk.ground_layer[255] = tile_id << 16 | 8 << 8 | 0


func autotile_bottom_left_ground(chunk: Chunk, bottom_chunk: Chunk, left_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	bitmask = 0
	tile_id = chunk.ground_layer[240] >> 16
	
	if tile_id != 0: # 0 -> geen tile
		if chunk.ground_layer[224] >> 16 == tile_id and chunk.wall_layer[224] >> 16 == 0: # UP
			bitmask |= 1
		if chunk.ground_layer[241] >> 16 == tile_id and chunk.wall_layer[241] >> 16 == 0: # RIGHT
			bitmask |= 2
		if bottom_chunk.ground_layer[0] >> 16 == tile_id and bottom_chunk.wall_layer[0] >> 16 == 0: # BOTTOM
			bitmask |= 4
		if left_chunk.ground_layer[255] >> 16 == tile_id and left_chunk.wall_layer[255] >> 16 == 0: # LEFT
			bitmask |= 8

		if tile_lookup_ground.has(bitmask):
			var atlas_pos = tile_lookup_ground[bitmask]
			chunk.ground_layer[240] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
		else:
			chunk.ground_layer[240] = tile_id << 16 | 8 << 8 | 0


func autotile_top_left_ground(chunk: Chunk, top_chunk: Chunk, left_chunk: Chunk):
	var bitmask: int 
	var tile_id: int
	
	bitmask = 0
	tile_id = chunk.ground_layer[0] >> 16
	
	if tile_id != 0: # 0 -> geen tile
		if top_chunk.ground_layer[240] >> 16 == tile_id and top_chunk.wall_layer[240] >> 16 == 0: # UP
			bitmask |= 1
		if chunk.ground_layer[1] >> 16 == tile_id and chunk.wall_layer[1] >> 16 == 0: # RIGHT
			bitmask |= 2
		if chunk.ground_layer[16] >> 16 == tile_id and chunk.wall_layer[16] >> 16 == 0: # BOTTOM
			bitmask |= 4
		if left_chunk.ground_layer[15] >> 16 == tile_id and left_chunk.wall_layer[15] >> 16 == 0: # LEFT
			bitmask |= 8

		if tile_lookup_ground.has(bitmask):
			var atlas_pos = tile_lookup_ground[bitmask]
			chunk.ground_layer[0] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
		else:
			chunk.ground_layer[0] = tile_id << 16 | 8 << 8 | 0


#endregion autotile ground


func chunk_loader():
	if not chunks_to_load.is_empty():
		var chunk: Chunk = chunks_to_load.pop_front()
		var i = 0
		
		for y_pos in range(16):
			for x_pos in range(16):
				
				if chunk.wall_layer[i] > 65000: # omdat niet elke x,y een wall heeft, anders overal muur
					wall_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 0, chunk.get_tile_coord(chunk.wall_layer[i])) 
				
				ground_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, chunk.ground_layer[i] >> 16,chunk.get_tile_coord(chunk.ground_layer[i]))
				i += 1
				
		chunk.is_loaded = true
		chunk.is_queued_load = false
		loaded_chunks.append(chunk)



func chunk_check():
	var player_chunk_coord = floor(player.global_position / 256)
	var start_coord: Vector2 = player_chunk_coord - Vector2(render_distance, render_distance) 
	var end_coord: Vector2 = player_chunk_coord + Vector2(render_distance, render_distance) 
	
	for coord_x in range(start_coord.x, end_coord.x + 1):
		for coord_y in range(start_coord.y, end_coord.y + 1):
			var chunk_pos = Vector2i(coord_x, coord_y)
			
			if generated_chunks.has(chunk_pos) and not generated_chunks[chunk_pos].is_loaded and generated_chunks[chunk_pos].autotile_flag == 1000 and not generated_chunks[chunk_pos].is_queued_load:
				generated_chunks[chunk_pos].is_queued_load = true
				chunks_to_load.append(generated_chunks[chunk_pos])
				# LOADING CHUNK
			
			else:
				if not chunks_to_generate.has(chunk_pos) and not generated_chunks.has(chunk_pos):
					chunks_to_generate[chunk_pos] = Chunk.new(chunk_pos)
					# GENERATING CHUNK
					
					
			if generated_chunks.has(chunk_pos):
				generated_chunks[chunk_pos].last_accessed = Time.get_ticks_msec() / 1000
				# SET CHUNK TIMER
	
	for chunk in loaded_chunks:
		if (Time.get_ticks_msec() /1000) - chunk.last_accessed > 2 and not chunk.is_queued_unload:
			chunk.is_queued_unload = true
			chunks_to_unload.append(chunk)
			# verwijderen van chunk met call defered?
			
			loaded_chunks.erase.call_deferred(chunk)



func chunk_unloader():
	if not chunks_to_unload.is_empty():
		var chunk = chunks_to_unload.pop_front()
		for x in range(16):
			for y in range(16):
				var tile_pos = (chunk.position * 16) + Vector2i(x,y)
				ground_layer.erase_cell(tile_pos)
				wall_layer.erase_cell(tile_pos)
		chunk.is_queued_unload = false
		chunk.is_loaded = false



#func _draw() -> void:
	#var chunk_pixel_size = 256
	#
	#z_index = 5
	#for x in range(-1280,1280, chunk_pixel_size):
		#for y in range(-1280,1280, chunk_pixel_size):
			#
			#draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.5), false, 1.)
			#draw_string(ThemeDB.fallback_font, Vector2(x,y ), str(Vector2(x / 256,y / 256)))
	#for x in range(-480,480, 16):
		#for y in range(-480,480, 16):
			#
			#draw_rect(Rect2(Vector2(x,y), Vector2(16,16)), Color(1,0,0,0.1), false, 1.)
