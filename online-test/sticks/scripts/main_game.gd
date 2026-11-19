extends Control

const STICK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/one_stick.png"),
	preload("res://assets/two_stick.png"),
	preload("res://assets/three_stick.png"),
	preload("res://assets/four_stick.png"),
]

var local_player: int = -1
var state: Dictionary = {}
var selected_source: int = 0

var status_label: Label
var turn_label: Label
var player_labels: Array[Label] = []
var hand_values: Array = [[], []]
var source_buttons: Array[Button] = []
var opponent_buttons: Array[Button] = []
var self_hit_buttons: Array[Button] = []
var split_left: SpinBox
var split_right_label: Label
var split_button: Button


func _ready() -> void:
	_build_ui()
	SticksNetwork.peer_joined.connect(_on_peer_joined)
	SticksNetwork.peer_left.connect(_on_peer_left)
	SticksNetwork.server_message.connect(_on_server_message)
	SticksNetwork.client_message.connect(_on_client_message)
	SticksNetwork.client_disconnected.connect(_on_client_disconnected)
	if SticksNetwork.is_host:
		local_player = 0
		state = SticksRules.new_game(SticksNetwork.host_settings)
		status_label.text = "Waiting for the other player to join..."
	else:
		status_label.text = "Connecting to the host..."
	_refresh()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#171c2c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 32)
	outer.add_theme_constant_override("margin_right", 32)
	outer.add_theme_constant_override("margin_top", 24)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	outer.add_child(layout)

	var title := Label.new()
	title.text = "STICKS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var instructions := Label.new()
	instructions.text = "Hit to add your hand's sticks to another live hand. Split or combine, then hit."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(instructions)

	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(turn_label)

	for player in 2:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 28)
		layout.add_child(row)
		var player_label := Label.new()
		player_label.custom_minimum_size.x = 130
		row.add_child(player_label)
		player_labels.append(player_label)
		for hand in 2:
			var hand_box := VBoxContainer.new()
			hand_box.custom_minimum_size = Vector2(110, 125)
			hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(hand_box)
			var side_label := Label.new()
			side_label.text = "LEFT HAND" if hand == 0 else "RIGHT HAND"
			side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hand_box.add_child(side_label)
			var texture := TextureRect.new()
			texture.custom_minimum_size = Vector2(72, 72)
			texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hand_box.add_child(texture)
			var value_label := Label.new()
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hand_box.add_child(value_label)
			hand_values[player].append({"texture": texture, "label": value_label})

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	var source_row := HBoxContainer.new()
	source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(source_row)
	for hand in 2:
		var source_button := Button.new()
		source_button.text = "Attack with left hand" if hand == 0 else "Attack with right hand"
		source_button.toggle_mode = true
		source_button.pressed.connect(_select_source.bind(hand))
		source_row.add_child(source_button)
		source_buttons.append(source_button)

	var target_row := HBoxContainer.new()
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(target_row)
	for hand in 2:
		var target_button := Button.new()
		target_button.text = "Hit opponent's left hand" if hand == 0 else "Hit opponent's right hand"
		target_button.pressed.connect(_hit_opponent.bind(hand))
		target_row.add_child(target_button)
		opponent_buttons.append(target_button)

	var self_row := HBoxContainer.new()
	self_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(self_row)
	for hand in 2:
		var self_button := Button.new()
		self_button.text = "Hit your left hand" if hand == 0 else "Hit your right hand"
		self_button.pressed.connect(_hit_self.bind(hand))
		self_row.add_child(self_button)
		self_hit_buttons.append(self_button)

	var split_row := HBoxContainer.new()
	split_row.alignment = BoxContainer.ALIGNMENT_CENTER
	split_row.add_theme_constant_override("separation", 10)
	actions.add_child(split_row)
	var split_label := Label.new()
	split_label.text = "New left hand:"
	split_row.add_child(split_label)
	split_left = SpinBox.new()
	split_left.min_value = 0
	split_left.max_value = 4
	split_left.step = 1
	split_left.value_changed.connect(_update_split_right)
	split_row.add_child(split_left)
	split_right_label = Label.new()
	split_row.add_child(split_right_label)
	split_button = Button.new()
	split_button.text = "Split / combine"
	split_button.pressed.connect(_split_hands)
	split_row.add_child(split_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(status_label)
	var menu_button := Button.new()
	menu_button.text = "Main menu"
	menu_button.pressed.connect(_return_to_menu)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(menu_button)


func _select_source(hand: int) -> void:
	selected_source = hand
	_refresh()


func _hit_opponent(hand: int) -> void:
	_send_action({"type": "hit", "source": selected_source, "target_player": 1 - local_player, "target_hand": hand})


func _hit_self(hand: int) -> void:
	_send_action({"type": "hit", "source": selected_source, "target_player": local_player, "target_hand": hand})


func _split_hands() -> void:
	_send_action({"type": "split", "left": int(split_left.value)})


func _send_action(action: Dictionary) -> void:
	if local_player < 0 or state.is_empty() or state["turn"] != local_player:
		return
	if SticksNetwork.is_host:
		_apply_host_action(action)
	else:
		SticksNetwork.send_to_server({"type": "action", "action": action})


func _apply_host_action(action: Dictionary) -> void:
	var error: String = SticksRules.apply_action(state, 0, action)
	if not error.is_empty():
		status_label.text = error
		return
	_broadcast_state()


func _on_peer_joined(peer_id: int) -> void:
	if not SticksNetwork.is_host:
		return
	status_label.text = "Player 2 joined."
	_send_state(peer_id)
	_refresh()


func _on_peer_left(_peer_id: int) -> void:
	status_label.text = "Player 2 disconnected."
	_refresh()


func _on_server_message(peer_id: int, message: Dictionary) -> void:
	if not SticksNetwork.is_host or message.get("type", "") != "action":
		return
	var error: String = SticksRules.apply_action(state, 1, message.get("action", {}))
	if not error.is_empty():
		SticksNetwork.send_to_peer(peer_id, {"type": "error", "message": error})
		return
	_broadcast_state()


func _on_client_message(message: Dictionary) -> void:
	match message.get("type", ""):
		"state":
			var received: Variant = message.get("state")
			if received is Dictionary:
				state = received
				local_player = 1
				status_label.text = str(message.get("message", "Game ready."))
				_refresh()
		"error":
			status_label.text = str(message.get("message", "The action was rejected."))


func _on_client_disconnected() -> void:
	status_label.text = "Disconnected from the host."
	state.clear()
	_refresh()


func _broadcast_state() -> void:
	var message := {"type": "state", "state": state, "message": "Game in progress."}
	for peer_id in SticksNetwork.peer_players:
		SticksNetwork.send_to_peer(peer_id, message)
	_refresh()


func _send_state(peer_id: int) -> void:
	SticksNetwork.send_to_peer(peer_id, {"type": "state", "state": state, "message": "Game ready."})


func _update_split_right(_value: float = 0.0) -> void:
	if state.is_empty() or local_player < 0:
		split_right_label.text = "Right hand: -"
		return
	var hands: Array = state["hands"][local_player]
	var right: int = hands[0] + hands[1] - int(split_left.value)
	split_right_label.text = "Right hand: %d" % right


func _refresh() -> void:
	var ready: bool = not state.is_empty() and local_player >= 0
	if not ready:
		turn_label.text = "Waiting for the server..."
		for player in 2:
			player_labels[player].text = "Player %d" % (player + 1)
			for hand in 2:
				hand_values[player][hand]["texture"].texture = null
				hand_values[player][hand]["label"].text = "-"
		_set_actions_enabled(false)
		_update_split_right()
		return

	for player in 2:
		player_labels[player].text = "Player %d%s" % [
			player + 1,
			" (you)" if player == local_player else "",
		]
		for hand in 2:
			var value: int = state["hands"][player][hand]
			var card: Dictionary = hand_values[player][hand]
			card["texture"].texture = STICK_TEXTURES[value - 1] if value > 0 else null
			card["label"].text = "%d sticks" % value if value > 0 else "OUT"

	var winner: int = state["winner"]
	if winner >= 0:
		turn_label.text = "Player %d wins!" % (winner + 1)
	elif state["turn"] == local_player:
		turn_label.text = "Your turn"
	else:
		turn_label.text = "Player %d's turn" % (state["turn"] + 1)

	_refresh_actions()
	_update_split_right()


func _refresh_actions() -> void:
	var opponent_connected: bool = not SticksNetwork.is_host or not SticksNetwork.peer_players.is_empty()
	var is_turn: bool = (
		state["turn"] == local_player
		and state["winner"] < 0
		and opponent_connected
	)
	var own_hands: Array = state["hands"][local_player]
	var opponent_hands: Array = state["hands"][1 - local_player]
	var settings: Dictionary = state["settings"]
	if not opponent_connected and state["winner"] < 0:
		turn_label.text = "Waiting for Player 2 to join..."
	var can_attack: bool = is_turn and own_hands[selected_source] > 0
	for hand in 2:
		source_buttons[hand].disabled = not is_turn or own_hands[hand] == 0
		opponent_buttons[hand].disabled = not can_attack or opponent_hands[hand] == 0
		var self_target_valid: bool = settings["self_hit"] and hand != selected_source
		self_hit_buttons[hand].visible = settings["self_hit"]
		self_hit_buttons[hand].disabled = not can_attack or not self_target_valid or own_hands[hand] == 0
		source_buttons[hand].button_pressed = selected_source == hand

	var total: int = own_hands[0] + own_hands[1]
	var max_left: int = min(4, total)
	split_left.max_value = max_left
	split_left.min_value = max(0, total - 4)
	var right_value: int = total - int(split_left.value)
	var split_possible: bool = (
		int(split_left.value) <= 4
		and right_value >= 0
		and right_value <= 4
		and (int(split_left.value) != own_hands[0] or right_value != own_hands[1])
		and not state["split_used"]
	)
	split_left.editable = is_turn and not state["split_used"] and split_possible_or_any(total, own_hands)
	split_button.disabled = not is_turn or not split_possible


func split_possible_or_any(total: int, hands: Array) -> bool:
	if total <= 0:
		return false
	for left in range(max(0, total - 4), min(4, total) + 1):
		if left != hands[0] or total - left != hands[1]:
			return true
	return false


func _set_actions_enabled(enabled: bool) -> void:
	for button in source_buttons + opponent_buttons + self_hit_buttons:
		button.disabled = not enabled
	split_left.editable = enabled
	split_button.disabled = not enabled


func _return_to_menu() -> void:
	LowLevelNetworkHandler.stop_network()
	SticksNetwork.is_host = false
	get_tree().change_scene_to_file("res://sticks/scenes/main_menu.tscn")
