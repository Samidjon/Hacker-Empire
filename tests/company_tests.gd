extends RefCounted
## Unit tests for the company and its staff. Run by tests/test_runner.gd,
## which resets every system before each test.

const COMPANY_NAME: String = "Null Pointer Ltd"

var _report: Callable


func _init(report: Callable) -> void:
	_report = report


func _check(condition: bool, description: String) -> void:
	_report.call(condition, description)


# --- Helpers ----------------------------------------------------------------

## Founds a company with plenty of money and a high enough level.
func _found(money: int = 100000) -> void:
	ProgressionManager.add_xp(100000000)
	EconomyManager.add_money(money, TransactionCategory.OTHER)
	OrganizationManager.found_company(COMPANY_NAME)


func _hire_first() -> Employee:
	var candidate: Employee = EmployeeManager.get_candidates()[0]
	EmployeeManager.hire(candidate.id)
	return EmployeeManager.get_employee(candidate.id)


# --- Organization -----------------------------------------------------------

func test_founding() -> void:
	var config: OrganizationConfig = OrganizationManager.CONFIG
	_check(not OrganizationManager.is_founded() and OrganizationManager.get_desk_capacity() == 0, "no company at the start")
	_check(OrganizationManager.validate_company_name(COMPANY_NAME).is_empty(), "a normal name is valid")
	_check(OrganizationManager.validate_company_name("  Byte & Sons  ").is_empty(), "ampersands and outer spaces are fine")
	_check(not OrganizationManager.validate_company_name("ab").is_empty(), "too short is rejected")
	_check(not OrganizationManager.validate_company_name("x".repeat(60)).is_empty(), "too long is rejected")
	_check(not OrganizationManager.validate_company_name("Evil<script>").is_empty(), "odd symbols are rejected")
	_check(OrganizationManager.get_founding_blockers(COMPANY_NAME).size() == 2, "a new player lacks both the level and the money")
	_check(not OrganizationManager.found_company(COMPANY_NAME), "founding is refused while blocked")

	ProgressionManager.add_xp(100000000)
	EconomyManager.add_money(config.founding_cost - 1, TransactionCategory.OTHER)
	_check(OrganizationManager.get_founding_blockers(COMPANY_NAME)[0].begins_with("Not enough money"), "one dollar short is still blocked")
	EconomyManager.add_money(1, TransactionCategory.OTHER)
	var events: Dictionary = {"founded": 0}
	var on_founded: Callable = func() -> void: events["founded"] += 1
	OrganizationManager.company_founded.connect(on_founded)
	_check(OrganizationManager.found_company("  %s " % COMPANY_NAME), "the company can be founded")
	_check(OrganizationManager.is_founded() and OrganizationManager.company_name == COMPANY_NAME, "the name is stored trimmed")
	_check(EconomyManager.money == 0 and events["founded"] == 1, "the fee is charged and company_founded is emitted")
	_check(OrganizationManager.get_office().id == "home_office" and OrganizationManager.get_desk_capacity() == 1, "it starts in the home office with one desk")
	_check(MailManager.has_message("company_founded"), "founding sends the registration mail")
	_check(not OrganizationManager.found_company("Second Co") and OrganizationManager.get_founding_blockers("Second Co") == PackedStringArray(["You already have a company"]), "only one company")
	_check(EmployeeManager.get_candidates().size() == EmployeeManager.CONFIG.candidate_count, "candidates apply once the company exists")
	OrganizationManager.company_founded.disconnect(on_founded)


