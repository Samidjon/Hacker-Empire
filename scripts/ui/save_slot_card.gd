class_name SaveSlotCard
extends PanelContainer
## One row in the save-slot list. Shows the slot's summary and emits the
## player's choice; it performs no saving or loading itself.

signal selected(slot: int)
signal delete_requested(slot: int)

var _slot: int = -1

@onready var _title_label: Label = %TitleLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _select_button: Button = %SelectButton
@onready var _delete_button: Button = %DeleteButton


func _ready() -> void:
	_select_button.pressed.connect(func() -> void: selected.emit(_slot))
	_delete_button.pressed.connect(func() -> void: delete_requested.emit(_slot))


## `for_new_game` switches between "start here" and "load" behaviour.
## Must be called after the card has entered the tree.
func setup(info: SaveSlotInfo, for_new_game: bool) -> void:
	_slot = info.slot
	_title_label.text = "SLOT %d" % info.slot
	_delete_button.visible = not info.is_empty()
	_detail_label.remove_theme_color_override(&"font_color")

	match info.status:
		SaveSlotInfo.Status.EMPTY:
			_detail_label.text = "Empty"
		SaveSlotInfo.Status.VALID:
			_detail_label.text = _describe(info)
		SaveSlotInfo.Status.RECOVERED_FROM_BACKUP:
			_detail_label.text = _describe(info) + "\nMain file damaged - restored from backup."
			_detail_label.add_theme_color_override(&"font_color", UIPalette.WARNING)
		SaveSlotInfo.Status.CORRUPTED:
			_detail_label.text = "Corrupted save - cannot be loaded.\n%s" % info.error
			_detail_label.add_theme_color_override(&"font_color", UIPalette.DANGER)

	if for_new_game:
		_select_button.text = "Start Here" if info.is_empty() else "Overwrite"
		_select_button.disabled = false
	else:
		_select_button.text = "Load"
		_select_button.disabled = not info.is_loadable()


func get_slot() -> int:
	return _slot


func focus_select_button() -> void:
	if not _select_button.disabled:
		_select_button.grab_focus()


func _describe(info: SaveSlotInfo) -> String:
	var summary: Dictionary = info.summary
	return "%s  |  Lv %d %s  |  %s  |  %s\nSaved %s" % [
		SaveDataReader.get_string(summary, "alias", "Unknown"),
		SaveDataReader.get_int(summary, "level", 1),
		SaveDataReader.get_string(summary, "rank"),
		FormatUtils.money(SaveDataReader.get_int(summary, "money")),
		FormatUtils.duration(SaveDataReader.get_float(summary, "playtime_seconds")),
		FormatUtils.local_timestamp(info.saved_at_unix),
	]
