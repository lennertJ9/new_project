## idee voor later:
##
## tilemappattern
## tijdens het generaten per chunk een tilemappattern maken
## tijdens het laden is set_cell nietmeer nodig omdat we gwn een tilemappattern inladen
##

extends Node2D

signal chunk_generated
signal chunk_deloaded
signal neighbours_checked


@export var player: Node2D
@export var noise_tex: NoiseTexture2D
var noise: Noise

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var object_layer: TileMapLayer = $ObjectLayer
@onready var shadow_layer: TileMapLayer = $ShadowLayer


@onready var autotiling: Node = $Autotiling
@onready var object_generator: Node = $ObjectGenerator


var render_distance: int = 2
var cpu_generator_delay: int = 25
var cpu_load_delay: int = 25

#-------------- Chunks  --------------------#
var generated_chunks: Dictionary[Vector2i, Chunk] # pure data, deze chunks zijn niet perse autotiled
var loaded_chunks: Array[Chunk] # loaded chunks, actief en autotiled
# --> nieuwe aanpak, generated chunks worden hierin gezet, hierdoor loopen, if alle 8 buren: append naar chunks_to_autotile

#-------------- Chunk die processed moeten worden  --------------------#
var chunks_to_data_generate: Dictionary[Vector2i, Chunk] # chunks die generated moeten worden -> puur data generatie, met tile ID
var chunks_to_autotile: Dictionary[Vector2i, Chunk] # chunks die autotiled moeten worden en waarvan alle 8 buren aanwezig zijn
var neighbourless_chunks: Array[Vector2i] # positions van generated chunks die mogelijks niet alle 8 buren hebben om geautotiled te worden
var chunks_to_load: Array[Chunk] # chunks die loaded moeten worden, deze zijn autotiled
var chunks_to_unload: Array[Chunk] # chunks die unloaded moeten worden

# ------------- Check Timers --------------#
var chunk_check_interval: float = 0.2
var chunk_load_interval: float = 0.002
var chunk_unload_interval: float = 0.002

var chunk_check_timer: float = 0
var chunk_load_timer: float = 0
var chunk_unload_timer: float = 0

# -------------- threads ------------------------------------------- #
var thread_chunk_generator: Thread = Thread.new()
var thread_chunk_autotiler: Thread = Thread.new()
var thread_neighbour_checker: Thread = Thread.new()
# ------------------------------------------------------------------ #

										 #top          #top-right      #right         #bottom-right   #bottom         #bottom-left     #left          #top-left
var chunk_neighbours: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), 
										Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1),  
  
]





func _ready() -> void:
	set_process(false)
	thread_chunk_generator.start(chunk_generator)
	thread_neighbour_checker.start(chunk_neighbour_checker)
	
	player = get_tree().get_first_node_in_group("world").camera
	noise = noise_tex.noise



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
		OS.delay_msec(cpu_generator_delay)
		
		if not chunks_to_data_generate.is_empty():
			
			var chunk: Chunk = chunks_to_data_generate.values()[0]
			var chunk_pos = chunk.position
			chunk.a_star_id = AStarManager.get_a_star_id()
			var i = 0
			for y in range(16):
				for x in range(16):
					chunk.walkable[i] = 1
					var global_pos = chunk.position * 16 + Vector2i(x,y)
					var walls_atlas_id = 0
					var random = noise.get_noise_2dv(global_pos)
					var wall_id: int
					var ground_id: int
					if random > 0.1:
						wall_id = 1 << 16 # dirt wall
						chunk.walkable[i] = 0
						
					else:
						wall_id = 0
						
					# dark grass
					if random < -0.08:
						ground_id = 2 << 16 # aanetten van 
						
					else:
						ground_id = 1 << 16
					
					chunk.shadow_layer[i] =  1 << 16
					chunk.ground_layer[i] = ground_id
					chunk.wall_layer[i] = wall_id
					i += 1
			
			object_generator.generate_trees(chunk)
			# dit maakt alleen points, geen connecties. connecties pas na de neighbour checker
			AStarManager.generate_a_star_points(chunk) 
			
			generated_chunks[chunk.position] = chunk 
			chunk.is_generated = true
			
			neighbourless_chunks.append(chunk_pos) # hier loopt thread en kijkt als buren generated zijn
			chunk.is_generated = true
			chunks_to_data_generate.erase(chunk_pos)
			
			emit_signal.call_deferred("chunk_generated", chunk)
			



