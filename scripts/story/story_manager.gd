extends Node
## StoryManager (autoload)
##
## The game's arc as a list of chapters (data/story/chapters.json). Each
## chapter has objectives measured against the other managers; when all of
## them hold, the chapter is completed, its reward is paid and the next one
## begins. Finishing the last chapter completes the story.
##
## Objectives are checked whenever something relevant changes during a
## session. They are not checked while a save is being loaded, so loading a
## game can never pay a reward twice.

signal chapter_started(chapter_index: int)
signal chapter_completed(chapter_index: int)
signal objectives_changed
signal story_completed

const DATA_PATH: String = "res://data/story/chapters.json"
const SAVE_SECTION: String = "story"

# Objective types: what is measured.
const TYPE_PLAYER_LEVEL: String = "player_level"
const TYPE_CONTRACTS_COMPLETED: String = "contracts_completed"
const TYPE_HARDWARE_BOUGHT: String = "hardware_bought"
const TYPE_SKILL_POINTS_SPENT: String = "skill_points_spent"
const TYPE_COMPANY_FOUNDED: String = "company_founded"
const TYPE_EMPLOYEES: String = "employees"
const TYPE_OFFICE_TIER: String = "office_tier"
const TYPE_COMPANY_LEVEL: String = "company_level"
const TYPE_RESEARCH_COMPLETED: String = "research_completed"
const TYPE_PRODUCTS_RELEASED: String = "products_released"
const KNOWN_TYPES: PackedStringArray = [
	TYPE_PLAYER_LEVEL, TYPE_CONTRACTS_COMPLETED, TYPE_HARDWARE_BOUGHT, TYPE_SKILL_POINTS_SPENT,
	TYPE_COMPANY_FOUNDED, TYPE_EMPLOYEES, TYPE_OFFICE_TIER, TYPE_COMPANY_LEVEL,
	TYPE_RESEARCH_COMPLETED, TYPE_PRODUCTS_RELEASED,
]

## Each: {id, title, summary, reward_money, reward_xp, objectives: [{text, type, target}]}.
var _chapters: Array[Dictionary] = []
var _chapter_index: int = 0
var _is_complete: bool = false
## Paying a reward changes money and XP, which would start another check.
var _is_checking: bool = false


func _ready() -> void:
	_load_chapters()
	SaveManager.register_section(SAVE_SECTION, self)
	# Everything an objective can depend on.
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _on_world_changed())
	ContractManager.contract_completed.connect(func(_result: Dictionary) -> void: _on_world_changed())
	HardwareManager.hardware_changed.connect(_on_world_changed)
	SkillManager.skills_changed.connect(_on_world_changed)
	OrganizationManager.company_changed.connect(_on_world_changed)
	EmployeeManager.employees_changed.connect(_on_world_changed)
	ResearchManager.research_changed.connect(_on_world_changed)
	ProductManager.products_changed.connect(_on_world_changed)


# --- Queries ----------------------------------------------------------------

func get_chapter_count() -> int:
	return _chapters.size()


func get_chapter_index() -> int:
	return _chapter_index


func is_story_complete() -> bool:
	return _is_complete


## The chapter in progress, or {} once the story is complete.
func get_current_chapter() -> Dictionary:
	if _is_complete or _chapter_index >= _chapters.size():
		return {}
	return _chapters[_chapter_index].duplicate(true)


func get_chapter(chapter_index: int) -> Dictionary:
	if chapter_index < 0 or chapter_index >= _chapters.size():
		return {}
	return _chapters[chapter_index].duplicate(true)


## Objectives of the current chapter with live progress:
## [{text, current, target, done}].
func get_objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for objective: Dictionary in SaveDataReader.get_array(get_current_chapter(), "objectives"):
		var target: int = objective["target"]
		var current: int = mini(target, get_value(objective["type"]))
		result.append({"text": objective["text"], "current": current, "target": target, "done": current >= target})
	return result


