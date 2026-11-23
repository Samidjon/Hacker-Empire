extends VBoxContainer
## Employees application: the staff list with task assignment, and the
## recruitment list. Everything goes through EmployeeManager.

enum View { STAFF, RECRUIT }

const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)
const DISMISS_TEXT: String = "Dismiss"
const DISMISS_CONFIRM_TEXT: String = "Click again to dismiss"

var _view: View = View.STAFF
var _employees: Array[Employee] = []
var _candidates: Array[Employee] = []
var _selected_employee_id: String = ""
var _selected_candidate_id: String = ""
## The dismiss button must be pressed twice in a row.
var _dismiss_armed: bool = false

@onready var _staff_tab: Button = %StaffTabButton
@onready var _recruit_tab: Button = %RecruitTabButton
@onready var _summary_label: Label = %StaffSummaryLabel
@onready var _no_company_label: Label = %NoCompanyLabel
@onready var _staff_view: Control = %StaffView
@onready var _recruit_view: Control = %RecruitView
@onready var _staff_list: ItemList = %StaffList
@onready var _employee_name: Label = %EmployeeNameLabel
@onready var _employee_meta: Label = %EmployeeMetaLabel
@onready var _employee_facts: RichTextLabel = %EmployeeFacts
@onready var _assignment_list: ItemList = %AssignmentList
@onready var _assignment_description: Label = %AssignmentDescription
@onready var _dismiss_button: Button = %DismissButton
@onready var _candidate_list: ItemList = %CandidateList
@onready var _candidate_name: Label = %CandidateNameLabel
@onready var _candidate_meta: Label = %CandidateMetaLabel
@onready var _candidate_facts: RichTextLabel = %CandidateFacts
@onready var _hire_blockers: Label = %HireBlockerLabel
@onready var _hire_button: Button = %HireButton


func _ready() -> void:
	_staff_tab.pressed.connect(show_view.bind(View.STAFF))
	_recruit_tab.pressed.connect(show_view.bind(View.RECRUIT))
	_staff_list.item_selected.connect(select_employee)
	_candidate_list.item_selected.connect(select_candidate)
	_assignment_list.item_selected.connect(assign_selected)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	_hire_button.pressed.connect(hire_selected)
	for assignment: EmployeeAssignment in EmployeeManager.get_assignments():
		_assignment_list.add_item(assignment.title)

	EmployeeManager.employees_changed.connect(_rebuild)
	EmployeeManager.candidates_changed.connect(_rebuild)
	OrganizationManager.company_changed.connect(_rebuild)
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_candidate_details())
	show_view(View.STAFF)


func get_view() -> View:
	return _view


func get_employee_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for employee: Employee in _employees:
		ids.append(employee.id)
	return ids


func get_candidate_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for candidate: Employee in _candidates:
		ids.append(candidate.id)
	return ids


func get_employee_details_text() -> String:
	return "%s\n%s\n%s" % [_employee_name.text, _employee_meta.text, _employee_facts.get_parsed_text()]


func get_candidate_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_candidate_name.text, _candidate_meta.text, _candidate_facts.get_parsed_text(), _hire_blockers.text
	]


func show_view(view: View) -> void:
	_view = view
	_staff_tab.set_pressed_no_signal(view == View.STAFF)
	_recruit_tab.set_pressed_no_signal(view == View.RECRUIT)
	_rebuild()


func select_employee(index: int) -> void:
	if index < 0 or index >= _employees.size():
		return
	_selected_employee_id = _employees[index].id
	_dismiss_armed = false
	if not _staff_list.is_selected(index):
		_staff_list.select(index)
	_refresh_employee_details()


func select_candidate(index: int) -> void:
	if index < 0 or index >= _candidates.size():
		return
	_selected_candidate_id = _candidates[index].id
	if not _candidate_list.is_selected(index):
		_candidate_list.select(index)
	_refresh_candidate_details()


## Gives the selected employee the task at `index` of the assignment list.
func assign_selected(index: int) -> bool:
	var assignments: Array[EmployeeAssignment] = EmployeeManager.get_assignments()
	if index < 0 or index >= assignments.size():
		return false
	return EmployeeManager.assign(_selected_employee_id, assignments[index].id)


## Hires the selected candidate, exactly as the Hire button does.
func hire_selected() -> bool:
	return EmployeeManager.hire(_selected_candidate_id)


## Dismisses the selected employee without the two-click confirmation.
func dismiss_selected() -> bool:
	return EmployeeManager.dismiss(_selected_employee_id)


func _on_dismiss_pressed() -> void:
	if _dismiss_armed:
		dismiss_selected()
	else:
		_dismiss_armed = true
		_dismiss_button.text = DISMISS_CONFIRM_TEXT


# --- Refreshing -------------------------------------------------------------

