extends Node
## Headless unit tests for the MVP 1 core systems.
## Run: godot --headless --path . res://tests/TestRunner.tscn
## Exit code 0 = all passed, 1 = failures.

const TEST_SAVE_DIRECTORY: String = "user://test_saves_unit"
const CONTRACT_TESTS: GDScript = preload("res://tests/contract_tests.gd")
const UPGRADE_TESTS: GDScript = preload("res://tests/upgrade_tests.gd")
const COMPANY_TESTS: GDScript = preload("res://tests/company_tests.gd")
const RESEARCH_TESTS: GDScript = preload("res://tests/research_tests.gd")
const STORY_TESTS: GDScript = preload("res://tests/story_tests.gd")

var _passed: int = 0
var _failed: int = 0
var _current_test: String = ""


func _ready() -> void:
	SaveManager.set_save_directory(TEST_SAVE_DIRECTORY)
	_clean_test_directory()

	_run("economy: add and spend", _test_economy_basic)
	_run("economy: never negative", _test_economy_no_negative)
	_run("economy: history is capped", _test_economy_history_cap)
	_run("progression: xp curve from config", _test_progression_curve)
	_run("progression: level ups", _test_progression_level_up)
	_run("progression: max level", _test_progression_max_level)
	_run("progression: rank table", _test_progression_ranks)
	_run("reputation: clamping", _test_reputation)
	_run("player: alias validation", _test_alias_validation)
	_run("format: money and duration", _test_format)
	_run("save: round trip", _test_save_round_trip)
	_run("save: slot info and most recent", _test_slot_info)
	_run("save: backup recovery", _test_backup_recovery)
	_run("save: corrupted load leaves state untouched", _test_corrupted_load)
	_run("save: newer version rejected", _test_newer_version)
	_run("save: bad field types sanitized", _test_sanitized_fields)
	_run("save: delete slot", _test_delete_slot)
	_run("world: iso projection", _test_iso_projection)
	_run("world: player position persistence", _test_world_position)
	_run("world: room walkable area", _test_room_walkable)
	_run("economy: category totals", _test_category_totals)
	_run("desktop: app registry", _test_app_registry)
	_run("desktop: virtual file system", _test_virtual_file_system)
	_run("desktop: terminal interpreter", _test_terminal_interpreter)
	_run("desktop: mail", _test_mail)
	_run("desktop: network data", _test_network_data)

	var contract_tests: RefCounted = CONTRACT_TESTS.new(_check)
	_run("puzzles: sequence", contract_tests.test_sequence_puzzle)
	_run("puzzles: cipher", contract_tests.test_cipher_puzzle)
	_run("puzzles: spot", contract_tests.test_spot_puzzle)
	_run("puzzles: match", contract_tests.test_match_puzzle)
	_run("contracts: data", contract_tests.test_contract_data)
	_run("contracts: board and requirements", contract_tests.test_contract_board)
	_run("contracts: completion", contract_tests.test_contract_completion)
	_run("contracts: failure", contract_tests.test_contract_failure)
	_run("contracts: save and load", contract_tests.test_contract_save)

	var upgrade_tests: RefCounted = UPGRADE_TESTS.new(_check)
	_run("effects: shared bonus registry", upgrade_tests.test_game_effects)
	_run("hardware: data", upgrade_tests.test_hardware_data)
	_run("hardware: starting state", upgrade_tests.test_hardware_starting_state)
	_run("hardware: purchase and install", upgrade_tests.test_hardware_purchase)
	_run("hardware: effects on contracts", upgrade_tests.test_hardware_effects)
	_run("hardware: contract requirements", upgrade_tests.test_hardware_requirements)
	_run("hardware: save and load", upgrade_tests.test_hardware_save)
	_run("skills: data", upgrade_tests.test_skill_data)
	_run("skills: points and upgrades", upgrade_tests.test_skill_points_and_upgrades)
	_run("skills: effects on contracts", upgrade_tests.test_skill_effects)
	_run("skills: requirements and save", upgrade_tests.test_skill_requirements_and_save)

	var company_tests: RefCounted = COMPANY_TESTS.new(_check)
	_run("company: founding", company_tests.test_founding)
	_run("company: level and reputation", company_tests.test_company_level)
	_run("company: office expansion", company_tests.test_office_expansion)
	_run("company: business day and rent", company_tests.test_business_day_and_rent)
	_run("company: save and load", company_tests.test_organization_save)
	_run("employees: data", company_tests.test_employee_data)
	_run("employees: recruitment", company_tests.test_recruitment)
	_run("employees: daily work", company_tests.test_daily_work)
	_run("employees: support and unpaid salaries", company_tests.test_support_and_unpaid)
	_run("employees: save and load", company_tests.test_employee_save)

	var research_tests: RefCounted = RESEARCH_TESTS.new(_check)
	_run("research: data", research_tests.test_research_data)
	_run("research: projects", research_tests.test_research_flow)
	_run("research: save and load", research_tests.test_research_save)
	_run("products: development", research_tests.test_product_development)
	_run("products: revenue and save", research_tests.test_product_revenue)
	_run("economy: running costs", research_tests.test_running_costs)
	_run("events: data", research_tests.test_event_data)
	_run("events: choices", research_tests.test_event_choices)
	_run("events: timing and save", research_tests.test_event_timing_and_save)

	var story_tests: RefCounted = STORY_TESTS.new(_check, self)
	_run("story: data", story_tests.test_story_data)
	_run("story: chapter progress", story_tests.test_story_progress)
	_run("story: completion and save", story_tests.test_story_completion_and_save)
	_run("world: rooms and travel", story_tests.test_rooms_and_travel)

	_clean_test_directory()
	SaveManager.reset_all_sections()
	print("\n==== %d passed, %d failed ====" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Tests ------------------------------------------------------------------

func _test_economy_basic() -> void:
	_check(EconomyManager.money == 0, "starts at zero after reset")
	_check(EconomyManager.add_money(500, TransactionCategory.CONTRACT, "job"), "add succeeds")
	_check(EconomyManager.spend_money(200, TransactionCategory.HARDWARE, "ram"), "spend succeeds")
	_check(EconomyManager.money == 300, "balance is 300")
	_check(EconomyManager.total_earned == 500 and EconomyManager.total_spent == 200, "totals tracked")
	var recent: Array[Dictionary] = EconomyManager.get_recent_transactions(5)
	_check(recent.size() == 2, "two transactions recorded")
	_check(recent[0]["amount"] == -200 and recent[0]["balance_after"] == 300, "newest first")
	EconomyManager.grant_starting_funds()
	_check(EconomyManager.money == 300 + EconomyManager.CONFIG.starting_money, "starting funds from config")


func _test_economy_no_negative() -> void:
	EconomyManager.add_money(100, TransactionCategory.OTHER)
	_check(not EconomyManager.spend_money(101, TransactionCategory.HARDWARE), "overspend rejected")
	_check(EconomyManager.money == 100, "balance unchanged after rejection")
	_check(not EconomyManager.spend_money(-50, TransactionCategory.HARDWARE), "negative spend rejected")
	_check(not EconomyManager.add_money(-50, TransactionCategory.OTHER), "negative income rejected")
	_check(not EconomyManager.add_money(0, TransactionCategory.OTHER), "zero income rejected")
	_check(EconomyManager.money == 100, "balance still 100")
	_check(EconomyManager.spend_money(100, TransactionCategory.HARDWARE), "can spend exact balance")
	_check(EconomyManager.money == 0, "balance is exactly zero")


func _test_economy_history_cap() -> void:
	var cap: int = EconomyManager.CONFIG.max_transaction_history
	for index: int in cap + 25:
		EconomyManager.add_money(1, TransactionCategory.OTHER)
	_check(EconomyManager.get_transaction_count() == cap, "history capped at %d" % cap)
	_check(EconomyManager.money == cap + 25, "balance unaffected by trimming")


func _test_progression_curve() -> void:
	var config: ProgressionConfig = ProgressionManager.CONFIG
	_check(config.max_level == 50, "50 levels configured")
	_check(config.get_xp_to_next_level(1) == config.base_xp, "level 1 needs base xp")
	_check(config.get_xp_to_next_level(config.max_level) == 0, "no xp needed at max")
	var increasing: bool = true
	for level: int in range(1, config.max_level - 1):
		if config.get_xp_to_next_level(level + 1) <= config.get_xp_to_next_level(level):
			increasing = false
	_check(increasing, "requirement strictly increases")


func _test_progression_level_up() -> void:
	var needed: int = ProgressionManager.get_xp_required()
	_check(ProgressionManager.add_xp(needed - 1) == 0, "no level before threshold")
	_check(ProgressionManager.level == 1, "still level 1")
	_check(ProgressionManager.add_xp(1) == 1, "levels at threshold")
	_check(ProgressionManager.level == 2 and ProgressionManager.current_xp == 0, "level 2, xp reset")
	var two_levels: int = ProgressionManager.CONFIG.get_xp_to_next_level(2) + ProgressionManager.CONFIG.get_xp_to_next_level(3)
	_check(ProgressionManager.add_xp(two_levels + 7) == 2, "multi level-up in one grant")
	_check(ProgressionManager.level == 4 and ProgressionManager.current_xp == 7, "remainder carried over")
	_check(ProgressionManager.add_xp(-10) == 0 and ProgressionManager.add_xp(0) == 0, "non-positive xp ignored")
	_check(ProgressionManager.total_xp == needed + two_levels + 7, "lifetime xp tracked")


func _test_progression_max_level() -> void:
	ProgressionManager.add_xp(100000000)
	_check(ProgressionManager.level == 50, "capped at level 50")
	_check(ProgressionManager.is_max_level() and ProgressionManager.current_xp == 0, "no overflow xp at max")
	_check(is_equal_approx(ProgressionManager.get_level_progress(), 1.0), "progress is full at max")
	_check(ProgressionManager.add_xp(500) == 0 and ProgressionManager.level == 50, "stays at max")


func _test_progression_ranks() -> void:
	var config: ProgressionConfig = ProgressionManager.CONFIG
	var expected: Dictionary = {
		1: "Beginner", 5: "Beginner", 6: "Amateur", 10: "Amateur",
		11: "Professional", 20: "Professional", 21: "Expert", 30: "Expert",
		31: "Specialist", 40: "Specialist", 41: "Legend", 50: "Legend",
	}
	for level: int in expected:
		_check(config.get_rank_name(level) == expected[level], "level %d is %s" % [level, expected[level]])


func _test_reputation() -> void:
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, 25)
	ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, 10)
	_check(ReputationManager.white_reputation == 25, "white rep added")
	_check(ReputationManager.underground_reputation == 10, "underground rep added")
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, -100)
	_check(ReputationManager.white_reputation == 0, "reputation cannot go below zero")
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, 99999999)
	_check(ReputationManager.white_reputation == ReputationManager.CONFIG.max_reputation, "reputation capped")
	ReputationManager.add_heat(250.0)
	_check(is_equal_approx(ReputationManager.heat, ReputationManager.CONFIG.max_heat), "heat capped")
	ReputationManager.add_heat(-1000.0)
	_check(is_zero_approx(ReputationManager.heat), "heat floors at zero")


