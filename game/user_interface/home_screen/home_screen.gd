class_name HomeScreen
extends Control

signal start_game_requested
signal join_game_requested
signal settings_requested


@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var join_game_button: Button = $VBoxContainer/JoinGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton


func _ready() -> void:
	start_game_button.pressed.connect(_on_start_game_button_pressed)
	join_game_button.pressed.connect(_on_join_game_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)



func _on_start_game_button_pressed() -> void:
	start_game_requested.emit()


func _on_join_game_button_pressed() -> void:
	join_game_requested.emit()


func _on_settings_button_pressed() -> void:
	settings_requested.emit()
