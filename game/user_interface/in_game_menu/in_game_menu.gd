extends Control


signal multiplayer_requested(enabled: bool)

@onready var multiplayer_setting_container: HBoxContainer = $MultiplayerSettingContainer
@onready var check_button: CheckButton = $MultiplayerSettingContainer/CheckButton


@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var settings_button: Button = $MenuContainer/SettingsButton
@onready var quit_button: Button = $MenuContainer/QuitButton


func _ready() -> void:
	multiplayer_setting_container.hide()
	if NetworkManager.is_host():
		multiplayer_setting_container.show()



func _on_check_button_toggled(toggled_on: bool) -> void:
	multiplayer_requested.emit(toggled_on)



# alleen zichtbaar als de instantie geen client is
func _on_visibility_changed() -> void:
	if is_node_ready():
		if visible and not NetworkManager.is_client():
				multiplayer_setting_container.show()