func _test_alias_validation() -> void:
	_check(PlayerManager.validate_alias("Zero_Cool").is_empty(), "normal alias valid")
	_check(PlayerManager.validate_alias("  neo-1  ").is_empty(), "surrounding spaces trimmed")
	_check(not PlayerManager.validate_alias("ab").is_empty(), "too short rejected")
	_check(not PlayerManager.validate_alias("a".repeat(40)).is_empty(), "too long rejected")
	_check(not PlayerManager.validate_alias("bad name!").is_empty(), "symbols rejected")
	_check(not PlayerManager.validate_alias("").is_empty(), "empty rejected")
	_check(not GameManager.start_new_game(1, "x"), "GameManager refuses invalid alias")
	_check(not GameManager.start_new_game(99, "ValidName"), "GameManager refuses invalid slot")


func _test_format() -> void:
	_check(FormatUtils.money(0) == "$0", "zero")
	_check(FormatUtils.money(999) == "$999", "no separator under 1000")
	_check(FormatUtils.money(1500) == "$1,500", "thousands")
	_check(FormatUtils.money(1234567) == "$1,234,567", "millions")
	_check(FormatUtils.signed_money(-200) == "-$200", "signed negative")
	_check(FormatUtils.signed_money(200) == "+$200", "signed positive")
	_check(FormatUtils.duration(3725.9) == "01:02:05", "duration")


