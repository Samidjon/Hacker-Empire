class_name StatCard
extends PanelContainer
## A titled value tile, e.g. "BALANCE / $1,500".

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_title_label.text = title

@onready var _title_label: Label = %TitleLabel
@onready var _value_label: Label = %ValueLabel


func _ready() -> void:
	_title_label.text = title


func set_value(text: String, color: Color = UIPalette.TEXT) -> void:
	_value_label.text = text
	_value_label.add_theme_color_override(&"font_color", color)


func get_value_text() -> String:
	return _value_label.text
