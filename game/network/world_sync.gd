extends Node
class_name WorldSync


const WORLD_CATCH_UP_BATCH_LIMIT: int = 128


signal client_world_start_requested(start_data: WorldStartData)
signal client_world_ready(peer_id: int, player_save_data: PlayerSaveData)


var active_world: World

var pending_join_player_data: PlayerSaveData
var pending_world_join_data: WorldJoinData

# Host state: one monotonic revision stream for permanent world changes.
var host_world_revision: int = 0
var host_world_change_log: Array[Dictionary] = []
var host_snapshot_revision_by_peer_id: Dictionary[int, int] = {}
var host_sync_target_revision_by_peer_id: Dictionary[int, int] = {}
var host_world_live_peer_ids: Dictionary[int, bool] = {}

# Client state: the revision included by the received snapshot and the latest
# permanent change that was successfully applied to the local world.
var client_snapshot_revision: int = -1
var client_last_applied_world_revision: int = -1


func set_active_world(world: World) -> void:
	if active_world == world:
		return

	_disconnect_from_active_world()
	active_world = world

	if active_world != null:
		active_world.chunk_manager.wall_destroyed.connect(_on_host_wall_destroyed)


func clear_active_world() -> void:
	_disconnect_from_active_world()
	active_world = null


func handle_network_packet(from_peer_id: int, message_type: int, payload: Dictionary) -> bool:
	match message_type:
		NetworkProtocol.MessageType.REQUEST_WORLD_JOIN_DATA:
			if NetworkManager.is_host():
				_handle_world_join_data_request(from_peer_id)
			return true

		NetworkProtocol.MessageType.WORLD_JOIN_DATA:
			if NetworkManager.is_client():
				_handle_world_join_data(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.REQUEST_WORLD_SNAPSHOT:
			if NetworkManager.is_host():
				_handle_world_snapshot_request(from_peer_id)
			return true

		NetworkProtocol.MessageType.WORLD_SNAPSHOT:
			if NetworkManager.is_client():
				_handle_world_snapshot(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.CLIENT_WORLD_LOADED:
			if NetworkManager.is_host():
				_handle_client_world_loaded(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.CLIENT_WORLD_READY:
			if NetworkManager.is_host():
				_handle_client_world_ready(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.WORLD_CATCH_UP:
			if NetworkManager.is_client():
				_handle_world_catch_up(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.WORLD_SYNC_COMPLETE:
			if NetworkManager.is_client():
				_handle_world_sync_complete(from_peer_id, payload)
			return true

		NetworkProtocol.MessageType.WORLD_TILES_CHANGED:
			if NetworkManager.is_client():
				_handle_world_tiles_changed(from_peer_id, payload)
			return true

	return false


func on_host_started() -> void:
	_reset_host_state()


func on_remote_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return

	_cleanup_host_peer_state(peer_id)


func begin_join(address: String, host_port: int, player_data: PlayerSaveData) -> void:
	_reset_client_state()
	pending_join_player_data = player_data

	var join_error: Error = NetworkManager.join_host(address, host_port)

	if join_error != OK:
		pending_join_player_data = null
		print("Joinen van wereld mislukt: %s" % error_string(join_error))


func request_world_join_data() -> void:
	if not NetworkManager.is_client():
		return

	var request_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_WORLD_JOIN_DATA,
		{},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if request_error != OK:
		print("Werelddata aanvragen mislukt: %s" % error_string(request_error))
		return

	print("Client vraagt werelddata op.")


# Called by Game only after the snapshot world finished initializing locally.
func notify_client_world_loaded() -> void:
	if active_world == null or client_snapshot_revision < 0:
		return

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.CLIENT_WORLD_LOADED,
		{
			"snapshot_revision": client_snapshot_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("CLIENT_WORLD_LOADED versturen mislukt: %s" % error_string(send_error))
		return

	print("Client meldt dat snapshot R%d lokaal geladen is." % client_snapshot_revision)


# Called by host-side gameplay code after a permanent world mutation.
func broadcast_tile_changes(tile_changes: Array[WorldTileChange]) -> void:
	if not NetworkManager.is_host():
		return

	if tile_changes.is_empty():
		return

	var serialized_changes: Array[Dictionary] = []

	for tile_change: WorldTileChange in tile_changes:
		serialized_changes.append(tile_change.to_dictionary())

	host_world_revision += 1
	var change_revision: int = host_world_revision
	var logged_batch: Dictionary = {
		"revision": change_revision,
		"changes": serialized_changes.duplicate(true),
	}

	host_world_change_log.append(logged_batch)
	_trim_host_world_change_log()

	for target_peer_id: int in host_world_live_peer_ids.keys():
		_send_live_world_tile_changes(
			target_peer_id,
			change_revision,
			serialized_changes
		)


func _disconnect_from_active_world() -> void:
	if active_world == null:
		return

	if active_world.chunk_manager.wall_destroyed.is_connected(_on_host_wall_destroyed):
		active_world.chunk_manager.wall_destroyed.disconnect(_on_host_wall_destroyed)


func _reset_host_state() -> void:
	host_world_revision = 0
	host_world_change_log.clear()
	host_snapshot_revision_by_peer_id.clear()
	host_sync_target_revision_by_peer_id.clear()
	host_world_live_peer_ids.clear()


func _reset_client_state() -> void:
	pending_join_player_data = null
	pending_world_join_data = null
	client_snapshot_revision = -1
	client_last_applied_world_revision = -1


func _cleanup_host_peer_state(peer_id: int) -> void:
	host_snapshot_revision_by_peer_id.erase(peer_id)
	host_sync_target_revision_by_peer_id.erase(peer_id)
	host_world_live_peer_ids.erase(peer_id)
	_trim_host_world_change_log()


# The temporary log only retains revisions that at least one loading client
# might still need. Live peers receive every later change directly.
func _trim_host_world_change_log() -> void:
	if host_snapshot_revision_by_peer_id.is_empty():
		host_world_change_log.clear()
		return

	var oldest_snapshot_revision: int = host_world_revision

	for snapshot_revision: int in host_snapshot_revision_by_peer_id.values():
		oldest_snapshot_revision = mini(oldest_snapshot_revision, snapshot_revision)

	while not host_world_change_log.is_empty():
		var oldest_batch: Dictionary = host_world_change_log[0]
		var oldest_batch_revision: int = int(oldest_batch.get("revision", -1))

		if oldest_batch_revision > oldest_snapshot_revision:
			break

		host_world_change_log.pop_front()


func _handle_world_join_data_request(from_peer_id: int) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		print("Host heeft geen actieve wereld om te versturen.")
		return

	var join_data: WorldJoinData = WorldJoinData.from_world_save_data(
		active_world.active_world_data
	)

	var send_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_JOIN_DATA,
		{"world": join_data.to_dictionary()},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print("WorldJoinData versturen mislukt: %s" % error_string(send_error))
		return

	print("WorldJoinData verstuurd naar peer %d." % from_peer_id)


func _handle_world_join_data(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	var raw_world_data: Variant = payload.get("world")
	if not raw_world_data is Dictionary:
		return

	var join_data: WorldJoinData = WorldJoinData.from_dictionary(raw_world_data)
	if join_data == null:
		print("Ontvangen WorldJoinData is ongeldig.")
		return

	pending_world_join_data = join_data
	_request_world_snapshot()

	print(
		"Wereld ontvangen: %s | seed: %d | spawn: %s"
		% [join_data.world_name, join_data.world_seed, join_data.spawn_position]
	)


func _request_world_snapshot() -> void:
	var request_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.REQUEST_WORLD_SNAPSHOT,
		{},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if request_error != OK:
		print("Wereldsnapshot aanvragen mislukt: %s" % error_string(request_error))
		return

	print("Client vraagt wereldsnapshot op.")


func _handle_world_snapshot_request(from_peer_id: int) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		print("Host heeft geen actieve wereldsnapshot.")
		return

	var snapshot_revision: int = host_world_revision
	var world_snapshot: Dictionary = active_world.active_world_data.to_dictionary()

	host_snapshot_revision_by_peer_id[from_peer_id] = snapshot_revision
	host_sync_target_revision_by_peer_id.erase(from_peer_id)
	host_world_live_peer_ids.erase(from_peer_id)
	_trim_host_world_change_log()

	var send_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_SNAPSHOT,
		{
			"world_snapshot": world_snapshot,
			"snapshot_revision": snapshot_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		host_snapshot_revision_by_peer_id.erase(from_peer_id)
		_trim_host_world_change_log()
		print("Wereldsnapshot versturen mislukt: %s" % error_string(send_error))
		return

	print(
		"Wereldsnapshot op revisie %d verstuurd naar peer %d."
		% [snapshot_revision, from_peer_id]
	)


func _handle_world_snapshot(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if pending_world_join_data == null:
		print("Wereldsnapshot ontvangen voor WorldJoinData.")
		return

	if pending_join_player_data == null:
		print("Geen speler geselecteerd voor deze join.")
		return

	var raw_snapshot: Variant = payload.get("world_snapshot")
	if not raw_snapshot is Dictionary:
		print("Ontvangen wereldsnapshot is geen Dictionary.")
		return

	var raw_snapshot_revision: Variant = payload.get("snapshot_revision")
	if not raw_snapshot_revision is int or raw_snapshot_revision < 0:
		print("Ontvangen wereldsnapshot heeft geen geldige revisie.")
		return

	if raw_snapshot.get("format_version") != WorldSaveData.FORMAT_VERSION:
		print("Wereldsnapshot heeft een onjuiste save-versie.")
		return

	var snapshot_data: WorldSaveData = WorldSaveData.from_dictionary(raw_snapshot)

	if snapshot_data.world_id.is_empty():
		print("Wereldsnapshot heeft geen world_id.")
		return

	if snapshot_data.world_id != pending_world_join_data.world_id:
		print("Wereldsnapshot hoort niet bij de eerder ontvangen wereldheader.")
		return

	client_snapshot_revision = raw_snapshot_revision
	client_last_applied_world_revision = raw_snapshot_revision

	print(
		"Wereldsnapshot R%d ontvangen: %d gewijzigde muurchunks, %d grondchunks, %d cliffchunks."
		% [
			client_snapshot_revision,
			snapshot_data.modified_wall_ids.size(),
			snapshot_data.modified_ground_ids.size(),
			snapshot_data.modified_cliff_ids.size(),
		]
	)

	var start_data: WorldStartData = WorldStartData.create(
		snapshot_data,
		pending_join_player_data
	)
	client_world_start_requested.emit(start_data)


func _handle_client_world_loaded(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if not host_snapshot_revision_by_peer_id.has(from_peer_id):
		print("Peer %d meldde WORLD_LOADED zonder actief snapshot." % from_peer_id)
		return

	var raw_snapshot_revision: Variant = payload.get("snapshot_revision")
	if not raw_snapshot_revision is int or raw_snapshot_revision < 0:
		print("CLIENT_WORLD_LOADED bevat geen geldige snapshotrevisie.")
		return

	var expected_snapshot_revision: int = host_snapshot_revision_by_peer_id[from_peer_id]
	var received_snapshot_revision: int = raw_snapshot_revision

	if received_snapshot_revision != expected_snapshot_revision:
		print(
			"Peer %d laadde snapshot R%d, maar host verwacht R%d."
			% [from_peer_id, received_snapshot_revision, expected_snapshot_revision]
		)
		return

	var sync_target_revision: int = host_world_revision

	if not _send_world_catch_up(
		from_peer_id,
		expected_snapshot_revision,
		sync_target_revision
	):
		return

	var complete_error: Error = NetworkManager.send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.WORLD_SYNC_COMPLETE,
		{
			"world_revision": sync_target_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if complete_error != OK:
		print("WORLD_SYNC_COMPLETE versturen mislukt: %s" % error_string(complete_error))
		return

	# Later tile changes are sent on this same reliable world channel, so no
	# revision can slip in between the catch-up and the live stream.
	host_sync_target_revision_by_peer_id[from_peer_id] = sync_target_revision
	host_world_live_peer_ids[from_peer_id] = true
	host_snapshot_revision_by_peer_id.erase(from_peer_id)
	_trim_host_world_change_log()

	print(
		"Catch-up R%d..R%d verstuurd naar peer %d."
		% [expected_snapshot_revision + 1, sync_target_revision, from_peer_id]
	)


func _send_world_catch_up(
	target_peer_id: int,
	after_revision: int,
	through_revision: int
) -> bool:
	var packet_batches: Array[Dictionary] = []

	for logged_batch: Dictionary in host_world_change_log:
		var batch_revision: int = int(logged_batch.get("revision", -1))

		if batch_revision <= after_revision or batch_revision > through_revision:
			continue

		packet_batches.append(logged_batch.duplicate(true))

		if packet_batches.size() >= WORLD_CATCH_UP_BATCH_LIMIT:
			if not _send_world_catch_up_packet(target_peer_id, packet_batches):
				return false
			packet_batches.clear()

	if not packet_batches.is_empty():
		if not _send_world_catch_up_packet(target_peer_id, packet_batches):
			return false

	return true


func _send_world_catch_up_packet(
	target_peer_id: int,
	batches: Array[Dictionary]
) -> bool:
	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.WORLD_CATCH_UP,
		{
			"batches": batches,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print("WORLD_CATCH_UP versturen mislukt: %s" % error_string(send_error))
		return false

	return true


func _handle_world_catch_up(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_batches: Variant = payload.get("batches")
	if not raw_batches is Array or raw_batches.is_empty():
		return

	for raw_batch: Variant in raw_batches:
		if not raw_batch is Dictionary:
			print("WORLD_CATCH_UP bevat een ongeldige batch.")
			return

		var batch: Dictionary = raw_batch
		var raw_revision: Variant = batch.get("revision")

		if not raw_revision is int or raw_revision < 0:
			print("WORLD_CATCH_UP bevat een ongeldige revisie.")
			return

		if not _apply_client_world_change_batch(
			raw_revision,
			batch.get("changes")
		):
			return


func _handle_world_sync_complete(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null or client_snapshot_revision < 0:
		return

	var raw_world_revision: Variant = payload.get("world_revision")
	if not raw_world_revision is int or raw_world_revision < 0:
		print("WORLD_SYNC_COMPLETE bevat geen geldige revisie.")
		return

	var sync_revision: int = raw_world_revision

	if sync_revision != client_last_applied_world_revision:
		print(
			"World-sync heeft een revisiegat: client staat op R%d, host eindigt op R%d."
			% [client_last_applied_world_revision, sync_revision]
		)
		return

	_send_client_world_ready()


func _send_client_world_ready() -> void:
	if active_world == null or active_world.local_player_data == null:
		return

	if client_last_applied_world_revision < 0:
		return

	var player_data: PlayerSaveData = active_world.local_player_data

	var send_error: Error = NetworkManager.send_packet(
		MultiplayerPeer.TARGET_PEER_SERVER,
		NetworkProtocol.MessageType.CLIENT_WORLD_READY,
		{
			"player_save": player_data.to_dictionary(),
			"world_revision": client_last_applied_world_revision,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if send_error != OK:
		print("CLIENT_WORLD_READY versturen mislukt: %s" % error_string(send_error))
		return

	print(
		"Client meldt dat wereldrevisie R%d klaar is."
		% client_last_applied_world_revision
	)


func _handle_client_world_ready(from_peer_id: int, payload: Dictionary) -> void:
	if not NetworkManager.is_client_approved(from_peer_id):
		return

	if active_world == null or active_world.active_world_data == null:
		return

	if not host_world_live_peer_ids.has(from_peer_id):
		print("CLIENT_WORLD_READY ontvangen voordat de worldstream live was.")
		return

	if not host_sync_target_revision_by_peer_id.has(from_peer_id):
		print("CLIENT_WORLD_READY ontvangen zonder syncdoel.")
		return

	var raw_world_revision: Variant = payload.get("world_revision")
	if not raw_world_revision is int or raw_world_revision < 0:
		print("CLIENT_WORLD_READY bevat geen geldige wereldrevisie.")
		return

	var expected_world_revision: int = host_sync_target_revision_by_peer_id[from_peer_id]
	var received_world_revision: int = raw_world_revision

	if received_world_revision != expected_world_revision:
		print(
			"Peer %d bevestigde R%d, maar host verwachtte R%d."
			% [from_peer_id, received_world_revision, expected_world_revision]
		)
		return

	var raw_player_save: Variant = payload.get("player_save")
	if not raw_player_save is Dictionary:
		print("CLIENT_WORLD_READY bevat geen PlayerSaveData.")
		return

	var player_save_dictionary: Dictionary = raw_player_save
	if player_save_dictionary.get("format_version") != PlayerSaveData.FORMAT_VERSION:
		print("CLIENT_WORLD_READY bevat een onjuiste PlayerSaveData-versie.")
		return

	var player_save_data: PlayerSaveData = PlayerSaveData.from_dictionary(
		player_save_dictionary
	)
	if player_save_data.character_id.is_empty():
		print("CLIENT_WORLD_READY bevat geen character_id.")
		return

	host_sync_target_revision_by_peer_id.erase(from_peer_id)
	client_world_ready.emit(from_peer_id, player_save_data)


func _on_host_wall_destroyed(tile_position: Vector2i, _destroyed_wall_id: int) -> void:
	if not NetworkManager.is_host():
		return

	var tile_change: WorldTileChange = WorldTileChange.create(
		tile_position,
		Chunk.TileLayer.WALL,
		0
	)
	var tile_changes: Array[WorldTileChange] = [tile_change]

	broadcast_tile_changes(tile_changes)


func _send_live_world_tile_changes(
	target_peer_id: int,
	change_revision: int,
	serialized_changes: Array[Dictionary]
) -> void:
	var send_error: Error = NetworkManager.send_packet(
		target_peer_id,
		NetworkProtocol.MessageType.WORLD_TILES_CHANGED,
		{
			"revision": change_revision,
			"changes": serialized_changes,
		},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_WORLD
	)

	if send_error != OK:
		print(
			"WORLD_TILES_CHANGED R%d versturen mislukt: %s."
			% [change_revision, error_string(send_error)]
		)


func _handle_world_tiles_changed(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if active_world == null:
		return

	var raw_revision: Variant = payload.get("revision")
	if not raw_revision is int or raw_revision < 0:
		print("WORLD_TILES_CHANGED bevat geen geldige revisie.")
		return

	_apply_client_world_change_batch(raw_revision, payload.get("changes"))


func _apply_client_world_change_batch(
	change_revision: int,
	raw_changes: Variant
) -> bool:
	if active_world == null:
		return false

	# Absolute tile state makes duplicate reliable packets harmless.
	if change_revision <= client_last_applied_world_revision:
		return true

	var expected_revision: int = client_last_applied_world_revision + 1
	if change_revision != expected_revision:
		print(
			"World-change revisiegat: verwacht R%d, ontving R%d."
			% [expected_revision, change_revision]
		)
		return false

	if not raw_changes is Array or raw_changes.is_empty():
		print("World-change R%d bevat geen wijzigingen." % change_revision)
		return false

	var tile_changes: Array[WorldTileChange] = []

	for raw_change: Variant in raw_changes:
		if not raw_change is Dictionary:
			return false

		var change_dictionary: Dictionary = raw_change
		var tile_change: WorldTileChange = WorldTileChange.from_dictionary(
			change_dictionary
		)

		if tile_change == null:
			return false

		tile_changes.append(tile_change)

	for tile_change: WorldTileChange in tile_changes:
		var applied: bool = active_world.chunk_manager.apply_world_tile_change(tile_change)

		if not applied:
			print(
				"Niet-ondersteunde world tile change ontvangen voor laag %d."
				% tile_change.layer
			)
			return false

	client_last_applied_world_revision = change_revision
	return true
