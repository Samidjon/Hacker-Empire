extends RefCounted
## Unit tests for the story and for travelling between rooms. Run by
## tests/test_runner.gd, which resets every system before each test and adds
## this object's host node to the tree.

const WORLD_SCENE: PackedScene = preload("res://scenes/world/GameWorld.tscn")

var _report: Callable
## Node the world scenes are added to while a test runs.
var _host: Node


func _init(report: Callable, host: Node) -> void:
	_report = report
	_host = host


func _check(condition: bool, description: String) -> void:
	_report.call(condition, description)


# --- Helpers ----------------------------------------------------------------

func _complete_contract(offer_id: int) -> void:
	ContractManager.load_save_data({"board": [{"offer_id": offer_id, "template_id": "cr_locked_diary", "reward": 100, "seed": offer_id}], "completed_count": ContractManager.get_completed_count()})
	ContractManager.accept_contract(offer_id)
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()


func _research(project_id: String) -> void:
	ResearchManager.start_project(project_id)
	ResearchManager.add_progress(ResearchManager.get_project(project_id).points)


func _hire(count: int) -> void:
	var guard: int = 0
	while EmployeeManager.get_employee_count() < count and guard < 200:
		guard += 1
		var candidates: Array[Employee] = EmployeeManager.get_candidates()
		if candidates.is_empty() or not EmployeeManager.hire(candidates[0].id):
			OrganizationManager.end_day()


# --- Story ------------------------------------------------------------------

func test_story_data() -> void:
	_check(StoryManager.get_chapter_count() >= 6, "at least six chapters")
	var raw: Array[Dictionary] = JsonDataLoader.load_entries(StoryManager.DATA_PATH, "chapters")
	_check(raw.size() == StoryManager.get_chapter_count(), "every chapter in the data file is valid")
	var data_ok: bool = true
	var used_types: Dictionary = {}
	for index: int in StoryManager.get_chapter_count():
		var chapter: Dictionary = StoryManager.get_chapter(index)
		var objectives: Array = chapter["objectives"]
		if String(chapter["title"]).is_empty() or String(chapter["summary"]).is_empty() or chapter["reward_money"] <= 0:
			data_ok = false
		if objectives.size() != (raw[index]["objectives"] as Array).size():
			data_ok = false
		for objective: Dictionary in objectives:
			used_types[objective["type"]] = true
			if String(objective["text"]).is_empty():
				data_ok = false
		# From the second chapter on, a mail introduces the chapter.
		var has_mail: bool = false
		for message: Dictionary in JsonDataLoader.load_entries(MailManager.DATA_PATH, "messages"):
			var trigger: Dictionary = message.get("trigger", {})
			if trigger.get("type") == MailManager.TRIGGER_STORY_CHAPTER and int(trigger.get("chapter", -1)) == index:
				has_mail = true
		if index > 0 and not has_mail:
			data_ok = false
	_check(data_ok, "every chapter has a title, a summary, a reward, valid objectives and an introduction mail")
	_check(used_types.size() == StoryManager.KNOWN_TYPES.size(), "every objective type is used by the story")
	_check(StoryManager.get_chapter(-1).is_empty() and StoryManager.get_chapter(999).is_empty(), "out-of-range chapters are empty")


