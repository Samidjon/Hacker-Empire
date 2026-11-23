extends MissionPuzzle
## Screen for SpotPuzzleLogic: toggle the lines that are problems, then submit.

var _buttons: Array[Button] = []

@onready var _line_list: VBoxContainer = %SpotLines
@onready var _counter_label: Label = %SpotCounter
@onready var _submit_button: Button = %SpotSubmitButton


func _ready() -> void:
	_submit_button.pressed.connect(submit)


func _build() -> void:
	for text: String in (_logic as SpotPuzzleLogic).get_lines():
		var button: Button = _make_line_button(text)
		button.toggle_mode = true
		button.toggled.connect(func(_is_pressed: bool) -> void: _refresh_counter())
		_line_list.add_child(button)
		_buttons.append(button)
	_refresh_counter()


## Selects or deselects the line at `index`, exactly as clicking it does.
func toggle(index: int) -> void:
	if index >= 0 and index < _buttons.size() and not _logic.is_solved():
		_buttons[index].button_pressed = not _buttons[index].button_pressed


func get_selected() -> Array[int]:
	var selected: Array[int] = []
	for index: int in _buttons.size():
		if _buttons[index].button_pressed:
			selected.append(index)
	return selected


## Submits the current selection, exactly as the Submit button does.
func submit() -> void:
	var logic := _logic as SpotPuzzleLogic
	if logic.is_solved():
		return
	if logic.submit(get_selected()):
		_submit_button.disabled = true
		for button: Button in _buttons:
			button.disabled = true
		solved.emit()
	else:
		mistake_made.emit(logic.last_feedback)


func _refresh_counter() -> void:
	_counter_label.text = "%d selected  -  %d problem(s) to find" % [
		get_selected().size(), (_logic as SpotPuzzleLogic).get_anomaly_count()
	]