func _test_save_round_trip() -> void:
	_populate_state()
	_check(SaveManager.save_to_slot(1), "save succeeds")
	var saved_id: String = PlayerManager.player_id
	SaveManager.reset_all_sections()
	_check(EconomyManager.money == 0 and ProgressionManager.level == 1, "reset clears state")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(PlayerManager.hacker_alias == "Tester_01", "alias restored")
	_check(PlayerManager.player_id == saved_id, "player id restored")
	_check(is_equal_approx(PlayerManager.playtime_seconds, 321.5), "playtime restored")
	_check(EconomyManager.money == 1150, "money restored")
	_check(EconomyManager.total_earned == 1500 and EconomyManager.total_spent == 350, "totals restored")
	_check(EconomyManager.get_transaction_count() == 2, "transactions restored")
	var newest: Dictionary = EconomyManager.get_recent_transactions(1)[0]
	_check(newest["amount"] is int and newest["amount"] == -350, "transaction amounts are ints again")
	_check(newest["description"] == "GPU", "transaction text restored")
	_check(ProgressionManager.level == 3 and ProgressionManager.current_xp == 40, "level and xp restored")
	_check(ReputationManager.white_reputation == 12, "white rep restored")
	_check(ReputationManager.underground_reputation == 7, "underground rep restored")
	_check(is_equal_approx(ReputationManager.heat, 33.0), "heat restored")
	EconomyManager.add_money(1, TransactionCategory.OTHER)
	_check(EconomyManager.get_recent_transactions(1)[0]["id"] == 3, "transaction ids continue after load")


func _test_slot_info() -> void:
	_check(SaveManager.get_slot_count() == SaveManager.CONFIG.slot_count, "slot count from config")
	_check(SaveManager.get_slot_info(1).is_empty(), "fresh slot is empty")
	_check(SaveManager.get_most_recent_slot() == SaveManager.NO_SLOT, "no recent slot when empty")
	_check(not SaveManager.has_any_save(), "no saves yet")
	_check(not SaveManager.load_from_slot(1), "loading an empty slot fails")
	_check(not SaveManager.save_to_slot(0) and not SaveManager.save_to_slot(99), "invalid slots rejected")

	_populate_state()
	SaveManager.save_to_slot(2)
	var info: SaveSlotInfo = SaveManager.get_slot_info(2)
	_check(info.status == SaveSlotInfo.Status.VALID, "slot is valid")
	_check(info.summary.get("alias") == "Tester_01", "summary has alias")
	_check(SaveDataReader.get_int(info.summary, "level") == 3, "summary has level")
	_check(SaveDataReader.get_int(info.summary, "money") == 1150, "summary has money")
	_check(info.saved_at_unix > 0, "timestamp recorded")
	_check(SaveManager.get_most_recent_slot() == 2, "most recent slot found")
	_check(SaveManager.has_any_save(), "has saves")