func test_story_progress() -> void:
	_check(StoryManager.get_chapter_index() == 0 and not StoryManager.is_story_complete(), "a new game starts at the first chapter")
	var objectives: Array[Dictionary] = StoryManager.get_objectives()
	_check(objectives.size() == 2 and not objectives[0]["done"] and objectives[1]["current"] == 1, "objectives show live progress")
	_check(StoryManager.check_progress() == 0, "nothing completes while objectives are open")

	var events: Dictionary = {"completed": [], "started": [], "changed": 0}
	var on_completed: Callable = func(index: int) -> void: events["completed"].append(index)
	var on_started: Callable = func(index: int) -> void: events["started"].append(index)
	var on_changed: Callable = func() -> void: events["changed"] += 1
	StoryManager.chapter_completed.connect(on_completed)
	StoryManager.chapter_started.connect(on_started)
	StoryManager.objectives_changed.connect(on_changed)

	PlayerManager.create_new_player("Storyteller")
	_complete_contract(1)
	_check(StoryManager.get_objectives()[0]["done"] and StoryManager.get_chapter_index() == 0, "one objective met is not a finished chapter")
	_check(StoryManager.get_chapter_index() == 0, "the story does not advance outside a play session by itself")
	ProgressionManager.add_xp(ProgressionManager.get_xp_required())
	var chapter: Dictionary = StoryManager.get_chapter(0)
	var money_before: int = EconomyManager.money
	var xp_before: int = ProgressionManager.total_xp
	_check(StoryManager.check_progress() == 1, "the chapter completes when every objective holds")
	_check(StoryManager.get_chapter_index() == 1 and events["completed"] == [0] and events["started"] == [1], "the next chapter starts")
	_check(EconomyManager.money == money_before + chapter["reward_money"] and ProgressionManager.total_xp == xp_before + chapter["reward_xp"], "the reward is paid")
	_check(MailManager.has_message("story_tools"), "the new chapter is introduced by mail")
	_check(events["changed"] >= 1, "objectives_changed is announced")
	_check(StoryManager.check_progress() == 0 and EconomyManager.money == money_before + chapter["reward_money"], "a reward is paid only once")

	# Several chapters can fall at once.
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	ProgressionManager.add_xp(100000000)
	HardwareManager.purchase("cpu_quadra")
	SkillManager.upgrade("prog_clean_code")
	_complete_contract(2)
	_complete_contract(3)
	OrganizationManager.found_company("Chapter Co")
	_research("automated_triage")
	_check(StoryManager.check_progress() == 2 and StoryManager.get_chapter_index() == 3, "two chapters complete in one check when both are already met")
	_check(events["completed"] == [0, 1, 2] and MailManager.has_message("story_alone") and MailManager.has_message("story_door"), "each completed chapter is announced in order")

	# Objective values follow the systems they measure.
	_check(StoryManager.get_value(StoryManager.TYPE_CONTRACTS_COMPLETED) == 3 and StoryManager.get_value(StoryManager.TYPE_HARDWARE_BOUGHT) == 1, "contracts and hardware are counted")
	_check(StoryManager.get_value(StoryManager.TYPE_COMPANY_FOUNDED) == 1 and StoryManager.get_value(StoryManager.TYPE_OFFICE_TIER) == 0 and StoryManager.get_value(StoryManager.TYPE_EMPLOYEES) == 0, "company values are read")
	_check(StoryManager.get_value("no_such_measure") == 0, "an unknown measure is zero")
	StoryManager.chapter_completed.disconnect(on_completed)
	StoryManager.chapter_started.disconnect(on_started)
	StoryManager.objectives_changed.disconnect(on_changed)


func test_story_completion_and_save() -> void:
	var finished: Dictionary = {"count": 0}
	var on_story_completed: Callable = func() -> void: finished["count"] += 1
	StoryManager.story_completed.connect(on_story_completed)

	# Build an empire the fast way.
	PlayerManager.create_new_player("Emperor")
	EconomyManager.add_money(100000000, TransactionCategory.OTHER)
	ProgressionManager.add_xp(100000000)
	HardwareManager.purchase("cpu_quadra")
	SkillManager.upgrade("prog_clean_code")
	for offer_id: int in [1, 2, 3]:
		_complete_contract(offer_id)
	OrganizationManager.found_company("Empire Inc")
	OrganizationManager.add_company_xp(100000000)
	while OrganizationManager.expand_office():
		pass
	for project_id: String in ["automated_triage", "log_correlation", "vault_core", "signature_library", "traffic_classifier"]:
		_research(project_id)
	StoryManager.check_progress()
	_check(StoryManager.get_chapter_index() == 3 and not StoryManager.is_story_complete(), "without staff and products the story waits at 'Not Alone Any More'")
	_hire(10)
	ProductManager.load_save_data({"released": {"log_lens": {}, "vault_keeper": {}, "net_sentinel": {}, "pocket_analyst": {}}})
	_check(StoryManager.check_progress() == StoryManager.get_chapter_count() - 3, "every remaining chapter completes")
	_check(StoryManager.is_story_complete() and finished["count"] == 1, "the story is complete and says so once")
	_check(StoryManager.get_current_chapter().is_empty() and StoryManager.get_objectives().is_empty(), "there is no current chapter after the end")
	_check(MailManager.has_message("story_complete"), "the ending is marked by a final mail")
	_check(StoryManager.check_progress() == 0 and finished["count"] == 1, "a finished story stays finished")

	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(StoryManager.get_chapter_index() == 0 and not StoryManager.is_story_complete(), "reset returns to the first chapter")
	var money_after_reset: int = EconomyManager.money
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(StoryManager.is_story_complete() and finished["count"] == 1, "the finished story is restored without announcing it again")

	# Loading a game in the middle of the story pays nothing twice.
	StoryManager.load_save_data({"chapter": 2})
	var money_before: int = EconomyManager.money
	_check(StoryManager.get_chapter_index() == 2 and EconomyManager.money == money_before and money_after_reset == 0, "loading sets the chapter without paying rewards")
	StoryManager.load_save_data({"chapter": 999, "complete": false})
	_check(StoryManager.is_story_complete(), "a chapter number past the end means the story is complete")
	StoryManager.load_save_data({"chapter": -5, "complete": true})
	_check(StoryManager.get_chapter_index() == 0 and not StoryManager.is_story_complete(), "'complete' is ignored when the chapter number disagrees")
	StoryManager.load_save_data({})
	_check(StoryManager.get_chapter_index() == 0, "a save from before the story existed starts at the first chapter")
	StoryManager.story_completed.disconnect(on_story_completed)


