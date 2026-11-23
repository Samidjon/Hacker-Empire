class_name ContractDefinition
extends RefCounted
## One contract template from data/contracts/contracts.json.

const ALIGNMENT_WHITE: String = "white"
const ALIGNMENT_UNDERGROUND: String = "underground"
const MAX_DIFFICULTY: int = 5

var id: String = ""
var title: String = ""
var description: String = ""
var client: String = ""
var category: String = ""
## Which reputation track the work belongs to.
var alignment: String = ALIGNMENT_WHITE
var difficulty: int = 1
var required_level: int = 1
## Skill id -> minimum level. Checked once the skill system exists (MVP 5).
var required_skills: Dictionary = {}
## Hardware ids. Checked once the hardware system exists (MVP 5).
var required_hardware: PackedStringArray = []
## Seconds a competent player is expected to need.
var estimated_duration: int = 60
var reward: int = 0
var xp_reward: int = 0
var reputation_white: int = 0
var reputation_underground: int = 0
var heat: float = 0.0
## Each stage: {title, instruction, puzzle, config}.
var stages: Array[Dictionary] = []


func get_stage_count() -> int:
	return stages.size()


## Builds a definition, or returns null (with a warning) when the data cannot
## produce a playable contract.
static func from_dictionary(data: Dictionary) -> ContractDefinition:
	var definition := ContractDefinition.new()
	definition.id = SaveDataReader.get_string(data, "id")
	if definition.id.is_empty():
		push_warning("ContractDefinition: skipped a contract without an id.")
		return null
	definition.title = SaveDataReader.get_string(data, "name", definition.id)
	definition.description = SaveDataReader.get_string(data, "description")
	definition.client = SaveDataReader.get_string(data, "client", "Unknown client")
	definition.category = SaveDataReader.get_string(data, "category")
	if not ContractCategory.is_valid(definition.category):
		push_warning("ContractDefinition: '%s' has unknown category '%s'." % [definition.id, definition.category])
		return null
	if SaveDataReader.get_string(data, "alignment") == ALIGNMENT_UNDERGROUND:
		definition.alignment = ALIGNMENT_UNDERGROUND
	definition.difficulty = clampi(SaveDataReader.get_int(data, "difficulty", 1), 1, MAX_DIFFICULTY)
	definition.required_level = maxi(1, SaveDataReader.get_int(data, "required_level", 1))
	definition.estimated_duration = maxi(10, SaveDataReader.get_int(data, "estimated_duration", 60))
	definition.reward = maxi(0, SaveDataReader.get_int(data, "reward"))
	definition.xp_reward = maxi(0, SaveDataReader.get_int(data, "xp_reward"))

	var reputation: Dictionary = SaveDataReader.get_dictionary(data, "reputation")
	definition.reputation_white = SaveDataReader.get_int(reputation, "white")
	definition.reputation_underground = SaveDataReader.get_int(reputation, "underground")
	definition.heat = SaveDataReader.get_float(reputation, "heat")

	var skills: Dictionary = SaveDataReader.get_dictionary(data, "required_skills")
	for skill_id: Variant in skills:
		if skill_id is String:
			definition.required_skills[skill_id] = maxi(1, SaveDataReader.get_int(skills, skill_id, 1))
	for hardware_id: Variant in SaveDataReader.get_array(data, "required_hardware"):
		if hardware_id is String:
			definition.required_hardware.append(hardware_id)

	for entry: Variant in SaveDataReader.get_array(data, "stages"):
		if not entry is Dictionary:
			continue
		var raw: Dictionary = entry
		var puzzle_type: String = SaveDataReader.get_string(raw, "puzzle")
		if not PuzzleFactory.is_known_type(puzzle_type):
			push_warning("ContractDefinition: '%s' uses unknown puzzle '%s'." % [definition.id, puzzle_type])
			return null
		definition.stages.append({
			"title": SaveDataReader.get_string(raw, "title", "Stage %d" % (definition.stages.size() + 1)),
			"instruction": SaveDataReader.get_string(raw, "instruction"),
			"puzzle": puzzle_type,
			"config": SaveDataReader.get_dictionary(raw, "config"),
		})
	if definition.stages.is_empty():
		push_warning("ContractDefinition: '%s' has no stages." % definition.id)
		return null
	return definition
