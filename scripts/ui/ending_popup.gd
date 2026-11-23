class_name EndingPopup
extends Control
## Shown once, when the last story chapter is completed: a summary of the
## whole run. The game is paused while it is open and continues afterwards;
## finishing the story does not end the save.

signal closed

@onready var _summary_label: Label = %EndingSummary
@onready var _stats: RichTextLabel = %EndingStats
@onready var _continue_button: Button = %EndingContinueButton

var _was_paused: bool = false


func _ready() -> void:
	hide()
	_continue_button.pressed.connect(close)


func is_open() -> bool:
	return visible


func get_stats_text() -> String:
	return _stats.get_parsed_text()


func open() -> void:
	if visible:
		return
	var company: String = OrganizationManager.company_name if OrganizationManager.is_founded() else "your company"
	_summary_label.text = (
		"%s started in one room with a computer that made a noise. Today %s is the name people say before they say 'security'."
		% [PlayerManager.hacker_alias, company]
	)
	var office: OfficeDefinition = OrganizationManager.get_office()
	var rows: Array = [
		["Time played", FormatUtils.duration(PlayerManager.playtime_seconds)],
		["Level", "%d  %s" % [ProgressionManager.level, ProgressionManager.get_rank_name()]],
		["Money earned", FormatUtils.money(EconomyManager.total_earned)],
		["Contracts completed", str(ContractManager.get_completed_count())],
		["Company", "%s, level %d" % [company, OrganizationManager.company_level]],
		["Office", office.title if office != null else "-"],
		["Staff", str(EmployeeManager.get_employee_count())],
		["Research projects", str(ResearchManager.get_completed_count())],
		["Products on the market", str(ProductManager.get_released_count())],
	]
	_stats.clear()
	_stats.push_table(2)
	for row: Array in rows:
		for column: int in 2:
			_stats.push_cell()
			_stats.set_cell_padding(Rect2(0.0, 3.0, 30.0, 3.0))
			_stats.push_color(UIPalette.TEXT_DIM if column == 0 else UIPalette.PRIMARY)
			_stats.add_text(row[column])
			_stats.pop()
			_stats.pop()
	_stats.pop()
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()
	_continue_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused
	get_viewport().gui_release_focus()
	closed.emit()
