class_name PlayerSelectionScreen
extends Control

signal player_selected(player_data: PlayerSaveData)
signal back_requested

@onready var player_list: VBoxContainer = $CenterContainer/Content/PlayerScroll/PlayerList
@onready var player_name_input: LineEdit = $CenterContainer/Content/PlayerNameInput
@onready var create_player_button: Button = $CenterContainer/Content/CreatePlayerButton
@onready var back_button: Button = $CenterContainer/Content/BackButton


func _ready() -> void:
	create_player_button.pressed.connect(_on_create_player_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	refresh_players()


func refresh_players() -> void:
	for child: Node in player_list.get_children():
		child.queue_free()

	var saved_players: Array[PlayerSaveData] = SaveService.get_saved_players()

	for player_data: PlayerSaveData in saved_players:
		var player_button: Button = Button.new()
		player_button.custom_minimum_size = Vector2(0.0, 36.0)
		player_button.text = player_data.character_name
		player_button.pressed.connect(_on_player_button_pressed.bind(player_data))

		player_list.add_child(player_button)


func _on_create_player_button_pressed() -> void:
	var player_data: PlayerSaveData = SaveService.create_and_save_new_player(
		player_name_input.text
	)

	if player_data == null:
		return

	player_selected.emit(player_data)


func _on_player_button_pressed(player_data: PlayerSaveData) -> void:
	player_selected.emit(player_data)


func _on_back_button_pressed() -> void:
	back_requested.emit()
