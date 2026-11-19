class_name SticksRules
extends RefCounted


static func new_game(settings: Dictionary) -> Dictionary:
	return {
		"hands": [[1, 1], [1, 1]],
		"turn": 0,
		"winner": -1,
		"split_used": false,
		"settings": settings.duplicate(true),
	}


static func apply_action(state: Dictionary, player: int, action: Dictionary) -> String:
	if state.is_empty() or state["winner"] != -1:
		return "The game is already over."
	if player != state["turn"]:
		return "It is not your turn."

	match action.get("type", ""):
		"hit":
			return _apply_hit(state, player, action)
		"split":
			return _apply_split(state, player, action)
		_:
			return "Unknown action."


static func _apply_hit(state: Dictionary, player: int, action: Dictionary) -> String:
	var hands: Array = state["hands"]
	var source: int = int(action.get("source", -1))
	var target_player: int = int(action.get("target_player", -1))
	var target_hand: int = int(action.get("target_hand", -1))
	if source < 0 or source > 1 or target_hand < 0 or target_hand > 1:
		return "Choose valid hands."
	if hands[player][source] == 0:
		return "A dead hand cannot attack."
	if target_player != 1 - player and target_player != player:
		return "Choose a valid target."
	if target_player == player:
		if not state["settings"]["self_hit"] or target_hand == source:
			return "You cannot attack that hand."
	if hands[target_player][target_hand] == 0:
		return "A dead hand cannot be attacked."

	var value: int = hands[target_player][target_hand] + hands[player][source]
	if state["settings"]["exact_five"]:
		value = 0 if value == 5 else value % 5
	else:
		value = 0 if value >= 5 else value
	hands[target_player][target_hand] = value
	return _finish_turn(state, player)


static func _apply_split(state: Dictionary, player: int, action: Dictionary) -> String:
	if state["split_used"]:
		return "You have already split this turn."
	var hands: Array = state["hands"]
	var total: int = hands[player][0] + hands[player][1]
	var left: int = int(action.get("left", -1))
	var right: int = total - left
	if left < 0 or left > 4 or right < 0 or right > 4:
		return "The new hands must each have between zero and four sticks."
	if left == hands[player][0] and right == hands[player][1]:
		return "Choose a different combination of hands."

	hands[player] = [left, right]
	if state["settings"]["split_is_turn"]:
		return _finish_turn(state, player)
	state["split_used"] = true
	return ""


static func _finish_turn(state: Dictionary, player: int) -> String:
	var opponent: int = 1 - player
	var hands: Array = state["hands"]
	if hands[player][0] == 0 and hands[player][1] == 0:
		state["winner"] = opponent
	elif hands[opponent][0] == 0 and hands[opponent][1] == 0:
		state["winner"] = player
	else:
		state["turn"] = opponent
	state["split_used"] = false
	return ""
