extends Node
## EventManager (autoload)
##
## Random world events with choices. Events are defined in
## data/events/events.json: when they can happen (conditions), how likely
## they are (weight), and for each choice a list of effects. This manager
## decides when an event occurs, holds it until the player chooses, and
## applies the chosen effects through the other managers.
##
## Effect types: money, xp, reputation, heat, company_reputation, company_xp,
## morale (all staff), employee_morale / employee_leaves (the employee the
## event is about), research_progress.

signal event_triggered(event_id: String)
## `outcome` lists what the choice did, as player-facing lines.
signal event_resolved(event_id: String, choice_index: int, outcome: PackedStringArray)

const CONFIG: EventConfig = preload("res://resources/configurations/event_config.tres")
const DATA_PATH: String = "res://data/events/events.json"
const SAVE_SECTION: String = "events"
const EMPLOYEE_TOKEN: String = "{employee}"
const COMPANY_TOKEN: String = "{company}"

var _definitions: Dictionary = {} # event id -> Dictionary from data
var _definition_order: Array[String] = []
## The event waiting for a decision: {id, employee_id, employee_name}. Empty when none.
var _pending: Dictionary = {}
var _seconds_until_check: float = 0.0
## Resolved events, oldest first: {id, title, choice, outcome}.
var _history: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "events"):
		var event_id: String = SaveDataReader.get_string(entry, "id")
		if event_id.is_empty() or _definitions.has(event_id) or SaveDataReader.get_array(entry, "choices").is_empty():
			push_warning("EventManager: skipped an event with a missing or duplicate id, or no choices.")
			continue
		_definitions[event_id] = entry
		_definition_order.append(event_id)
	_seconds_until_check = CONFIG.grace_period_seconds
	SaveManager.register_section(SAVE_SECTION, self)


func _process(delta: float) -> void:
	# Nothing happens to the player while they are in the main menu.
	if GameManager.is_in_game():
		advance_time(delta)


## Moves the event clock forward. Called every frame; exposed for tests.
func advance_time(seconds: float) -> void:
	if seconds <= 0.0 or has_pending_event():
		return
	_seconds_until_check -= seconds
	if _seconds_until_check <= 0.0:
		_seconds_until_check = CONFIG.check_interval_seconds
		if _rng.randf() < CONFIG.trigger_chance:
			trigger_random_event()


# --- Queries ----------------------------------------------------------------

func get_event_ids() -> PackedStringArray:
	return PackedStringArray(_definition_order)


func has_pending_event() -> bool:
	return not _pending.is_empty()


func get_pending_event_id() -> String:
	return SaveDataReader.get_string(_pending, "id")


## The waiting event, ready to show:
## {id, title, description, choices: [{label, description, cost, enabled, blocker}]}.
func get_pending_event() -> Dictionary:
	if not has_pending_event():
		return {}
	var definition: Dictionary = _definitions[_pending["id"]]
	var choices: Array[Dictionary] = []
	for raw: Variant in SaveDataReader.get_array(definition, "choices"):
		if not raw is Dictionary:
			continue
		var cost: int = _choice_cost(raw)
		var affordable: bool = EconomyManager.can_afford(cost)
		choices.append({
			"label": _fill_tokens(SaveDataReader.get_string(raw, "label", "Continue")),
			"description": _fill_tokens(SaveDataReader.get_string(raw, "description")),
			"cost": cost,
			"enabled": affordable,
			"blocker": "" if affordable else "You cannot afford %s" % FormatUtils.money(cost),
		})
	return {
		"id": _pending["id"],
		"title": SaveDataReader.get_string(definition, "title", "Event"),
		"description": _fill_tokens(SaveDataReader.get_string(definition, "description")),
		"choices": choices,
	}


## True when the event's conditions hold right now.
func is_eligible(event_id: String) -> bool:
	if not _definitions.has(event_id):
		return false
	var conditions: Dictionary = SaveDataReader.get_dictionary(_definitions[event_id], "conditions")
	if ProgressionManager.level < SaveDataReader.get_int(conditions, "min_level", 1):
		return false
	if EmployeeManager.get_employee_count() < SaveDataReader.get_int(conditions, "min_employees"):
		return false
	if conditions.get("requires_company") == true and not OrganizationManager.is_founded():
		return false
	if conditions.get("requires_active_research") == true and not ResearchManager.has_active_project():
		return false
	if conditions.get("requires_released_product") == true and ProductManager.get_released_count() == 0:
		return false
	# Something that can fail: a server in the rack or a running subscription.
	if conditions.get("requires_infrastructure") == true:
		var has_server: bool = HardwareManager.get_installed(HardwareCategory.SERVER) != null
		if not has_server and ProductManager.get_daily_maintenance_cost() == 0:
			return false
	return true


