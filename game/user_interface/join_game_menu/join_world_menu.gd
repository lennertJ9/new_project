extends Control
class_name JoinWorldScreen

signal world_join_requested(address: String, host_port: int)


@onready var ip_adrress: LineEdit = $IPAdrress
@onready var port: LineEdit = $Port



func _on_button_pressed() -> void:
	var address: String = ip_adrress.text.strip_edges()
	var port_text: String = port.text.strip_edges()
	
	if address.is_empty():
		print("Vul een IP-adres in.")
		return
	
	if not port_text.is_valid_int():
		print("De poort moet een getal zijn.")
		return
	
	var host_port: int = port_text.to_int()
	
	if host_port < 1 or host_port > 65535:
		print("De poort moet tussen 1 en 65535 liggen.")
		return
	
	
	world_join_requested.emit(address, host_port)
