class_name ConfirmPopup
extends Control
## Modal yes/no prompt. Call ask() with the action to run on confirmation.

signal confirmed
signal cancelled

var _on_confirm: Callable = Callable()

@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	hide()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func ask(message: String, confirm_text: String, on_confirm: Callable) -> void:
	_message_label.text = message
	_confirm_button.text = confirm_text
	_on_confirm = on_confirm
	show()
	_cancel_button.grab_focus()


func _on_confirm_pressed() -> void:
	hide()
	var action: Callable = _on_confirm
	_on_confirm = Callable()
	confirmed.emit()
	if action.is_valid():
		action.call()


func _on_cancel_pressed() -> void:
	hide()
	_on_confirm = Callable()
	cancelled.emit()
