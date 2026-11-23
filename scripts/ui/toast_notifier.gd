class_name ToastNotifier
extends Control
## Short-lived messages stacked in the top-right corner.

const DISPLAY_SECONDS: float = 2.5
const FADE_SECONDS: float = 0.4
const MIN_TEXT_WIDTH: float = 340.0
## Older toasts are dropped so a burst of events cannot cover the screen.
const MAX_VISIBLE: int = 4

var _total_shown: int = 0

@onready var _toast_list: VBoxContainer = %ToastList


func show_toast(
	message: String, color: Color = UIPalette.PRIMARY, display_seconds: float = DISPLAY_SECONDS
) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = MIN_TEXT_WIDTH
	label.add_theme_color_override(&"font_color", color)
	panel.add_child(label)
	_toast_list.add_child(panel)
	_total_shown += 1
	while _toast_list.get_child_count() > MAX_VISIBLE:
		var oldest: Node = _toast_list.get_child(0)
		_toast_list.remove_child(oldest)
		oldest.queue_free()

	var tween: Tween = panel.create_tween()
	tween.tween_interval(maxf(0.1, display_seconds))
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(panel.queue_free)


## How many toasts have been shown since this notifier was created.
func get_total_shown() -> int:
	return _total_shown


## How many toasts are on screen right now.
func get_toast_count() -> int:
	return _toast_list.get_child_count()
