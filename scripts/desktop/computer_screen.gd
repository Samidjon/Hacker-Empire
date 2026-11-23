class_name ComputerScreen
extends Control
## Full-screen view shown while the player sits at the computer. It hosts
## the HackerDesktop and handles sitting down and getting up; the desktop
## itself keeps its windows between visits for the rest of the session.

signal opened
signal closed

@onready var _desktop: HackerDesktop = %Desktop


func _ready() -> void:
	hide()
	_desktop.log_off_requested.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func get_desktop() -> HackerDesktop:
	return _desktop


func open() -> void:
	if visible:
		return
	show()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	# Otherwise movement keys would keep going to a hidden text field or button.
	get_viewport().gui_release_focus()
	closed.emit()


func is_open() -> bool:
	return visible
