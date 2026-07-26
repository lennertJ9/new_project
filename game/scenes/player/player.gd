extends CharacterBody2D
class_name Player

class RemotePositionSnapshot:
	var position: Vector2 = Vector2.ZERO
	var received_time_msec: int = 0


signal movement_input_sampled(movement_input: Vector2)

const REMOTE_INTERPOLATION_DELAY_MSEC: int = 100
const MAX_REMOTE_POSITION_SNAPSHOTS: int = 4

# multiplayer correction voor clients
const LOCAL_RECONCILIATION_TOLERANCE: float = 8.0
const LOCAL_RECONCILIATION_HARD_DISTANCE: float = 64.0
const LOCAL_RECONCILIATION_SOFT_FACTOR: float = 0.25

var speed: int = 120
var facing_direction: Vector2 = Vector2.UP
var chunk_manager: ChunkManager
var projectile_container: Node2D
var controls_enabled: bool = false
var remote_position_snapshots: Array[RemotePositionSnapshot] = []


@onready var animation_player: AnimationPlayer = $AnimationPlayer
const BOLT_SCENE: PackedScene = preload("res://scenes/spells/magic_bolt/MagicBolt.tscn")


func configure_world(chunk_manager_reference: ChunkManager, projectile_container_reference: Node2D) -> void:
	chunk_manager = chunk_manager_reference
	projectile_container = projectile_container_reference



func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	if not controls_enabled:
		velocity = Vector2.ZERO



func _process(_delta: float) -> void:
	_interpolate_remote_position()



func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		return

	var movement_input: Vector2 = Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")
	movement_input_sampled.emit(movement_input)
	
	simulate_movement(movement_input)



# Simuleert één movementstap op basis van een reeds gekozen richting.
# Deze functie leest zelf geen toetsenbordinput.
func simulate_movement(movement_input: Vector2) -> void:
	_update_facing_direction(movement_input)

	velocity = movement_input * speed
	move_and_slide()

	_update_movement_animation(velocity)



func _update_facing_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing_direction = direction



## als movement_velocity 0 is, dan speelt de idle animation, als het niet 0 is word de run animation gespeeld
func _update_movement_animation(movement_velocity: Vector2) -> void:
	if not movement_velocity.is_zero_approx():
		_play_directional_animation("RUN", movement_velocity)
		return

	_play_directional_animation("IDLE", facing_direction)



## idle en run animations
func _play_directional_animation(animation_prefix: String, direction: Vector2) -> void:
	if direction.x > 0:
		animation_player.play("%s_RIGHT" % animation_prefix)
	elif direction.x < 0:
		animation_player.play("%s_LEFT" % animation_prefix)
	elif direction.y > 0:
		animation_player.play("%s_DOWN" % animation_prefix)
	else:
		animation_player.play("%s_UP" % animation_prefix)



func get_network_movement_velocity() -> Vector2:
	return velocity



func get_facing_direction() -> Vector2:
	return facing_direction



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



#region network

## toevoegen van positie aan de interpolatiebuffer
## deze buffer is een lijst die de positie interpoleerd naar de nieuwste positie
## remote_position_snapshots is de lijst waar _interpolate_remote_position() over looped
func push_remote_position_snapshot(position: Vector2) -> void:
	var snapshot: RemotePositionSnapshot = RemotePositionSnapshot.new()

	snapshot.position = position
	snapshot.received_time_msec = Time.get_ticks_msec()

	remote_position_snapshots.append(snapshot)

	while remote_position_snapshots.size() > MAX_REMOTE_POSITION_SNAPSHOTS:
		remote_position_snapshots.remove_at(0)



## looped over _interpolate_remote_position()
## interpolate naar de nieuwste value
## value word toegewezen aan de Player
func _interpolate_remote_position() -> void:
	if remote_position_snapshots.size() < 2:
		return

	var render_time_msec: int = (Time.get_ticks_msec() - REMOTE_INTERPOLATION_DELAY_MSEC)

	while remote_position_snapshots.size() >= 3:
		var second_snapshot: RemotePositionSnapshot = (remote_position_snapshots[1])
		
		if second_snapshot.received_time_msec > render_time_msec:
			break

		remote_position_snapshots.remove_at(0)

	var from_snapshot: RemotePositionSnapshot = remote_position_snapshots[0]
	var to_snapshot: RemotePositionSnapshot = remote_position_snapshots[1]

	var duration_msec: int = (to_snapshot.received_time_msec - from_snapshot.received_time_msec)

	if duration_msec <= 0:
		duration_msec = 1

	var interpolation_weight: float = clampf(float(render_time_msec - from_snapshot.received_time_msec) / float(duration_msec), 0.0, 1.0)

	global_position = from_snapshot.position.lerp(to_snapshot.position, interpolation_weight)



## controleerd de authoritative_position met zijn eigen positie en corrigeerd naar authoritative_position wanneer nodig
func reconcile_to_authoritative_position(authoritative_position: Vector2) -> void:
	var position_error: Vector2 = authoritative_position - global_position
	var error_distance: float = position_error.length()

	if error_distance <= LOCAL_RECONCILIATION_TOLERANCE:
		return

	if error_distance >= LOCAL_RECONCILIATION_HARD_DISTANCE:
		global_position = authoritative_position
		velocity = Vector2.ZERO

		print("Lokale speler hard gecorrigeerd door host.")
		return

	global_position += position_error * LOCAL_RECONCILIATION_SOFT_FACTOR



func apply_remote_snapshot(player_snapshot: PlayerSnapshot) -> void:
	push_remote_position_snapshot(player_snapshot.world_position)

	facing_direction = player_snapshot.facing_direction
	_update_movement_animation(player_snapshot.movement_velocity)


#endregion