func test_company_level() -> void:
	OrganizationManager.add_company_xp(500)
	_check(OrganizationManager.company_xp == 0, "no company, no company XP")
	_found()
	var config: OrganizationConfig = OrganizationManager.CONFIG
	var needed: int = OrganizationManager.get_xp_required()
	_check(needed == config.xp_base, "level 1 needs the base XP")
	var levels_seen: Array[int] = []
	var on_level: Callable = func(level: int) -> void: levels_seen.append(level)
	OrganizationManager.company_level_changed.connect(on_level)
	OrganizationManager.add_company_xp(needed - 1)
	_check(OrganizationManager.company_level == 1, "not yet level 2")
	OrganizationManager.add_company_xp(1)
	_check(OrganizationManager.company_level == 2 and OrganizationManager.company_xp == 0 and levels_seen == [2], "reaches level 2 exactly at the threshold")
	_check(OrganizationManager.get_xp_required() > needed, "the next level costs more")
	_check(is_equal_approx(GameEffects.get_total(GameEffects.CONTRACT_REWARD), config.reward_percent_per_level), "company level raises contract pay")
	OrganizationManager.add_company_xp(100000000)
	_check(OrganizationManager.company_level == config.max_company_level and OrganizationManager.get_xp_required() == 0, "company level is capped")
	OrganizationManager.company_level_changed.disconnect(on_level)

	OrganizationManager.add_reputation(5)
	OrganizationManager.add_reputation(-50)
	_check(OrganizationManager.reputation == 0, "reputation cannot go below zero")

	# The player's own contracts build the company too.
	OrganizationManager.reset_to_defaults()
	EconomyManager.add_money(100000, TransactionCategory.OTHER)
	OrganizationManager.found_company(COMPANY_NAME)
	ContractManager.load_save_data({"board": [{"offer_id": 1, "template_id": "cr_locked_diary", "reward": 100, "seed": 1}]})
	ContractManager.accept_contract(1)
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()
	_check(OrganizationManager.company_xp > 0 and OrganizationManager.reputation == config.contract_reputation, "completing a contract gives the company XP and reputation")


func test_office_expansion() -> void:
	_check(OrganizationManager.get_expansion_blockers() == PackedStringArray(["Found a company first"]), "no expansion without a company")
	ProgressionManager.add_xp(100000000)
	EconomyManager.add_money(OrganizationManager.CONFIG.founding_cost, TransactionCategory.OTHER)
	OrganizationManager.found_company(COMPANY_NAME)
	var offices: Array[OfficeDefinition] = OrganizationManager.get_offices()
	var data_ok: bool = offices.size() >= 5
	for index: int in range(1, offices.size()):
		if offices[index].capacity <= offices[index - 1].capacity or offices[index].rent <= offices[index - 1].rent or offices[index].cost <= offices[index - 1].cost:
			data_ok = false
	_check(data_ok, "each office is bigger and dearer than the one before")
	_check(OrganizationManager.get_expansion_blockers()[0].begins_with("Not enough money"), "expansion needs money")
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	var money_before: int = EconomyManager.money
	_check(OrganizationManager.expand_office(), "the office can be expanded")
	var office: OfficeDefinition = OrganizationManager.get_office()
	_check(office.id == "shared_desk" and OrganizationManager.get_desk_capacity() == office.capacity, "the company moves to the next office")
	_check(EconomyManager.money == money_before - office.cost, "the moving cost is charged")
	_check(not OrganizationManager.expand_office() and OrganizationManager.get_office().id == "shared_desk", "the third office needs a higher company level")
	_check(OrganizationManager.get_expansion_blockers()[0].begins_with("Requires company level"), "and says so")
	OrganizationManager.add_company_xp(100000000)
	var guard: int = 0
	while OrganizationManager.expand_office() and guard < 20:
		guard += 1
	_check(OrganizationManager.get_next_office() == null and OrganizationManager.get_expansion_blockers() == PackedStringArray(["This is the largest office"]), "expansion ends at the largest office")