## Resolved events, newest first: {id, title, choice, outcome}.
func get_history() -> Array[Dictionary]:
	var newest_first: Array[Dictionary] = []
	for index: int in range(_history.size() - 1, -1, -1):
		newest_first.append(_history[index].duplicate(true))
	return newest_first


# --- Triggering and resolving -----------------------------------------------

## Starts one eligible event chosen by weight. False when none can happen.
func trigger_random_event() -> bool:
	var eligible: Array[String] = []
	var total_weight: float = 0.0
	for event_id: String in _definition_order:
		if is_eligible(event_id):
			eligible.append(event_id)
			total_weight += _weight(event_id)
	if eligible.is_empty() or total_weight <= 0.0:
		return false
	var roll: float = _rng.randf() * total_weight
	for event_id: String in eligible:
		roll -= _weight(event_id)
		if roll <= 0.0:
			return trigger_event(event_id)
	return trigger_event(eligible.back())


## Starts a specific event if its conditions hold and nothing is waiting.
func trigger_event(event_id: String) -> bool:
	if has_pending_event() or not is_eligible(event_id):
		return false
	_pending = {"id": event_id, "employee_id": "", "employee_name": ""}
	# Events about a person pick who it is now, so the text and the effects agree.
	var staff: Array[Employee] = EmployeeManager.get_employees()
	if not staff.is_empty():
		var chosen: Employee = staff[_rng.randi_range(0, staff.size() - 1)]
		_pending["employee_id"] = chosen.id
		_pending["employee_name"] = chosen.display_name
	event_triggered.emit(event_id)
	return true


## Applies the choice at `choice_index` of the waiting event.
func choose(choice_index: int) -> bool:
	var event: Dictionary = get_pending_event()
	var choices: Array = SaveDataReader.get_array(event, "choices")
	if choice_index < 0 or choice_index >= choices.size() or not choices[choice_index]["enabled"]:
		return false
	var event_id: String = _pending["id"]
	var raw_choice: Dictionary = SaveDataReader.get_array(_definitions[event_id], "choices")[choice_index]
	var outcome: PackedStringArray = []
	for effect: Variant in SaveDataReader.get_array(raw_choice, "effects"):
		if effect is Dictionary:
			_apply_effect(effect, outcome)
	if outcome.is_empty():
		outcome.append("Nothing changes.")

	_history.append({
		"id": event_id, "title": event["title"], "choice": choices[choice_index]["label"],
		"outcome": Array(outcome),
	})
	if _history.size() > CONFIG.max_history:
		_history = _history.slice(_history.size() - CONFIG.max_history)
	_pending = {}
	event_resolved.emit(event_id, choice_index, outcome)
	return true


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"pending": _pending.duplicate(),
		"seconds_until_check": _seconds_until_check,
		"history": _history.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_pending = {}
	var saved_pending: Dictionary = SaveDataReader.get_dictionary(data, "pending")
	var pending_id: String = SaveDataReader.get_string(saved_pending, "id")
	if _definitions.has(pending_id):
		_pending = {
			"id": pending_id,
			"employee_id": SaveDataReader.get_string(saved_pending, "employee_id"),
			"employee_name": SaveDataReader.get_string(saved_pending, "employee_name"),
		}
	_seconds_until_check = clampf(
		SaveDataReader.get_float(data, "seconds_until_check", CONFIG.check_interval_seconds),
		1.0, maxf(CONFIG.check_interval_seconds, CONFIG.grace_period_seconds)
	)
	_history.clear()
	for entry: Variant in SaveDataReader.get_array(data, "history"):
		if not entry is Dictionary:
			continue
		var outcome: Array = []
		for line: Variant in SaveDataReader.get_array(entry, "outcome"):
			if line is String:
				outcome.append(line)
		_history.append({
			"id": SaveDataReader.get_string(entry, "id"),
			"title": SaveDataReader.get_string(entry, "title", "Event"),
			"choice": SaveDataReader.get_string(entry, "choice"),
			"outcome": outcome,
		})
	if _history.size() > CONFIG.max_history:
		_history = _history.slice(_history.size() - CONFIG.max_history)
	if has_pending_event():
		event_triggered.emit(_pending["id"])


