extends Node
class_name ProjectileSync


const MAGIC_BOLT_SPELL_ID: String = "magic_bolt"
const MAGIC_BOLT_PROJECTILE_TYPE: String = "magic_bolt"
const MAGIC_BOLT_SCENE: PackedScene = preload("res://scenes/spells/magic_bolt/MagicBolt.tscn")

var next_client_cast_id: int = 0
var predicted_bolts_by_client_cast_id: Dictionary[int, MagicBolt] = {}

enum CastResult {
	OK,
}

var active_world: World
var next_projectile_id: int = 0
var visual_projectiles_by_id: Dictionary[int, MagicBolt] = {}


func set_active_world(world: World) -> void:
	if active_world == world:
		return

	_disconnect_from_active_world()
	_clear_visual_projectiles()
	active_world = world
	if active_world == null:
		return
	
	active_world.player.spell_cast_requested.connect(request_spell_cast)



func _disconnect_from_active_world() -> void:
	if active_world == null:
		return

	if active_world.player.spell_cast_requested.is_connected(request_spell_cast):
		active_world.player.spell_cast_requested.disconnect(request_spell_cast)



func clear_active_world() -> void:
	_disconnect_from_active_world()
	_clear_visual_projectiles()
	active_world = null



func on_host_started() -> void:
	next_projectile_id = 0



