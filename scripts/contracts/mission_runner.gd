class_name MissionRunner
extends VBoxContainer
## Plays the contract in progress: shows the current stage's puzzle, the
## mistake counter and the clock, and the result when the contract ends.
## Works with any MissionPuzzle; all rules live in ContractManager.

signal result_dismissed

const LOW_TIME_SECONDS: float = 30.0

var _puzzle: MissionPuzzle

@onready var _mission_panel: Control = %MissionPanel
@onready var _title_label: Label = %MissionTitle
@onready var _stage_label: Label = %StageLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _mistakes_label: Label = %MistakesLabel
@onready var _time_label: Label = %TimeLabel
@onready var _abandon_button: Button = %AbandonButton
@onready var _puzzle_holder: VBoxContainer = %PuzzleHolder
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _result_close_button: Button = %ResultCloseButton


func _ready() -> void:
	_abandon_button.pressed.connect(ContractManager.abandon_contract)
	_result_close_button.pressed.connect(dismiss_result)
	ContractManager.stage_changed.connect(func(_index: int) -> void: _show_stage())
	ContractManager.mistakes_changed.connect(func(_made: int, _limit: int) -> void: _refresh_status())
	ContractManager.contract_completed.connect(_show_result)
	ContractManager.contract_failed.connect(_show_result)
	_result_panel.hide()
	_mission_panel.visible = ContractManager.has_active_contract()
	# Reopening the app, or loading a save, resumes the stage in progress.
	if ContractManager.has_active_contract():
		_show_stage()


func _process(_delta: float) -> void:
	if _mission_panel.visible:
		_refresh_time()


func get_puzzle() -> MissionPuzzle:
	return _puzzle


func is_showing_result() -> bool:
	return _result_panel.visible


func get_result_text() -> String:
	return "%s\n%s" % [_result_title.text, _result_text.text]


func get_feedback_text() -> String:
	return _feedback_label.text


func dismiss_result() -> void:
	_result_panel.hide()
	result_dismissed.emit()


func _show_stage() -> void:
	var definition: ContractDefinition = ContractManager.get_active_definition()
	var stage: Dictionary = ContractManager.get_current_stage()
	if definition == null or stage.is_empty():
		return
	_clear_puzzle()
	_result_panel.hide()
	_mission_panel.show()
	_feedback_label.text = ""
	_title_label.text = definition.title
	_stage_label.text = "STAGE %d OF %d  -  %s" % [
		ContractManager.get_stage_index() + 1, definition.get_stage_count(),
		String(stage["title"]).to_upper()
	]

	var logic: PuzzleLogic = ContractManager.create_stage_logic()
	_puzzle = PuzzleFactory.create_view(logic)
	if _puzzle == null:
		# Broken data must not trap the player in an unwinnable contract.
		_instruction_label.text = "This stage could not be loaded. You can abandon the contract."
		return
	var instruction: String = SaveDataReader.get_string(stage, "instruction")
	_instruction_label.text = instruction if not instruction.is_empty() else logic.default_instruction
	_puzzle_holder.add_child(_puzzle)
	_puzzle.setup(logic)
	_puzzle.solved.connect(_on_puzzle_solved)
	_puzzle.mistake_made.connect(_on_mistake_made)
	_refresh_status()
	_refresh_time()


func _on_puzzle_solved() -> void:
	# Deferred so the puzzle is not freed in the middle of its own button press.
	ContractManager.complete_stage.call_deferred()


func _on_mistake_made(message: String) -> void:
	_feedback_label.text = message
	# Deferred for the same reason: the last mistake ends the contract.
	ContractManager.register_mistake.call_deferred()


func _reason_text(reason: String) -> String:
	if reason == ContractManager.REASON_MISTAKES:
		return "Too many mistakes. The client lost confidence."
	if reason == ContractManager.REASON_TIMEOUT:
		return "Time ran out. The client went elsewhere."
	if reason == ContractManager.REASON_ABANDONED:
		return "You walked away from the job."
	return "The contract failed."


func _show_result(result: Dictionary) -> void:
	_clear_puzzle()
	_mission_panel.hide()
	_result_panel.show()
	var is_success: bool = result.get("outcome") == ContractManager.OUTCOME_COMPLETED
	_result_title.text = "CONTRACT COMPLETED" if is_success else "CONTRACT FAILED"
	_result_title.add_theme_color_override(
		&"font_color", UIPalette.ACCENT if is_success else UIPalette.DANGER
	)
	var lines: PackedStringArray = [SaveDataReader.get_string(result, "name")]
	if is_success:
		lines.append("")
		lines.append("Payment      %s" % FormatUtils.money(SaveDataReader.get_int(result, "reward")))
		var bonus: int = SaveDataReader.get_int(result, "bonus")
		if bonus > 0:
			lines.append("Flawless bonus  %s" % FormatUtils.signed_money(bonus))
		lines.append("Experience   +%d XP" % SaveDataReader.get_int(result, "xp"))
	else:
		lines.append(_reason_text(SaveDataReader.get_string(result, "reason")))
		lines.append("")
		lines.append("No payment.")
	lines.append_array(_reputation_lines(result))
	_result_text.text = "\n".join(lines)
	_result_close_button.grab_focus()


func _reputation_lines(result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var white: int = SaveDataReader.get_int(result, "white")
	var underground: int = SaveDataReader.get_int(result, "underground")
	var heat: float = SaveDataReader.get_float(result, "heat")
	if white != 0:
		lines.append("White reputation  %+d" % white)
	if underground != 0:
		lines.append("Underground reputation  %+d" % underground)
	if not is_zero_approx(heat):
		lines.append("Heat  %+d" % roundi(heat))
	return lines


func _clear_puzzle() -> void:
	if _puzzle != null and is_instance_valid(_puzzle):
		_puzzle_holder.remove_child(_puzzle)
		_puzzle.queue_free()
	_puzzle = null


func _refresh_status() -> void:
	var left: int = ContractManager.get_max_mistakes() - ContractManager.get_mistakes()
	_mistakes_label.text = "Mistakes left: %d" % maxi(0, left)
	_mistakes_label.add_theme_color_override(
		&"font_color", UIPalette.DANGER if left <= 1 else UIPalette.TEXT
	)


func _refresh_time() -> void:
	var remaining: float = ContractManager.get_time_remaining()
	_time_label.text = "Time left: %s" % FormatUtils.duration(remaining).substr(3)
	_time_label.add_theme_color_override(
		&"font_color", UIPalette.DANGER if remaining <= LOW_TIME_SECONDS else UIPalette.TEXT
	)