func _test_backup_recovery() -> void:
	_populate_state()
	SaveManager.save_to_slot(1)                       # first save: money 1150
	EconomyManager.add_money(50, TransactionCategory.OTHER)
	SaveManager.save_to_slot(1)                       # second save rotates the first into .bak
	_check(FileAccess.file_exists(SaveManager.get_backup_path(1)), "backup created on second save")

	_write_raw(SaveManager.get_slot_path(1), "{ this is not json")
	var info: SaveSlotInfo = SaveManager.get_slot_info(1)
	_check(info.status == SaveSlotInfo.Status.RECOVERED_FROM_BACKUP, "slot reports backup recovery")
	_check(info.is_loadable(), "recovered slot is loadable")
	SaveManager.reset_all_sections()
	_check(SaveManager.load_from_slot(1), "load falls back to backup")
	_check(EconomyManager.money == 1150, "backup holds the previous save")

	# Saving over a damaged primary must not destroy the working backup.
	_write_raw(SaveManager.get_slot_path(1), "garbage")
	_check(SaveManager.save_to_slot(1), "can save over a corrupted primary")
	_check(SaveManager.get_slot_info(1).status == SaveSlotInfo.Status.VALID, "slot valid again")


func _test_corrupted_load() -> void:
	_write_raw(SaveManager.get_slot_path(3), "\u0000\u0001 nonsense")
	_write_raw(SaveManager.get_backup_path(3), "[1, 2, 3]")
	var info: SaveSlotInfo = SaveManager.get_slot_info(3)
	_check(info.status == SaveSlotInfo.Status.CORRUPTED, "slot reported corrupted")
	_check(not info.is_loadable() and not info.error.is_empty(), "corruption has a reason")
	_check(SaveManager.get_most_recent_slot() == SaveManager.NO_SLOT, "corrupted slot is never 'most recent'")
	_check(SaveManager.has_any_save(), "corrupted slot still counts as occupied")

	EconomyManager.add_money(777, TransactionCategory.OTHER)
	ProgressionManager.add_xp(150)
	_check(not SaveManager.load_from_slot(3), "corrupted load fails")
	_check(EconomyManager.money == 777 and ProgressionManager.level == 2, "live state untouched by failed load")

	_write_raw(SaveManager.get_slot_path(2), JSON.stringify({"format": "something_else", "version": 1, "sections": {}}))
	_check(SaveManager.get_slot_info(2).status == SaveSlotInfo.Status.CORRUPTED, "foreign file rejected")
	_write_raw(SaveManager.get_slot_path(2), JSON.stringify({"format": SaveManager.SAVE_FORMAT_ID, "version": 1}))
	_check(SaveManager.get_slot_info(2).status == SaveSlotInfo.Status.CORRUPTED, "missing sections rejected")


func _test_newer_version() -> void:
	var payload: Dictionary = {
		"format": SaveManager.SAVE_FORMAT_ID,
		"version": SaveManager.SAVE_VERSION + 1,
		"saved_at": 100,
		"sections": {},
	}
	_write_raw(SaveManager.get_slot_path(1), JSON.stringify(payload))
	var info: SaveSlotInfo = SaveManager.get_slot_info(1)
	_check(info.status == SaveSlotInfo.Status.CORRUPTED, "newer version not loadable")
	_check(info.error.contains("newer"), "error explains the version problem")
	_check(not SaveManager.load_from_slot(1), "load refuses newer version")


func _test_sanitized_fields() -> void:
	var payload: Dictionary = {
		"format": SaveManager.SAVE_FORMAT_ID,
		"version": SaveManager.SAVE_VERSION,
		"saved_at": 100,
		"sections": {
			"player": {"alias": 12345, "playtime_seconds": "long"},
			"economy": {"money": -500, "transactions": ["junk", {"amount": "x"}, 7]},
			"progression": {"level": 9999, "current_xp": -20},
			"reputation": {"white": -3, "underground": [], "heat": 5000},
			# "unknown_future_section" style data must simply be ignored.
			"mystery": {"a": 1},
		},
	}
	_write_raw(SaveManager.get_slot_path(1), JSON.stringify(payload))
	_check(SaveManager.load_from_slot(1), "structurally valid file loads")
	_check(PlayerManager.hacker_alias == PlayerManager.CONFIG.default_alias, "bad alias falls back to default")
	_check(is_zero_approx(PlayerManager.playtime_seconds), "bad playtime falls back to zero")
	_check(EconomyManager.money == 0, "negative money clamped to zero")
	_check(EconomyManager.get_transaction_count() == 1, "junk transactions dropped")
	_check(ProgressionManager.level == 50 and ProgressionManager.current_xp == 0, "level clamped to max")
	_check(ReputationManager.white_reputation == 0 and ReputationManager.underground_reputation == 0, "reputation sanitized")
	_check(is_equal_approx(ReputationManager.heat, ReputationManager.CONFIG.max_heat), "heat clamped")

	# A save written before a system existed has no section for it.
	payload["sections"] = {"economy": {"money": 42}}
	_write_raw(SaveManager.get_slot_path(1), JSON.stringify(payload))
	_check(SaveManager.load_from_slot(1), "save with missing sections loads")
	_check(EconomyManager.money == 42 and ProgressionManager.level == 1, "missing sections use defaults")


