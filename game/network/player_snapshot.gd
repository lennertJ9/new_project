class_name PlayerSnapshot
extends RefCounted


var state_sequence: int = 0
var peer_id: int = 0
var world_position: Vector2 = Vector2.ZERO
var movement_velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.UP


static func create(new_state_sequence: int, new_peer_id: int, new_world_position: Vector2, new_movement_velocity: Vector2, new_facing_direction: Vector2) -> PlayerSnapshot:
	var player_snapshot: PlayerSnapshot = PlayerSnapshot.new()

	player_snapshot.state_sequence = new_state_sequence
	player_snapshot.peer_id = new_peer_id
	player_snapshot.world_position = new_world_position
	player_snapshot.movement_velocity = new_movement_velocity
	player_snapshot.facing_direction = new_facing_direction

	return player_snapshot


func to_dictionary() -> Dictionary:
	return {
		"state_sequence": state_sequence,
		"peer_id": peer_id,
		"position": world_position,
		"movement_velocity": movement_velocity,
		"facing_direction": facing_direction,
	}



static func from_dictionary(payload: Dictionary) -> PlayerSnapshot:
	var raw_state_sequence: Variant = payload.get("state_sequence")
	var raw_peer_id: Variant = payload.get("peer_id")
	var raw_position: Variant = payload.get("position")
	var raw_movement_velocity: Variant = payload.get("movement_velocity")
	var raw_facing_direction: Variant = payload.get("facing_direction")

	if not raw_state_sequence is int or raw_state_sequence < 0:
		return null

	if not raw_peer_id is int or raw_peer_id <= 0:
		return null

	if not raw_position is Vector2:
		return null

	if not raw_movement_velocity is Vector2:
		return null

	if not raw_facing_direction is Vector2:
		return null

	var facing_direction: Vector2 = raw_facing_direction

	if facing_direction.is_zero_approx():
		return null

	return create(
		raw_state_sequence,
		raw_peer_id,
		raw_position,
		raw_movement_velocity,
		facing_direction
	)
