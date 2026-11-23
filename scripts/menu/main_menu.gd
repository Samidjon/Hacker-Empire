extends Control
## Main menu: continue, new game (slot + alias), load game, quit.
## All real work is delegated to GameManager and SaveManager.

enum SlotMode { NEW_GAME, LOAD_GAME }

const SLOT_CARD_SCENE: PackedScene = preload("res://scenes/ui/SaveSlotCard.tscn")
const NO_SLOT: int = -1

var _slot_mode: SlotMode = SlotMode.NEW_GAME
var _new_game_slot: int = NO_SLOT

@onready var _main_panel: Control = %MainPanel
@onready var _slot_panel: Control = %SlotPanel
@onready var _new_game_panel: Control = %NewGamePanel
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _quit_button: Button = %QuitButton
@onready var _slot_title_label: Label = %SlotTitleLabel
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _slot_back_button: Button = %SlotBackButton
@onready var _new_game_slot_label: Label = %NewGameSlotLabel
@onready var _alias_edit: LineEdit = %AliasEdit
@onready var _alias_error_label: Label = %AliasErrorLabel
@onready var _new_game_back_button: Button = %NewGameBackButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel
@onready var _confirm_popup: ConfirmPopup = %ConfirmPopup


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_show_slots.bind(SlotMode.NEW_GAME))
	_load_game_button.pressed.connect(_show_slots.bind(SlotMode.LOAD_GAME))
	_quit_button.pressed.connect(func() -> void: GameManager.quit_game(false))
	_slot_back_button.pressed.connect(_show_main)
	_new_game_back_button.pressed.connect(_show_slots.bind(SlotMode.NEW_GAME))
	_start_button.pressed.connect(_on_start_pressed)
	_alias_edit.text_submitted.connect(func(_text: String) -> void: _on_start_pressed())
	_alias_edit.text_changed.connect(func(_text: String) -> void: _alias_error_label.text = "")
	SaveManager.load_failed.connect(_on_load_failed)
	SaveManager.save_failed.connect(_on_save_failed)

	_alias_edit.max_length = PlayerManager.CONFIG.max_alias_length
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _new_game_panel.visible:
		_show_slots(SlotMode.NEW_GAME)
		get_viewport().set_input_as_handled()
	elif _slot_panel.visible:
		_show_main()
		get_viewport().set_input_as_handled()


# --- Pages ------------------------------------------------------------------

func _show_main() -> void:
	_main_panel.show()
	_slot_panel.hide()
	_new_game_panel.hide()
	_continue_button.disabled = SaveManager.get_most_recent_slot() == NO_SLOT
	_load_game_button.disabled = not SaveManager.has_any_save()
	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()


func _show_slots(mode: SlotMode) -> void:
	_slot_mode = mode
	_status_label.text = ""
	_main_panel.hide()
	_new_game_panel.hide()
	_slot_panel.show()
	_slot_title_label.text = (
		"NEW GAME - CHOOSE A SLOT" if mode == SlotMode.NEW_GAME else "LOAD GAME"
	)
	_rebuild_slot_list()
	_slot_back_button.grab_focus()


func _show_new_game_form(slot: int) -> void:
	_new_game_slot = slot
	_slot_panel.hide()
	_new_game_panel.show()
	_new_game_slot_label.text = "SLOT %d" % slot
	_alias_error_label.text = ""
	_alias_edit.grab_focus()


func _rebuild_slot_list() -> void:
	for child: Node in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	for info: SaveSlotInfo in SaveManager.get_all_slot_infos():
		var card: SaveSlotCard = SLOT_CARD_SCENE.instantiate()
		_slot_list.add_child(card)
		card.setup(info, _slot_mode == SlotMode.NEW_GAME)
		card.selected.connect(_on_slot_selected)
		card.delete_requested.connect(_on_slot_delete_requested)


# --- Actions ----------------------------------------------------------------

func _on_continue_pressed() -> void:
	var slot: int = SaveManager.get_most_recent_slot()
	if slot != NO_SLOT:
		GameManager.load_game(slot)


func _on_slot_selected(slot: int) -> void:
	if _slot_mode == SlotMode.LOAD_GAME:
		GameManager.load_game(slot)
		return
	if SaveManager.get_slot_info(slot).is_empty():
		_show_new_game_form(slot)
	else:
		_confirm_popup.ask(
			"Slot %d already contains a save.\nStarting a new game here will overwrite it." % slot,
			"Overwrite",
			_show_new_game_form.bind(slot)
		)


func _on_slot_delete_requested(slot: int) -> void:
	_confirm_popup.ask(
		"Permanently delete the save in slot %d?\nThis cannot be undone." % slot,
		"Delete",
		_delete_slot.bind(slot)
	)


func _delete_slot(slot: int) -> void:
	if not SaveManager.delete_slot(slot):
		_status_label.text = "Could not delete slot %d." % slot
	if _slot_mode == SlotMode.LOAD_GAME and not SaveManager.has_any_save():
		_show_main()
	else:
		_rebuild_slot_list()


func _on_start_pressed() -> void:
	var entered_alias: String = _alias_edit.text.strip_edges()
	var alias_error: String = PlayerManager.validate_alias(entered_alias)
	if not alias_error.is_empty():
		_alias_error_label.text = alias_error
		return
	if not GameManager.start_new_game(_new_game_slot, entered_alias):
		if _alias_error_label.text.is_empty():
			_alias_error_label.text = "Could not start a new game."


func _on_load_failed(_slot: int, reason: String) -> void:
	_status_label.text = "Load failed: %s" % reason


func _on_save_failed(_slot: int, reason: String) -> void:
	_alias_error_label.text = "Could not create the save: %s" % reason
