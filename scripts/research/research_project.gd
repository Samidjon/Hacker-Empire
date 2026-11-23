class_name ResearchProject
extends RefCounted
## One research project from data/research/projects.json.

var id: String = ""
var title: String = ""
var description: String = ""
var field: String = ""
## Money paid when the project starts.
var cost: int = 0
## Research points needed to finish.
var points: int = 1
var required_level: int = 1
## Ids of projects that must be finished first.
var requires: PackedStringArray = []
var xp_reward: int = 0
## Money paid by a sponsor on completion.
var grant: int = 0
## Technology unlocked for good: GameEffects id -> value.
var effects: Dictionary = {}
## Ids of products this project makes possible.
var unlocks_products: PackedStringArray = []


func describe_effects() -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect_id: String in effects:
		lines.append(GameEffects.describe(effect_id, float(effects[effect_id])))
	return lines


static func from_dictionary(data: Dictionary) -> ResearchProject:
	var project := ResearchProject.new()
	project.id = SaveDataReader.get_string(data, "id")
	if project.id.is_empty():
		push_warning("ResearchProject: skipped a project without an id.")
		return null
	project.title = SaveDataReader.get_string(data, "name", project.id)
	project.description = SaveDataReader.get_string(data, "description")
	project.field = SaveDataReader.get_string(data, "field", "General")
	project.cost = maxi(0, SaveDataReader.get_int(data, "cost"))
	project.points = maxi(1, SaveDataReader.get_int(data, "points", 1))
	project.required_level = maxi(1, SaveDataReader.get_int(data, "required_level", 1))
	project.xp_reward = maxi(0, SaveDataReader.get_int(data, "xp_reward"))
	project.grant = maxi(0, SaveDataReader.get_int(data, "grant"))
	for entry: Variant in SaveDataReader.get_array(data, "requires"):
		if entry is String:
			project.requires.append(entry)
	for entry: Variant in SaveDataReader.get_array(data, "unlocks_products"):
		if entry is String:
			project.unlocks_products.append(entry)
	var raw_effects: Dictionary = SaveDataReader.get_dictionary(data, "effects")
	for effect_id: Variant in raw_effects:
		if effect_id is String:
			project.effects[effect_id] = SaveDataReader.get_float(raw_effects, effect_id)
	return project
