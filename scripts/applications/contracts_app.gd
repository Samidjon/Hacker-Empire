extends VBoxContainer
## Contracts application: the contract board, the mission in progress and
## the contract history. All rules live in ContractManager.

enum View { BOARD, ACTIVE, HISTORY }

const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)
const DIFFICULTY_MARK: String = "*"

var _view: View = View.BOARD
var _offers: Array[Dictionary] = []
var _selected_offer_id: int = -1

@onready var _board_tab: Button = %BoardTabButton
@onready var _active_tab: Button = %ActiveTabButton
@onready var _history_tab: Button = %HistoryTabButton
@onready var _stats_label: Label = %ContractStatsLabel
@onready var _board_view: Control = %BoardView
@onready var _active_view: Control = %ActiveView
@onready var _history_view: Control = %HistoryView
@onready var _offer_list: ItemList = %OfferList
@onready var _refresh_button: Button = %RefreshBoardButton
@onready var _offer_title: Label = %OfferTitle
@onready var _offer_meta: Label = %OfferMeta
@onready var _offer_description: Label = %OfferDescription
@onready var _offer_facts: RichTextLabel = %OfferFacts
@onready var _requirement_label: Label = %RequirementLabel
@onready var _accept_button: Button = %AcceptButton
@onready var _runner: MissionRunner = %MissionRunner
@onready var _no_active_label: Label = %NoActiveLabel
@onready var _history_table: RichTextLabel = %ContractHistoryTable


func _ready() -> void:
	_board_tab.pressed.connect(show_view.bind(View.BOARD))
	_active_tab.pressed.connect(show_view.bind(View.ACTIVE))
	_history_tab.pressed.connect(show_view.bind(View.HISTORY))
	_offer_list.item_selected.connect(select_offer)
	_refresh_button.pressed.connect(ContractManager.refresh_board)
	_accept_button.pressed.connect(accept_selected)
	_runner.result_dismissed.connect(show_view.bind(View.BOARD))

	ContractManager.board_changed.connect(_rebuild_board)
	ContractManager.contract_accepted.connect(func(_offer: Dictionary) -> void: show_view(View.ACTIVE))
	ContractManager.contract_completed.connect(func(_result: Dictionary) -> void: _refresh_all())
	ContractManager.contract_failed.connect(func(_result: Dictionary) -> void: _refresh_all())
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _refresh_details())

	_rebuild_board()
	show_view(View.ACTIVE if ContractManager.has_active_contract() else View.BOARD)


func _process(_delta: float) -> void:
	if _board_view.visible:
		_refresh_refresh_button()


func get_view() -> View:
	return _view


func get_runner() -> MissionRunner:
	return _runner


func get_offer_count() -> int:
	return _offers.size()


func get_selected_offer_id() -> int:
	return _selected_offer_id


func get_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_offer_title.text, _offer_meta.text, _offer_facts.get_parsed_text(), _requirement_label.text
	]


func get_history_text() -> String:
	return _history_table.get_parsed_text()


func show_view(view: View) -> void:
	_view = view
	_board_view.visible = view == View.BOARD
	_active_view.visible = view == View.ACTIVE
	_history_view.visible = view == View.HISTORY
	_board_tab.set_pressed_no_signal(view == View.BOARD)
	_active_tab.set_pressed_no_signal(view == View.ACTIVE)
	_history_tab.set_pressed_no_signal(view == View.HISTORY)
	_refresh_all()


