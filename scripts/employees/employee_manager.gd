extends Node
## EmployeeManager (autoload)
##
## Owns the staff: candidates, hiring and dismissal, skills and growth,
## salaries, assignments, and what each person does on a business day.
## Daily work is done in OrganizationManager.day_processing, where income,
## salaries and notes are written into the day's report. Support bonuses are
## published through GameEffects.

signal employees_changed
signal candidates_changed
signal employee_hired(employee: Employee)
## `reason` is REASON_DISMISSED or REASON_RESIGNED.
signal employee_left(employee_name: String, reason: String)

const CONFIG: EmployeeConfig = preload("res://resources/configurations/employee_config.tres")
const ROLES_PATH: String = "res://data/employees/roles.json"
const ASSIGNMENTS_PATH: String = "res://data/employees/assignments.json"
const NAMES_PATH: String = "res://data/employees/names.json"
const SAVE_SECTION: String = "employees"
const REASON_DISMISSED: String = "dismissed"
const REASON_RESIGNED: String = "resigned"
const WORK_INCOME_LABEL: String = "Client work"
const SALARY_LABEL: String = "Salaries"
const FALLBACK_NAME: String = "New Hire"

var _roles: Dictionary = {} # role id -> EmployeeRole
var _role_order: Array[String] = []
var _assignments: Dictionary = {} # assignment id -> EmployeeAssignment
var _assignment_order: Array[String] = []
var _first_names: Array[String] = []
var _last_names: Array[String] = []
var _employees: Array[Employee] = []
var _candidates: Array[Employee] = []
var _next_id: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_provider(get_effect)
	OrganizationManager.day_processing.connect(_on_day_processing)
	OrganizationManager.company_founded.connect(_refresh_candidates)
	OrganizationManager.company_level_changed.connect(func(_level: int) -> void: _refresh_candidates())


# --- Catalogue --------------------------------------------------------------

func get_roles() -> Array[EmployeeRole]:
	var roles: Array[EmployeeRole] = []
	for role_id: String in _role_order:
		roles.append(_roles[role_id])
	return roles


func get_role(role_id: String) -> EmployeeRole:
	return _roles.get(role_id)


func get_assignments() -> Array[EmployeeAssignment]:
	var assignments: Array[EmployeeAssignment] = []
	for assignment_id: String in _assignment_order:
		assignments.append(_assignments[assignment_id])
	return assignments


func get_assignment(assignment_id: String) -> EmployeeAssignment:
	return _assignments.get(assignment_id)


func get_default_assignment_id() -> String:
	return _assignment_order[0] if not _assignment_order.is_empty() else ""


# --- Staff ------------------------------------------------------------------

func get_employees() -> Array[Employee]:
	return _employees.duplicate()


func get_employee(employee_id: String) -> Employee:
	for employee: Employee in _employees:
		if employee.id == employee_id:
			return employee
	return null


func get_employee_count() -> int:
	return _employees.size()


func get_free_desks() -> int:
	return maxi(0, OrganizationManager.get_desk_capacity() - _employees.size())


func get_daily_salary_total() -> int:
	var total: int = 0
	for employee: Employee in _employees:
		total += employee.salary
	return total


## The role's working skill of this person.
func get_primary_skill(employee: Employee) -> int:
	var role: EmployeeRole = get_role(employee.role_id)
	return employee.get_skill(role.primary_skill) if role != null else 1


## Money this person would bring in today on an income-producing assignment.
func get_expected_income(employee: Employee) -> int:
	var role: EmployeeRole = get_role(employee.role_id)
	if role == null:
		return 0
	return roundi(
		role.income_per_skill * get_primary_skill(employee) * employee.productivity * employee.get_efficiency()
	)


## XP this person needs to reach their next level.
func get_xp_for_next_level(employee: Employee) -> int:
	return employee.level * CONFIG.xp_per_level


func calculate_salary(employee: Employee) -> int:
	var role: EmployeeRole = get_role(employee.role_id)
	if role == null:
		return 0
	return (
		role.base_salary + role.salary_per_skill * get_primary_skill(employee)
		+ CONFIG.salary_per_level * (employee.level - 1)
	)


## Gives the employee a different task. Takes effect from the next day's work;
## support bonuses change at once.
func assign(employee_id: String, assignment_id: String) -> bool:
	var employee: Employee = get_employee(employee_id)
	if employee == null or not _assignments.has(assignment_id):
		return false
	if employee.assignment_id == assignment_id:
		return true
	employee.assignment_id = assignment_id
	_announce_staff_change()
	return true


