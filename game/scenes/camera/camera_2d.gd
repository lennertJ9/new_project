extends Camera2D


var min_zoom: Vector2 = Vector2(0.1 ,0.1)
var max_zoom: Vector2 = Vector2(3 , 3)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if zoom - Vector2(0.1,0.1) > min_zoom:
				zoom -= Vector2(0.1,0.1)
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if zoom + Vector2(0.1,0.1) < max_zoom:
				zoom += Vector2(0.1,0.1)
