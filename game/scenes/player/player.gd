extends CharacterBody2D

var speed = 150
var input: Vector2
var last_input: Vector2

@onready var animation_player: AnimationPlayer = $AnimationPlayer
var bolt_scene: PackedScene = preload("res://scenes/spells/magic_bolt/MagicBolt.tscn")



func _process(delta: float) -> void:
	input = Input.get_vector("LEFT","RIGHT","UP","DOWN")
	
	
	velocity = input * speed
	
	move_and_slide()
	
	if input != Vector2.ZERO:
		last_input = input
		if input.x != 0:
			if input.x > 0:
				animation_player.play("RUN_RIGHT")
			else:
				animation_player.play("RUN_LEFT")
		else:
			if input.y > 0:
				animation_player.play("RUN_DOWN")
			else:
				animation_player.play("RUN_UP")
	else:
		if last_input.x != 0:
			if last_input.x > 0:
				animation_player.play("IDLE_RIGHT")
			else:
				animation_player.play("IDLE_LEFT")
		else:
			if last_input.y > 0:
				animation_player.play("IDLE_DOWN")
			else:
				animation_player.play("IDLE_UP")



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		
		var chunkmanager_node: ChunkManager = get_node("/root/World/ChunkManager")
		
		var tile_pos = chunkmanager_node.wall_layer.local_to_map(get_global_mouse_position())
		var local_wall_pos = Vector2i(
			posmod(tile_pos.x, 16),
			posmod(tile_pos.y, 16)
			)
		#print(v)
		
		var chunk_pos = floor(get_global_mouse_position() / 256)
		var chunk = chunkmanager_node.generated_chunks[chunk_pos]
		var local_wall_index = chunk.local_vector_to_index(local_wall_pos)
		if chunk.wall_layer[local_wall_index] != 0:
			
			if chunk.wall_health.has(local_wall_index):
				chunk.wall_health[local_wall_index] -=  30
				if chunk.wall_health[local_wall_index] < 0:
					
					chunkmanager_node.wall_layer.erase_cell(tile_pos)
			else:
				chunk.wall_health[local_wall_index] = chunk.max_health - 30
				if chunk.wall_health[local_wall_index] < 0:
					
					chunkmanager_node.wall_layer.erase_cell(tile_pos)
			
		else:
			print("empty")
	
	if event.is_action_pressed("right_click"):
		var chunkmanager_node: ChunkManager = get_node("/root/World/ChunkManager")
		var bolt = bolt_scene.instantiate()
		bolt.position = global_position
		bolt.direction = global_position.direction_to(get_global_mouse_position())
		
		
		#bolt.direction = Vector2i.RIGHT
		var projectiles = get_node("/root/World/Projectiles")
		projectiles.add_child(bolt)
		