func dismiss(employee_id: String) -> bool:
	var employee: Employee = get_employee(employee_id)
	if employee == null:
		return false
	_employees.erase(employee)
	employee_left.emit(employee.display_name, REASON_DISMISSED)
	_announce_staff_change()
	return true


## Raises or lowers one person's morale (events, bonuses).
func change_morale(employee_id: String, amount: float) -> void:
	var employee: Employee = get_employee(employee_id)
	if employee != null:
		employee.morale = clampf(employee.morale + amount, 0.0, Employee.MAX_CONDITION)
		_announce_staff_change()


func change_morale_all(amount: float) -> void:
	for employee: Employee in _employees:
		employee.morale = clampf(employee.morale + amount, 0.0, Employee.MAX_CONDITION)
	_announce_staff_change()


## The employee leaves of their own accord.
func resign(employee_id: String) -> bool:
	var employee: Employee = get_employee(employee_id)
	if employee == null:
		return false
	_employees.erase(employee)
	employee_left.emit(employee.display_name, REASON_RESIGNED)
	_announce_staff_change()
	return true


# --- Recruitment ------------------------------------------------------------

func get_candidates() -> Array[Employee]:
	return _candidates.duplicate()


func get_candidate(candidate_id: String) -> Employee:
	for candidate: Employee in _candidates:
		if candidate.id == candidate_id:
			return candidate
	return null


## One-time cost of hiring this candidate.
func get_signing_fee(candidate: Employee) -> int:
	return candidate.salary * CONFIG.signing_fee_days if candidate != null else 0


