class_name AppIcon
extends Button
## Launcher entry for one application. Apps that are not installed are shown
## disabled with the reason as a tooltip.

signal activated(app_id: String)

var _app_id: String = ""

@onready var _badge_label: Label = %BadgeLabel


func _ready() -> void:
	pressed.connect(func() -> void: activated.emit(_app_id))
	set_badge(0)


## Must be called after the icon has entered the tree.
func setup(definition: AppDefinition) -> void:
	_app_id = definition.id
	text = "%s\n%s" % [definition.glyph, definition.title]
	disabled = not definition.is_available()
	tooltip_text = "Open %s" % definition.title if definition.is_available() else definition.locked_note


func get_app_id() -> String:
	return _app_id


## Shows a counter in the corner, e.g. unread mail. Zero hides it.
func set_badge(count: int) -> void:
	_badge_label.visible = count > 0
	_badge_label.text = str(count)


func get_badge() -> int:
	return int(_badge_label.text) if _badge_label.visible else 0
