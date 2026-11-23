class_name WorldHud
extends Control
## Always-visible strip while walking around: who you are, level, money,
## plus Save and Menu buttons. Reads managers; emits button presses.

signal save_pressed
signal menu_pressed

@onready var _alias_label: Label = %HudAliasLabel
@onready var _level_label: Label = %HudLevelLabel
@onready var _money_label: Label = %HudMoneyLabel
@onready var _save_button: Button = %SaveButton
@onready var _menu_button: Button = %MenuButton
@onready var _objectives_label: RichTextLabel = %ObjectivesLabel


func _ready() -> void:
	_save_button.pressed.connect(func() -> void: save_pressed.emit())
	_menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	PlayerManager.profile_changed.connect(_refresh)
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _refresh())
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh())
	StoryManager.objectives_changed.connect(_refresh_objectives)
	_refresh()
	_refresh_objectives()


func get_objectives_text() -> String:
	return _objectives_label.get_parsed_text()


## The current chapter and its objectives, ticked off as they are met.
func _refresh_objectives() -> void:
	_objectives_label.clear()
	if StoryManager.is_story_complete():
		_objectives_label.push_color(UIPalette.ACCENT)
		_objectives_label.add_text("STORY COMPLETE - the empire is yours")
		_objectives_label.pop()
		return
	var chapter: Dictionary = StoryManager.get_current_chapter()
	_objectives_label.push_color(UIPalette.PRIMARY)
	_objectives_label.add_text("CHAPTER %d - %s" % [
		StoryManager.get_chapter_index() + 1, String(chapter.get("title", "")).to_upper()
	])
	_objectives_label.pop()
	for objective: Dictionary in StoryManager.get_objectives():
		_objectives_label.newline()
		_objectives_label.push_color(UIPalette.ACCENT if objective["done"] else UIPalette.TEXT)
		var progress: String = "" if objective["target"] <= 1 else "  (%d/%d)" % [objective["current"], objective["target"]]
		_objectives_label.add_text("%s %s%s" % ["[x]" if objective["done"] else "[ ]", objective["text"], progress])
		_objectives_label.pop()


func _refresh() -> void:
	_alias_label.text = PlayerManager.hacker_alias
	_level_label.text = "LV %d  %s" % [
		ProgressionManager.level, ProgressionManager.get_rank_name().to_upper()
	]
	_money_label.text = FormatUtils.money(EconomyManager.money)