func _test_delete_slot() -> void:
	_populate_state()
	SaveManager.save_to_slot(1)
	SaveManager.save_to_slot(1)
	_check(SaveManager.delete_slot(1), "delete succeeds")
	_check(SaveManager.get_slot_info(1).is_empty(), "slot empty after delete")
	_check(not FileAccess.file_exists(SaveManager.get_backup_path(1)), "backup removed too")
	_check(SaveManager.delete_slot(1), "deleting an empty slot is harmless")
	_check(not SaveManager.delete_slot(99), "invalid slot rejected")


func _test_iso_projection() -> void:
	_check(IsoUtils.grid_to_screen(Vector2.ZERO) == Vector2.ZERO, "origin maps to origin")
	_check(IsoUtils.grid_to_screen(Vector2(1, 0)) == Vector2(64, 32), "grid x runs down-right")
	_check(IsoUtils.grid_to_screen(Vector2(0, 1)) == Vector2(-64, 32), "grid y runs down-left")
	_check(IsoUtils.grid_to_screen(Vector2.ZERO, 1.0) == Vector2(0, -64), "elevation raises on screen")
	var all_round_trip: bool = true
	for grid: Vector2 in [Vector2(3.5, 1.25), Vector2(0, 8), Vector2(7.9, 0.1), Vector2(-2, 5)]:
		if not IsoUtils.screen_to_grid(IsoUtils.grid_to_screen(grid)).is_equal_approx(grid):
			all_round_trip = false
	_check(all_round_trip, "screen_to_grid inverts grid_to_screen")


func _test_world_position() -> void:
	_check(not PlayerManager.has_world_position, "no position after reset")
	_check(not PlayerManager.get_save_data().has("world_position"), "no position written when unknown")
	PlayerManager.create_new_player("Walker")
	PlayerManager.set_world_position(Vector2(123.5, -45.25))
	PlayerManager.set_world_position(Vector2(NAN, 3.0))
	_check(PlayerManager.world_position == Vector2(123.5, -45.25), "non-finite position ignored")
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(not PlayerManager.has_world_position, "reset clears position")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(PlayerManager.has_world_position, "position flagged after load")
	_check(PlayerManager.world_position.is_equal_approx(Vector2(123.5, -45.25)), "position restored")

	# MVP 1 saves have no position; damaged ones must not produce one.
	PlayerManager.load_save_data({"alias": "OldSave"})
	_check(not PlayerManager.has_world_position, "old save without position loads")
	PlayerManager.load_save_data({"alias": "Broken", "world_position": {"x": "left", "y": 4}})
	_check(not PlayerManager.has_world_position, "malformed position rejected")
	PlayerManager.load_save_data({"alias": "Broken", "world_position": [1, 2]})
	_check(not PlayerManager.has_world_position, "wrong position type rejected")


func _test_room_walkable() -> void:
	var room: HackerRoom = (load("res://scenes/world/HackerRoom.tscn") as PackedScene).instantiate()
	add_child(room)
	_check(room.is_position_walkable(room.get_spawn_position()), "spawn point is walkable")
	_check(not room.is_position_walkable(Vector2(99999.0, 0.0)), "far outside is rejected")
	_check(not room.is_position_walkable(IsoUtils.grid_to_screen(Vector2(-0.5, 4.0))), "behind the wall is rejected")
	_check(not room.is_position_walkable(IsoUtils.grid_to_screen(Vector2(3.0, 0.5))), "inside the desk is rejected")
	_check(not room.is_position_walkable(IsoUtils.grid_to_screen(Vector2(1.0, 6.4))), "inside the bed is rejected")
	_check(room.is_position_walkable(IsoUtils.grid_to_screen(Vector2(3.0, 1.45))), "in front of the desk is walkable")

	var interactables: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if room.is_ancestor_of(node):
			interactables.append(node)
	_check(interactables.size() == 5, "room has five interactables")
	var all_reachable: bool = true
	var kinds: Dictionary = {}
	for node: Node in interactables:
		var interactable := node as Interactable
		kinds[interactable.kind] = true
		if not room.is_position_walkable(room.to_local(interactable.global_position)):
			all_reachable = false
		if interactable.prompt_text.is_empty():
			all_reachable = false
	_check(all_reachable, "every interactable stands on walkable floor and has a prompt")
	_check(kinds.size() == 5, "computer, rest, inspect, storage and travel interactions all present")
	room.queue_free()


