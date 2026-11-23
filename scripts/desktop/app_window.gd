class_name AppWindow
extends PanelContainer
## A desktop window: title bar, minimise / maximise / close, dragging.
##
## It hosts any Control as its content and knows nothing about what the
## application does. It only reports what the user asked for; the desktop
## decides what closing or minimising means.

signal close_requested
signal minimize_requested

## Part of the title bar that must stay reachable when dragged to an edge.
const MIN_VISIBLE_TITLE: float = 120.0
const TITLE_BAR_HEIGHT: float = 40.0

var app_id: String = ""
## False once the user closed it (a kept-state window stays in the tree, hidden).
var is_open: bool = true

var _content: Control
var _is_dragging: bool = false
var _is_maximized: bool = false
var _restore_rect: Rect2 = Rect2()
## The size the window is meant to have while not maximised.
var _normal_size: Vector2 = Vector2.ZERO

@onready var _title_bar: Control = %TitleBar
@onready var _title_label: Label = %WindowTitleLabel
@onready var _minimize_button: Button = %MinimizeButton
@onready var _maximize_button: Button = %MaximizeButton
@onready var _close_button: Button = %CloseButton
@onready var _content_holder: Control = %ContentHolder


func _ready() -> void:
	_title_bar.gui_input.connect(_on_title_bar_gui_input)
	_minimize_button.pressed.connect(func() -> void: minimize_requested.emit())
	_maximize_button.pressed.connect(toggle_maximized)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	minimum_size_changed.connect(_restore_normal_size)


func set_title(title: String) -> void:
	_title_label.text = title


func get_title() -> String:
	return _title_label.text


func set_content(content: Control) -> void:
	_content = content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_holder.add_child(content)


func get_content() -> Control:
	return _content


## Highlights the title of the window that has focus.
func set_active(is_active: bool) -> void:
	_title_label.add_theme_color_override(
		&"font_color", UIPalette.PRIMARY if is_active else UIPalette.TEXT_DIM
	)


func is_maximized() -> bool:
	return _is_maximized


func toggle_maximized() -> void:
	set_maximized(not _is_maximized)


func set_maximized(value: bool) -> void:
	if value == _is_maximized:
		return
	var area := get_parent() as Control
	if value:
		_restore_rect = Rect2(position, size)
		_is_maximized = true
		_fill_parent()
		if area != null and not area.resized.is_connected(_fill_parent):
			area.resized.connect(_fill_parent)
	else:
		_is_maximized = false
		if area != null and area.resized.is_connected(_fill_parent):
			area.resized.disconnect(_fill_parent)
		position = _restore_rect.position
		size = _restore_rect.size
	_maximize_button.text = "[ ]" if not _is_maximized else "[=]"
	_maximize_button.tooltip_text = "Maximize" if not _is_maximized else "Restore"


## Places the window, keeping it inside the parent area where possible.
func place(new_position: Vector2, new_size: Vector2) -> void:
	var area := get_parent() as Control
	if area != null and area.size.x > 0.0 and area.size.y > 0.0:
		new_size = new_size.min(area.size)
		# A newly placed window starts fully visible, so nothing at its
		# bottom edge (such as an Accept button) opens off screen.
		new_position = new_position.min(area.size - new_size)
	_normal_size = new_size
	size = new_size
	position = _clamp_position(new_position)


## A free-standing Control grows to fit its content's minimum size but never
## shrinks back. Word-wrapped text reports a very tall minimum for a moment
## while it is being laid out, which would leave the window stretched; so
## whenever the minimum changes, the intended size is applied again.
func _restore_normal_size() -> void:
	if _is_maximized:
		_fill_parent()
	elif _normal_size != Vector2.ZERO and size != _normal_size:
		size = _normal_size


func _fill_parent() -> void:
	var area := get_parent() as Control
	if area != null and _is_maximized:
		position = Vector2.ZERO
		size = area.size


func _on_title_bar_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and button.double_click:
			_is_dragging = false
			toggle_maximized()
		else:
			_is_dragging = button.pressed and not _is_maximized
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _is_dragging:
		position = _clamp_position(position + motion.relative)


## Keeps the title bar on screen so a window can never be lost off an edge.
func _clamp_position(wanted: Vector2) -> Vector2:
	var area := get_parent() as Control
	if area == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return wanted
	return Vector2(
		clampf(wanted.x, MIN_VISIBLE_TITLE - size.x, area.size.x - MIN_VISIBLE_TITLE),
		clampf(wanted.y, 0.0, maxf(0.0, area.size.y - TITLE_BAR_HEIGHT))
	)
