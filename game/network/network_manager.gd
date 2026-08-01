extends Node


signal host_started
signal client_connected
signal client_connection_failed
signal server_disconnected
signal remote_peer_connected(peer_id: int)
signal remote_peer_disconnected(peer_id: int)

signal packet_received(from_peer_id: int, message_type: int, payload: Dictionary)
signal client_hello_received(peer_id: int)

signal client_session_approved(peer_id: int)
signal session_approved_by_host

signal connection_rejected(reason: int)

const DEFAULT_PORT: int = 25001
const MAX_CLIENTS: int = 4
const ENET_CHANNEL_COUNT: int = 4

@onready var scene_multiplayer: SceneMultiplayer = multiplayer as SceneMultiplayer

var approved_client_peer_ids: Dictionary[int, bool] = {}
var is_approved_by_host: bool = false
var accepting_new_clients: bool = true

enum SessionMode {
	OFFLINE,
	HOST,
	CLIENT,
}


var peer: ENetMultiplayerPeer
var session_mode: SessionMode = SessionMode.OFFLINE


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	if scene_multiplayer == null:
		push_error("De standaard SceneMultiplayer is niet beschikbaar.")
		return
	
	scene_multiplayer.peer_packet.connect(_on_peer_packet)
	packet_received.connect(_on_packet_received)



func send_packet(
	target_peer_id: int, 
	message_type: int, 
	payload: Dictionary,
	transfer_mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE,
	channel: int = NetworkProtocol.CHANNEL_CONTROL
	) -> Error:
	
	if scene_multiplayer == null:
		return ERR_UNAVAILABLE
	
	var packet: Dictionary = {
		"version": NetworkProtocol.VERSION,
		"type": message_type,
		"payload": payload,
	}
	
	var bytes: PackedByteArray = var_to_bytes(packet)
	
	return scene_multiplayer.send_bytes(bytes, target_peer_id, transfer_mode, channel)


# dit onvangt het packet, zet het om van bytes naar een leesbare variable, _on_packet_received word daarna aangeroepen
func _on_peer_packet(from_peer_id: int, bytes: PackedByteArray) -> void:
	var decoded: Variant = bytes_to_var(bytes)

	if not decoded is Dictionary:
		return

	var packet: Dictionary = decoded

	if packet.get("version") != NetworkProtocol.VERSION:
		return

	var raw_message_type: Variant = packet.get("type")
	if not raw_message_type is int:
		return

	var raw_payload: Variant = packet.get("payload")
	if not raw_payload is Dictionary:
		return

	var message_type: int = raw_message_type
	var payload: Dictionary = raw_payload

	var role: String = "host" if is_host() else "client"
	packet_received.emit(from_peer_id, message_type, payload)



func _on_packet_received(from_peer_id: int, message_type: int, payload: Dictionary) -> void:
	match message_type:
		NetworkProtocol.MessageType.HELLO:
			if is_host():
				_handle_hello(from_peer_id, payload)
		NetworkProtocol.MessageType.HELLO_ACCEPTED:
			if is_client():
				_handle_hello_accepted(from_peer_id, payload)
		NetworkProtocol.MessageType.REJECT:
			if is_client():
				_handle_reject(from_peer_id, payload)