func _test_category_totals() -> void:
	EconomyManager.add_money(1000, TransactionCategory.CONTRACT)
	EconomyManager.add_money(250, TransactionCategory.CONTRACT)
	EconomyManager.add_money(40, TransactionCategory.SUBSCRIPTION)
	EconomyManager.spend_money(300, TransactionCategory.HARDWARE)
	EconomyManager.spend_money(999999, TransactionCategory.SALARY) # rejected
	var income: Dictionary = EconomyManager.get_income_by_category()
	var expenses: Dictionary = EconomyManager.get_expenses_by_category()
	_check(income.get(TransactionCategory.CONTRACT) == 1250, "income summed per category")
	_check(income.get(TransactionCategory.SUBSCRIPTION) == 40, "second income category tracked")
	_check(expenses.get(TransactionCategory.HARDWARE) == 300, "expenses summed per category")
	_check(not expenses.has(TransactionCategory.SALARY), "rejected spend is not counted")
	income["tampered"] = 1
	_check(not EconomyManager.get_income_by_category().has("tampered"), "returned totals are a copy")

	# Totals outlive the trimmed history.
	for index: int in EconomyManager.CONFIG.max_transaction_history + 5:
		EconomyManager.add_money(1, TransactionCategory.OTHER)
	_check(EconomyManager.get_income_by_category().get(TransactionCategory.CONTRACT) == 1250, "totals survive history trimming")

	SaveManager.save_to_slot(1)
	SaveManager.reset_all_sections()
	_check(EconomyManager.get_income_by_category().is_empty(), "reset clears totals")
	SaveManager.load_from_slot(1)
	_check(EconomyManager.get_income_by_category().get(TransactionCategory.CONTRACT) == 1250, "totals restored from save")
	_check(EconomyManager.get_expenses_by_category().get(TransactionCategory.HARDWARE) == 300, "expense totals restored")

	# Saves made before totals existed rebuild them from the history.
	EconomyManager.load_save_data({"money": 70, "transactions": [
		{"id": 1, "amount": 100, "category": "contract"}, {"id": 2, "amount": -30, "category": "hardware"},
	]})
	_check(EconomyManager.get_income_by_category().get("contract") == 100, "old save: income rebuilt from history")
	_check(EconomyManager.get_expenses_by_category().get("hardware") == 30, "old save: expenses rebuilt from history")


func _test_app_registry() -> void:
	var definitions: Array[AppDefinition] = AppRegistry.load_definitions(AppRegistry.DEFAULT_DATA_PATH, true)
	var by_id: Dictionary = {}
	for definition: AppDefinition in definitions:
		by_id[definition.id] = definition
	_check(by_id.size() == definitions.size(), "app ids are unique")
	var required: PackedStringArray = [
		"dashboard", "terminal", "contracts", "marketplace", "files", "mail", "hardware",
		"skills", "network", "finance", "organization", "employees", "research",
	]
	var all_present: bool = true
	for app_id: String in required:
		if not by_id.has(app_id):
			all_present = false
	_check(all_present, "all 13 required applications are registered")
	var installed: PackedStringArray = []
	var scenes_ok: bool = true
	for definition: AppDefinition in definitions:
		if definition.is_available():
			installed.append(definition.id)
			var instance: Node = (load(definition.scene_path) as PackedScene).instantiate()
			if not instance is Control:
				scenes_ok = false
			instance.free()
		elif definition.locked_note.is_empty():
			scenes_ok = false
	_check(scenes_ok, "installed apps load as Controls; the others explain why they are missing")
	for app_id: String in ["dashboard", "terminal", "files", "mail", "finance", "network", "contracts", "marketplace", "hardware", "skills", "organization", "employees", "research"]:
		_check(installed.has(app_id), "%s is installed" % app_id)
	_check(by_id.has("devtools"), "dev tools listed in debug builds")
	var release_ids: PackedStringArray = []
	for definition: AppDefinition in AppRegistry.load_definitions(AppRegistry.DEFAULT_DATA_PATH, false):
		release_ids.append(definition.id)
	_check(not release_ids.has("devtools"), "dev tools hidden outside debug builds")


