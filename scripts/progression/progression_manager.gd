extends Node
## ProgressionManager (autoload)
##
## Owns XP, level and rank. The curve and rank table come from
## ProgressionConfig; nothing here is hardcoded.

signal xp_gained(amount: int, source: String)
signal xp_changed(current_xp: int, xp_required: int)
signal level_changed(new_level: int, old_level: int)
signal rank_changed(new_rank: String)

const CONFIG: ProgressionConfig = preload("res://resources/configurations/progression_config.tres")
const SAVE_SECTION: String = "progression"
const STARTING_LEVEL: int = 1

var level: int = STARTING_LEVEL
## XP earned toward the next level.
var current_xp: int = 0
## Lifetime XP, kept for statistics.
var total_xp: int = 0


func _ready() -> void:
	SaveManager.register_section(SAVE_SECTION, self)


## Adds XP and applies any level-ups. Returns the number of levels gained.
func add_xp(amount: int, source: String = "") -> int:
	if amount <= 0:
		return 0
	var old_level: int = level
	var old_rank: String = get_rank_name()
	total_xp += amount

	if not is_max_level():
		current_xp += amount
		while not is_max_level() and current_xp >= get_xp_required():
			current_xp -= get_xp_required()
			level += 1
		if is_max_level():
			current_xp = 0

	xp_gained.emit(amount, source)
	xp_changed.emit(current_xp, get_xp_required())
	if level != old_level:
		level_changed.emit(level, old_level)
		var new_rank: String = get_rank_name()
		if new_rank != old_rank:
			rank_changed.emit(new_rank)
	return level - old_level


## XP needed to finish the current level. Zero at max level.
func get_xp_required() -> int:
	return CONFIG.get_xp_to_next_level(level)


## 0.0 - 1.0 progress through the current level (1.0 at max level).
func get_level_progress() -> float:
	var required: int = get_xp_required()
	if required <= 0:
		return 1.0
	return clampf(float(current_xp) / float(required), 0.0, 1.0)


func get_rank_name() -> String:
	return CONFIG.get_rank_name(level)


func is_max_level() -> bool:
	return level >= CONFIG.max_level


func get_max_level() -> int:
	return CONFIG.max_level


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"level": level,
		"current_xp": current_xp,
		"total_xp": total_xp,
	}


func load_save_data(data: Dictionary) -> void:
	level = clampi(SaveDataReader.get_int(data, "level", STARTING_LEVEL), STARTING_LEVEL, CONFIG.max_level)
	total_xp = maxi(0, SaveDataReader.get_int(data, "total_xp"))
	if is_max_level():
		current_xp = 0
	else:
		current_xp = clampi(SaveDataReader.get_int(data, "current_xp"), 0, get_xp_required() - 1)
	_emit_full_refresh()


func reset_to_defaults() -> void:
	level = STARTING_LEVEL
	current_xp = 0
	total_xp = 0
	_emit_full_refresh()


func _emit_full_refresh() -> void:
	xp_changed.emit(current_xp, get_xp_required())
	level_changed.emit(level, level)
	rank_changed.emit(get_rank_name())
