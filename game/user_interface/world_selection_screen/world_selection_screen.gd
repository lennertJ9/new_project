class_name WorldSelectionScreen
extends Control

signal world_selected(world_data: WorldSaveData)
signal back_requested

@onready var world_list: VBoxContainer = $CenterContainer/Content/WorldScroll/WorldList
@onready var world_name_input: LineEdit = $CenterContainer/Content/WorldNameInput
@onready var create_world_button: Button = $CenterContainer/Content/CreateWorldButton
@onready var back_button: Button = $CenterContainer/Content/BackButton


func _ready() -> void:
	create_world_button.pressed.connect(_on_create_world_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	refresh_worlds()


func refresh_worlds() -> void:
	for child: Node in world_list.get_children():
		child.queue_free()

	var saved_worlds: Array[WorldSaveData] = SaveService.get_saved_worlds()
	print(saved_worlds)
	for world_data: WorldSaveData in saved_worlds:
		var world_button: Button = Button.new()
		world_button.custom_minimum_size = Vector2(0.0, 36.0)
		world_button.text = world_data.world_name
		world_button.pressed.connect(_on_world_button_pressed.bind(world_data))

		world_list.add_child(world_button)


func _on_create_world_button_pressed() -> void:
	var new_world_seed: int = randi()
	var world_data: WorldSaveData = SaveService.create_and_save_new_world(
		new_world_seed,
		world_name_input.text
	)

	if world_data == null:
		return

	world_selected.emit(world_data)


func _on_world_button_pressed(world_data: WorldSaveData) -> void:
	world_selected.emit(world_data)


func _on_back_button_pressed() -> void:
	back_requested.emit()
