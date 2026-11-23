class_name EmployeeAssignment
extends RefCounted
## One kind of task from data/employees/assignments.json: what an employee
## does during a business day and what it does to them.

var id: String = ""
var title: String = ""
var description: String = ""
## Change in energy per day (negative = tiring).
var energy_change: float = 0.0
var morale_change: float = 0.0
var xp_gain: int = 0
## Earns money for the company each day.
var produces_income: bool = false
## Gives the player the support bonus of the employee's role.
var grants_support: bool = false
## GameEffects id -> amount per point of the employee's role skill, granted
## while they are on this assignment (research power, development power).
var effects: Dictionary = {}


static func from_dictionary(data: Dictionary) -> EmployeeAssignment:
	var assignment := EmployeeAssignment.new()
	assignment.id = SaveDataReader.get_string(data, "id")
	if assignment.id.is_empty():
		push_warning("EmployeeAssignment: skipped an assignment without an id.")
		return null
	assignment.title = SaveDataReader.get_string(data, "name", assignment.id.capitalize())
	assignment.description = SaveDataReader.get_string(data, "description")
	assignment.energy_change = SaveDataReader.get_float(data, "energy_change")
	assignment.morale_change = SaveDataReader.get_float(data, "morale_change")
	assignment.xp_gain = maxi(0, SaveDataReader.get_int(data, "xp_gain"))
	assignment.produces_income = data.get("produces_income") == true
	assignment.grants_support = data.get("grants_support") == true
	var raw_effects: Dictionary = SaveDataReader.get_dictionary(data, "effects")
	for effect_id: Variant in raw_effects:
		if effect_id is String:
			assignment.effects[effect_id] = SaveDataReader.get_float(raw_effects, effect_id)
	return assignment
