extends Node
## HardwareManager (autoload)
##
## Owns the player's hardware: what is owned, what is installed in each of
## the computer's slots, buying, and the bonuses the installed parts give.
## Bonuses are published through GameEffects; this manager does not know
## which systems use them.

signal hardware_changed
signal item_purchased(item_id: String)
signal item_installed(item_id: String)

const CONFIG: HardwareConfig = preload("res://resources/configurations/hardware_config.tres")
const DATA_PATH: String = "res://data/items/hardware.json"
const SAVE_SECTION: String = "hardware"
const REQUIREMENT_KIND: String = "hardware"
## In a requirement, "cpu:2" means "a CPU of tier 2 or better is installed".
const TIER_REQUIREMENT_SEPARATOR: String = ":"
const ELECTRICITY_LABEL: String = "Electricity"

var _items: Dictionary = {} # item id -> HardwareItem
var _item_order: Array[String] = []
var _owned: Array[String] = []
var _installed: Dictionary = {} # category -> item id


func _ready() -> void:
	_load_items()
	_apply_starting_hardware()
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_provider(get_effect)
	GameEffects.register_requirement_checker(REQUIREMENT_KIND, get_unmet_contract_requirements)
	GameEffects.register_daily_cost(ELECTRICITY_LABEL, TransactionCategory.ELECTRICITY, get_daily_power_cost)


# --- Catalogue --------------------------------------------------------------

func get_item(item_id: String) -> HardwareItem:
	return _items.get(item_id)


## Every item, or only one category, in catalogue order (lowest tier first).
func get_items(category: String = "") -> Array[HardwareItem]:
	var items: Array[HardwareItem] = []
	for item_id: String in _item_order:
		var item: HardwareItem = _items[item_id]
		if category.is_empty() or item.category == category:
			items.append(item)
	return items


## Items that can be bought (everything except starter parts).
func get_shop_items(category: String = "") -> Array[HardwareItem]:
	var items: Array[HardwareItem] = []
	for item: HardwareItem in get_items(category):
		if not item.is_starter:
			items.append(item)
	return items


# --- Ownership --------------------------------------------------------------

func is_owned(item_id: String) -> bool:
	return _owned.has(item_id)


func is_installed(item_id: String) -> bool:
	var item: HardwareItem = get_item(item_id)
	return item != null and _installed.get(item.category) == item_id


## The item in a slot, or null when the slot is empty.
func get_installed(category: String) -> HardwareItem:
	return get_item(_installed.get(category, ""))


func get_installed_tier(category: String) -> int:
	var item: HardwareItem = get_installed(category)
	return item.tier if item != null else -1


func get_owned_items(category: String = "") -> Array[HardwareItem]:
	var items: Array[HardwareItem] = []
	for item: HardwareItem in get_items(category):
		if is_owned(item.id):
			items.append(item)
	return items


## How many parts the player has bought (starter parts do not count).
func get_purchased_count() -> int:
	var count: int = 0
	for item: HardwareItem in get_owned_items():
		if not item.is_starter:
			count += 1
	return count


## Owned items that are not installed (the contents of the storage cabinet).
func get_spare_items() -> Array[HardwareItem]:
	var items: Array[HardwareItem] = []
	for item: HardwareItem in get_owned_items():
		if not is_installed(item.id):
			items.append(item)
	return items