func reset_to_defaults() -> void:
	_pending = {}
	_history.clear()
	_seconds_until_check = CONFIG.grace_period_seconds


# --- Internals --------------------------------------------------------------

func _weight(event_id: String) -> float:
	return maxf(0.0, SaveDataReader.get_float(_definitions[event_id], "weight", 1.0))


## Money a choice takes from the player (sum of its negative money effects).
func _choice_cost(raw_choice: Dictionary) -> int:
	var cost: int = 0
	for effect: Variant in SaveDataReader.get_array(raw_choice, "effects"):
		if effect is Dictionary and SaveDataReader.get_string(effect, "type") == "money":
			cost += maxi(0, -SaveDataReader.get_int(effect, "amount"))
	return cost


func _fill_tokens(text: String) -> String:
	var employee_name: String = SaveDataReader.get_string(_pending, "employee_name", "A colleague")
	if employee_name.is_empty():
		employee_name = "A colleague"
	var company: String = OrganizationManager.company_name if OrganizationManager.is_founded() else "your business"
	return text.replace(EMPLOYEE_TOKEN, employee_name).replace(COMPANY_TOKEN, company)


## Applies one effect and records what it did.
func _apply_effect(effect: Dictionary, outcome: PackedStringArray) -> void:
	var amount: int = SaveDataReader.get_int(effect, "amount")
	match SaveDataReader.get_string(effect, "type"):
		"money":
			var category: String = SaveDataReader.get_string(effect, "category", TransactionCategory.OTHER)
			var title: String = SaveDataReader.get_string(_definitions[_pending["id"]], "title", "Event")
			if amount > 0 and EconomyManager.add_money(amount, category, title):
				outcome.append("You receive %s." % FormatUtils.money(amount))
			elif amount < 0 and EconomyManager.spend_money(-amount, category, title):
				outcome.append("You pay %s." % FormatUtils.money(-amount))
		"xp":
			ProgressionManager.add_xp(amount, "event")
			outcome.append("+%d XP." % amount)
		"reputation":
			var is_underground: bool = SaveDataReader.get_string(effect, "track") == "underground"
			ReputationManager.add_reputation(
				ReputationManager.Kind.UNDERGROUND if is_underground else ReputationManager.Kind.WHITE, amount
			)
			outcome.append("%s reputation %+d." % ["Underground" if is_underground else "White", amount])
		"heat":
			ReputationManager.add_heat(float(amount))
			outcome.append("Heat %+d." % amount)
		"company_reputation":
			if OrganizationManager.is_founded():
				OrganizationManager.add_reputation(amount)
				outcome.append("Company reputation %+d." % amount)
		"company_xp":
			if OrganizationManager.is_founded():
				OrganizationManager.add_company_xp(amount)
				outcome.append("Company XP +%d." % amount)
		"morale":
			if EmployeeManager.get_employee_count() > 0:
				EmployeeManager.change_morale_all(float(amount))
				outcome.append("Staff morale %+d." % amount)
		"employee_morale":
			var employee: Employee = EmployeeManager.get_employee(SaveDataReader.get_string(_pending, "employee_id"))
			if employee != null:
				EmployeeManager.change_morale(employee.id, float(amount))
				outcome.append("%s's morale %+d." % [employee.display_name, amount])
		"employee_leaves":
			var leaving: Employee = EmployeeManager.get_employee(SaveDataReader.get_string(_pending, "employee_id"))
			if leaving != null and EmployeeManager.resign(leaving.id):
				outcome.append("%s leaves the company." % leaving.display_name)
		"research_progress":
			if ResearchManager.has_active_project():
				ResearchManager.add_progress(float(amount))
				outcome.append("Research %s %d points." % ["gains" if amount >= 0 else "loses", absi(amount)])
		var unknown:
			push_warning("EventManager: unknown effect type '%s'." % unknown)