func test_business_day_and_rent() -> void:
	OrganizationManager.advance_time(100000.0)
	_check(OrganizationManager.day == 0, "no days pass without a company")
	_found(OrganizationManager.CONFIG.founding_cost + 1000 + 1000)
	var config: OrganizationConfig = OrganizationManager.CONFIG
	var finished: Array[Dictionary] = []
	var on_finished: Callable = func(report: Dictionary) -> void: finished.append(report)
	OrganizationManager.day_finished.connect(on_finished)

	OrganizationManager.advance_time(config.day_length_seconds * 0.5)
	_check(OrganizationManager.day == 0 and is_equal_approx(OrganizationManager.get_day_progress(), 0.5), "half a day is half the progress")
	OrganizationManager.advance_time(config.day_length_seconds * 0.5)
	_check(OrganizationManager.day == 1 and finished.size() == 1, "a full day ends the business day")
	_check(SaveDataReader.get_dictionary(finished[0], "expenses").is_empty() and finished[0]["net"] == 0, "the home office is rent-free")

	OrganizationManager.expand_office() # shared desks: 1000 to move in, 60 a day
	var money_before: int = EconomyManager.money
	OrganizationManager.end_day()
	_check(EconomyManager.money == money_before - 60 and finished[1]["expenses"][OrganizationManager.RENT_LABEL] == 60, "rent is charged at the end of the day")
	_check(finished[1]["net"] == -60, "the report's net is income minus expenses")
	_check(EconomyManager.get_expenses_by_category().get(TransactionCategory.OFFICE_RENT) == 1060, "rent is booked as office rent")
	OrganizationManager.advance_time(config.day_length_seconds * 3.0)
	_check(OrganizationManager.day == 5 and finished.size() == 5, "a long gap passes several days")

	# Unpaid rent becomes a debt, costs reputation, and is settled later.
	OrganizationManager.add_reputation(10)
	EconomyManager.spend_money(EconomyManager.money, TransactionCategory.OTHER)
	OrganizationManager.end_day()
	_check(EconomyManager.money == 0 and OrganizationManager.rent_arrears == 60, "unpaid rent becomes overdue instead of a negative balance")
	_check(OrganizationManager.reputation == 10 - config.unpaid_rent_reputation_penalty, "missing the rent costs reputation")
	_check(Array(finished[5]["notes"]).size() == 1, "the report notes the missed rent")
	EconomyManager.add_money(100000, TransactionCategory.OTHER)
	_check(OrganizationManager.get_expansion_blockers().has("Pay the overdue rent first ($60)"), "overdue rent blocks expansion")
	_check(EmployeeManager.get_hire_blockers(EmployeeManager.get_candidates()[0].id).has("Pay the overdue rent first"), "and hiring")
	OrganizationManager.end_day()
	_check(OrganizationManager.rent_arrears == 0 and finished[6]["expenses"][OrganizationManager.ARREARS_LABEL] == 60, "overdue rent is settled when money returns")

	for index: int in config.report_history + 5:
		OrganizationManager.end_day()
	var reports: Array[Dictionary] = OrganizationManager.get_reports()
	_check(reports.size() == config.report_history and reports[0]["day"] == OrganizationManager.day, "reports are capped and newest first")
	_check(OrganizationManager.get_last_report()["day"] == OrganizationManager.day, "the last report is available")
	OrganizationManager.day_finished.disconnect(on_finished)


func test_organization_save() -> void:
	_found()
	OrganizationManager.expand_office()
	OrganizationManager.add_company_xp(OrganizationManager.get_xp_required() + 40)
	OrganizationManager.add_reputation(7)
	OrganizationManager.end_day()
	OrganizationManager.advance_time(33.0)
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(not OrganizationManager.is_founded() and OrganizationManager.get_reports().is_empty(), "reset dissolves the company")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(OrganizationManager.is_founded() and OrganizationManager.company_name == COMPANY_NAME, "company restored")
	_check(OrganizationManager.company_level == 2 and OrganizationManager.company_xp == 40 and OrganizationManager.reputation == 7, "level, XP and reputation restored")
	_check(OrganizationManager.get_office().id == "shared_desk" and OrganizationManager.day == 1, "office and day restored")
	_check(is_equal_approx(OrganizationManager.get_seconds_until_next_day(), OrganizationManager.CONFIG.day_length_seconds - 33.0), "time of day restored")
	_check(OrganizationManager.get_last_report()["expenses"][OrganizationManager.RENT_LABEL] == 60, "reports restored")

	OrganizationManager.load_save_data({"founded": true, "name": "<>", "level": 5})
	_check(not OrganizationManager.is_founded(), "a company with an unusable name is not restored")
	OrganizationManager.load_save_data({
		"founded": true, "name": "Okay Co", "level": 999, "xp": -5, "reputation": -9, "office": "moon_base",
		"day": -4, "day_seconds": 1e9, "rent_arrears": -100, "reports": ["junk", {"day": 3, "income": {"x": -5, "7": 2}, "notes": [1, "fine"]}],
	})
	_check(OrganizationManager.company_level == OrganizationManager.CONFIG.max_company_level and OrganizationManager.company_xp == 0, "level and XP are clamped")
	_check(OrganizationManager.reputation == 0 and OrganizationManager.day == 0 and OrganizationManager.rent_arrears == 0, "negative values are clamped")
	_check(OrganizationManager.get_office().id == "home_office", "an unknown office falls back to the first")
	_check(OrganizationManager.get_day_progress() < 1.0, "the time of day stays inside the day")
	var report: Dictionary = OrganizationManager.get_last_report()
	_check(report["income"]["x"] == 0 and Array(report["notes"]) == ["fine"], "damaged reports are sanitised")
	OrganizationManager.load_save_data({})
	_check(not OrganizationManager.is_founded(), "a save from before companies existed has none")


