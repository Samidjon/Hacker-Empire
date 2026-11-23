extends VBoxContainer
## Organization application: found the company, then watch its level,
## reputation, office and daily books, and expand the office.

const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)

@onready var _founding_view: Control = %FoundingView
@onready var _company_view: Control = %CompanyView
@onready var _name_edit: LineEdit = %CompanyNameEdit
@onready var _founding_facts: Label = %FoundingFactsLabel
@onready var _founding_blockers: Label = %FoundingBlockerLabel
@onready var _found_button: Button = %FoundButton
@onready var _company_name_label: Label = %CompanyNameLabel
@onready var _company_level_label: Label = %CompanyLevelLabel
@onready var _xp_bar: ProgressBar = %CompanyXpBar
@onready var _xp_label: Label = %CompanyXpLabel
@onready var _reputation_card: StatCard = %CompanyReputationCard
@onready var _staff_card: StatCard = %CompanyStaffCard
@onready var _costs_card: StatCard = %CompanyCostsCard
@onready var _day_card: StatCard = %CompanyDayCard
@onready var _office_facts: RichTextLabel = %OfficeFacts
@onready var _expansion_blockers: Label = %ExpansionBlockerLabel
@onready var _expand_button: Button = %ExpandButton
@onready var _day_bar: ProgressBar = %DayProgressBar
@onready var _report_title: Label = %ReportTitle
@onready var _report_table: RichTextLabel = %ReportTable


func _ready() -> void:
	_name_edit.max_length = OrganizationManager.CONFIG.max_name_length
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_founding())
	_name_edit.text_submitted.connect(func(_text: String) -> void: found_company())
	_found_button.pressed.connect(found_company)
	_expand_button.pressed.connect(OrganizationManager.expand_office)
	OrganizationManager.company_changed.connect(refresh)
	OrganizationManager.day_finished.connect(func(_report: Dictionary) -> void: refresh())
	EmployeeManager.employees_changed.connect(refresh)
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: refresh())
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: refresh())
	refresh()


func _process(_delta: float) -> void:
	if _company_view.visible:
		_day_bar.value = OrganizationManager.get_day_progress() * _day_bar.max_value


func set_company_name_text(text: String) -> void:
	_name_edit.text = text
	_refresh_founding()


## Founds the company with the typed name, exactly as the button does.
func found_company() -> bool:
	return OrganizationManager.found_company(_name_edit.text)


func get_founding_text() -> String:
	return "%s\n%s" % [_founding_facts.text, _founding_blockers.text]


func get_office_text() -> String:
	return "%s\n%s" % [_office_facts.get_parsed_text(), _expansion_blockers.text]


func get_report_text() -> String:
	return "%s\n%s" % [_report_title.text, _report_table.get_parsed_text()]


func refresh() -> void:
	var is_founded: bool = OrganizationManager.is_founded()
	_founding_view.visible = not is_founded
	_company_view.visible = is_founded
	if is_founded:
		_refresh_company()
	else:
		_refresh_founding()


func _refresh_founding() -> void:
	var config: OrganizationConfig = OrganizationManager.CONFIG
	_founding_facts.text = "Registration fee: %s     Required level: %d" % [
		FormatUtils.money(config.founding_cost), config.required_level
	]
	var blockers: PackedStringArray = OrganizationManager.get_founding_blockers(_name_edit.text)
	# An empty name box is not an error yet; just keep the button off.
	_founding_blockers.text = "" if _name_edit.text.strip_edges().is_empty() and blockers.size() == 1 else "\n".join(blockers)
	_found_button.disabled = not blockers.is_empty()


