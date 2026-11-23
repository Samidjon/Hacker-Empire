extends Node
## ResearchManager (autoload)
##
## Owns research: which projects are finished, the one in progress, and the
## technology they unlock. Research runs in real play time, at a rate set by
## research power (the player's own plus everything published through
## GameEffects: hardware, skills, staff assigned to research). Finished
## projects grant permanent bonuses, again through GameEffects.

signal research_started(project_id: String)
signal research_completed(project_id: String)
signal research_changed

const CONFIG: ResearchConfig = preload("res://resources/configurations/research_config.tres")
const DATA_PATH: String = "res://data/research/projects.json"
const SAVE_SECTION: String = "research"
const SECONDS_PER_MINUTE: float = 60.0

var _projects: Dictionary = {} # project id -> ResearchProject
var _project_order: Array[String] = []
var _completed: Array[String] = []
var _active_id: String = ""
## Research points gathered for the active project.
var _progress: float = 0.0


func _ready() -> void:
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "projects"):
		var project: ResearchProject = ResearchProject.from_dictionary(entry)
		if project != null and not _projects.has(project.id):
			_projects[project.id] = project
			_project_order.append(project.id)
	for project_id: String in _project_order:
		for required_id: String in (_projects[project_id] as ResearchProject).requires:
			if not _projects.has(required_id):
				push_warning("ResearchManager: '%s' requires unknown project '%s'." % [project_id, required_id])
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_provider(get_effect)


func _process(delta: float) -> void:
	advance_time(delta)


## Moves research forward. Called every frame; exposed so tests can fast-forward.
func advance_time(seconds: float) -> void:
	if seconds > 0.0 and has_active_project():
		add_progress(get_research_power() * seconds / SECONDS_PER_MINUTE)


# --- Catalogue --------------------------------------------------------------

func get_projects() -> Array[ResearchProject]:
	var projects: Array[ResearchProject] = []
	for project_id: String in _project_order:
		projects.append(_projects[project_id])
	return projects


func get_project(project_id: String) -> ResearchProject:
	return _projects.get(project_id)


# --- State ------------------------------------------------------------------

func is_completed(project_id: String) -> bool:
	return _completed.has(project_id)


func get_completed_count() -> int:
	return _completed.size()


func has_active_project() -> bool:
	return not _active_id.is_empty()


func get_active_project() -> ResearchProject:
	return get_project(_active_id)


func get_progress() -> float:
	return _progress


## 0.0 - 1.0 through the active project.
func get_progress_ratio() -> float:
	var project: ResearchProject = get_active_project()
	return clampf(_progress / project.points, 0.0, 1.0) if project != null else 0.0


## Research points produced per minute of play.
func get_research_power() -> float:
	return CONFIG.base_research_power + maxf(0.0, GameEffects.get_total(GameEffects.RESEARCH_POWER))


## Minutes of play the active project still needs at the current power.
func get_minutes_remaining() -> float:
	var project: ResearchProject = get_active_project()
	var power: float = get_research_power()
	if project == null or power <= 0.0:
		return 0.0
	return maxf(0.0, project.points - _progress) / power


## Reasons the project cannot be started now. Empty = it can.
func get_start_blockers(project_id: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	var project: ResearchProject = get_project(project_id)
	if project == null:
		blockers.append("Unknown project")
		return blockers
	if is_completed(project_id):
		blockers.append("Already researched")
		return blockers
	if _active_id == project_id:
		blockers.append("In progress")
		return blockers
	if has_active_project():
		blockers.append("Finish %s first" % get_active_project().title)
	if ProgressionManager.level < project.required_level:
		blockers.append("Requires level %d" % project.required_level)
	for required_id: String in project.requires:
		if not is_completed(required_id):
			var required: ResearchProject = get_project(required_id)
			blockers.append("Requires %s" % (required.title if required != null else required_id))
	if not EconomyManager.can_afford(project.cost):
		blockers.append("Not enough money (%s short)" % FormatUtils.money(project.cost - EconomyManager.money))
	return blockers


func can_start(project_id: String) -> bool:
	return get_start_blockers(project_id).is_empty()


## Pays for a project and makes it the active one.
func start_project(project_id: String) -> bool:
	if not can_start(project_id):
		return false
	var project: ResearchProject = get_project(project_id)
	if project.cost > 0 and not EconomyManager.spend_money(
		project.cost, TransactionCategory.RESEARCH_COST, project.title
	):
		return false
	_active_id = project_id
	_progress = 0.0
	research_started.emit(project_id)
	research_changed.emit()
	return true


## Adds (or, with a negative amount, removes) research points on the active
## project and completes it when it is full.
func add_progress(points: float) -> void:
	var project: ResearchProject = get_active_project()
	if project == null or is_zero_approx(points):
		return
	_progress = maxf(0.0, _progress + points)
	if _progress >= project.points:
		_complete(project)
	else:
		research_changed.emit()


# --- Bonuses ----------------------------------------------------------------

## GameEffects provider: the technology unlocked by finished projects.
func get_effect(effect_id: String) -> float:
	var total: float = 0.0
	for project_id: String in _completed:
		var project: ResearchProject = get_project(project_id)
		if project != null and project.effects.has(effect_id):
			total += float(project.effects[effect_id])
	return total


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"completed": _completed.duplicate(), "active": _active_id, "progress": _progress}


func load_save_data(data: Dictionary) -> void:
	_completed.clear()
	for entry: Variant in SaveDataReader.get_array(data, "completed"):
		if entry is String and _projects.has(entry) and not _completed.has(entry):
			_completed.append(entry)
	_active_id = SaveDataReader.get_string(data, "active")
	_progress = 0.0
	if not _projects.has(_active_id) or is_completed(_active_id):
		_active_id = ""
	else:
		# Never restore a project as already full: it completes through play.
		_progress = clampf(
			SaveDataReader.get_float(data, "progress"), 0.0, get_active_project().points - 0.01
		)
	research_changed.emit()
	GameEffects.notify_changed()


func reset_to_defaults() -> void:
	_completed.clear()
	_active_id = ""
	_progress = 0.0
	research_changed.emit()
	GameEffects.notify_changed()


# --- Internals --------------------------------------------------------------

func _complete(project: ResearchProject) -> void:
	_completed.append(project.id)
	_active_id = ""
	_progress = 0.0
	if project.grant > 0:
		EconomyManager.add_money(project.grant, TransactionCategory.RESEARCH_REWARD, "Grant: %s" % project.title)
	ProgressionManager.add_xp(project.xp_reward, "research")
	GameEffects.notify_changed()
	research_completed.emit(project.id)
	research_changed.emit()