# --- Employees --------------------------------------------------------------

func test_employee_data() -> void:
	var roles: Array[EmployeeRole] = EmployeeManager.get_roles()
	var role_ids: PackedStringArray = []
	var roles_ok: bool = true
	for role: EmployeeRole in roles:
		role_ids.append(role.id)
		if role.income_per_skill <= 0 or role.salary_per_skill <= 0 or role.support_effects.is_empty() or role.description.is_empty():
			roles_ok = false
		for effect_id: String in role.support_effects:
			if GameEffects.describe(effect_id, 1.0).ends_with(effect_id):
				roles_ok = false
	for required: String in ["programmer", "security_analyst", "network_engineer", "reverse_engineer", "ai_engineer", "system_administrator"]:
		_check(role_ids.has(required), "role %s exists" % required)
	_check(roles_ok, "every role earns, costs and gives a described support bonus")
	var assignments: Array[EmployeeAssignment] = EmployeeManager.get_assignments()
	var kinds: Dictionary = {"income": 0, "support": 0, "rest": 0, "training": 0}
	for assignment: EmployeeAssignment in assignments:
		if assignment.produces_income:
			kinds["income"] += 1
		if assignment.grants_support:
			kinds["support"] += 1
		if assignment.energy_change > 0.0:
			kinds["rest"] += 1
		if assignment.xp_gain >= 40:
			kinds["training"] += 1
	_check(kinds["income"] >= 1 and kinds["support"] >= 1 and kinds["rest"] >= 1 and kinds["training"] >= 1, "there are tasks for earning, supporting, training and resting")
	_check(EmployeeManager.get_candidates().is_empty() and EmployeeManager.get_free_desks() == 0, "no candidates and no desks without a company")


