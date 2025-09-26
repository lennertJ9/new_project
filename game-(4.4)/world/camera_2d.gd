extends Camera2D


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= 1000 * delta
	if Input.is_action_pressed("ui_right"):
		position.x += 1000 * delta
	if Input.is_action_pressed("ui_up"):
		position.y -= 1000 * delta
	if Input.is_action_pressed("ui_down"):
		position.y += 1000 * delta



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(0.1,0.1)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(0.1,0.1)
			
			
	#if event.is("ui_left"):
		#position.x -= 50
	#if event.is_action("ui_right"):
		#position.x -= -100
	#if event.is_action("ui_up"):
		#position.y -= 100
	#if event.is_action("ui_down"):
		#position.y -= -100
	

	