## The live number behind an objective type.
func get_value(objective_type: String) -> int:
	match objective_type:
		TYPE_PLAYER_LEVEL:
			return ProgressionManager.level
		TYPE_CONTRACTS_COMPLETED:
			return ContractManager.get_completed_count()
		TYPE_HARDWARE_BOUGHT:
			return HardwareManager.get_purchased_count()
		TYPE_SKILL_POINTS_SPENT:
			return SkillManager.get_spent_points()
		TYPE_COMPANY_FOUNDED:
			return 1 if OrganizationManager.is_founded() else 0
		TYPE_EMPLOYEES:
			return EmployeeManager.get_employee_count()
		TYPE_OFFICE_TIER:
			return OrganizationManager.get_office_index() if OrganizationManager.is_founded() else 0
		TYPE_COMPANY_LEVEL:
			return OrganizationManager.company_level if OrganizationManager.is_founded() else 0
		TYPE_RESEARCH_COMPLETED:
			return ResearchManager.get_completed_count()
		TYPE_PRODUCTS_RELEASED:
			return ProductManager.get_released_count()
	return 0


## Completes every chapter whose objectives all hold, paying each reward.
## Returns how many chapters were completed.
func check_progress() -> int:
	if _is_checking or _is_complete:
		return 0
	_is_checking = true
	var completed: int = 0
	while not _is_complete and _are_objectives_met():
		var finished_index: int = _chapter_index
		var chapter: Dictionary = _chapters[finished_index]
		_chapter_index += 1
		completed += 1
		var reward_money: int = chapter["reward_money"]
		if reward_money > 0:
			EconomyManager.add_money(reward_money, TransactionCategory.OTHER, "Milestone: %s" % chapter["title"])
		ProgressionManager.add_xp(chapter["reward_xp"], "story")
		chapter_completed.emit(finished_index)
		if _chapter_index >= _chapters.size():
			_is_complete = true
			story_completed.emit()
		else:
			chapter_started.emit(_chapter_index)
	_is_checking = false
	objectives_changed.emit()
	return completed


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"chapter": _chapter_index, "complete": _is_complete}


func load_save_data(data: Dictionary) -> void:
	_chapter_index = clampi(SaveDataReader.get_int(data, "chapter"), 0, _chapters.size())
	# "Complete" must agree with the chapter number, whatever the file says.
	_is_complete = _chapter_index >= _chapters.size()
	objectives_changed.emit()


func reset_to_defaults() -> void:
	_chapter_index = 0
	_is_complete = _chapters.is_empty()
	objectives_changed.emit()


# --- Internals --------------------------------------------------------------

func _load_chapters() -> void:
	_chapters.clear()
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "chapters"):
		var objectives: Array[Dictionary] = []
		for raw: Variant in SaveDataReader.get_array(entry, "objectives"):
			if not raw is Dictionary:
				continue
			var objective_type: String = SaveDataReader.get_string(raw, "type")
			if not KNOWN_TYPES.has(objective_type):
				push_warning("StoryManager: unknown objective type '%s'." % objective_type)
				continue
			objectives.append({
				"text": SaveDataReader.get_string(raw, "text", objective_type.capitalize()),
				"type": objective_type,
				"target": maxi(1, SaveDataReader.get_int(raw, "target", 1)),
			})
		if objectives.is_empty():
			push_warning("StoryManager: skipped a chapter without valid objectives.")
			continue
		_chapters.append({
			"id": SaveDataReader.get_string(entry, "id", "chapter_%d" % _chapters.size()),
			"title": SaveDataReader.get_string(entry, "title", "Chapter %d" % (_chapters.size() + 1)),
			"summary": SaveDataReader.get_string(entry, "summary"),
			"reward_money": maxi(0, SaveDataReader.get_int(entry, "reward_money")),
			"reward_xp": maxi(0, SaveDataReader.get_int(entry, "reward_xp")),
			"objectives": objectives,
		})
	_is_complete = _chapters.is_empty()


func _are_objectives_met() -> bool:
	if _chapter_index >= _chapters.size():
		return false
	for objective: Dictionary in _chapters[_chapter_index]["objectives"]:
		if get_value(objective["type"]) < int(objective["target"]):
			return false
	return true


func _on_world_changed() -> void:
	# Only during play: while a save is loading, the other systems already
	# hold the loaded state but the story's own chapter number does not yet.
	if GameManager.is_in_game():
		check_progress()
