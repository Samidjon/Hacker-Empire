extends Node
## SkillManager (autoload)
##
## Owns the skill tree: which skills the player has learned and to what
## level, skill points, unlock conditions, and the bonuses skills give.
## Bonuses are published through GameEffects.
##
## Skill points are not stored: the number earned follows from the player's
## level and the number spent follows from the learned skills, so the two can
## never drift apart.

signal skill_upgraded(skill_id: String, new_level: int)
signal points_changed(available: int)
signal skills_changed

const CONFIG: SkillConfig = preload("res://resources/configurations/skill_config.tres")
const DATA_PATH: String = "res://data/skills/skills.json"
const SAVE_SECTION: String = "skills"
const REQUIREMENT_KIND: String = "skills"

var _skills: Dictionary = {} # skill id -> SkillDefinition
var _skill_order: Array[String] = []
var _levels: Dictionary = {} # skill id -> learned level (absent = 0)


func _ready() -> void:
	_load_skills()
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_provider(get_effect)
	GameEffects.register_requirement_checker(REQUIREMENT_KIND, get_unmet_contract_requirements)
	ProgressionManager.level_changed.connect(
		func(_new: int, _old: int) -> void: points_changed.emit(get_available_points())
	)


# --- Catalogue --------------------------------------------------------------

func get_skill(skill_id: String) -> SkillDefinition:
	return _skills.get(skill_id)


## Every skill, or only one branch, in data order.
func get_skills(branch: String = "") -> Array[SkillDefinition]:
	var skills: Array[SkillDefinition] = []
	for skill_id: String in _skill_order:
		var skill: SkillDefinition = _skills[skill_id]
		if branch.is_empty() or skill.branch == branch:
			skills.append(skill)
	return skills


# --- Levels and points ------------------------------------------------------

func get_level(skill_id: String) -> int:
	return int(_levels.get(skill_id, 0))


func is_maxed(skill_id: String) -> bool:
	var skill: SkillDefinition = get_skill(skill_id)
	return skill != null and get_level(skill_id) >= skill.max_level


func get_earned_points() -> int:
	return CONFIG.starting_points + (ProgressionManager.level - 1) * CONFIG.points_per_level


func get_spent_points() -> int:
	var spent: int = 0
	for skill_id: String in _levels:
		var skill: SkillDefinition = get_skill(skill_id)
		if skill != null:
			spent += get_level(skill_id) * skill.cost_per_level
	return spent


func get_available_points() -> int:
	return maxi(0, get_earned_points() - get_spent_points())


## Reasons the skill cannot be raised right now. Empty = it can.
func get_upgrade_blockers(skill_id: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	var skill: SkillDefinition = get_skill(skill_id)
	if skill == null:
		blockers.append("Unknown skill")
		return blockers
	if is_maxed(skill_id):
		blockers.append("Already at maximum level")
		return blockers
	if ProgressionManager.level < skill.required_level:
		blockers.append("Requires level %d" % skill.required_level)
	for required_id: String in skill.requires:
		var needed: int = skill.requires[required_id]
		if get_level(required_id) < needed:
			var required_skill: SkillDefinition = get_skill(required_id)
			blockers.append("Requires %s level %d" % [
				required_skill.title if required_skill != null else required_id, needed
			])
	if get_available_points() < skill.cost_per_level:
		blockers.append("Needs %d skill point(s), you have %d" % [
			skill.cost_per_level, get_available_points()
		])
	return blockers


func can_upgrade(skill_id: String) -> bool:
	return get_upgrade_blockers(skill_id).is_empty()


## True when only missing points stand in the way (used to dim the tree).
func is_unlocked(skill_id: String) -> bool:
	var skill: SkillDefinition = get_skill(skill_id)
	if skill == null or ProgressionManager.level < skill.required_level:
		return false
	for required_id: String in skill.requires:
		if get_level(required_id) < int(skill.requires[required_id]):
			return false
	return true


## Spends points to raise a skill by one level.
func upgrade(skill_id: String) -> bool:
	if not can_upgrade(skill_id):
		return false
	_levels[skill_id] = get_level(skill_id) + 1
	skill_upgraded.emit(skill_id, get_level(skill_id))
	_announce_change()
	return true


# --- Bonuses ----------------------------------------------------------------

## GameEffects provider: what the learned skills grant for an effect.
func get_effect(effect_id: String) -> float:
	var total: float = 0.0
	for skill_id: String in _levels:
		var skill: SkillDefinition = get_skill(skill_id)
		if skill != null and skill.effects.has(effect_id):
			total += float(skill.effects[effect_id]) * get_level(skill_id)
	return total


## Requirement checker for contracts: `definition.required_skills` maps a
## skill id to the level it must have.
func get_unmet_contract_requirements(definition: ContractDefinition) -> PackedStringArray:
	var unmet: PackedStringArray = []
	if definition == null:
		return unmet
	for skill_id: String in definition.required_skills:
		var needed: int = definition.required_skills[skill_id]
		if get_level(skill_id) < needed:
			var skill: SkillDefinition = get_skill(skill_id)
			unmet.append("Requires skill %s level %d" % [skill.title if skill != null else skill_id, needed])
	return unmet


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"levels": _levels.duplicate()}


func load_save_data(data: Dictionary) -> void:
	_levels.clear()
	var saved: Dictionary = SaveDataReader.get_dictionary(data, "levels")
	# In data order, so prerequisites are restored before what depends on them.
	for skill_id: String in _skill_order:
		var skill: SkillDefinition = _skills[skill_id]
		var level: int = clampi(SaveDataReader.get_int(saved, skill_id), 0, skill.max_level)
		if level > 0:
			_levels[skill_id] = level
	_announce_change()


func reset_to_defaults() -> void:
	_levels.clear()
	_announce_change()


# --- Internals --------------------------------------------------------------

func _load_skills() -> void:
	_skills.clear()
	_skill_order.clear()
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "skills"):
		var skill: SkillDefinition = SkillDefinition.from_dictionary(entry)
		if skill == null:
			continue
		if _skills.has(skill.id):
			push_warning("SkillManager: duplicate skill id '%s'." % skill.id)
			continue
		_skills[skill.id] = skill
		_skill_order.append(skill.id)
	for skill_id: String in _skill_order:
		for required_id: String in (_skills[skill_id] as SkillDefinition).requires:
			if not _skills.has(required_id):
				push_warning("SkillManager: '%s' requires unknown skill '%s'." % [skill_id, required_id])


func _announce_change() -> void:
	skills_changed.emit()
	points_changed.emit(get_available_points())
	GameEffects.notify_changed()