func _refresh_company() -> void:
	var manager := OrganizationManager
	_company_name_label.text = manager.company_name
	_company_level_label.text = "COMPANY LEVEL %d" % manager.company_level
	var required: int = manager.get_xp_required()
	_xp_bar.value = _xp_bar.max_value if required <= 0 else float(manager.company_xp) / required * _xp_bar.max_value
	_xp_label.text = "MAX LEVEL" if required <= 0 else "%d / %d XP" % [manager.company_xp, required]

	var payroll: int = EmployeeManager.get_daily_salary_total()
	_reputation_card.set_value(str(manager.reputation), UIPalette.PRIMARY)
	_staff_card.set_value("%d / %d" % [EmployeeManager.get_employee_count(), manager.get_desk_capacity()])
	_costs_card.set_value(FormatUtils.money(payroll + manager.get_daily_rent()), UIPalette.DANGER)
	_day_card.set_value(str(manager.day), UIPalette.SECONDARY)

	var office: OfficeDefinition = manager.get_office()
	var next: OfficeDefinition = manager.get_next_office()
	_office_facts.clear()
	_office_facts.push_table(2)
	_add_cell(_office_facts, "Office", UIPalette.TEXT_DIM)
	_add_cell(_office_facts, office.title, UIPalette.PRIMARY)
	_add_cell(_office_facts, "Desks", UIPalette.TEXT_DIM)
	_add_cell(_office_facts, str(office.capacity), UIPalette.TEXT)
	_add_cell(_office_facts, "Rent per day", UIPalette.TEXT_DIM)
	_add_cell(_office_facts, FormatUtils.money(office.rent), UIPalette.TEXT)
	if manager.rent_arrears > 0:
		_add_cell(_office_facts, "Overdue rent", UIPalette.TEXT_DIM)
		_add_cell(_office_facts, FormatUtils.money(manager.rent_arrears), UIPalette.DANGER)
	if manager.company_level > 1:
		_add_cell(_office_facts, "Company bonus", UIPalette.TEXT_DIM)
		_add_cell(
			_office_facts,
			GameEffects.describe(GameEffects.CONTRACT_REWARD, manager.get_effect(GameEffects.CONTRACT_REWARD)),
			UIPalette.ACCENT
		)
	if next != null:
		_add_cell(_office_facts, "Next office", UIPalette.TEXT_DIM)
		_add_cell(
			_office_facts,
			"%s: %d desks, %s a day, %s to move in" % [
				next.title, next.capacity, FormatUtils.money(next.rent), FormatUtils.money(next.cost)
			],
			UIPalette.TEXT
		)
	_office_facts.pop()
	_office_facts.newline()
	_office_facts.push_color(UIPalette.TEXT_DIM)
	_office_facts.add_text(office.description)
	_office_facts.pop()

	var blockers: PackedStringArray = manager.get_expansion_blockers()
	_expansion_blockers.text = "\n".join(blockers)
	_expand_button.disabled = not blockers.is_empty()
	_expand_button.text = "Largest Office" if next == null else "Move to %s (%s)" % [
		next.title, FormatUtils.money(next.cost)
	]
	_refresh_report()


func _refresh_report() -> void:
	var report: Dictionary = OrganizationManager.get_last_report()
	_report_table.clear()
	if report.is_empty():
		_report_title.text = "DAILY REPORT"
		_report_table.push_color(UIPalette.TEXT_DIM)
		_report_table.add_text("The first business day has not ended yet. Rent and salaries are paid, and staff earn money, at the end of each day.")
		_report_table.pop()
		return
	var net: int = SaveDataReader.get_int(report, "net")
	_report_title.text = "REPORT FOR DAY %d" % SaveDataReader.get_int(report, "day")
	_report_table.push_table(2)
	var income: Dictionary = SaveDataReader.get_dictionary(report, "income")
	for label: String in income:
		_add_cell(_report_table, label, UIPalette.TEXT)
		_add_cell(_report_table, FormatUtils.signed_money(income[label]), UIPalette.ACCENT)
	var expenses: Dictionary = SaveDataReader.get_dictionary(report, "expenses")
	for label: String in expenses:
		_add_cell(_report_table, label, UIPalette.TEXT)
		_add_cell(_report_table, FormatUtils.signed_money(-int(expenses[label])), UIPalette.DANGER)
	_add_cell(_report_table, "Net", UIPalette.TEXT_DIM)
	_add_cell(_report_table, FormatUtils.signed_money(net), UIPalette.ACCENT if net >= 0 else UIPalette.DANGER)
	_report_table.pop()
	for note: Variant in SaveDataReader.get_array(report, "notes"):
		_report_table.newline()
		_report_table.push_color(UIPalette.WARNING)
		_report_table.add_text(str(note))
		_report_table.pop()


func _add_cell(table: RichTextLabel, text: String, color: Color) -> void:
	table.push_cell()
	table.set_cell_padding(CELL_PADDING)
	table.push_color(color)
	table.add_text(text)
	table.pop()
	table.pop()
