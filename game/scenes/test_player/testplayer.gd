extends CharacterBody2D

var speed = 100


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())



func get_input() -> void:
	var input = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	velocity = input * speed


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	get_input()
	move_and_slide()
