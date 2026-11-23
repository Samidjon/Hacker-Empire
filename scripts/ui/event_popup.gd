class_name EventPopup
extends Control
## Modal dialog for a world event: the situation, one button per choice,
## then what the choice did. The game is paused while it is open, so an
## event never costs the player time on a contract.

signal closed

@onready var _title_label: Label = %EventTitle
@onready var _description_label: Label = %EventDescription
@onready var _choice_list: VBoxContainer = %EventChoices
@onready var _outcome_label: Label = %EventOutcome
@onready var _continue_button: Button = %EventContinueButton

var _was_paused: bool = false


func _ready() -> void:
	hide()
	_continue_button.pressed.connect(close)
	EventManager.event_resolved.connect(_on_event_resolved)


func is_open() -> bool:
	return visible


func get_choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _choice_list.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func get_outcome_text() -> String:
	return _outcome_label.text


## Shows the event that is waiting in EventManager, if any.
func show_pending_event() -> void:
	var event: Dictionary = EventManager.get_pending_event()
	if event.is_empty():
		return
	_title_label.text = String(event["title"]).to_upper()
	_description_label.text = event["description"]
	_outcome_label.text = ""
	_outcome_label.hide()
	_continue_button.hide()
	for child: Node in _choice_list.get_children():
		_choice_list.remove_child(child)
		child.queue_free()
	var choices: Array = event["choices"]
	for index: int in choices.size():
		var choice: Dictionary = choices[index]
		var button := Button.new()
		var text: String = choice["label"]
		if choice["cost"] > 0:
			text += "   (%s)" % FormatUtils.money(choice["cost"])
		if not String(choice["description"]).is_empty():
			text += "\n%s" % choice["description"]
		if not choice["enabled"]:
			text += "\n%s" % choice["blocker"]
		button.text = text
		button.disabled = not choice["enabled"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(560.0, 0.0)
		button.pressed.connect(EventManager.choose.bind(index))
		_choice_list.add_child(button)
	_choice_list.show()
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		show()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused
	get_viewport().gui_release_focus()
	closed.emit()


func _on_event_resolved(_event_id: String, _choice_index: int, outcome: PackedStringArray) -> void:
	if not visible:
		return
	_choice_list.hide()
	_outcome_label.text = "\n".join(outcome)
	_outcome_label.show()
	_continue_button.show()
	_continue_button.grab_focus()
