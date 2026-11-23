class_name InteractionPrompt
extends Control
## "[E] Use Computer" hint shown while something is in reach.

## Key name shown in the prompt. Matches the "interact" input action.
@export var key_label: String = "E"

@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel


func _ready() -> void:
	_key_label.text = key_label
	set_prompt("")


## An empty string hides the prompt.
func set_prompt(prompt_text: String) -> void:
	_action_label.text = prompt_text
	visible = not prompt_text.is_empty()


func get_prompt() -> String:
	return _action_label.text if visible else ""
