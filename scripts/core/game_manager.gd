extends Node
## GameManager (autoload)
##
## High-level game state and scene transitions: starting, loading, saving and
## leaving a session. Gameplay rules live in the other managers.

signal state_changed(new_state: State)
signal scene_transition_finished(scene_path: String)

enum State { MAIN_MENU, IN_GAME }

const FADE_SECONDS: float = 0.25
const FADE_LAYER_INDEX: int = 100

var state: State = State.MAIN_MENU

var _is_transitioning: bool = false
var _fade_rect: ColorRect


func _ready() -> void:
	# Keeps transitions and the quit handler working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Closing the window is routed through quit_game() so progress is saved.
	get_tree().auto_accept_quit = false
	SaveManager.set_summary_provider(_build_save_summary)
	_create_fade_layer()


func _process(delta: float) -> void:
	if state == State.IN_GAME and not get_tree().paused and not _is_transitioning:
		PlayerManager.add_playtime(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game(true)


func is_in_game() -> bool:
	return state == State.IN_GAME


func is_transitioning() -> bool:
	return _is_transitioning


# --- Session flow -----------------------------------------------------------

## Creates a fresh game in `slot` and enters it. Returns false when the alias
## is invalid or the initial save cannot be written.
func start_new_game(slot: int, hacker_alias: String) -> bool:
	if _is_transitioning:
		return false
	if not SaveManager.is_valid_slot(slot):
		push_warning("GameManager: invalid slot %d for a new game." % slot)
		return false
	var alias_error: String = PlayerManager.validate_alias(hacker_alias)
	if not alias_error.is_empty():
		push_warning("GameManager: %s" % alias_error)
		return false

	SaveManager.reset_all_sections()
	PlayerManager.create_new_player(hacker_alias)
	EconomyManager.grant_starting_funds()
	MailManager.deliver_trigger(MailManager.TRIGGER_NEW_GAME)

	# Write the slot immediately so the new game exists on disk.
	if not SaveManager.save_to_slot(slot):
		SaveManager.reset_all_sections()
		return false

	SaveManager.begin_session(slot)
	_set_state(State.IN_GAME)
	_change_scene(ScenePaths.GAME_SESSION)
	return true


func load_game(slot: int) -> bool:
	if _is_transitioning:
		return false
	if not SaveManager.load_from_slot(slot):
		return false
	SaveManager.begin_session(slot)
	_set_state(State.IN_GAME)
	_change_scene(ScenePaths.GAME_SESSION)
	return true


func save_game() -> bool:
	if not is_in_game():
		return false
	return SaveManager.save_active_slot(false)


## Leaves the session. With `save_first`, a failed save aborts the exit so
## progress is never silently lost.
func return_to_main_menu(save_first: bool = true) -> bool:
	if _is_transitioning:
		return false
	if save_first and is_in_game() and not SaveManager.save_active_slot(false):
		return false
	SaveManager.end_session()
	SaveManager.reset_all_sections()
	get_tree().paused = false
	_set_state(State.MAIN_MENU)
	_change_scene(ScenePaths.MAIN_MENU)
	return true


func quit_game(save_first: bool = true) -> void:
	if save_first and is_in_game():
		SaveManager.save_active_slot(true)
	get_tree().quit()


# --- Internals --------------------------------------------------------------

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _build_save_summary() -> Dictionary:
	return {
		"alias": PlayerManager.hacker_alias,
		"level": ProgressionManager.level,
		"rank": ProgressionManager.get_rank_name(),
		"money": EconomyManager.money,
		"playtime_seconds": PlayerManager.playtime_seconds,
	}


func _create_fade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TransitionLayer"
	layer.layer = FADE_LAYER_INDEX
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = UIPalette.BACKGROUND
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


func _change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("GameManager: scene not found: %s" % scene_path)
		return
	_is_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # block clicks mid-fade
	await _fade_to(1.0)

	var change_error: Error = get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("GameManager: failed to load %s (%s)." % [scene_path, error_string(change_error)])
	# The new scene is added at the end of the current frame.
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	scene_transition_finished.emit(scene_path)


func _fade_to(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, FADE_SECONDS)
	await tween.finished
