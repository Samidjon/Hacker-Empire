extends Node
## ReputationManager (autoload)
##
## Tracks the two reputation tracks and the heat level.

signal reputation_changed(kind: Kind, new_value: int)
signal heat_changed(new_value: float)

enum Kind { WHITE, UNDERGROUND }

const CONFIG: ReputationConfig = preload("res://resources/configurations/reputation_config.tres")
const SAVE_SECTION: String = "reputation"

var white_reputation: int = 0
var underground_reputation: int = 0
var heat: float = 0.0


func _ready() -> void:
	SaveManager.register_section(SAVE_SECTION, self)


func get_reputation(kind: Kind) -> int:
	return white_reputation if kind == Kind.WHITE else underground_reputation


## `amount` may be negative. The result is clamped to 0..max_reputation.
func add_reputation(kind: Kind, amount: int) -> void:
	var new_value: int = clampi(get_reputation(kind) + amount, 0, CONFIG.max_reputation)
	if new_value == get_reputation(kind):
		return
	if kind == Kind.WHITE:
		white_reputation = new_value
	else:
		underground_reputation = new_value
	reputation_changed.emit(kind, new_value)


## `amount` may be negative. The result is clamped to 0..max_heat.
func add_heat(amount: float) -> void:
	var new_value: float = clampf(heat + amount, 0.0, CONFIG.max_heat)
	if is_equal_approx(new_value, heat):
		return
	heat = new_value
	heat_changed.emit(heat)


## 0.0 - 1.0 share of the maximum heat.
func get_heat_ratio() -> float:
	return clampf(heat / CONFIG.max_heat, 0.0, 1.0)


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"white": white_reputation,
		"underground": underground_reputation,
		"heat": heat,
	}


func load_save_data(data: Dictionary) -> void:
	white_reputation = clampi(SaveDataReader.get_int(data, "white"), 0, CONFIG.max_reputation)
	underground_reputation = clampi(
		SaveDataReader.get_int(data, "underground"), 0, CONFIG.max_reputation
	)
	heat = clampf(SaveDataReader.get_float(data, "heat"), 0.0, CONFIG.max_heat)
	_emit_full_refresh()


func reset_to_defaults() -> void:
	white_reputation = 0
	underground_reputation = 0
	heat = 0.0
	_emit_full_refresh()


func _emit_full_refresh() -> void:
	reputation_changed.emit(Kind.WHITE, white_reputation)
	reputation_changed.emit(Kind.UNDERGROUND, underground_reputation)
	heat_changed.emit(heat)