## Reasons the item cannot be bought right now. Empty = it can.
func get_purchase_blockers(item_id: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	var item: HardwareItem = get_item(item_id)
	if item == null or item.is_starter:
		blockers.append("Not for sale")
		return blockers
	if is_owned(item_id):
		blockers.append("Already owned")
		return blockers
	if ProgressionManager.level < item.required_level:
		blockers.append("Requires level %d" % item.required_level)
	if not EconomyManager.can_afford(item.price):
		blockers.append("Not enough money (%s short)" % FormatUtils.money(item.price - EconomyManager.money))
	return blockers


func can_purchase(item_id: String) -> bool:
	return get_purchase_blockers(item_id).is_empty()


## Buys an item and installs it in its slot. The part it replaces is kept.
func purchase(item_id: String) -> bool:
	if not can_purchase(item_id):
		return false
	var item: HardwareItem = get_item(item_id)
	if not EconomyManager.spend_money(item.price, TransactionCategory.HARDWARE, item.title):
		return false
	_owned.append(item_id)
	_installed[item.category] = item_id
	item_purchased.emit(item_id)
	item_installed.emit(item_id)
	_announce_change()
	return true


## Puts an owned item into its slot, replacing what was there.
func install(item_id: String) -> bool:
	var item: HardwareItem = get_item(item_id)
	if item == null or not is_owned(item_id) or is_installed(item_id):
		return false
	_installed[item.category] = item_id
	item_installed.emit(item_id)
	_announce_change()
	return true


# --- Stats and bonuses ------------------------------------------------------

## Stat id -> total over every installed item.
func get_stat_totals() -> Dictionary:
	var totals: Dictionary = {}
	for stat: String in HardwareItem.STATS:
		totals[stat] = 0.0
	for category: String in _installed:
		var item: HardwareItem = get_installed(category)
		if item != null:
			for stat: String in HardwareItem.STATS:
				totals[stat] += item.get_stat(stat)
	return totals


## GameEffects provider: what the installed hardware grants for an effect.
func get_effect(effect_id: String) -> float:
	var totals: Dictionary = get_stat_totals()
	match effect_id:
		GameEffects.CONTRACT_TIME:
			return totals[HardwareItem.STAT_SPEED] * CONFIG.time_percent_per_speed
		GameEffects.BOARD_SIZE:
			return float(mini(
				CONFIG.max_extra_offers,
				floori(totals[HardwareItem.STAT_CAPACITY] / CONFIG.capacity_per_offer)
			))
		GameEffects.REFRESH_COOLDOWN:
			return totals[HardwareItem.STAT_NETWORK] * CONFIG.cooldown_percent_per_network
		GameEffects.RESEARCH_POWER:
			return totals[HardwareItem.STAT_RESEARCH] * CONFIG.research_power_per_point
	return 0.0


## Electricity the installed hardware uses per business day. Better parts
## draw more; research can make the machine more efficient.
func get_daily_power_cost() -> int:
	var tiers: int = 0
	for category: String in _installed:
		var item: HardwareItem = get_installed(category)
		if item != null:
			tiers += item.tier
	var reduction: float = clampf(
		GameEffects.get_total(GameEffects.ELECTRICITY_REDUCTION), 0.0, CONFIG.max_electricity_reduction
	)
	return roundi(tiers * CONFIG.power_cost_per_tier * (1.0 - reduction / 100.0))


## The effects hardware can grant, with their current values (zero included).
func get_effects_summary() -> Dictionary:
	var summary: Dictionary = {}
	for effect_id: String in [
		GameEffects.CONTRACT_TIME, GameEffects.BOARD_SIZE,
		GameEffects.REFRESH_COOLDOWN, GameEffects.RESEARCH_POWER,
	]:
		summary[effect_id] = get_effect(effect_id)
	return summary


## Requirement checker for contracts: `definition.required_hardware` lists
## item ids ("gpu_spark") or minimum tiers ("cpu:2").
func get_unmet_contract_requirements(definition: ContractDefinition) -> PackedStringArray:
	var unmet: PackedStringArray = []
	if definition == null:
		return unmet
	for requirement: String in definition.required_hardware:
		if requirement.contains(TIER_REQUIREMENT_SEPARATOR):
			var parts: PackedStringArray = requirement.split(TIER_REQUIREMENT_SEPARATOR)
			var needed_tier: int = parts[1].to_int()
			if get_installed_tier(parts[0]) < needed_tier:
				unmet.append("Requires %s tier %d or better" % [
					HardwareCategory.get_display_name(parts[0]), needed_tier
				])
		elif not is_installed(requirement):
			var item: HardwareItem = get_item(requirement)
			unmet.append("Requires %s installed" % (item.title if item != null else requirement))
	return unmet


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"owned": _owned.duplicate(), "installed": _installed.duplicate()}


func load_save_data(data: Dictionary) -> void:
	# Start from the stock machine, so a save from before hardware existed
	# (or a damaged one) still has a working computer.
	_apply_starting_hardware()
	for entry: Variant in SaveDataReader.get_array(data, "owned"):
		if entry is String and _items.has(entry) and not _owned.has(entry):
			_owned.append(entry)
	var installed: Dictionary = SaveDataReader.get_dictionary(data, "installed")
	for category: String in HardwareCategory.ALL:
		var item_id: String = SaveDataReader.get_string(installed, category)
		var item: HardwareItem = get_item(item_id)
		# Only an owned item of the right category can sit in a slot.
		if item != null and item.category == category and is_owned(item_id):
			_installed[category] = item_id
	_announce_change()


func reset_to_defaults() -> void:
	_apply_starting_hardware()
	_announce_change()


# --- Internals --------------------------------------------------------------

func _load_items() -> void:
	_items.clear()
	_item_order.clear()
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "items"):
		var item: HardwareItem = HardwareItem.from_dictionary(entry)
		if item == null:
			continue
		if _items.has(item.id):
			push_warning("HardwareManager: duplicate item id '%s'." % item.id)
			continue
		_items[item.id] = item
		_item_order.append(item.id)


func _apply_starting_hardware() -> void:
	_owned.clear()
	_installed.clear()
	for item_id: String in _item_order:
		var item: HardwareItem = _items[item_id]
		if item.is_starter:
			_owned.append(item_id)
			_installed[item.category] = item_id


func _announce_change() -> void:
	hardware_changed.emit()
	GameEffects.notify_changed()
