extends MissionPuzzle
## Screen for MatchPuzzleLogic: pick the candidate identical to the target.

var _buttons: Array[Button] = []

@onready var _round_label: Label = %MatchRound
@onready var _target_label: Label = %MatchTarget
@onready var _option_list: VBoxContainer = %MatchOptions


func _ready() -> void:
	_target_label.add_theme_font_override(&"font", MONO_FONT)


func _build() -> void:
	_show_round()


## Picks the candidate at `index`, exactly as clicking its button does.
func pick(index: int) -> void:
	var logic := _logic as MatchPuzzleLogic
	if index < 0 or index >= _buttons.size() or logic.is_solved() or _buttons[index].disabled:
		return
	if not logic.try_pick(index):
		_buttons[index].disabled = true # a ruled-out candidate cannot be picked again
		mistake_made.emit("That one differs from the target.")
		return
	if logic.is_solved():
		for button: Button in _buttons:
			button.disabled = true
		solved.emit()
	else:
		_show_round()


func is_option_ruled_out(index: int) -> bool:
	return index >= 0 and index < _buttons.size() and _buttons[index].disabled


func _show_round() -> void:
	var logic := _logic as MatchPuzzleLogic
	_round_label.text = "ROUND %d OF %d  -  TARGET" % [logic.get_round() + 1, logic.get_round_count()]
	_target_label.text = logic.get_target()
	for button: Button in _buttons:
		_option_list.remove_child(button)
		button.queue_free()
	_buttons.clear()
	var options: PackedStringArray = logic.get_options()
	for index: int in options.size():
		var button: Button = _make_line_button(options[index])
		button.pressed.connect(pick.bind(index))
		_option_list.add_child(button)
		_buttons.append(button)
