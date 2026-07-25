extends CharacterBody2D
class_name Player

var speed: int = 250
var input: Vector2
var last_input: Vector2
var chunk_manager: ChunkManager
var projectile_container: Node2D
var controls_enabled: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
const BOLT_SCENE: PackedScene = preload("res://scenes/spells/magic_bolt/MagicBolt.tscn")


func configure_world(chunk_manager_reference: ChunkManager, projectile_container_reference: Node2D) -> void:
	chunk_manager = chunk_manager_reference
	projectile_container = projectile_container_reference



func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	if not controls_enabled:
		velocity = Vector2.ZERO



func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		return

	var movement_input: Vector2 = Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")

	simulate_movement(movement_input)



# Simuleert één movementstap op basis van een reeds gekozen richting.
# Deze functie leest zelf geen toetsenbordinput.
func simulate_movement(movement_input: Vector2) -> void:
	velocity = movement_input * speed
	move_and_slide()

	_update_movement_animation(movement_input)



func _update_movement_animation(movement_input: Vector2) -> void:
	if movement_input != Vector2.ZERO:
		last_input = movement_input

		if movement_input.x > 0:
			animation_player.play("RUN_RIGHT")
		elif movement_input.x < 0:
			animation_player.play("RUN_LEFT")
		elif movement_input.y > 0:
			animation_player.play("RUN_DOWN")
		else:
			animation_player.play("RUN_UP")
		return

	if last_input.x > 0:
		animation_player.play("IDLE_RIGHT")
	elif last_input.x < 0:
		animation_player.play("IDLE_LEFT")
	elif last_input.y > 0:
		animation_player.play("IDLE_DOWN")
	else:
		animation_player.play("IDLE_UP")




func _input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event.is_action_pressed("left_click"):
		if chunk_manager != null:
			chunk_manager.damage_wall(get_global_mouse_position(), 30)
	
	if event.is_action_pressed("right_click"):
		if chunk_manager == null or projectile_container == null:
			return

		var bolt: MagicBolt = BOLT_SCENE.instantiate() as MagicBolt
		if bolt == null:
			return

		bolt.global_position = global_position
		bolt.direction = global_position.direction_to(get_global_mouse_position())
		bolt.chunk_manager = chunk_manager
		projectile_container.add_child(bolt)