func chunk_neighbour_checker():
	while true:
		OS.delay_msec(100)
		var chunk: Chunk
		
		for i in range(neighbourless_chunks.size() - 1, -1, -1): # reverse loop voor item deletion
			var is_neighboured = true
			var chunk_pos = neighbourless_chunks[i]
			chunk = generated_chunks[chunk_pos]
			
			var j: int = 0
			for neighbour in chunk_neighbours:
				if generated_chunks.has(chunk_pos + neighbour):
					chunk.neighbours[j] = generated_chunks[chunk_pos + neighbour]
					j += 1
				else:
					is_neighboured = false
					break
			
			# hier worden chunks klaargemaakt voor astar en autotiling, alle 8 neigbours zijn hiervoor nodig.
			if is_neighboured:
				chunk.is_neigbhoured = true
				autotiling.chunks_to_autotile[chunk_pos] = generated_chunks[chunk_pos]
				neighbourless_chunks.remove_at(i)
				
				#neighbours_checked.emit(chunk)
				
				emit_signal.call_deferred("neighbours_checked", chunk)
				#AStarManager.chunk_to_connect.append(generated_chunks[chunk_pos])



func chunk_loader():
	if not chunks_to_load.is_empty():
		var chunk: Chunk = chunks_to_load.pop_front()
		var i = 0
		
		for y_pos in range(16):
			for x_pos in range(16):
				
				if chunk.shadow_layer[i] >> 16 == 1:
					shadow_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 1, Vector2i(0,0))
				
				if chunk.wall_layer[i] > 65000: # omdat niet elke x,y een wall heeft, anders overal muur
					wall_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, 1, chunk.get_tile_coord(chunk.wall_layer[i])) 
				if chunk.object_layer[i] > 65000:
					object_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, chunk.object_layer[i] >> 16, chunk.get_tile_coord(chunk.object_layer[i]))
				
				ground_layer.set_cell(Vector2i(x_pos,y_pos) + chunk.position * 16, chunk.ground_layer[i] >> 16,chunk.get_tile_coord(chunk.ground_layer[i]))
				i += 1
				
		chunk.is_loaded = true
		chunk.is_queued_load = false
		loaded_chunks.append(chunk)


# chunk worden geload wanneer: in generated lijst | niet al loaded of queued voor loading zijn | autotiled zijn 
func chunk_check():
	var player_chunk_coord = floor(player.global_position / 256)
	var start_coord: Vector2 = player_chunk_coord - Vector2(render_distance, render_distance) 
	var end_coord: Vector2 = player_chunk_coord + Vector2(render_distance, render_distance) 
	
	for coord_x in range(start_coord.x, end_coord.x + 1):
		for coord_y in range(start_coord.y, end_coord.y + 1):
			var chunk_pos = Vector2i(coord_x, coord_y)
			
			if generated_chunks.has(chunk_pos):
				var chunk: Chunk = generated_chunks[chunk_pos]
				if not chunk.is_loaded and not chunk.is_queued_load and chunk.is_autotiled:
					generated_chunks[chunk_pos].is_queued_load = true
					chunks_to_load.append(generated_chunks[chunk_pos])
				
					
					
			#if generated_chunks.has(chunk_pos) and not generated_chunks[chunk_pos].is_loaded and generated_chunks[chunk_pos].is_autotiled and not generated_chunks[chunk_pos].is_queued_load:
				#generated_chunks[chunk_pos].is_queued_load = true
				#chunks_to_load.append(generated_chunks[chunk_pos])
				# LOADING CHUNK
			
			else:
				if not chunks_to_data_generate.has(chunk_pos) and not generated_chunks.has(chunk_pos):
					chunks_to_data_generate[chunk_pos] = Chunk.new(chunk_pos)
					
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
		chunk_deloaded.emit(chunk)
		



#func _draw() -> void:
	#var chunk_pixel_size = 256
	#
	#
	#for x in range(-1280,1280, chunk_pixel_size):
		#for y in range(-1280,1280, chunk_pixel_size):
			#
			#draw_rect(Rect2(Vector2(x,y), Vector2(256,256)), Color(1,0,0,0.5), false, 1.)
			#draw_string(ThemeDB.fallback_font, Vector2(x,y ), str(Vector2(x / 256,y / 256)))
	#for x in range(-480,480, 16):
		#for y in range(-480,480, 16):
			#
			#draw_rect(Rect2(Vector2(x,y), Vector2(16,16)), Color(1,0,0,0.1), false, 1.)
