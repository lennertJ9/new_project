extends CharacterBody2D

var speed = 100
@export var camera_scene: PackedScene

# alleen uitvoeren op de client
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	if NetworkManager.is_server:
		return
	
	if name.to_int() ==  multiplayer.get_unique_id():
		set_multiplayer_authority(name.to_int())
		add_child(camera_scene.instantiate())
		ChunkManager.player = self
		ChunkManager.set_process(true)
	
	print("unique id? ", multiplayer.get_unique_id())
	#print("is server: ",NetworkManager.is_server, " node: ", self, "authority: ", get_multiplayer_authority())


func get_input() -> void:
	var input = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	velocity = input * speed


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	get_input()
	move_and_slide()
