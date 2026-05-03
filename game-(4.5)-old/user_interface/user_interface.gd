extends Control





func _on_server_pressed() -> void:
	NetworkManager.start_server()


func _on_client_pressed() -> void:
	NetworkManager.start_client()




func _on_debug_pressed() -> void:
	var world = get_node("/root/World")
	if world.debug_mode:
		world.debug_mode = false
	else:
		world.debug_mode = true