func test_recruitment() -> void:
	_found()
	var candidates: Array[Employee] = EmployeeManager.get_candidates()
	var fields_ok: bool = true
	var ids: Dictionary = {}
	for candidate: Employee in candidates:
		ids[candidate.id] = true
		var role: EmployeeRole = EmployeeManager.get_role(candidate.role_id)
		if role == null or candidate.display_name.is_empty() or candidate.salary != EmployeeManager.calculate_salary(candidate):
			fields_ok = false
		if candidate.skills.size() != Employee.SKILLS.size() or candidate.productivity < 0.5 or candidate.productivity > 1.5:
			fields_ok = false
		if candidate.energy != Employee.MAX_CONDITION or candidate.morale <= 0.0 or candidate.experience != 0:
			fields_ok = false
	_check(fields_ok and ids.size() == candidates.size(), "candidates have unique ids, a name, a role, all skills, a salary, productivity, energy and morale")

	var chosen: Employee = candidates[0]
	var fee: int = EmployeeManager.get_signing_fee(chosen)
	_check(fee == chosen.salary * EmployeeManager.CONFIG.signing_fee_days, "the signing fee follows from the salary")
	var hired: Array[String] = []
	var on_hired: Callable = func(employee: Employee) -> void: hired.append(employee.id)
	EmployeeManager.employee_hired.connect(on_hired)
	var money_before: int = EconomyManager.money
	_check(EmployeeManager.hire(chosen.id), "a candidate can be hired")
	_check(EconomyManager.money == money_before - fee and EconomyManager.get_expenses_by_category().get(TransactionCategory.SALARY) == fee, "the signing fee is charged as salary expense")
	_check(EmployeeManager.get_employee(chosen.id) != null and EmployeeManager.get_candidate(chosen.id) == null and hired == [chosen.id], "they move from candidates to staff")
	_check(EmployeeManager.get_employee(chosen.id).assignment_id == EmployeeManager.get_default_assignment_id(), "new staff start on the default task")
	_check(EmployeeManager.get_free_desks() == 0, "the home office is now full")
	_check(EmployeeManager.get_hire_blockers(candidates[1].id)[0].begins_with("No free desk") and not EmployeeManager.hire(candidates[1].id), "no desk, no hire")
	_check(EmployeeManager.get_hire_blockers("gone")[0].contains("no longer available"), "an unknown candidate cannot be hired")
	EmployeeManager.employee_hired.disconnect(on_hired)

	OrganizationManager.expand_office()
	EconomyManager.spend_money(EconomyManager.money, TransactionCategory.OTHER)
	_check(EmployeeManager.get_hire_blockers(candidates[1].id)[0].begins_with("Not enough money"), "the signing fee must be affordable")

	var left: Array = []
	var on_left: Callable = func(employee_name: String, reason: String) -> void: left.append([employee_name, reason])
	EmployeeManager.employee_left.connect(on_left)
	_check(EmployeeManager.dismiss(chosen.id) and EmployeeManager.get_employee_count() == 0, "staff can be dismissed")
	_check(left == [[chosen.display_name, EmployeeManager.REASON_DISMISSED]] and not EmployeeManager.dismiss(chosen.id), "dismissal is announced once")
	EmployeeManager.employee_left.disconnect(on_left)

	# Candidates are renewed every business day, and a better company attracts better people.
	var before: Array = EmployeeManager.get_candidates().map(func(candidate: Employee) -> String: return candidate.id)
	OrganizationManager.end_day()
	var after: Array = EmployeeManager.get_candidates().map(func(candidate: Employee) -> String: return candidate.id)
	var overlap: bool = false
	for candidate_id: String in after:
		if before.has(candidate_id):
			overlap = true
	_check(not overlap and after.size() == EmployeeManager.CONFIG.candidate_count, "a new day brings new candidates")
	OrganizationManager.add_company_xp(100000000)
	var best: int = 0
	for candidate: Employee in EmployeeManager.get_candidates():
		best = maxi(best, EmployeeManager.get_primary_skill(candidate))
	_check(best >= 4, "a high-level company attracts skilled candidates")


