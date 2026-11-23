class_name EmployeeRole
extends RefCounted
## One job role from data/employees/roles.json.

var id: String = ""
var title: String = ""
var description: String = ""
## The Employee skill this role works with.
var primary_skill: String = ""
var base_salary: int = 0
var salary_per_skill: int = 0
## Money a full-strength employee earns per day and point of primary skill.
var income_per_skill: int = 0
## GameEffects id -> bonus per point of primary skill while supporting the player.
var support_effects: Dictionary = {}


static func from_dictionary(data: Dictionary) -> EmployeeRole:
	var role := EmployeeRole.new()
	role.id = SaveDataReader.get_string(data, "id")
	role.primary_skill = SaveDataReader.get_string(data, "primary_skill")
	if role.id.is_empty() or not Employee.SKILLS.has(role.primary_skill):
		push_warning("EmployeeRole: skipped a role with a missing id or unknown primary skill.")
		return null
	role.title = SaveDataReader.get_string(data, "name", role.id.capitalize())
	role.description = SaveDataReader.get_string(data, "description")
	role.base_salary = maxi(0, SaveDataReader.get_int(data, "base_salary"))
	role.salary_per_skill = maxi(0, SaveDataReader.get_int(data, "salary_per_skill"))
	role.income_per_skill = maxi(0, SaveDataReader.get_int(data, "income_per_skill"))
	var effects: Dictionary = SaveDataReader.get_dictionary(data, "support_effects")
	for effect_id: Variant in effects:
		if effect_id is String:
			role.support_effects[effect_id] = SaveDataReader.get_float(effects, effect_id)
	return role
