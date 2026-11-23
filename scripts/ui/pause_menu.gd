class_name PauseMenu
extends Control
## In-game pause overlay (Esc). Pauses the tree while open.

## Set false while another screen owns the cancel key (e.g. the computer).
var can_open: bool = true

@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %PauseSaveButton
@onready var _menu_button: Button = %SaveAndMenuButton
@onready var _quit_button: Button = %SaveAndQuitButton
@onready var _status_label: Label = %PauseStatusLabel


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(close)
	_save_button.pressed.connect(_on_save_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or GameManager.is_transitioning():
		return
	if not visible and not can_open:
		return # leave the event for whoever is in front
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not can_open:
		return
	_status_label.text = ""
	show()
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	# Otherwise movement keys would keep navigating the hidden buttons.
	get_viewport().gui_release_focus()


func _on_save_pressed() -> void:
	if GameManager.save_game():
		_set_status("Game saved.", UIPalette.ACCENT)
	else:
		_set_status("Save failed. See the log for details.", UIPalette.DANGER)


func _on_menu_pressed() -> void:
	if not GameManager.return_to_main_menu(true):
		_set_status("Save failed - staying in game so progress is not lost.", UIPalette.DANGER)


func _on_quit_pressed() -> void:
	if GameManager.save_game():
		GameManager.quit_game(false)
	else:
		_set_status("Save failed - not quitting so progress is not lost.", UIPalette.DANGER)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(&"font_color", color)