func test_daily_work() -> void:
	_found()
	var employee: Employee = _hire_first()
	var role: EmployeeRole = EmployeeManager.get_role(employee.role_id)
	employee.morale = 100.0
	employee.skills[role.primary_skill] = 5
	employee.productivity = 1.0
	employee.salary = EmployeeManager.calculate_salary(employee)
	_check(is_equal_approx(employee.get_efficiency(), 1.0), "a rested, happy employee works at full efficiency")
	var expected: int = role.income_per_skill * 5
	_check(EmployeeManager.get_expected_income(employee) == expected, "income is rate x skill x productivity x efficiency")
	_check(expected > employee.salary, "a competent employee earns more than they cost")

	var money_before: int = EconomyManager.money
	var xp_before: int = OrganizationManager.company_xp
	OrganizationManager.end_day()
	var report: Dictionary = OrganizationManager.get_last_report()
	_check(report["income"][EmployeeManager.WORK_INCOME_LABEL] == expected, "client work income appears in the report")
	_check(report["expenses"][EmployeeManager.SALARY_LABEL] == employee.salary, "the salary appears in the report")
	_check(EconomyManager.money == money_before + expected - employee.salary and report["net"] == expected - employee.salary, "the balance moves by exactly the day's net")
	_check(EconomyManager.get_income_by_category().get(TransactionCategory.MAINTENANCE_CONTRACT) == expected, "staff income is booked as maintenance contracts")
	_check(employee.energy < Employee.MAX_CONDITION and employee.experience > 0 and employee.days_employed == 1 and employee.total_earned == expected, "a day of work costs energy and gives experience")
	_check(OrganizationManager.company_xp > xp_before and OrganizationManager.reputation == 1, "staff work builds the company")

	# Tired people earn less; rest restores them.
	employee.energy = 0.0
	_check(EmployeeManager.get_expected_income(employee) < expected / 2, "an exhausted employee earns much less")
	var morale_before: float = employee.morale
	OrganizationManager.end_day()
	_check(employee.morale < morale_before - 1.5, "working while exhausted costs extra morale")
	EmployeeManager.assign(employee.id, "rest")
	OrganizationManager.end_day()
	_check(employee.energy >= 40.0 and not OrganizationManager.get_last_report()["income"].has(EmployeeManager.WORK_INCOME_LABEL), "time off restores energy and earns nothing")

	# Training gives much more experience and, in time, a level.
	EmployeeManager.assign(employee.id, "training")
	var level_before: int = employee.level
	var salary_before: int = employee.salary
	for index: int in 3:
		employee.energy = 100.0
		OrganizationManager.end_day()
	_check(employee.level > level_before, "training levels an employee up")
	_check(EmployeeManager.get_primary_skill(employee) == 6 and employee.salary > salary_before, "a level raises the role skill and the salary")
	_check(not EmployeeManager.assign(employee.id, "juggling") and not EmployeeManager.assign("nobody", "rest"), "unknown tasks and people are rejected")


func test_support_and_unpaid() -> void:
	_found()
	var employee: Employee = _hire_first()
	var role: EmployeeRole = EmployeeManager.get_role(employee.role_id)
	employee.morale = 100.0
	employee.skills[role.primary_skill] = 4
	var effect_id: String = role.support_effects.keys()[0]
	var base: float = GameEffects.get_total(effect_id)
	_check(EmployeeManager.assign(employee.id, "support"), "an employee can be assigned to support the player")
	var bonus: float = float(role.support_effects[effect_id]) * 4
	_check(is_equal_approx(GameEffects.get_total(effect_id), base + bonus), "support gives the role's bonus x skill, at once")
	_check(EmployeeManager.describe_support(employee).size() == role.support_effects.size(), "the support bonus is described")
	employee.energy = 0.0
	_check(GameEffects.get_total(effect_id) < base + bonus, "a tired supporter gives less")
	EmployeeManager.assign(employee.id, "client_work")
	_check(is_equal_approx(GameEffects.get_total(effect_id), base), "the bonus ends when they stop supporting")

	# Salaries that cannot be paid: no debt, but morale collapses and people leave.
	EmployeeManager.assign(employee.id, "rest")
	EconomyManager.spend_money(EconomyManager.money, TransactionCategory.OTHER)
	employee.morale = 60.0
	var left: Array = []
	var on_left: Callable = func(employee_name: String, reason: String) -> void: left.append([employee_name, reason])
	EmployeeManager.employee_left.connect(on_left)
	OrganizationManager.end_day()
	_check(EconomyManager.money == 0, "an unpaid salary never makes the balance negative")
	_check(is_equal_approx(employee.morale, 60.0 + 6.0 - EmployeeManager.CONFIG.unpaid_morale_penalty), "not being paid costs morale")
	_check(Array(OrganizationManager.get_last_report()["notes"]).has("%s was not paid today." % employee.display_name), "the report says who was not paid")
	var name_before: String = employee.display_name
	OrganizationManager.end_day()
	OrganizationManager.end_day()
	OrganizationManager.end_day()
	_check(EmployeeManager.get_employee_count() == 0 and left == [[name_before, EmployeeManager.REASON_RESIGNED]], "an employee who is never paid resigns")
	EmployeeManager.employee_left.disconnect(on_left)

	# Partial payroll: the longest-serving are paid first.
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	OrganizationManager.expand_office()
	var first: Employee = _hire_first()
	var second: Employee = _hire_first()
	EconomyManager.spend_money(EconomyManager.money, TransactionCategory.OTHER)
	EmployeeManager.assign(first.id, "rest")
	EmployeeManager.assign(second.id, "rest")
	OrganizationManager.end_day() # rent (60) is unpaid, both salaries unpaid
	EconomyManager.add_money(OrganizationManager.rent_arrears + OrganizationManager.get_daily_rent() + first.salary, TransactionCategory.OTHER)
	var second_morale: float = second.morale
	OrganizationManager.end_day()
	_check(EconomyManager.money == 0 and OrganizationManager.get_last_report()["expenses"][EmployeeManager.SALARY_LABEL] == first.salary, "with too little money, the first hire is paid and the balance stops at zero")
	_check(second.morale < second_morale, "and the one left unpaid loses morale")


