extends Node
## OrganizationManager (autoload)
##
## Owns the player's company: founding, name, company level and reputation,
## the office and its expansion, rent, and the business-day clock.
##
## It knows nothing about employees. Each business day it builds a report,
## charges the rent, then emits day_processing(report); any system that acts
## daily (EmployeeManager, later research) does its work in that signal and
## writes its income, expenses and notes into the same report.

signal company_founded
signal company_changed
signal company_level_changed(new_level: int)
signal office_expanded(office_id: String)
## Emitted during a day change. Listeners may add to the report:
## report.income[label] = amount, report.expenses[label] = amount,
## report.notes.append(text).
signal day_processing(report: Dictionary)
signal day_finished(report: Dictionary)

const CONFIG: OrganizationConfig = preload("res://resources/configurations/organization_config.tres")
const OFFICES_PATH: String = "res://data/organization/offices.json"
const SAVE_SECTION: String = "organization"
const RENT_LABEL: String = "Office rent"
const ARREARS_LABEL: String = "Overdue rent"

var company_name: String = ""
var company_level: int = 1
## XP toward the next company level.
var company_xp: int = 0
var reputation: int = 0
## Business days since founding.
var day: int = 0
## Rent that could not be paid. Settled automatically; blocks expansion and hiring.
var rent_arrears: int = 0

var _is_founded: bool = false
var _offices: Array[OfficeDefinition] = []
var _office_index: int = 0
var _day_seconds: float = 0.0
## Daily reports, oldest first.
var _reports: Array[Dictionary] = []


func _ready() -> void:
	for entry: Dictionary in JsonDataLoader.load_entries(OFFICES_PATH, "offices"):
		var office: OfficeDefinition = OfficeDefinition.from_dictionary(entry)
		if office != null:
			_offices.append(office)
	if _offices.is_empty():
		push_error("OrganizationManager: no offices defined in %s." % OFFICES_PATH)
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_provider(get_effect)
	ContractManager.contract_completed.connect(_on_contract_completed)


func _process(delta: float) -> void:
	advance_time(delta)


## Moves the business clock forward. Called every frame; exposed so tests can
## fast-forward. One call can pass several days.
func advance_time(seconds: float) -> void:
	if not _is_founded or seconds <= 0.0:
		return
	_day_seconds += seconds
	while _day_seconds >= CONFIG.day_length_seconds:
		_day_seconds -= CONFIG.day_length_seconds
		end_day()


# --- Founding ---------------------------------------------------------------

func is_founded() -> bool:
	return _is_founded