func _test_virtual_file_system() -> void:
	var fs: VirtualFileSystem = VirtualFileSystem.load_from_file()
	_check(fs.is_directory("/") and fs.is_directory(VirtualFileSystem.HOME), "root and home exist")
	_check(fs.is_file("/home/user/welcome.txt"), "file exists")
	_check(not fs.exists("/home/user/missing.txt"), "missing path reported")
	_check(fs.normalize_path("notes/../welcome.txt", "/home/user") == "/home/user/welcome.txt", "relative path with ..")
	_check(fs.normalize_path("../../../..", "/home/user") == "/", ".. cannot climb above the root")
	_check(fs.normalize_path("~/notes") == "/home/user/notes", "~ expands to home")
	_check(fs.normalize_path("/docs//./x/") == "/docs/x", "redundant separators removed")
	var entries: Array[Dictionary] = fs.list_directory(VirtualFileSystem.HOME)
	_check(entries.size() == 2 and entries[0]["is_directory"] and entries[0]["name"] == "notes", "folders listed first")
	_check(entries[1]["name"] == "welcome.txt" and entries[1]["size"] > 0, "files report a size")
	_check(fs.read_file("/sys/version.txt").begins_with("EMPIRE OS"), "file content read")
	_check(fs.read_file("/sys").is_empty() and fs.list_directory("/sys/version.txt").is_empty(), "wrong kind of path yields nothing")
	_check(fs.get_parent_path("/docs") == "/" and fs.get_parent_path("/") == "/", "parent path")


func _test_terminal_interpreter() -> void:
	PlayerManager.create_new_player("Term_User")
	EconomyManager.add_money(4321, TransactionCategory.OTHER)
	var interpreter := TerminalInterpreter.new()
	interpreter.filesystem = VirtualFileSystem.load_from_file()
	interpreter.app_definitions = AppRegistry.load_definitions()

	_check(interpreter.execute("   ").lines.is_empty(), "blank input prints nothing")
	var help: TerminalInterpreter.Result = interpreter.execute("help")
	var help_text: String = "\n".join(help.lines)
	var documented: bool = true
	for command_name: String in interpreter.get_command_names():
		if not help_text.contains(command_name):
			documented = false
	_check(documented and not help.is_error, "help documents every command")
	_check(interpreter.execute("HELP").is_error == false, "commands are case-insensitive")
	_check(interpreter.execute("nmap 10.0.0.1").is_error, "unknown commands fail")
	_check("\n".join(interpreter.execute("whoami").lines) == "Term_User", "whoami")
	_check("\n".join(interpreter.execute("balance").lines).contains("$4,321"), "balance reads the economy")
	_check("\n".join(interpreter.execute("status").lines).contains("Beginner"), "status reads progression")
	_check(interpreter.get_prompt() == "term_user@empire:~$", "prompt shows alias and folder")

	_check(interpreter.execute("pwd").lines[0] == VirtualFileSystem.HOME, "starts in home")
	_check(not interpreter.execute("cd notes").is_error and interpreter.cwd == "/home/user/notes", "cd relative")
	_check(interpreter.get_prompt().ends_with("~/notes$"), "prompt follows cd")
	_check(Array(interpreter.execute("ls").lines).has("todo.txt"), "ls current folder")
	_check(Array(interpreter.execute("ls /").lines).has("docs/"), "ls marks folders")
	_check(interpreter.execute("cd /nowhere").is_error and interpreter.cwd == "/home/user/notes", "cd to a missing folder fails and stays")
	_check(interpreter.execute("cd todo.txt").is_error, "cd into a file fails")
	_check(interpreter.execute("cat").is_error, "cat without arguments shows usage")
	_check(interpreter.execute("cat /docs").is_error, "cat on a folder fails")
	_check(interpreter.execute("cat todo.txt").lines[0] == "TODO", "cat prints a file")
	_check(not interpreter.execute("cd").is_error and interpreter.cwd == VirtualFileSystem.HOME, "cd alone goes home")
	_check(interpreter.execute("echo a  b c").lines[0] == "a b c", "echo")

	var opened: Array[String] = []
	interpreter.open_app_requested.connect(func(app_id: String) -> void: opened.append(app_id))
	_check(not interpreter.execute("open mail").is_error and opened == ["mail"], "open requests an installed app")
	_check(interpreter.execute("open nosuchapp").is_error and opened.size() == 1, "open refuses an unknown app")
	_check(interpreter.execute("open").is_error and interpreter.execute("open xyz").is_error, "open validates its argument")
	var flags: Dictionary = {"cleared": false, "exited": false}
	interpreter.clear_requested.connect(func() -> void: flags["cleared"] = true)
	interpreter.exit_requested.connect(func() -> void: flags["exited"] = true)
	interpreter.execute("clear")
	interpreter.execute("exit")
	_check(flags["cleared"] and flags["exited"], "clear and exit raise their signals")
	_check(interpreter.execute("history").lines.size() == interpreter.get_history().size(), "history lists what was typed")
	for index: int in TerminalInterpreter.MAX_HISTORY + 20:
		interpreter.execute("echo %d" % index)
	_check(interpreter.get_history().size() == TerminalInterpreter.MAX_HISTORY, "history is capped")

	var bare := TerminalInterpreter.new()
	_check(bare.execute("ls").is_error and bare.execute("cat x").is_error and bare.execute("apps").is_error, "commands fail cleanly without a file system or app list")


