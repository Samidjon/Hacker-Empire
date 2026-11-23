class_name HardwareItem
extends RefCounted
## One hardware component from data/items/hardware.json.

## Performance attributes an item can have.
const STAT_SPEED: String = "speed"       ## How fast simulated work runs.
const STAT_CAPACITY: String = "capacity" ## How many tasks fit at once.
const STAT_NETWORK: String = "network"   ## Link quality.
const STAT_RESEARCH: String = "research" ## Compute available for research.
const STATS: PackedStringArray = [STAT_SPEED, STAT_CAPACITY, STAT_NETWORK, STAT_RESEARCH]
const STAT_NAMES: Dictionary = {
	STAT_SPEED: "Speed",
	STAT_CAPACITY: "Capacity",
	STAT_NETWORK: "Network",
	STAT_RESEARCH: "Research",
}
const MAX_TIER: int = 4

var id: String = ""
var category: String = ""
var title: String = ""
var description: String = ""
var price: int = 0
var tier: int = 0
## Stat id -> value.
var attributes: Dictionary = {}
## Unlock requirement: the player level needed to buy it.
var required_level: int = 1
## Part of the machine a new game starts with. Never sold.
var is_starter: bool = false


func get_stat(stat: String) -> float:
	return float(attributes.get(stat, 0.0))


## "Speed +14, Capacity +10", or "No bonuses".
func describe_attributes() -> String:
	var parts: PackedStringArray = []
	for stat: String in STATS:
		var value: float = get_stat(stat)
		if not is_zero_approx(value):
			parts.append("%s %+d" % [STAT_NAMES[stat], roundi(value)])
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"


## Returns null (with a warning) when the data cannot describe a usable item.
static func from_dictionary(data: Dictionary) -> HardwareItem:
	var item := HardwareItem.new()
	item.id = SaveDataReader.get_string(data, "id")
	item.category = SaveDataReader.get_string(data, "category")
	if item.id.is_empty() or not HardwareCategory.is_valid(item.category):
		push_warning("HardwareItem: skipped an item with a missing id or unknown category.")
		return null
	item.title = SaveDataReader.get_string(data, "name", item.id)
	item.description = SaveDataReader.get_string(data, "description")
	item.price = maxi(0, SaveDataReader.get_int(data, "price"))
	item.tier = clampi(SaveDataReader.get_int(data, "tier"), 0, MAX_TIER)
	item.required_level = maxi(1, SaveDataReader.get_int(data, "required_level", 1))
	item.is_starter = data.get("starter") == true
	var raw_attributes: Dictionary = SaveDataReader.get_dictionary(data, "attributes")
	for stat: String in STATS:
		var value: float = SaveDataReader.get_float(raw_attributes, stat)
		if not is_zero_approx(value):
			item.attributes[stat] = value
	return item
