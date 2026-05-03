extends Camera2D



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(0.1,0.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(0.1,0.1)
