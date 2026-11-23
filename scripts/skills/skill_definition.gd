class_name SkillDefinition
extends RefCounted
## One skill from data/skills/skills.json.

var id: String = ""
var branch: String = ""
var title: String = ""
var description: String = ""
var max_level: int = 1
## Skill points each level costs.
var cost_per_level: int = 1
## Unlock condition: player level needed to learn the first level.
var required_level: int = 1
## Unlock condition: skill id -> level that skill must have.
var requires: Dictionary = {}
## Gameplay bonuses: GameEffects id -> value granted per level.
var effects: Dictionary = {}
## Row in the skill tree (0 = top).
var row: int = 0


## Bonuses at `level`, as player-facing lines.
func describe_effects(level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect_id: String in effects:
		lines.append(GameEffects.describe(effect_id, float(effects[effect_id]) * level))
	return lines


## Returns null (with a warning) when the data cannot describe a usable skill.
static func from_dictionary(data: Dictionary) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.id = SaveDataReader.get_string(data, "id")
	skill.branch = SaveDataReader.get_string(data, "branch")
	if skill.id.is_empty() or not SkillBranch.is_valid(skill.branch):
		push_warning("SkillDefinition: skipped a skill with a missing id or unknown branch.")
		return null
	skill.title = SaveDataReader.get_string(data, "name", skill.id)
	skill.description = SaveDataReader.get_string(data, "description")
	skill.max_level = clampi(SaveDataReader.get_int(data, "max_level", 1), 1, 10)
	skill.cost_per_level = maxi(1, SaveDataReader.get_int(data, "cost", 1))
	skill.required_level = maxi(1, SaveDataReader.get_int(data, "required_level", 1))
	skill.row = maxi(0, SaveDataReader.get_int(data, "row"))
	var raw_requires: Dictionary = SaveDataReader.get_dictionary(data, "requires")
	for required_id: Variant in raw_requires:
		if required_id is String:
			skill.requires[required_id] = maxi(1, SaveDataReader.get_int(raw_requires, required_id, 1))
	var raw_effects: Dictionary = SaveDataReader.get_dictionary(data, "effects")
	for effect_id: Variant in raw_effects:
		if effect_id is String:
			skill.effects[effect_id] = SaveDataReader.get_float(raw_effects, effect_id)
	if skill.effects.is_empty():
		push_warning("SkillDefinition: '%s' grants nothing." % skill.id)
		return null
	return skill