func _rebuild() -> void:
	var is_founded: bool = OrganizationManager.is_founded()
	_no_company_label.visible = not is_founded
	_staff_view.visible = is_founded and _view == View.STAFF
	_recruit_view.visible = is_founded and _view == View.RECRUIT
	_summary_label.text = "" if not is_founded else "%d of %d desks used   -   payroll %s a day" % [
		EmployeeManager.get_employee_count(), OrganizationManager.get_desk_capacity(),
		FormatUtils.money(EmployeeManager.get_daily_salary_total())
	]

	_employees = EmployeeManager.get_employees()
	_staff_list.clear()
	var selected_index: int = -1
	for index: int in _employees.size():
		var employee: Employee = _employees[index]
		var assignment: EmployeeAssignment = EmployeeManager.get_assignment(employee.assignment_id)
		_staff_list.add_item("%s   -   %s" % [employee.display_name, assignment.title if assignment != null else "idle"])
		if employee.id == _selected_employee_id:
			selected_index = index
	if selected_index < 0 and not _employees.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_selected_employee_id = _employees[selected_index].id
		_staff_list.select(selected_index)
	else:
		_selected_employee_id = ""
	_refresh_employee_details()

	_candidates = EmployeeManager.get_candidates()
	_candidate_list.clear()
	selected_index = -1
	for index: int in _candidates.size():
		var candidate: Employee = _candidates[index]
		var role: EmployeeRole = EmployeeManager.get_role(candidate.role_id)
		_candidate_list.add_item("%s   -   %s   %s/day" % [
			candidate.display_name, role.title if role != null else "?", FormatUtils.money(candidate.salary)
		])
		if candidate.id == _selected_candidate_id:
			selected_index = index
	if selected_index < 0 and not _candidates.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_selected_candidate_id = _candidates[selected_index].id
		_candidate_list.select(selected_index)
	else:
		_selected_candidate_id = ""
	_refresh_candidate_details()


func _refresh_employee_details() -> void:
	var employee: Employee = EmployeeManager.get_employee(_selected_employee_id)
	_dismiss_button.text = DISMISS_CONFIRM_TEXT if _dismiss_armed else DISMISS_TEXT
	_dismiss_button.disabled = employee == null
	_assignment_list.deselect_all()
	if employee == null:
		_employee_name.text = "No staff yet"
		_employee_meta.text = ""
		_employee_facts.clear()
		_assignment_description.text = "Hire someone on the Recruit tab."
		return
	var role: EmployeeRole = EmployeeManager.get_role(employee.role_id)
	_employee_name.text = employee.display_name
	_employee_meta.text = "%s   -   LEVEL %d   -   ID %s" % [role.title.to_upper(), employee.level, employee.id]
	_fill_person_facts(_employee_facts, employee, true)

	var assignments: Array[EmployeeAssignment] = EmployeeManager.get_assignments()
	for index: int in assignments.size():
		if assignments[index].id == employee.assignment_id:
			_assignment_list.select(index)
			var text: String = assignments[index].description
			if assignments[index].produces_income:
				text += "\nExpected today: %s" % FormatUtils.money(EmployeeManager.get_expected_income(employee))
			if assignments[index].grants_support:
				text += "\nGives you: %s" % ", ".join(EmployeeManager.describe_support(employee))
			_assignment_description.text = text


func _refresh_candidate_details() -> void:
	var candidate: Employee = EmployeeManager.get_candidate(_selected_candidate_id)
	if candidate == null:
		_candidate_name.text = "No candidates"
		_candidate_meta.text = ""
		_candidate_facts.clear()
		_hire_blockers.text = "New candidates apply every business day."
		_hire_button.disabled = true
		return
	var role: EmployeeRole = EmployeeManager.get_role(candidate.role_id)
	_candidate_name.text = candidate.display_name
	_candidate_meta.text = role.title.to_upper()
	_fill_person_facts(_candidate_facts, candidate, false)
	_candidate_facts.newline()
	_candidate_facts.push_color(UIPalette.TEXT_DIM)
	_candidate_facts.add_text(role.description)
	_candidate_facts.pop()
	var blockers: PackedStringArray = EmployeeManager.get_hire_blockers(candidate.id)
	_hire_blockers.text = "\n".join(blockers)
	_hire_button.disabled = not blockers.is_empty()
	_hire_button.text = "Hire (signing fee %s)" % FormatUtils.money(EmployeeManager.get_signing_fee(candidate))


func _fill_person_facts(table: RichTextLabel, person: Employee, is_staff: bool) -> void:
	table.clear()
	table.push_table(2)
	_add_fact(table, "Salary", "%s a day" % FormatUtils.money(person.salary), UIPalette.DANGER)
	_add_fact(table, "Productivity", "%d%%" % roundi(person.productivity * 100.0), UIPalette.TEXT)
	if is_staff:
		_add_fact(table, "Experience", "%d / %d XP" % [
			person.experience, EmployeeManager.get_xp_for_next_level(person)
		], UIPalette.SECONDARY)
		_add_fact(table, "Energy", "%d / 100" % roundi(person.energy), _condition_color(person.energy))
	_add_fact(table, "Morale", "%d / 100" % roundi(person.morale), _condition_color(person.morale))
	if is_staff:
		_add_fact(table, "Days employed", str(person.days_employed), UIPalette.TEXT)
		_add_fact(table, "Earned for you", FormatUtils.money(person.total_earned), UIPalette.ACCENT)
	var role: EmployeeRole = EmployeeManager.get_role(person.role_id)
	for skill_id: String in Employee.SKILLS:
		var is_primary: bool = role != null and role.primary_skill == skill_id
		_add_fact(
			table, "%s%s" % [Employee.SKILL_NAMES[skill_id], "  (role)" if is_primary else ""],
			"%d / %d" % [person.get_skill(skill_id), EmployeeManager.CONFIG.max_skill],
			UIPalette.PRIMARY if is_primary else UIPalette.TEXT_DIM
		)
	table.pop()


func _condition_color(value: float) -> Color:
	if value <= 25.0:
		return UIPalette.DANGER
	if value <= 50.0:
		return UIPalette.WARNING
	return UIPalette.ACCENT


func _add_fact(table: RichTextLabel, label: String, value: String, value_color: Color) -> void:
	for cell: Array in [[label, UIPalette.TEXT_DIM], [value, value_color]]:
		table.push_cell()
		table.set_cell_padding(CELL_PADDING)
		table.push_color(cell[1])
		table.add_text(cell[0])
		table.pop()
		table.pop()