## Shows the offer at `index` of the list.
func select_offer(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	_selected_offer_id = _offers[index]["offer_id"]
	if not _offer_list.is_selected(index):
		_offer_list.select(index)
	_refresh_details()


## Accepts the selected offer, exactly as the Accept button does.
func accept_selected() -> bool:
	return ContractManager.accept_contract(_selected_offer_id)


# --- Refreshing -------------------------------------------------------------

func _refresh_all() -> void:
	_stats_label.text = "Completed %d   Failed %d" % [
		ContractManager.get_completed_count(), ContractManager.get_failed_count()
	]
	_active_tab.text = "Active (1)" if ContractManager.has_active_contract() else "Active"
	_no_active_label.visible = (
		not ContractManager.has_active_contract() and not _runner.is_showing_result()
	)
	_refresh_details()
	_refresh_history()


func _rebuild_board() -> void:
	_offers = ContractManager.get_board()
	_offer_list.clear()
	var selected_index: int = -1
	for index: int in _offers.size():
		var offer: Dictionary = _offers[index]
		var definition: ContractDefinition = ContractManager.get_definition(offer["template_id"])
		_offer_list.add_item("%s   %s" % [
			FormatUtils.money(ContractManager.get_effective_reward(offer)).rpad(8), definition.title
		])
		if definition.alignment == ContractDefinition.ALIGNMENT_UNDERGROUND:
			_offer_list.set_item_custom_fg_color(index, UIPalette.SECONDARY)
		if offer["offer_id"] == _selected_offer_id:
			selected_index = index
	if selected_index < 0 and not _offers.is_empty():
		selected_index = 0
	if selected_index >= 0:
		select_offer(selected_index)
	else:
		_selected_offer_id = -1
		_refresh_details()


func _refresh_details() -> void:
	var offer: Dictionary = ContractManager.find_offer(_selected_offer_id)
	if offer.is_empty():
		_offer_title.text = "No offers"
		_offer_meta.text = ""
		_offer_description.text = "The board is empty. New contracts appear as you level up."
		_offer_facts.clear()
		_requirement_label.text = ""
		_accept_button.disabled = true
		return
	var definition: ContractDefinition = ContractManager.get_definition(offer["template_id"])
	_offer_title.text = definition.title
	_offer_meta.text = "%s   -   %s" % [
		ContractCategory.get_display_name(definition.category).to_upper(), definition.client
	]
	_offer_description.text = definition.description

	_offer_facts.clear()
	_offer_facts.push_table(2)
	_add_fact("Payment", FormatUtils.money(ContractManager.get_effective_reward(offer)), UIPalette.ACCENT)
	_add_fact("Experience", "+%d XP" % ContractManager.get_effective_xp(definition), UIPalette.SECONDARY)
	_add_fact("Reputation", _reputation_text(definition), UIPalette.TEXT)
	_add_fact("Difficulty", DIFFICULTY_MARK.repeat(definition.difficulty), UIPalette.WARNING)
	_add_fact("Required level", str(definition.required_level), UIPalette.TEXT)
	_add_fact("Estimated time", FormatUtils.duration(definition.estimated_duration).substr(3), UIPalette.TEXT)
	_add_fact(
		"Time limit", FormatUtils.duration(ContractManager.get_time_limit(definition)).substr(3),
		UIPalette.TEXT
	)
	var stage_titles: PackedStringArray = []
	for stage: Dictionary in definition.stages:
		stage_titles.append(stage["title"])
	_add_fact("Stages", "%d: %s" % [stage_titles.size(), ", ".join(stage_titles)], UIPalette.TEXT)
	_offer_facts.pop()

	var unmet: PackedStringArray = ContractManager.get_unmet_requirements(definition)
	if ContractManager.has_active_contract():
		_requirement_label.text = "Finish your current contract first."
	else:
		_requirement_label.text = "\n".join(unmet)
	_accept_button.disabled = not ContractManager.can_accept(_selected_offer_id)


func _reputation_text(definition: ContractDefinition) -> String:
	var parts: PackedStringArray = []
	if definition.reputation_white != 0:
		parts.append("white %+d" % definition.reputation_white)
	if definition.reputation_underground != 0:
		parts.append("underground %+d" % definition.reputation_underground)
	if not is_zero_approx(definition.heat):
		parts.append("heat %+d" % roundi(definition.heat))
	return ", ".join(parts) if not parts.is_empty() else "none"


func _refresh_refresh_button() -> void:
	var cooldown: float = ContractManager.get_refresh_cooldown_remaining()
	_refresh_button.disabled = cooldown > 0.0
	_refresh_button.text = "New Offers" if cooldown <= 0.0 else "New Offers (%ds)" % ceili(cooldown)


func _refresh_history() -> void:
	_history_table.clear()
	var history: Array[Dictionary] = ContractManager.get_history()
	if history.is_empty():
		_history_table.push_color(UIPalette.TEXT_DIM)
		_history_table.add_text("No finished contracts yet.")
		_history_table.pop()
		return
	_history_table.push_table(5)
	for result: Dictionary in history:
		var is_success: bool = result["outcome"] == ContractManager.OUTCOME_COMPLETED
		var payment: int = SaveDataReader.get_int(result, "reward") + SaveDataReader.get_int(result, "bonus")
		_add_history_cell(FormatUtils.local_timestamp(result["finished_at"]), UIPalette.TEXT_DIM)
		_add_history_cell(
			"COMPLETED" if is_success else "FAILED", UIPalette.ACCENT if is_success else UIPalette.DANGER
		)
		_add_history_cell(result["name"], UIPalette.TEXT)
		_add_history_cell(ContractCategory.get_display_name(result["category"]), UIPalette.TEXT_DIM)
		_add_history_cell(FormatUtils.money(payment) if is_success else "-", UIPalette.TEXT)
	_history_table.pop()


func _add_fact(label: String, value: String, value_color: Color) -> void:
	_add_cell(_offer_facts, label, UIPalette.TEXT_DIM)
	_add_cell(_offer_facts, value, value_color)


func _add_history_cell(text: String, color: Color) -> void:
	_add_cell(_history_table, text, color)


func _add_cell(table: RichTextLabel, text: String, color: Color) -> void:
	table.push_cell()
	table.set_cell_padding(CELL_PADDING)
	table.push_color(color)
	table.add_text(text)
	table.pop()
	table.pop()
