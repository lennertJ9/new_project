extends Camera2D

var speed = 300
@export var player: Node2D


func _ready() -> void:
	set_process(false)
	player = get_tree().get_first_node_in_group("player")
	set_process(true)


func _process(delta: float) -> void:
	if player:
		
		position = player.global_position



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
	

	