func handle_network_packet(from_peer_id: int, message_type: int, payload: Dictionary) -> bool:
	match message_type:
		
		NetworkProtocol.MessageType.REQUEST_CAST_SPELL:
			if NetworkManager.is_host():
				_handle_spell_cast_request(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.PROJECTILE_SPAWN:
			if NetworkManager.is_client():
				_handle_projectile_spawn(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.PROJECTILE_DESPAWN:
			if NetworkManager.is_client():
				_handle_projectile_despawn(from_peer_id, payload)
			return true

	return false



## uitgevoerd wanneer player.gd het signaal spell_cast_requested emit
func request_spell_cast(spell_id: String, aim_direction: Vector2) -> void:
	if not _is_supported_spell(spell_id):
		return

	if aim_direction.is_zero_approx():
		return

	if NetworkManager.is_client():
		next_client_cast_id += 1
		var client_cast_id: int = next_client_cast_id

		_spawn_predicted_magic_bolt(client_cast_id, aim_direction)

		var send_error: Error = _send_spell_cast_request(spell_id, aim_direction, client_cast_id)

		if send_error != OK:
			_remove_predicted_magic_bolt(client_cast_id)

		return

	_try_cast_spell(MultiplayerPeer.TARGET_PEER_SERVER, spell_id, aim_direction, 0)



func _spawn_predicted_magic_bolt(client_cast_id: int, aim_direction: Vector2) -> void:
	if active_world == null or active_world.player == null:
		return

	var predicted_projectile_id: int = -client_cast_id
	var predicted_bolt: MagicBolt = _create_magic_bolt(predicted_projectile_id, active_world.player.global_position, aim_direction, false)

	if predicted_bolt == null:
		return

	predicted_bolts_by_client_cast_id[client_cast_id] = predicted_bolt



func _remove_predicted_magic_bolt(client_cast_id: int) -> void:
	if not predicted_bolts_by_client_cast_id.has(client_cast_id):
		return

	var predicted_bolt: MagicBolt = predicted_bolts_by_client_cast_id[client_cast_id]
	predicted_bolts_by_client_cast_id.erase(client_cast_id)

	if predicted_bolt != null:
		predicted_bolt.queue_free()



func _send_spell_cast_request(spell_id: String, aim_direction: Vector2, client_cast_id: int) -> Error:
	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_CAST_SPELL,
		{
			"spell_id": spell_id,
			"aim_direction": aim_direction.normalized(),
			"client_cast_id": client_cast_id,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_GAMEPLAY,
	)
	
	if send_error != OK:
		print("REQUEST_CAST_SPELL versturen mislukt: %s." % error_string(send_error))

	return send_error



func _handle_spell_cast_request(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	var raw_spell_id: Variant = payload.get("spell_id")
	var raw_aim_direction: Variant = payload.get("aim_direction")
	var raw_client_cast_id: Variant = payload.get("client_cast_id")
	
	if not raw_client_cast_id is int or raw_client_cast_id <= 0:
		return

	if not raw_spell_id is String:
		return

	if not raw_aim_direction is Vector2:
		return

	_try_cast_spell(from_peer_id, raw_spell_id, raw_aim_direction, raw_client_cast_id)



## voert een check uit via _check_cast, als deze OK returned word _spawn_authoritative_magic_bolt uitgevoert
func _try_cast_spell(owner_peer_id: int, spell_id: String, aim_direction: Vector2, client_cast_id: int) -> void:
	if active_world == null:
		return

	if not _is_supported_spell(spell_id):
		return

	if aim_direction.is_zero_approx():
		return

	var owner_player: Player = active_world.get_player_for_peer(owner_peer_id)
	if owner_player == null:
		return

	var cast_result: CastResult = _check_cast(owner_peer_id, spell_id)
	if cast_result != CastResult.OK:
		return

	_spawn_authoritative_magic_bolt(owner_peer_id, aim_direction, client_cast_id)



func _check_cast(_owner_peer_id: int, _spell_id: String) -> CastResult:
	return CastResult.OK



func _spawn_authoritative_magic_bolt(owner_peer_id: int, aim_direction: Vector2, client_cast_id: int) -> void:
	if active_world == null or active_world.chunk_manager == null:
		return

	var owner_player: Player = active_world.get_player_for_peer(owner_peer_id)
	if owner_player == null:
		return

	var direction: Vector2 = aim_direction.normalized()
	if direction.is_zero_approx():
		return

	next_projectile_id += 1
	var projectile_id: int = next_projectile_id
	var spawn_position: Vector2 = owner_player.global_position

	var bolt: MagicBolt = _create_magic_bolt(projectile_id, spawn_position, direction, true)
	
	if bolt == null:
		return

	bolt.projectile_impacted.connect(_on_authoritative_projectile_impacted)
	_broadcast_projectile_spawn(projectile_id, owner_peer_id, spawn_position, direction, client_cast_id)



func _create_magic_bolt(projectile_id: int, spawn_position: Vector2, direction: Vector2, should_apply_world_damage: bool) -> MagicBolt:
	if active_world == null:
		return null

	var bolt: MagicBolt = MAGIC_BOLT_SCENE.instantiate() as MagicBolt
	if bolt == null:
		return null

	active_world.projectiles.add_child(bolt)
	bolt.configure(projectile_id, spawn_position, direction, active_world.chunk_manager, should_apply_world_damage)
	
	return bolt



func _broadcast_projectile_spawn(projectile_id: int, owner_peer_id: int, spawn_position: Vector2, direction: Vector2, client_cast_id: int) -> void:
	if not NetworkManager.is_host():
		return

	for target_peer_id: int in NetworkManager.approved_client_peer_ids.keys():
		var send_error: Error = NetworkManager.send_packet(
			target_peer_id,
			NetworkProtocol.MessageType.PROJECTILE_SPAWN,
			{
				"projectile_id": projectile_id,
				"projectile_type": MAGIC_BOLT_PROJECTILE_TYPE,
				"owner_peer_id": owner_peer_id,
				"spawn_position": spawn_position,
				"direction": direction,
				"client_cast_id": client_cast_id,
			},
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetworkProtocol.CHANNEL_GAMEPLAY
		)

		if send_error != OK:
			print("PROJECTILE_SPAWN versturen mislukt: %s." % error_string(send_error))



func _on_authoritative_projectile_impacted(projectile_id: int) -> void:
	if not NetworkManager.is_host():
		return

	for target_peer_id: int in NetworkManager.approved_client_peer_ids.keys():
		var send_error: Error = NetworkManager.send_packet(
			target_peer_id,
			NetworkProtocol.MessageType.PROJECTILE_DESPAWN,
			{
				"projectile_id": projectile_id,
			},
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetworkProtocol.CHANNEL_GAMEPLAY
		)

		if send_error != OK:
			print("PROJECTILE_DESPAWN versturen mislukt: %s." % error_string(send_error))



func _handle_projectile_spawn(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_projectile_id: Variant = payload.get("projectile_id")
	var raw_projectile_type: Variant = payload.get("projectile_type")
	var raw_owner_peer_id: Variant = payload.get("owner_peer_id")
	var raw_spawn_position: Variant = payload.get("spawn_position")
	var raw_direction: Variant = payload.get("direction")
	var raw_client_cast_id: Variant = payload.get("client_cast_id")

	if not raw_projectile_id is int or raw_projectile_id <= 0:
		return

	if raw_projectile_type != MAGIC_BOLT_PROJECTILE_TYPE:
		return

	if not raw_owner_peer_id is int or raw_owner_peer_id <= 0:
		return

	if not raw_spawn_position is Vector2:
		return

	if not raw_direction is Vector2 or raw_direction.is_zero_approx():
		return
		
	if not raw_client_cast_id is int or raw_client_cast_id < 0:
		return

	var owner_peer_id: int = raw_owner_peer_id
	var client_cast_id: int = raw_client_cast_id
	var projectile_id: int = raw_projectile_id
	
	if visual_projectiles_by_id.has(projectile_id):
		var old_visual: MagicBolt = visual_projectiles_by_id[projectile_id]
		if old_visual != null:
			old_visual.queue_free()

	if owner_peer_id == NetworkManager.get_local_peer_id() and client_cast_id > 0:
		if _confirm_predicted_magic_bolt(client_cast_id, projectile_id, raw_direction):
			return
	
	var visual_bolt: MagicBolt = _create_magic_bolt(projectile_id, raw_spawn_position, raw_direction, false)
	if visual_bolt == null:
		return

	visual_projectiles_by_id[projectile_id] = visual_bolt



func _confirm_predicted_magic_bolt(client_cast_id: int, projectile_id: int, authoritative_direction: Vector2) -> bool:
	if not predicted_bolts_by_client_cast_id.has(client_cast_id):
		return false

	var predicted_bolt: MagicBolt = predicted_bolts_by_client_cast_id[client_cast_id]
	predicted_bolts_by_client_cast_id.erase(client_cast_id)

	if predicted_bolt == null:
		return false

	predicted_bolt.projectile_id = projectile_id
	predicted_bolt.direction = authoritative_direction.normalized()
	visual_projectiles_by_id[projectile_id] = predicted_bolt
	return true



func _handle_projectile_despawn(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	var raw_projectile_id: Variant = payload.get("projectile_id")
	if not raw_projectile_id is int or raw_projectile_id <= 0:
		return

	var projectile_id: int = raw_projectile_id
	if not visual_projectiles_by_id.has(projectile_id):
		return

	var visual_bolt: MagicBolt = visual_projectiles_by_id[projectile_id]
	visual_projectiles_by_id.erase(projectile_id)

	if visual_bolt != null:
		visual_bolt.queue_free()



func _clear_visual_projectiles() -> void:
	for visual_bolt: MagicBolt in visual_projectiles_by_id.values():
		if visual_bolt != null:
			visual_bolt.queue_free()

	visual_projectiles_by_id.clear()
	
	for predicted_bolt: MagicBolt in predicted_bolts_by_client_cast_id.values():
		if predicted_bolt != null:
			predicted_bolt.queue_free()

	predicted_bolts_by_client_cast_id.clear()



func _is_supported_spell(spell_id: String) -> bool:
	return spell_id == MAGIC_BOLT_SPELL_ID
