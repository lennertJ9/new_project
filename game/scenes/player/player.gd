extends CharacterBody2D

var speed = 150
var input: Vector2
var last_input: Vector2

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	print("d")



func _process(delta: float) -> void:
	input = Input.get_vector("LEFT","RIGHT","UP","DOWN")
	
	
	velocity = input * speed
	
	move_and_slide()
	
	if input != Vector2.ZERO:
		last_input = input
		if input.x != 0:
			if input.x > 0:
				animation_player.play("RUN_RIGHT")
			else:
				animation_player.play("RUN_LEFT")
		else:
			if input.y > 0:
				animation_player.play("RUN_DOWN")
			else:
				animation_player.play("RUN_UP")
	else:
		if last_input.x != 0:
			if last_input.x > 0:
				animation_player.play("IDLE_RIGHT")
			else:
				animation_player.play("IDLE_LEFT")
		else:
			if last_input.y > 0:
				animation_player.play("IDLE_DOWN")
			else:
				animation_player.play("IDLE_UP")
