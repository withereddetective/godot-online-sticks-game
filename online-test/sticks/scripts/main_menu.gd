extends Control

@onready var settings_exact_five: CheckButton = $CenterContainer/VBoxContainer/SettingsButton1
@onready var settings_split_turn: CheckButton = $CenterContainer/VBoxContainer/SettingsButton2
@onready var settings_self_hit: CheckButton = $CenterContainer/VBoxContainer/SettingsButton3
@onready var address_input: LineEdit = $CenterContainer/VBoxContainer/AddressInput
@onready var port_input: SpinBox = $CenterContainer/VBoxContainer/PortInput
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_host_pressed)
	$CenterContainer/VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)


func _on_host_pressed() -> void:
	if not _valid_port():
		return
	var settings: Dictionary = {
		"exact_five": settings_exact_five.button_pressed,
		"split_is_turn": settings_split_turn.button_pressed,
		"self_hit": settings_self_hit.button_pressed,
	}
	if not SticksNetwork.start_host(int(port_input.value), settings):
		status_label.text = "Could not start the server. Check the port and try again."
		return
	get_tree().change_scene_to_file("res://sticks/scenes/main_game.tscn")


func _on_join_pressed() -> void:
	if not _valid_port():
		return
	if address_input.text.strip_edges().is_empty():
		status_label.text = "Enter the host's IP address."
		return
	if not SticksNetwork.start_client(address_input.text.strip_edges(), int(port_input.value)):
		status_label.text = "Could not start the client."
		return
	get_tree().change_scene_to_file("res://sticks/scenes/main_game.tscn")


func _valid_port() -> bool:
	if port_input.value < 1 or port_input.value > 65535:
		status_label.text = "Port must be between 1 and 65535."
		return false
	return true
