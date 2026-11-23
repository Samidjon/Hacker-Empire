extends MissionPuzzle
## Screen for SequencePuzzleLogic: click the entries in ascending order.

const DONE_PREFIX: String = "[ok]  "

var _buttons: Array[Button] = []

@onready var _item_list: VBoxContainer = %SequenceItems
@onready var _progress_label: Label = %SequenceProgress


func _build() -> void:
	var logic := _logic as SequencePuzzleLogic
	var labels: PackedStringArray = logic.get_labels()
	for index: int in labels.size():
		var button: Button = _make_line_button(labels[index])
		button.pressed.connect(pick.bind(index))
		_item_list.add_child(button)
		_buttons.append(button)
	_refresh_progress()


## Picks the entry at `index`, exactly as clicking its button does.
func pick(index: int) -> void:
	var logic := _logic as SequencePuzzleLogic
	if index < 0 or index >= _buttons.size() or logic.is_solved() or logic.is_picked(index):
		return
	if not logic.try_pick(index):
		mistake_made.emit("That entry is not the next one in order.")
		return
	_buttons[index].disabled = true
	_buttons[index].text = DONE_PREFIX + _buttons[index].text
	_refresh_progress()
	if logic.is_solved():
		solved.emit()


func _refresh_progress() -> void:
	var logic := _logic as SequencePuzzleLogic
	var done: int = 0
	for index: int in logic.get_item_count():
		if logic.is_picked(index):
			done += 1
	_progress_label.text = "%d of %d placed" % [done, logic.get_item_count()]
