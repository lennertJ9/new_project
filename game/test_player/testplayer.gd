extends CharacterBody2D

var speed = 100

func get_input() -> void:
	var input = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	velocity = input * speed


func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