func test_employee_save() -> void:
	_found()
	OrganizationManager.expand_office()
	var first: Employee = _hire_first()
	var second: Employee = _hire_first()
	EmployeeManager.assign(second.id, "support")
	OrganizationManager.end_day()
	var candidates_before: Array = EmployeeManager.get_candidates().map(func(candidate: Employee) -> String: return candidate.id)
	var snapshot: Dictionary = first.to_dictionary()
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(EmployeeManager.get_employee_count() == 0 and EmployeeManager.get_candidates().is_empty(), "reset clears staff and candidates")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(EmployeeManager.get_employee_count() == 2, "staff restored")
	var restored: Employee = EmployeeManager.get_employee(first.id)
	_check(restored != null and restored.to_dictionary() == snapshot, "every field of an employee is restored")
	_check(EmployeeManager.get_employee(second.id).assignment_id == "support", "assignments restored")
	var candidates_after: Array = EmployeeManager.get_candidates().map(func(candidate: Employee) -> String: return candidate.id)
	_check(candidates_after == candidates_before, "the same candidates are waiting after loading")
	OrganizationManager.end_day()
	var newest: int = 0
	for candidate: Employee in EmployeeManager.get_candidates():
		newest = maxi(newest, candidate.id.to_int())
	_check(newest > second.id.to_int() and not EmployeeManager.get_candidates().any(func(candidate: Employee) -> bool: return candidate.id == first.id), "new people get fresh ids after loading")

	# Damaged data.
	var good: Dictionary = first.to_dictionary()
	EmployeeManager.load_save_data({"employees": [
		good, good, "junk", {"id": "77", "name": "No Role", "role": "astronaut"},
		{"id": "78", "name": "Odd Values", "role": "programmer", "energy": 900, "morale": -5, "productivity": 40,
			"skills": {"programming": 99}, "assignment": "juggling", "salary": -3},
		{"id": "79", "name": "Third", "role": "programmer"},
	]})
	_check(EmployeeManager.get_employee_count() == 2, "duplicates, junk, unknown roles and staff beyond the desk limit are dropped")
	var odd: Employee = EmployeeManager.get_employee("78")
	_check(odd != null and odd.energy == 100.0 and odd.morale == 0.0 and odd.productivity == 1.5, "condition values are clamped")
	_check(odd.get_skill("programming") == EmployeeManager.CONFIG.max_skill and odd.get_skill("ai") == 1, "skills are clamped and filled in")
	_check(odd.assignment_id == EmployeeManager.get_default_assignment_id() and odd.salary == 0, "an unknown task falls back to the default")
	_check(EmployeeManager.get_candidates().size() == EmployeeManager.CONFIG.candidate_count, "missing candidates are regenerated for an existing company")
	OrganizationManager.reset_to_defaults()
	EmployeeManager.load_save_data({"employees": [good]})
	_check(EmployeeManager.get_employee_count() == 0, "staff cannot exist without a company")
