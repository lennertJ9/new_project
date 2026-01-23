extends Node



var chunks_to_autotile: Dictionary[Vector2i, Chunk]

var thread_chunk_autotiler: Thread = Thread.new()
var cpu_autotile_delay: int = 25

# -------------- LOOKUP TABLES -------------------------------------#
var tile_lookup: Dictionary[int, Vector2i] = { #bitmask: atlas_position }
	0: Vector2i(4,4),
	1: Vector2i(4,2),
	3: Vector2i(4,2),
	4: Vector2i(0,4),
	5: Vector2i(0,8),
	6: Vector2i(0,4),
	7: Vector2i(0,2),
	12: Vector2i(0,4),
	14: Vector2i(0,4),
	15: Vector2i(0,2),
	16: Vector2i(4,0),
	17: Vector2i(4,1),
	19: Vector2i(4,1),
	21: Vector2i(6,5),
	23: Vector2i(6,3),
	24: Vector2i(4,0),
	25: Vector2i(4,1),
	28: Vector2i(0,0),
	29: Vector2i(6,4),
	30: Vector2i(0,0),
	31: Vector2i(0,1),
	48: Vector2i(4,0),
	49: Vector2i(4,1),
	54: Vector2i(10,3),
	56: Vector2i(4,0),
	60: Vector2i(0,0),
	62: Vector2i(0,0),
	63: Vector2i(0,1),
	64: Vector2i(2,4),
	65: Vector2i(3,8),
	68: Vector2i(1,4),
	70: Vector2i(1,4),
	71: Vector2i(2,6),
	76: Vector2i(1,4),
	79: Vector2i(2,6),
	81: Vector2i(8,6),
	84: Vector2i(12,1),
	92: Vector2i(8,0),
	95: Vector2i(12,2),
	96: Vector2i(2,4),
	97: Vector2i(2,8),
	100: Vector2i(1,4),
	102: Vector2i(1,4),
	108: Vector2i(1,4),
	112: Vector2i(2,0),
	113: Vector2i(8,4),
	115: Vector2i(8,4),
	116: Vector2i(6,0),
	119: Vector2i(6,6),
	120: Vector2i(2,0),
	124: Vector2i(1,0),
	125: Vector2i(10,1), 
	126: Vector2i(1,0),
	127: Vector2i(8,2),
	128: Vector2i(2,4),
	129: Vector2i(4,2),
	131: Vector2i(4,2),
	135: Vector2i(0,2),
	143: Vector2i(0,2),
	145: Vector2i(4,1),
	156: Vector2i(0,0),
	159: Vector2i(0,1),
	185: Vector2i(4,1),
	191: Vector2i(0,1),
	192: Vector2i(2,4),
	193: Vector2i(2,2),
	195: Vector2i(2,2),
	196: Vector2i(1,4),
	197: Vector2i(0,6),
	198: Vector2i(1,4),
	199: Vector2i(1,2),
	203: Vector2i(2,2),
	207: Vector2i(1,2),
	209: Vector2i(8,3),
	211: Vector2i(8,3),
	215: Vector2i(12,1),
	221: Vector2i(8,6),
	223: Vector2(8,1),
	224: Vector2i(2,4),
	225: Vector2i(2,2),
	227: Vector2i(2,2),
	229: Vector2i(0,6),
	231: Vector2i(1,2),
	239: Vector2i(1,2),
	240: Vector2i(2,0),
	241: Vector2i(2,1),
	243: Vector2i(2,1),
	244: Vector2i(6,0),
	245: Vector2i(10,2),
	247: Vector2i(6,1),
	248: Vector2i(2,0),
	249: Vector2i(2,1),
	251: Vector2i(2,1),
	252: Vector2i(1,0),
	253: Vector2i(6,2),
	254: Vector2i(1,0),
	255: Vector2i(1,1),

}
var tile_lookup_ground: Dictionary[int, Dictionary] = {
	0: {Vector2i(5,5): 100},
	1: {Vector2i(5,3): 100},
	2: {Vector2i(0,5): 100},
	3: {Vector2i(0,3): 100},
	4: {Vector2i(5,0): 100},
	5: {Vector2i(5,2): 100},
	6: {Vector2i(0,0): 100},
	7: {Vector2i(0,2): 100},
	8: {Vector2i(3,5): 100},
	9: {Vector2i(3,3): 100},
	10:{Vector2i(2,5): 100},
	11: {Vector2i(2,3): 100},
	12: {Vector2i(3,0): 100},
	13: {Vector2i(3,2): 100},
	14: {Vector2i(2,0): 100},
	15: {Vector2i(2,2): 90, Vector2i(9,2): 10},
}
# ------------------------------------------------------------------#


