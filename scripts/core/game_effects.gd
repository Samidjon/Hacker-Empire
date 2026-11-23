class_name GameEffects
extends RefCounted
## Shared vocabulary for gameplay bonuses, and the meeting point between the
## systems that grant them (hardware, skills) and the systems that use them
## (contracts, later research).
##
## A granting system registers a provider: Callable(effect_id: String) -> float.
## A consuming system asks get_total(effect_id) and never learns who answered.
## This keeps the managers independent of each other and of autoload order.

## Percent of extra time on a contract's clock.
const CONTRACT_TIME: String = "contract_time"
## Percent of extra pay. Add ":<category>" for one contract category only.
const CONTRACT_REWARD: String = "contract_reward"
## Percent of extra XP from contracts.
const CONTRACT_XP: String = "contract_xp"
## Additional mistakes allowed before a contract fails.
const EXTRA_MISTAKES: String = "extra_mistakes"
## Additional offers on the contract board.
const BOARD_SIZE: String = "board_size"
## Percent shaved off the board refresh cooldown.
const REFRESH_COOLDOWN: String = "refresh_cooldown"
## Percent less heat gained from contracts.
const HEAT_REDUCTION: String = "heat_reduction"
## Percentage points added to the flawless bonus.
const FLAWLESS_BONUS: String = "flawless_bonus"
## Research capability. Stored and shown now; consumed by Research in MVP 7.
const RESEARCH_POWER: String = "research_power"

## Percent off the daily electricity bill.
const ELECTRICITY_REDUCTION: String = "electricity_reduction"
## Product development points per business day.
const DEVELOPMENT_POWER: String = "development_power"

const CATEGORY_SEPARATOR: String = ":"

static var _providers: Array[Callable] = []
static var _requirement_checkers: Dictionary = {}
static var _change_listeners: Array[Callable] = []
## Running costs charged every business day: {label, category, provider}.
static var _daily_costs: Array[Dictionary] = []


# --- Bonuses ----------------------------------------------------------------

static func register_provider(provider: Callable) -> void:
	if provider.is_valid() and not _providers.has(provider):
		_providers.append(provider)


static func unregister_provider(provider: Callable) -> void:
	_providers.erase(provider)


## Sum of what every provider grants for `effect_id`.
static func get_total(effect_id: String) -> float:
	var total: float = 0.0
	for provider: Callable in _providers:
		if provider.is_valid():
			var value: Variant = provider.call(effect_id)
			if value is float or value is int:
				total += float(value)
	return total


## The id of an effect limited to one category, e.g. contract_reward:cryptography.
static func for_category(effect_id: String, category: String) -> String:
	return effect_id + CATEGORY_SEPARATOR + category


## Called by a provider whenever what it grants has changed.
static func notify_changed() -> void:
	for listener: Callable in _change_listeners:
		if listener.is_valid():
			listener.call()


static func add_change_listener(listener: Callable) -> void:
	if listener.is_valid() and not _change_listeners.has(listener):
		_change_listeners.append(listener)


# --- Daily running costs ----------------------------------------------------

## Registers a cost the company pays every business day. `provider` is a
## Callable() -> int returning today's amount; `category` is a
## TransactionCategory id. OrganizationManager charges these with the rent.
static func register_daily_cost(label: String, category: String, provider: Callable) -> void:
	for cost: Dictionary in _daily_costs:
		if cost["label"] == label:
			cost["category"] = category
			cost["provider"] = provider
			return
	_daily_costs.append({"label": label, "category": category, "provider": provider})


static func get_daily_costs() -> Array[Dictionary]:
	return _daily_costs


# --- Requirements -----------------------------------------------------------

## A checker decides one kind of requirement ("skills", "hardware"). It
## receives whatever is being checked and returns the unmet reasons as a
## PackedStringArray.
static func register_requirement_checker(kind: String, checker: Callable) -> void:
	if checker.is_valid():
		_requirement_checkers[kind] = checker
	else:
		_requirement_checkers.erase(kind)


static func get_requirement_checker(kind: String) -> Callable:
	return _requirement_checkers.get(kind, Callable())


static func has_requirement_checker(kind: String) -> bool:
	return get_requirement_checker(kind).is_valid()


## Unmet reasons for `subject`. Empty when satisfied or when nothing checks
## this kind (callers decide what a missing checker means).
static func check_requirement(kind: String, subject: Variant) -> PackedStringArray:
	var checker: Callable = get_requirement_checker(kind)
	if not checker.is_valid():
		return PackedStringArray()
	var result: Variant = checker.call(subject)
	return result if result is PackedStringArray else PackedStringArray()


# --- Display ----------------------------------------------------------------

## Player-facing description of an effect, e.g. "+12% contract time".
static func describe(effect_id: String, value: float) -> String:
	var amount: String = "%+d" % roundi(value)
	var parts: PackedStringArray = effect_id.split(CATEGORY_SEPARATOR)
	match parts[0]:
		CONTRACT_TIME:
			return "%s%% time on contracts" % amount
		CONTRACT_REWARD:
			if parts.size() > 1:
				return "%s%% pay for %s contracts" % [amount, ContractCategory.get_display_name(parts[1])]
			return "%s%% pay for all contracts" % amount
		CONTRACT_XP:
			return "%s%% XP from contracts" % amount
		EXTRA_MISTAKES:
			return "%s mistake(s) allowed per contract" % amount
		BOARD_SIZE:
			return "%s offer(s) on the contract board" % amount
		REFRESH_COOLDOWN:
			return "%d%% shorter wait for new offers" % roundi(value)
		HEAT_REDUCTION:
			return "%d%% less heat from contracts" % roundi(value)
		FLAWLESS_BONUS:
			return "%s points on the flawless bonus" % amount
		RESEARCH_POWER:
			return "%s research power" % amount
		ELECTRICITY_REDUCTION:
			return "%d%% lower electricity bill" % roundi(value)
		DEVELOPMENT_POWER:
			return "%s development power" % amount
	return "%s %s" % [amount, effect_id]