## Reasons this candidate cannot be hired now. Empty = they can.
func get_hire_blockers(candidate_id: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	var candidate: Employee = get_candidate(candidate_id)
	if candidate == null:
		blockers.append("This candidate is no longer available")
		return blockers
	if not OrganizationManager.is_founded():
		blockers.append("Found a company first")
		return blockers
	if get_free_desks() <= 0:
		blockers.append("No free desk. Expand the office")
	if OrganizationManager.rent_arrears > 0:
		blockers.append("Pay the overdue rent first")
	var fee: int = get_signing_fee(candidate)
	if not EconomyManager.can_afford(fee):
		blockers.append("Not enough money for the signing fee (%s short)" % FormatUtils.money(fee - EconomyManager.money))
	return blockers


func hire(candidate_id: String) -> bool:
	if not get_hire_blockers(candidate_id).is_empty():
		return false
	var candidate: Employee = get_candidate(candidate_id)
	var fee: int = get_signing_fee(candidate)
	if fee > 0 and not EconomyManager.spend_money(
		fee, TransactionCategory.SALARY, "Signing fee: %s" % candidate.display_name
	):
		return false
	_candidates.erase(candidate)
	candidate.assignment_id = get_default_assignment_id()
	_employees.append(candidate)
	employee_hired.emit(candidate)
	candidates_changed.emit()
	_announce_staff_change()
	return true


# --- Bonuses ----------------------------------------------------------------

## GameEffects provider: what the staff assigned to support the player grant.
func get_effect(effect_id: String) -> float:
	var total: float = 0.0
	for employee: Employee in _employees:
		var assignment: EmployeeAssignment = get_assignment(employee.assignment_id)
		var role: EmployeeRole = get_role(employee.role_id)
		if assignment == null or role == null:
			continue
		var strength: float = get_primary_skill(employee) * employee.get_efficiency()
		if assignment.grants_support and role.support_effects.has(effect_id):
			total += float(role.support_effects[effect_id]) * strength
		if assignment.effects.has(effect_id):
			total += float(assignment.effects[effect_id]) * strength
	return total


## The bonus lines this employee would give while supporting the player.
func describe_support(employee: Employee) -> PackedStringArray:
	var lines: PackedStringArray = []
	var role: EmployeeRole = get_role(employee.role_id)
	if role != null:
		for effect_id: String in role.support_effects:
			lines.append(GameEffects.describe(
				effect_id,
				float(role.support_effects[effect_id]) * get_primary_skill(employee) * employee.get_efficiency()
			))
	return lines


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	var staff: Array = []
	for employee: Employee in _employees:
		staff.append(employee.to_dictionary())
	var candidates: Array = []
	for candidate: Employee in _candidates:
		candidates.append(candidate.to_dictionary())
	return {"employees": staff, "candidates": candidates, "next_id": _next_id}


func load_save_data(data: Dictionary) -> void:
	_employees.clear()
	_candidates.clear()
	var seen_ids: Dictionary = {}
	var highest_id: int = 0
	# The company is loaded before the staff, so the desk limit is known.
	var capacity: int = OrganizationManager.get_desk_capacity()
	for entry: Variant in SaveDataReader.get_array(data, "employees"):
		var employee: Employee = _restore_person(entry, seen_ids)
		if employee == null or _employees.size() >= capacity:
			continue
		if not _assignments.has(employee.assignment_id):
			employee.assignment_id = get_default_assignment_id()
		_employees.append(employee)
		highest_id = maxi(highest_id, employee.id.to_int())
	for entry: Variant in SaveDataReader.get_array(data, "candidates"):
		var candidate: Employee = _restore_person(entry, seen_ids)
		if candidate != null and _candidates.size() < CONFIG.candidate_count:
			candidate.assignment_id = ""
			_candidates.append(candidate)
			highest_id = maxi(highest_id, candidate.id.to_int())
	_next_id = maxi(SaveDataReader.get_int(data, "next_id", 1), highest_id + 1)
	if OrganizationManager.is_founded() and _candidates.is_empty():
		_generate_candidates()
	candidates_changed.emit()
	_announce_staff_change()


func reset_to_defaults() -> void:
	_employees.clear()
	_candidates.clear()
	_next_id = 1
	candidates_changed.emit()
	_announce_staff_change()


# --- Business day -----------------------------------------------------------

func _on_day_processing(report: Dictionary) -> void:
	var notes: Array = report["notes"]
	var day: int = SaveDataReader.get_int(report, "day")

	# 1. Everyone does their assignment.
	var work_income: int = 0
	for employee: Employee in _employees:
		var assignment: EmployeeAssignment = get_assignment(employee.assignment_id)
		if assignment == null:
			continue
		var efficiency: float = employee.get_efficiency()
		if assignment.produces_income:
			var earned: int = get_expected_income(employee)
			work_income += earned
			employee.total_earned += earned
		_gain_experience(employee, roundi(assignment.xp_gain * (0.5 + 0.5 * efficiency)), notes)
		# Working while exhausted wears people down.
		if assignment.energy_change < 0.0 and employee.energy <= CONFIG.low_energy_threshold:
			employee.morale -= CONFIG.overwork_morale_penalty
		employee.energy = clampf(employee.energy + assignment.energy_change, 0.0, Employee.MAX_CONDITION)
		employee.morale = clampf(employee.morale + assignment.morale_change, 0.0, Employee.MAX_CONDITION)
		employee.days_employed += 1

	if work_income > 0:
		EconomyManager.add_money(
			work_income, TransactionCategory.MAINTENANCE_CONTRACT, "%s, day %d" % [WORK_INCOME_LABEL, day]
		)
		report["income"][WORK_INCOME_LABEL] = work_income
		OrganizationManager.add_company_xp(roundi(work_income * CONFIG.company_xp_per_income))
		OrganizationManager.add_reputation(1)

	# 2. Salaries: one payment when the money is there, otherwise person by
	# person in hiring order so the longest-serving are paid first.
	var payroll: int = get_daily_salary_total()
	var paid: int = 0
	if payroll > 0 and EconomyManager.spend_money(
		payroll, TransactionCategory.SALARY, "Salaries for %d staff, day %d" % [_employees.size(), day]
	):
		paid = payroll
	else:
		for employee: Employee in _employees:
			if employee.salary <= 0:
				continue
			if EconomyManager.spend_money(employee.salary, TransactionCategory.SALARY, "Salary: %s" % employee.display_name):
				paid += employee.salary
			else:
				employee.morale = maxf(0.0, employee.morale - CONFIG.unpaid_morale_penalty)
				notes.append("%s was not paid today." % employee.display_name)
	if paid > 0:
		report["expenses"][SALARY_LABEL] = paid

	# 3. People who have had enough leave.
	for employee: Employee in _employees.duplicate():
		if employee.morale <= CONFIG.resignation_morale:
			_employees.erase(employee)
			notes.append("%s resigned." % employee.display_name)
			employee_left.emit(employee.display_name, REASON_RESIGNED)

	_generate_candidates()
	candidates_changed.emit()
	_announce_staff_change()


# --- Internals --------------------------------------------------------------

func _load_data() -> void:
	for entry: Dictionary in JsonDataLoader.load_entries(ROLES_PATH, "roles"):
		var role: EmployeeRole = EmployeeRole.from_dictionary(entry)
		if role != null and not _roles.has(role.id):
			_roles[role.id] = role
			_role_order.append(role.id)
	for entry: Dictionary in JsonDataLoader.load_entries(ASSIGNMENTS_PATH, "assignments"):
		var assignment: EmployeeAssignment = EmployeeAssignment.from_dictionary(entry)
		if assignment != null and not _assignments.has(assignment.id):
			_assignments[assignment.id] = assignment
			_assignment_order.append(assignment.id)
	var names: Dictionary = JsonDataLoader.load_dictionary(NAMES_PATH)
	for entry: Variant in SaveDataReader.get_array(names, "first_names"):
		if entry is String:
			_first_names.append(entry)
	for entry: Variant in SaveDataReader.get_array(names, "last_names"):
		if entry is String:
			_last_names.append(entry)


func _refresh_candidates() -> void:
	_generate_candidates()
	candidates_changed.emit()


## Replaces the candidate list. Better companies attract better people.
func _generate_candidates() -> void:
	_candidates.clear()
	if not OrganizationManager.is_founded() or _role_order.is_empty():
		return
	var company_level: int = OrganizationManager.company_level
	@warning_ignore("integer_division")
	var skill_low: int = clampi(2 + company_level / 3, 1, CONFIG.max_skill)
	@warning_ignore("integer_division")
	var skill_high: int = clampi(3 + company_level / 2, skill_low, CONFIG.max_skill)
	for index: int in CONFIG.candidate_count:
		var candidate := Employee.new()
		candidate.id = str(_next_id)
		_next_id += 1
		candidate.display_name = _random_name()
		candidate.role_id = _role_order[_rng.randi_range(0, _role_order.size() - 1)]
		var role: EmployeeRole = _roles[candidate.role_id]
		for skill_id: String in Employee.SKILLS:
			candidate.skills[skill_id] = _rng.randi_range(1, maxi(1, skill_low - 1))
		candidate.skills[role.primary_skill] = _rng.randi_range(skill_low, skill_high)
		candidate.productivity = snappedf(_rng.randf_range(0.75, 1.25), 0.01)
		candidate.morale = float(_rng.randi_range(60, 85))
		candidate.salary = calculate_salary(candidate)
		_candidates.append(candidate)


func _random_name() -> String:
	if _first_names.is_empty() or _last_names.is_empty():
		return FALLBACK_NAME
	# A few tries to avoid two people with the same name.
	for attempt: int in 8:
		var candidate_name: String = "%s %s" % [
			_first_names[_rng.randi_range(0, _first_names.size() - 1)],
			_last_names[_rng.randi_range(0, _last_names.size() - 1)],
		]
		if not _is_name_taken(candidate_name):
			return candidate_name
	return "%s %s" % [_first_names[0], _last_names[_rng.randi_range(0, _last_names.size() - 1)]]


func _is_name_taken(candidate_name: String) -> bool:
	for person: Employee in _employees + _candidates:
		if person.display_name == candidate_name:
			return true
	return false


## Adds XP; each level gained raises the role's skill and the salary.
func _gain_experience(employee: Employee, amount: int, notes: Array) -> void:
	if amount <= 0:
		return
	employee.experience += amount
	var role: EmployeeRole = get_role(employee.role_id)
	while employee.experience >= get_xp_for_next_level(employee):
		employee.experience -= get_xp_for_next_level(employee)
		employee.level += 1
		if role != null:
			employee.skills[role.primary_skill] = mini(CONFIG.max_skill, get_primary_skill(employee) + 1)
		employee.salary = calculate_salary(employee)
		notes.append("%s reached level %d. Salary is now %s a day." % [
			employee.display_name, employee.level, FormatUtils.money(employee.salary)
		])


func _restore_person(entry: Variant, seen_ids: Dictionary) -> Employee:
	if not entry is Dictionary:
		return null
	var person: Employee = Employee.from_dictionary(entry, _roles, CONFIG.max_skill)
	if person == null or seen_ids.has(person.id):
		return null
	seen_ids[person.id] = true
	return person


func _announce_staff_change() -> void:
	employees_changed.emit()
	GameEffects.notify_changed()