func _ready() -> void:
	thread_chunk_autotiler.start(chunk_autotiler)




func chunk_autotiler():
	while true:
		OS.delay_msec(cpu_autotile_delay)
		if not chunks_to_autotile.is_empty():
			
			var chunk: Chunk = chunks_to_autotile.values()[0]
			var chunk_pos = chunk.position
			var bitmask: int = 0
			var tile_id: int = 0
			
			# ----------------- INNER ------------------------------------#
			autotile_inner(chunk)
			autotile_inner_ground(chunk)
			
			# ----------------- SIDES--------------------------------#
			var top_chunk: Chunk = owner.generated_chunks[chunk_pos - Vector2i(0,1)]
			autotile_top(chunk, top_chunk)
			autotile_top_ground(chunk, top_chunk)
			
			var right_chunk: Chunk = owner.generated_chunks[chunk_pos + Vector2i(1,0)]
			autotile_right(chunk, right_chunk)
			autotile_right_ground(chunk, right_chunk)
			
			var bottom_chunk: Chunk = owner.generated_chunks[chunk_pos + Vector2i(0,1)]
			autotile_bottom(chunk, bottom_chunk)
			autotile_bottom_ground(chunk, bottom_chunk)
			
			var left_chunk: Chunk = owner.generated_chunks[chunk_pos - Vector2i(1,0)]
			autotile_left(chunk, left_chunk)
			autotile_left_ground(chunk, left_chunk)
			
			# ----------------- EDGES ------------------------------------#
			autotile_top_right(chunk, owner.generated_chunks[chunk_pos + Vector2i(0,-1)], owner.generated_chunks[chunk_pos + Vector2i(1,-1)], owner.generated_chunks[chunk_pos + Vector2i(1,0)])
			autotile_top_right_ground(chunk, top_chunk, right_chunk)
			
			autotile_bottom_right(chunk, owner.generated_chunks[chunk_pos + Vector2i(1,0)], owner.generated_chunks[chunk_pos + Vector2i(1,1)], owner.generated_chunks[chunk_pos + Vector2i(0,1)])
			autotile_bottom_right_ground(chunk, right_chunk, bottom_chunk)
			
			autotile_bottom_left(chunk, owner.generated_chunks[chunk_pos + Vector2i(0,1)], owner.generated_chunks[chunk_pos + Vector2i(-1,1)], owner.generated_chunks[chunk_pos + Vector2i(-1,0)])
			autotile_bottom_left_ground(chunk, bottom_chunk, left_chunk)
			
			autotile_top_left(chunk, owner.generated_chunks[chunk_pos + Vector2i(0,-1)], owner.generated_chunks[chunk_pos + Vector2i(-1,0)], owner.generated_chunks[chunk_pos + Vector2i(-1,-1)])
			autotile_top_left_ground(chunk, top_chunk, left_chunk)
			
			chunk.is_autotiled = true
			chunks_to_autotile.erase(chunk.position)



func pick_tile_variant(bitmask):
	var dict = tile_lookup_ground[bitmask]
	dict.sort()
	
	var sum: int = 0
	var random = randi_range(0,99) # ik denk verschillend bij seeds maar opzich geen probleem
	
	for key in dict:
		sum += dict[key]
		if sum > random:
			return key



# --------------- WALL LAYER -------------------------- #
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


#  ------------------- GROUND LAYER --------------------------------- #

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
					var atlas_pos = pick_tile_variant(bitmask)
					#var atlas_pos = tile_lookup_ground[bitmask]
					chunk.ground_layer[i] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
				else:
					chunk.ground_layer[i] = tile_id << 16 | 8 << 8 | 0
				
				#var m: int
				#for u in range(1000000):
					#m+= 1



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
				var atlas_pos = pick_tile_variant(bitmask)
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
				var atlas_pos = pick_tile_variant(bitmask)
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
				var atlas_pos = pick_tile_variant(bitmask)
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
				var atlas_pos = pick_tile_variant(bitmask)
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
			var atlas_pos = pick_tile_variant(bitmask)
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
			var atlas_pos = pick_tile_variant(bitmask)
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
			var atlas_pos = pick_tile_variant(bitmask)
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
			var atlas_pos = pick_tile_variant(bitmask)
			chunk.ground_layer[0] = tile_id << 16 | atlas_pos.x << 8 | atlas_pos.y
		else:
			chunk.ground_layer[0] = tile_id << 16 | 8 << 8 | 0
