class_name Employee
extends RefCounted
## One person: a job candidate or a member of staff.

const SKILL_PROGRAMMING: String = "programming"
const SKILL_SECURITY: String = "security"
const SKILL_NETWORKING: String = "networking"
const SKILL_REVERSE_ENGINEERING: String = "reverse_engineering"
const SKILL_AI: String = "ai"
const SKILL_OPERATIONS: String = "operations"
const SKILLS: PackedStringArray = [
	SKILL_PROGRAMMING, SKILL_SECURITY, SKILL_NETWORKING,
	SKILL_REVERSE_ENGINEERING, SKILL_AI, SKILL_OPERATIONS,
]
const SKILL_NAMES: Dictionary = {
	SKILL_PROGRAMMING: "Programming",
	SKILL_SECURITY: "Security",
	SKILL_NETWORKING: "Networking",
	SKILL_REVERSE_ENGINEERING: "Reverse Engineering",
	SKILL_AI: "AI",
	SKILL_OPERATIONS: "Operations",
}
const MAX_CONDITION: float = 100.0
## Share of output kept at zero energy / zero morale.
const MIN_ENERGY_FACTOR: float = 0.4
const MIN_MORALE_FACTOR: float = 0.5

var id: String = ""
var display_name: String = ""
var role_id: String = ""
## Skill id -> 1..max.
var skills: Dictionary = {}
var experience: int = 0
var level: int = 1
## Pay per business day.
var salary: int = 0
## Personal work rate, around 1.0. Does not change.
var productivity: float = 1.0
var energy: float = MAX_CONDITION
var morale: float = 70.0
var assignment_id: String = ""
var days_employed: int = 0
## Money earned for the company so far.
var total_earned: int = 0


func get_skill(skill_id: String) -> int:
	return int(skills.get(skill_id, 1))


## 0.2 - 1.0: how much of their potential they deliver today. Tired or
## unhappy people get less done.
func get_efficiency() -> float:
	var energy_factor: float = MIN_ENERGY_FACTOR + (1.0 - MIN_ENERGY_FACTOR) * energy / MAX_CONDITION
	var morale_factor: float = MIN_MORALE_FACTOR + (1.0 - MIN_MORALE_FACTOR) * morale / MAX_CONDITION
	return clampf(energy_factor * morale_factor, 0.0, 1.0)


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"role": role_id,
		"skills": skills.duplicate(),
		"experience": experience,
		"level": level,
		"salary": salary,
		"productivity": productivity,
		"energy": energy,
		"morale": morale,
		"assignment": assignment_id,
		"days_employed": days_employed,
		"total_earned": total_earned,
	}


## Rebuilds a person from saved data, clamping every value. Returns null when
## the data has no id, no name or a role that no longer exists.
static func from_dictionary(data: Dictionary, valid_roles: Dictionary, max_skill: int) -> Employee:
	var employee := Employee.new()
	employee.id = SaveDataReader.get_string(data, "id")
	employee.display_name = SaveDataReader.get_string(data, "name")
	employee.role_id = SaveDataReader.get_string(data, "role")
	if employee.id.is_empty() or employee.display_name.is_empty() or not valid_roles.has(employee.role_id):
		return null
	var saved_skills: Dictionary = SaveDataReader.get_dictionary(data, "skills")
	for skill_id: String in SKILLS:
		employee.skills[skill_id] = clampi(SaveDataReader.get_int(saved_skills, skill_id, 1), 1, max_skill)
	employee.experience = maxi(0, SaveDataReader.get_int(data, "experience"))
	employee.level = maxi(1, SaveDataReader.get_int(data, "level", 1))
	employee.salary = maxi(0, SaveDataReader.get_int(data, "salary"))
	employee.productivity = clampf(SaveDataReader.get_float(data, "productivity", 1.0), 0.5, 1.5)
	employee.energy = clampf(SaveDataReader.get_float(data, "energy", MAX_CONDITION), 0.0, MAX_CONDITION)
	employee.morale = clampf(SaveDataReader.get_float(data, "morale", 70.0), 0.0, MAX_CONDITION)
	employee.assignment_id = SaveDataReader.get_string(data, "assignment")
	employee.days_employed = maxi(0, SaveDataReader.get_int(data, "days_employed"))
	employee.total_earned = maxi(0, SaveDataReader.get_int(data, "total_earned"))
	return employee