# --- Rooms and travel -------------------------------------------------------

func test_rooms_and_travel() -> void:
	var world: GameWorld = WORLD_SCENE.instantiate()
	_host.add_child(world)
	_check(world.get_room_id() == GameWorld.ROOM_APARTMENT and world.get_room() != null and not world.get_room() is OfficeRoom, "the world starts in the apartment")
	_check(world.get_player().get_parent() == world.get_room().get_actor_parent(), "the player stands among the room's furniture")
	_check(not world.can_enter(GameWorld.ROOM_OFFICE) and not world.travel_to(GameWorld.ROOM_OFFICE), "there is no office to go to without a company")
	_check(not world.can_enter("the_moon") and not world.travel_to("the_moon"), "an unknown room cannot be entered")

	EconomyManager.add_money(100000000, TransactionCategory.OTHER)
	ProgressionManager.add_xp(100000000)
	OrganizationManager.found_company("Travel Co")
	_check(not OrganizationManager.has_external_office() and not world.can_enter(GameWorld.ROOM_OFFICE), "the home office is not a place to travel to")
	OrganizationManager.expand_office()
	_hire(1)
	var changes: Array[String] = []
	var on_changed: Callable = func(room_id: String) -> void: changes.append(room_id)
	world.room_changed.connect(on_changed)
	_check(world.travel_to(GameWorld.ROOM_OFFICE) and changes == [GameWorld.ROOM_OFFICE], "with rented desks the player can travel to the office")
	var office := world.get_room() as OfficeRoom
	_check(office != null and world.get_room_id() == GameWorld.ROOM_OFFICE, "the office is its own room")
	_check(world.get_player().get_parent() == office.get_actor_parent() and world.get_player().position.is_equal_approx(office.get_spawn_position()), "the player arrives at the office entrance")
	_check(office.get_desk_count() == OrganizationManager.get_desk_capacity(), "the office has one desk per place in the office tier")
	var employee: Employee = EmployeeManager.get_employees()[0]
	_check(office.get_staff_names() == PackedStringArray([employee.display_name]), "an employee sits at a desk under their name")
	_check(office.is_position_walkable(office.get_desk_approach_position(0)), "the player can walk up to a desk")

	# The office follows the company: hiring fills desks, expanding rebuilds the room.
	_hire(2)
	_check(office.get_staff_names().size() == 2, "a new hire appears at the next desk")
	EmployeeManager.dismiss(employee.id)
	_check(office.get_staff_names().size() == 1 and not office.get_staff_names().has(employee.display_name), "someone who leaves is gone from the office")
	OrganizationManager.add_company_xp(100000000)
	OrganizationManager.expand_office()
	var bigger := world.get_room() as OfficeRoom
	_check(bigger != office and bigger.get_desk_count() == OrganizationManager.get_desk_capacity() and changes.size() == 2, "expanding while inside rebuilds the office at its new size")
	_check(world.get_player().get_parent() == bigger.get_actor_parent(), "the player is still in the room after it is rebuilt")

	_check(world.travel_to(GameWorld.ROOM_APARTMENT) and world.get_room_id() == GameWorld.ROOM_APARTMENT, "the player can go home")
	world.room_changed.disconnect(on_changed)
	world.free()

	# The saved room is used when it can still be entered.
	PlayerManager.world_room = GameWorld.ROOM_OFFICE
	var second: GameWorld = WORLD_SCENE.instantiate()
	_host.add_child(second)
	_check(second.get_room_id() == GameWorld.ROOM_OFFICE, "a game saved in the office resumes in the office")
	second.free()
	OrganizationManager.reset_to_defaults()
	var third: GameWorld = WORLD_SCENE.instantiate()
	_host.add_child(third)
	_check(third.get_room_id() == GameWorld.ROOM_APARTMENT, "a saved room that no longer exists falls back to the apartment")
	third.free()

	PlayerManager.set_world_position(Vector2(10.0, 20.0))
	PlayerManager.world_room = GameWorld.ROOM_OFFICE
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(PlayerManager.world_room == PlayerManager.DEFAULT_ROOM, "reset returns the player home")
	_check(SaveManager.load_from_slot(1) and PlayerManager.world_room == GameWorld.ROOM_OFFICE, "the room is saved with the position")
	PlayerManager.load_save_data({"alias": "OldSave"})
	_check(PlayerManager.world_room == PlayerManager.DEFAULT_ROOM, "a save without a room starts in the apartment")