func _handle_hello(from_peer_id: int, _payload: Dictionary) -> void:
	if approved_client_peer_ids.has(from_peer_id):
		return

	var rejection_reason: int = validate_client(from_peer_id)

	if rejection_reason != NetworkProtocol.RejectReason.NONE:
		_reject_client(from_peer_id, rejection_reason)
		return

	print("Peer %d heeft HELLO gestuurd." % from_peer_id)
	client_hello_received.emit(from_peer_id)

	var accepted_error: Error = send_packet(
		from_peer_id,
		NetworkProtocol.MessageType.HELLO_ACCEPTED,
		{},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if accepted_error != OK:
		print("HELLO_ACCEPTED kon niet verstuurd worden: %s" % error_string(accepted_error))
		return

	approved_client_peer_ids[from_peer_id] = true
	print("Peer %d is door de host toegelaten." % from_peer_id)
	client_session_approved.emit(from_peer_id)



func _handle_hello_accepted(from_peer_id: int, _payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	if is_approved_by_host:
		return

	is_approved_by_host = true
	print("Host heeft deze sessie toegelaten.")
	session_approved_by_host.emit()



func validate_client(_peer_id: int) -> int:
	if not accepting_new_clients:
		return NetworkProtocol.RejectReason.HOST_NOT_ACCEPTING_NEW_CLIENTS

	if approved_client_peer_ids.size() >= MAX_CLIENTS:
		return NetworkProtocol.RejectReason.SESSION_FULL
	
	return NetworkProtocol.RejectReason.NONE



func is_client_approved(peer_id: int) -> bool:
	if not is_host():
		return false

	return approved_client_peer_ids.has(peer_id)



func start_host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	stop_session()

	var new_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var start_error: Error = new_peer.create_server(port, max_clients, ENET_CHANNEL_COUNT)

	if start_error != OK:
		return start_error

	peer = new_peer
	multiplayer.multiplayer_peer = peer
	session_mode = SessionMode.HOST

	host_started.emit()
	return OK



func join_host(address: String, port: int = DEFAULT_PORT, ) -> Error:
	var clean_address: String = address.strip_edges()
	if clean_address.is_empty():
		return ERR_INVALID_PARAMETER

	stop_session()

	var new_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var connect_error: Error = new_peer.create_client(clean_address, port, ENET_CHANNEL_COUNT)

	if connect_error != OK:
		return connect_error

	peer = new_peer
	multiplayer.multiplayer_peer = peer
	session_mode = SessionMode.CLIENT

	return OK



func stop_session() -> void:
	if peer != null:
		peer.close()

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	approved_client_peer_ids.clear()
	is_approved_by_host = false
	session_mode = SessionMode.OFFLINE



func is_host() -> bool:
	return session_mode == SessionMode.HOST



func is_client() -> bool:
	return session_mode == SessionMode.CLIENT



func _on_peer_connected(peer_id: int) -> void:
	remote_peer_connected.emit(peer_id)



func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		approved_client_peer_ids.erase(peer_id)
		
	remote_peer_disconnected.emit(peer_id)



func _on_connected_to_server() -> void:
	var hello_error: Error = send_packet(MultiplayerPeer.TARGET_PEER_SERVER, 
										NetworkProtocol.MessageType.HELLO, 
										{}, 
										MultiplayerPeer.TRANSFER_MODE_RELIABLE, 
										NetworkProtocol.CHANNEL_CONTROL)

	if hello_error != OK:
		print("HELLO kon niet verstuurd worden: %s" % error_string(hello_error))
		return

	print("HELLO verstuurd naar host.")
	client_connected.emit()



func _on_connection_failed() -> void:
	stop_session()
	client_connection_failed.emit()



func _on_server_disconnected() -> void:
	
	stop_session()
	server_disconnected.emit()





func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed("create_server"):
		var host_error: Error = start_host()

		if host_error != OK:
			print("Host starten mislukt: %s" % error_string(host_error))
			return

		print("Host gestart op poort %d." % DEFAULT_PORT)
	if event.is_action_pressed("disconnect"):
		stop_session()

	elif event.is_action_pressed("join_server"):
		var join_error: Error = join_host("127.0.0.1")

		if join_error != OK:
			print("Verbinden mislukt: %s" % error_string(join_error))
			return

		print("Verbinding met lokale host wordt gemaakt.")



func _reject_client(peer_id: int, reason: int) -> void:
	var reject_error: Error = send_packet(
		peer_id,
		NetworkProtocol.MessageType.REJECT,
		{"reason": reason},
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetworkProtocol.CHANNEL_CONTROL
	)

	if reject_error != OK:
		print("REJECT kon niet verstuurd worden: %s" % error_string(reject_error))
		return

	print("Peer %d is afgewezen." % peer_id)



func _handle_reject(from_peer_id: int, payload: Dictionary) -> void:
	if from_peer_id != MultiplayerPeer.TARGET_PEER_SERVER:
		return

	var raw_reason: Variant = payload.get("reason")
	if not raw_reason is int:
		return

	var reason: int = raw_reason

	print("Host heeft de verbinding afgewezen: %s" % _get_reject_reason_text(reason))

	stop_session()
	connection_rejected.emit(reason)



func _get_reject_reason_text(reason: int) -> String:
	match reason:
		NetworkProtocol.RejectReason.HOST_NOT_ACCEPTING_NEW_CLIENTS:
			return "De host laat momenteel geen nieuwe spelers toe."
		NetworkProtocol.RejectReason.SESSION_FULL:
			return "Session is full."
		_:
			return "Onbekende reden."


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()