func _test_mail() -> void:
	_check(MailManager.get_message_count() == 0, "inbox empty after reset")
	PlayerManager.create_new_player("Mail_User")
	var received: Array[String] = []
	var on_received: Callable = func(message: Dictionary) -> void: received.append(message["id"])
	MailManager.mail_received.connect(on_received)

	_check(MailManager.deliver_trigger(MailManager.TRIGGER_NEW_GAME) == 2, "new game delivers the welcome mail")
	_check(MailManager.deliver_trigger(MailManager.TRIGGER_NEW_GAME) == 0, "a message is never delivered twice")
	_check(MailManager.get_unread_count() == 2 and received.size() == 2, "unread count and signal")
	var messages: Array[Dictionary] = MailManager.get_messages()
	_check(messages[0]["id"] == received[1], "newest message first")
	_check(String(messages[1]["subject"]).contains("Mail_User") and not String(messages[1]["body"]).contains("{alias}"), "alias filled into the text")
	_check(not MailManager.deliver("no_such_message"), "unknown message id rejected")

	MailManager.mark_read(messages[0]["id"])
	MailManager.mark_read(messages[0]["id"])
	_check(MailManager.get_unread_count() == 1, "mark_read is idempotent")

	# Level-ups deliver mail, including every step of a multi-level jump.
	ProgressionManager.add_xp(ProgressionManager.get_xp_required())
	_check(MailManager.has_message("level_2"), "reaching level 2 delivers mail")
	var config: ProgressionConfig = ProgressionManager.CONFIG
	var xp_to_level_12: int = 0
	for level: int in range(2, 12):
		xp_to_level_12 += config.get_xp_to_next_level(level)
	ProgressionManager.add_xp(xp_to_level_12)
	_check(ProgressionManager.level == 12, "jumped to level 12")
	_check(MailManager.has_message("rank_amateur") and MailManager.has_message("rank_professional"), "a multi-level jump delivers every milestone")
	_check(not MailManager.has_message("rank_expert"), "later milestones not delivered early")

	var count_before: int = MailManager.get_message_count()
	var unread_before: int = MailManager.get_unread_count()
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(MailManager.get_message_count() == 0, "reset empties the inbox")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(MailManager.get_message_count() == count_before and MailManager.get_unread_count() == unread_before, "inbox and read state restored")
	_check(MailManager.get_message_count() == count_before, "loading a level does not re-deliver mail")

	MailManager.load_save_data({"inbox": [
		{"id": "level_2", "read": true}, {"id": "level_2"}, {"id": "deleted_message"}, "junk", {"read": true},
	]})
	_check(MailManager.get_message_count() == 1 and MailManager.get_unread_count() == 0, "damaged inbox data sanitised")
	MailManager.mail_received.disconnect(on_received)


func _test_network_data() -> void:
	var nodes: Array[NetworkNodeData] = NetworkNodeData.load_all()
	_check(nodes.size() >= 5, "network nodes loaded")
	var ids: Dictionary = {}
	var links_valid: bool = true
	var positions_valid: bool = true
	for node: NetworkNodeData in nodes:
		ids[node.id] = true
	for node: NetworkNodeData in nodes:
		for link: String in node.links:
			if not ids.has(link):
				links_valid = false
		if node.map_position.x < 0.0 or node.map_position.x > 1.0 or node.map_position.y < 0.0 or node.map_position.y > 1.0:
			positions_valid = false
	_check(links_valid and positions_valid, "links and positions are valid")
	_check(nodes[0].is_discovered(1), "the home node is known from the start")
	var locked_at_start: int = 0
	for node: NetworkNodeData in nodes:
		if not node.is_discovered(1):
			locked_at_start += 1
			if node.is_discovered(node.required_level - 1) or not node.is_discovered(node.required_level):
				links_valid = false
	_check(locked_at_start > 0 and links_valid, "nodes unlock exactly at their required level")


# --- Helpers ----------------------------------------------------------------

func _populate_state() -> void:
	SaveManager.reset_all_sections()
	PlayerManager.create_new_player("Tester_01")
	PlayerManager.add_playtime(321.5)
	EconomyManager.add_money(1500, TransactionCategory.STARTING_FUNDS, "Initial savings")
	EconomyManager.spend_money(350, TransactionCategory.HARDWARE, "GPU")
	var config: ProgressionConfig = ProgressionManager.CONFIG
	ProgressionManager.add_xp(config.get_xp_to_next_level(1) + config.get_xp_to_next_level(2) + 40)
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, 12)
	ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, 7)
	ReputationManager.add_heat(33.0)


func _run(test_name: String, test: Callable) -> void:
	_current_test = test_name
	_clean_test_directory()
	SaveManager.reset_all_sections()
	var failures_before: int = _failed
	test.call()
	print("[%s] %s" % ["PASS" if _failed == failures_before else "FAIL", test_name])


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("    FAILED: %s -> %s" % [_current_test, description])


func _write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIRECTORY)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("    Could not write test file %s" % path)
		return
	file.store_string(text)
	file.close()


func _clean_test_directory() -> void:
	var directory := DirAccess.open(TEST_SAVE_DIRECTORY)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
