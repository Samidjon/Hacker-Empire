class_name MissionPuzzle
extends Control
## Base class of every puzzle screen. A screen shows one PuzzleLogic and
## turns clicks into moves; the rules stay in the logic object.
##
## Whoever hosts the puzzle (MissionRunner) listens to these two signals and
## never needs to know which kind of puzzle it is.

signal solved
signal mistake_made(message: String)

const MONO_FONT: Font = preload("res://resources/themes/mono_font.tres")
const MONO_FONT_SIZE: int = 17

var _logic: PuzzleLogic


## Call once, after the puzzle has been added to the tree.
func setup(logic: PuzzleLogic) -> void:
	_logic = logic
	_build()


func get_logic() -> PuzzleLogic:
	return _logic


## Subclasses create their controls from _logic here.
func _build() -> void:
	pass


## A left-aligned monospace button, used for code and log lines.
func _make_line_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"SmallButton"
	button.add_theme_font_override(&"font", MONO_FONT)
	button.add_theme_font_size_override(&"font_size", MONO_FONT_SIZE)
	button.clip_text = true
	return button