## Returns an error message, or an empty string when the name is acceptable.
func validate_company_name(candidate: String) -> String:
	var trimmed: String = candidate.strip_edges()
	if trimmed.length() < CONFIG.min_name_length:
		return "Company name must be at least %d characters." % CONFIG.min_name_length
	if trimmed.length() > CONFIG.max_name_length:
		return "Company name must be at most %d characters." % CONFIG.max_name_length
	for index: int in trimmed.length():
		var character: String = trimmed[index]
		var code: int = trimmed.unicode_at(index)
		var is_letter_or_digit: bool = (
			(code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		)
		if not is_letter_or_digit and not " .-&'".contains(character):
			return "Company name may only contain letters, numbers, spaces and . - & '"
	return ""


## Reasons a company with this name cannot be founded now. Empty = it can.
func get_founding_blockers(candidate_name: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	if _is_founded:
		blockers.append("You already have a company")
		return blockers
	var name_error: String = validate_company_name(candidate_name)
	if not name_error.is_empty():
		blockers.append(name_error)
	if ProgressionManager.level < CONFIG.required_level:
		blockers.append("Requires level %d" % CONFIG.required_level)
	if not EconomyManager.can_afford(CONFIG.founding_cost):
		blockers.append("Not enough money (%s short)" % FormatUtils.money(CONFIG.founding_cost - EconomyManager.money))
	return blockers


func found_company(new_name: String) -> bool:
	if not get_founding_blockers(new_name).is_empty():
		return false
	if CONFIG.founding_cost > 0 and not EconomyManager.spend_money(
		CONFIG.founding_cost, TransactionCategory.OTHER, "Company registration"
	):
		return false
	_is_founded = true
	company_name = new_name.strip_edges()
	company_founded.emit()
	_announce_change()
	return true


# --- Level and reputation ---------------------------------------------------

## Company XP needed to finish the current level. Zero at the maximum level.
func get_xp_required() -> int:
	if company_level >= CONFIG.max_company_level:
		return 0
	return maxi(1, roundi(CONFIG.xp_base * pow(float(company_level), CONFIG.xp_exponent)))


func add_company_xp(amount: int) -> void:
	if not _is_founded or amount <= 0 or company_level >= CONFIG.max_company_level:
		return
	company_xp += amount
	var old_level: int = company_level
	while company_level < CONFIG.max_company_level and company_xp >= get_xp_required():
		company_xp -= get_xp_required()
		company_level += 1
	if company_level >= CONFIG.max_company_level:
		company_xp = 0
	if company_level != old_level:
		company_level_changed.emit(company_level)
	_announce_change()


## `amount` may be negative; reputation never drops below zero.
func add_reputation(amount: int) -> void:
	if not _is_founded or amount == 0:
		return
	reputation = maxi(0, reputation + amount)
	company_changed.emit()


## GameEffects provider: a known company gets paid better.
func get_effect(effect_id: String) -> float:
	if _is_founded and effect_id == GameEffects.CONTRACT_REWARD:
		return CONFIG.reward_percent_per_level * (company_level - 1)
	return 0.0


# --- Office -----------------------------------------------------------------

func get_offices() -> Array[OfficeDefinition]:
	return _offices


func get_office() -> OfficeDefinition:
	return _offices[_office_index] if not _offices.is_empty() else null


## Position of the current office in the list (0 = home office).
func get_office_index() -> int:
	return _office_index


## True when the company has premises the player can walk into.
func has_external_office() -> bool:
	return _is_founded and _office_index > 0


## The office an expansion would move to, or null at the largest one.
func get_next_office() -> OfficeDefinition:
	return _offices[_office_index + 1] if _office_index + 1 < _offices.size() else null


## Desks available for employees. Zero without a company.
func get_desk_capacity() -> int:
	var office: OfficeDefinition = get_office()
	return office.capacity if _is_founded and office != null else 0


func get_daily_rent() -> int:
	var office: OfficeDefinition = get_office()
	return office.rent if _is_founded and office != null else 0


func get_expansion_blockers() -> PackedStringArray:
	var blockers: PackedStringArray = []
	if not _is_founded:
		blockers.append("Found a company first")
		return blockers
	var next: OfficeDefinition = get_next_office()
	if next == null:
		blockers.append("This is the largest office")
		return blockers
	if company_level < next.required_company_level:
		blockers.append("Requires company level %d" % next.required_company_level)
	if rent_arrears > 0:
		blockers.append("Pay the overdue rent first (%s)" % FormatUtils.money(rent_arrears))
	if not EconomyManager.can_afford(next.cost):
		blockers.append("Not enough money (%s short)" % FormatUtils.money(next.cost - EconomyManager.money))
	return blockers


## Moves the company into the next office.
func expand_office() -> bool:
	if not get_expansion_blockers().is_empty():
		return false
	var next: OfficeDefinition = get_next_office()
	if next.cost > 0 and not EconomyManager.spend_money(
		next.cost, TransactionCategory.OFFICE_RENT, "Move to %s" % next.title
	):
		return false
	_office_index += 1
	office_expanded.emit(next.id)
	_announce_change()
	return true


# --- Business days ----------------------------------------------------------

## 0.0 - 1.0 through the current business day.
func get_day_progress() -> float:
	return clampf(_day_seconds / CONFIG.day_length_seconds, 0.0, 1.0)


func get_seconds_until_next_day() -> float:
	return maxf(0.0, CONFIG.day_length_seconds - _day_seconds)


## Ends the business day now: rent, then everything listening to
## day_processing, then the report is filed.
func end_day() -> void:
	if not _is_founded:
		return
	day += 1
	var report: Dictionary = {"day": day, "income": {}, "expenses": {}, "notes": []}
	_charge_rent(report)
	_charge_running_costs(report)
	day_processing.emit(report)

	var net: int = 0
	for label: String in report["income"]:
		net += int(report["income"][label])
	for label: String in report["expenses"]:
		net -= int(report["expenses"][label])
	report["net"] = net
	_reports.append(report)
	if _reports.size() > CONFIG.report_history:
		_reports = _reports.slice(_reports.size() - CONFIG.report_history)
	day_finished.emit(report)
	company_changed.emit()


## Daily reports, newest first. Each: {day, income, expenses, notes, net}.
func get_reports() -> Array[Dictionary]:
	var newest_first: Array[Dictionary] = []
	for index: int in range(_reports.size() - 1, -1, -1):
		newest_first.append(_reports[index].duplicate(true))
	return newest_first


func get_last_report() -> Dictionary:
	return _reports.back().duplicate(true) if not _reports.is_empty() else {}


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	var office: OfficeDefinition = get_office()
	return {
		"founded": _is_founded,
		"name": company_name,
		"level": company_level,
		"xp": company_xp,
		"reputation": reputation,
		"office": office.id if office != null else "",
		"day": day,
		"day_seconds": _day_seconds,
		"rent_arrears": rent_arrears,
		"reports": _reports.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_reset_state()
	var saved_name: String = SaveDataReader.get_string(data, "name")
	# A company needs a usable name; anything else means "no company".
	if data.get("founded") != true or not validate_company_name(saved_name).is_empty():
		_announce_change()
		return
	_is_founded = true
	company_name = saved_name.strip_edges()
	company_level = clampi(SaveDataReader.get_int(data, "level", 1), 1, CONFIG.max_company_level)
	company_xp = 0
	if company_level < CONFIG.max_company_level:
		company_xp = clampi(SaveDataReader.get_int(data, "xp"), 0, get_xp_required() - 1)
	reputation = maxi(0, SaveDataReader.get_int(data, "reputation"))
	var office_id: String = SaveDataReader.get_string(data, "office")
	for index: int in _offices.size():
		if _offices[index].id == office_id:
			_office_index = index
	day = maxi(0, SaveDataReader.get_int(data, "day"))
	_day_seconds = clampf(SaveDataReader.get_float(data, "day_seconds"), 0.0, CONFIG.day_length_seconds - 0.01)
	rent_arrears = maxi(0, SaveDataReader.get_int(data, "rent_arrears"))
	for entry: Variant in SaveDataReader.get_array(data, "reports"):
		if entry is Dictionary:
			_reports.append(_sanitize_report(entry))
	if _reports.size() > CONFIG.report_history:
		_reports = _reports.slice(_reports.size() - CONFIG.report_history)
	_announce_change()


func reset_to_defaults() -> void:
	_reset_state()
	_announce_change()


# --- Internals --------------------------------------------------------------

func _reset_state() -> void:
	_is_founded = false
	company_name = ""
	company_level = 1
	company_xp = 0
	reputation = 0
	day = 0
	rent_arrears = 0
	_office_index = 0
	_day_seconds = 0.0
	_reports.clear()


func _charge_rent(report: Dictionary) -> void:
	# Old debt first, as far as the balance reaches.
	if rent_arrears > 0:
		var settled: int = mini(rent_arrears, EconomyManager.money)
		if settled > 0 and EconomyManager.spend_money(settled, TransactionCategory.OFFICE_RENT, ARREARS_LABEL):
			rent_arrears -= settled
			report["expenses"][ARREARS_LABEL] = settled
	var rent: int = get_daily_rent()
	if rent <= 0:
		return
	if EconomyManager.spend_money(rent, TransactionCategory.OFFICE_RENT, "%s, day %d" % [get_office().title, day]):
		report["expenses"][RENT_LABEL] = rent
	else:
		rent_arrears += rent
		reputation = maxi(0, reputation - CONFIG.unpaid_rent_reputation_penalty)
		report["notes"].append("Rent of %s could not be paid and is now overdue." % FormatUtils.money(rent))


## Electricity, server maintenance and whatever else is registered in
## GameEffects. An unpaid bill joins the overdue total, like unpaid rent.
func _charge_running_costs(report: Dictionary) -> void:
	for cost: Dictionary in GameEffects.get_daily_costs():
		var provider: Callable = cost["provider"]
		if not provider.is_valid():
			continue
		var amount: int = int(provider.call())
		if amount <= 0:
			continue
		var label: String = cost["label"]
		if EconomyManager.spend_money(amount, cost["category"], "%s, day %d" % [label, day]):
			report["expenses"][label] = amount
		else:
			rent_arrears += amount
			report["notes"].append("%s of %s could not be paid and is now overdue." % [label, FormatUtils.money(amount)])


func _sanitize_report(raw: Dictionary) -> Dictionary:
	var report: Dictionary = {
		"day": maxi(0, SaveDataReader.get_int(raw, "day")),
		"income": {}, "expenses": {}, "notes": [],
		"net": SaveDataReader.get_int(raw, "net"),
	}
	for section: String in ["income", "expenses"]:
		var entries: Dictionary = SaveDataReader.get_dictionary(raw, section)
		for label: Variant in entries:
			if label is String:
				report[section][label] = maxi(0, SaveDataReader.get_int(entries, label))
	for note: Variant in SaveDataReader.get_array(raw, "notes"):
		if note is String:
			report["notes"].append(note)
	return report


func _on_contract_completed(result: Dictionary) -> void:
	if not _is_founded:
		return
	add_company_xp(roundi(SaveDataReader.get_int(result, "xp") * CONFIG.contract_xp_share))
	add_reputation(CONFIG.contract_reputation)


func _announce_change() -> void:
	company_changed.emit()
	GameEffects.notify_changed()
