extends Control





func _on_server_pressed() -> void:
	NetworkManager.start_server()


func _on_client_pressed() -> void:
	NetworkManager.start_client()
