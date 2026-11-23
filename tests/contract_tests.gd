extends RefCounted
## Unit tests for puzzles and the contract system. Run by tests/test_runner.gd,
## which resets every system before each test.

var _report: Callable


func _init(report: Callable) -> void:
	_report = report


func _check(condition: bool, description: String) -> void:
	_report.call(condition, description)


# --- Puzzles ----------------------------------------------------------------

func test_sequence_puzzle() -> void:
	var pools: Dictionary = ContractManager.get_pools()
	var config: Dictionary = {"pool": "incident_timeline", "count": 6}
	var logic := SequencePuzzleLogic.new()
	_check(logic.generate(config, pools, _seeded(11)), "generates")
	_check(logic.get_item_count() == 6 and logic.get_labels().size() == 6, "has the configured number of entries")
	var twin := SequencePuzzleLogic.new()
	twin.generate(config, pools, _seeded(11))
	_check(twin.get_labels() == logic.get_labels(), "same seed gives the same puzzle")
	var other := SequencePuzzleLogic.new()
	other.generate(config, pools, _seeded(12))
	_check(other.get_labels() != logic.get_labels(), "a different seed gives a different puzzle")
	# Keys are sortable text, so sorting the labels gives the solution order.
	var sorted_labels: Array = Array(logic.get_labels())
	sorted_labels.sort()
	_check(Array(logic.get_labels()) != sorted_labels, "the list is never handed over already sorted")
	_check(logic.get_labels()[logic.get_next_correct_index()] == sorted_labels[0], "the first entry to pick has the lowest key")

	var first: int = logic.get_next_correct_index()
	var wrong: int = (first + 1) % logic.get_item_count()
	_check(not logic.try_pick(wrong) and not logic.is_picked(wrong), "a wrong pick is rejected and changes nothing")
	_check(logic.try_pick(first) and logic.is_picked(first), "the lowest entry is accepted")
	_check(logic.try_pick(first), "picking a placed entry again is harmless")
	_check(not logic.try_pick(-1) and not logic.try_pick(99), "out-of-range picks are rejected")
	var picks: int = 1
	var in_key_order: bool = true
	while not logic.is_solved() and picks < 20:
		var next_index: int = logic.get_next_correct_index()
		if logic.get_labels()[next_index] != sorted_labels[picks]:
			in_key_order = false
		logic.try_pick(next_index)
		picks += 1
	_check(logic.is_solved() and picks == 6, "picking in order solves it in exactly 6 picks")
	_check(in_key_order, "the solution order is the order of the visible keys")
	_check(not SequencePuzzleLogic.new().generate({"pool": "missing"}, pools, _seeded(1)), "unknown pool fails cleanly")
	var clamped := SequencePuzzleLogic.new()
	clamped.generate({"pool": "malware_execution", "count": 999}, pools, _seeded(3))
	_check(clamped.get_item_count() == 8, "count is clamped to the pool size")


func test_cipher_puzzle() -> void:
	_check(CipherPuzzleLogic.shift_text("ABC XYZ", 3) == "DEF ABC", "shift wraps around the alphabet")
	_check(CipherPuzzleLogic.shift_text("HELLO, WORLD 42!", 0) == "HELLO, WORLD 42!", "zero shift changes nothing")
	_check(CipherPuzzleLogic.shift_text(CipherPuzzleLogic.shift_text("ROUND TRIP", 7), -7) == "ROUND TRIP", "shifting back restores the text")
	var pools: Dictionary = ContractManager.get_pools()
	var logic := CipherPuzzleLogic.new()
	_check(logic.generate({"pool": "field_notes"}, pools, _seeded(5)), "generates")
	var shift: int = logic.get_correct_shift()
	_check(shift >= 1 and shift <= 25, "shift is never zero")
	_check(logic.get_ciphertext() != logic.decode(shift), "the ciphertext is not the plaintext")
	var phrases: Array = pools["cipher"]["field_notes"]["phrases"]
	_check(phrases.has(logic.decode(shift)), "the correct shift reveals a phrase from the pool")
	_check(not logic.submit(shift + 1) and not logic.is_solved(), "a wrong shift is rejected")
	_check(logic.submit(shift + 26) and logic.is_solved(), "the correct shift is accepted (modulo 26)")
	_check(not CipherPuzzleLogic.new().generate({"pool": "missing"}, pools, _seeded(1)), "unknown pool fails cleanly")


func test_spot_puzzle() -> void:
	var pools: Dictionary = ContractManager.get_pools()
	var logic := SpotPuzzleLogic.new()
	_check(logic.generate({"pool": "audit_config", "normal": 6, "anomalies": 2}, pools, _seeded(21)), "generates")
	_check(logic.get_line_count() == 8 and logic.get_anomaly_count() == 2, "line and problem counts follow the config")
	var problems: Array = []
	var clean: Array = []
	for index: int in logic.get_line_count():
		if logic.is_anomaly(index):
			problems.append(index)
		else:
			clean.append(index)
	var anomaly_pool: Array = pools["spot"]["audit_config"]["anomalies"]
	_check(anomaly_pool.has(logic.get_lines()[problems[0]]) and not anomaly_pool.has(logic.get_lines()[clean[0]]), "problem lines come from the problem pool")
	_check(not logic.submit([]), "an empty selection is wrong")
	_check(not logic.submit([problems[0]]) and logic.last_feedback.begins_with("1 of 2"), "a partial answer is wrong and explained")
	_check(not logic.submit(problems + [clean[0]]) and logic.last_feedback.contains("1 wrong"), "an extra selection is wrong")
	_check(not logic.is_solved(), "still unsolved after wrong answers")
	_check(logic.submit([problems[1], problems[0], problems[0], "junk"]) and logic.is_solved(), "the exact set solves it (order and duplicates ignored)")

	# Code keeps its line order; only the faulty lines are inserted.
	var code := SpotPuzzleLogic.new()
	code.generate({"pool": "buggy_code", "normal": 12, "anomalies": 2}, pools, _seeded(4))
	var remaining: Array = []
	for index: int in code.get_line_count():
		if not code.is_anomaly(index):
			remaining.append(code.get_lines()[index])
	var code_pool: Array = pools["spot"]["buggy_code"]["normal"]
	_check(remaining == code_pool, "code lines stay in their original order")
	_check(not SpotPuzzleLogic.new().generate({"pool": "missing"}, pools, _seeded(1)), "unknown pool fails cleanly")


func test_match_puzzle() -> void:
	var logic := MatchPuzzleLogic.new()
	_check(logic.generate({"length": 16, "options": 6, "rounds": 2}, {}, _seeded(8)), "generates without a pool")
	_check(MatchPuzzleLogic.format_code("ABCDEFGH12") == "ABCD EFGH 12", "codes are grouped in fours")
	var options: PackedStringArray = logic.get_options()
	_check(options.size() == 6 and logic.get_round_count() == 2, "option and round counts follow the config")
	var identical: int = 0
	var unique: Dictionary = {}
	var all_near: bool = true
	for option: String in options:
		unique[option] = true
		if option == logic.get_target():
			identical += 1
		var differences: int = 0
		for index: int in option.length():
			if option[index] != logic.get_target()[index]:
				differences += 1
		if differences > 1:
			all_near = false
	_check(identical == 1 and options[logic.get_correct_index()] == logic.get_target(), "exactly one candidate is identical")
	_check(unique.size() == 6 and all_near, "decoys are unique and differ by one character")
	var wrong: int = (logic.get_correct_index() + 1) % 6
	_check(not logic.try_pick(wrong) and logic.get_round() == 0, "a wrong pick is rejected")
	var first_target: String = logic.get_target()
	_check(logic.try_pick(logic.get_correct_index()) and logic.get_round() == 1 and not logic.is_solved(), "a correct pick starts the next round")
	_check(logic.get_target() != first_target, "the next round has a new target")
	_check(logic.try_pick(logic.get_correct_index()) and logic.is_solved(), "the last round solves it")
	_check(not logic.try_pick(logic.get_correct_index()), "nothing happens after it is solved")
	var extreme := MatchPuzzleLogic.new()
	extreme.generate({"length": 1, "options": 99, "rounds": 99}, {}, _seeded(2))
	_check(extreme.get_options().size() == MatchPuzzleLogic.MAX_OPTIONS, "the option count is clamped")
	_check(extreme.get_target().replace(" ", "").length() == MatchPuzzleLogic.MIN_LENGTH, "the code length is clamped")


# --- Contract data ----------------------------------------------------------

func test_contract_data() -> void:
	var definitions: Array[ContractDefinition] = ContractManager.get_definitions()
	_check(definitions.size() >= 14, "at least 14 contracts defined")
	var categories: Dictionary = {}
	var puzzle_types: Dictionary = {}
	var fields_ok: bool = true
	var level_one: int = 0
	for definition: ContractDefinition in definitions:
		categories[definition.category] = true
		if definition.required_level == 1:
			level_one += 1
		if definition.reward <= 0 or definition.xp_reward <= 0 or definition.description.is_empty():
			fields_ok = false
		if definition.get_stage_count() < 2 or definition.title.is_empty() or definition.client.is_empty():
			fields_ok = false
		if definition.reputation_white == 0 and definition.reputation_underground == 0:
			fields_ok = false
		for stage: Dictionary in definition.stages:
			puzzle_types[stage["puzzle"]] = true
	_check(fields_ok, "every contract has rewards, a description, a client and at least two stages")
	_check(categories.size() == ContractCategory.ALL.size(), "all seven categories have contracts")
	_check(puzzle_types.size() == PuzzleFactory.get_types().size(), "every puzzle type is used")
	_check(level_one >= ContractManager.CONFIG.board_size, "a new player can fill the board")

	# Every stage of every contract must produce a solvable puzzle.
	var all_solvable: bool = true
	var generated: int = 0
	for definition: ContractDefinition in definitions:
		for stage: Dictionary in definition.stages:
			for seed_value: int in [1, 77, 4242, 900001]:
				var logic: PuzzleLogic = PuzzleFactory.create_logic(
					stage["puzzle"], stage["config"], ContractManager.get_pools(), _seeded(seed_value)
				)
				generated += 1
				if logic == null or not _solve_logic(logic):
					all_solvable = false
					printerr("    unsolvable: %s / %s seed %d" % [definition.id, stage["title"], seed_value])
	_check(all_solvable and generated > 100, "all %d generated puzzles are solvable" % generated)

	var screens_ok: bool = true
	for puzzle_type: String in PuzzleFactory.get_types():
		var view: Node = (load(PuzzleFactory.VIEW_SCENES[puzzle_type]) as PackedScene).instantiate()
		if not view is MissionPuzzle:
			screens_ok = false
		view.free()
	_check(screens_ok, "every puzzle type has a screen")
	_check(ContractDefinition.from_dictionary({"id": "x", "category": "file_recovery", "stages": []}) == null, "a contract without stages is rejected")
	_check(ContractDefinition.from_dictionary({"id": "x", "category": "nonsense", "stages": [{"puzzle": "spot"}]}) == null, "an unknown category is rejected")
	_check(ContractDefinition.from_dictionary({"id": "x", "category": "file_recovery", "stages": [{"puzzle": "teleport"}]}) == null, "an unknown puzzle type is rejected")


# --- Board and requirements -------------------------------------------------

func test_contract_board() -> void:
	var config: ContractConfig = ContractManager.CONFIG
	var board: Array[Dictionary] = ContractManager.get_board()
	_check(board.size() == config.board_size, "a new game starts with a full board")
	var templates: Dictionary = {}
	var offers_ok: bool = true
	for offer: Dictionary in board:
		var definition: ContractDefinition = ContractManager.get_definition(offer["template_id"])
		templates[offer["template_id"]] = true
		var low: float = definition.reward * (1.0 - config.reward_variance) - 10.0
		var high: float = definition.reward * (1.0 + config.reward_variance) + 10.0
		if definition.required_level > 1 or offer["reward"] < low or offer["reward"] > high:
			offers_ok = false
		if int(offer["reward"]) % 10 != 0:
			offers_ok = false
	_check(offers_ok, "offers match the player's level and pay within the allowed range")
	_check(templates.size() == board.size(), "no contract is offered twice")
	board[0]["reward"] = 999999
	_check(ContractManager.get_board()[0]["reward"] != 999999, "the board cannot be changed from outside")

	var first_ids: Array = _offer_ids(board)
	_check(ContractManager.refresh_board(), "the board can be refreshed")
	var new_ids: Array = _offer_ids(ContractManager.get_board())
	var overlap: bool = false
	for offer_id: int in new_ids:
		if first_ids.has(offer_id):
			overlap = true
	_check(not overlap and new_ids.size() == config.board_size, "refreshing replaces every offer")
	_check(not ContractManager.refresh_board() and ContractManager.get_refresh_cooldown_remaining() > 0.0, "refreshing has a cooldown")
	ContractManager.advance_time(config.refresh_cooldown_seconds + 0.1)
	_check(ContractManager.can_refresh_board(), "the cooldown expires")

	# Requirements.
	var advanced: ContractDefinition = ContractManager.get_definition("ii_breach_tabletop")
	_check(ContractManager.get_unmet_requirements(advanced)[0] == "Requires level 10", "a level 10 contract is locked at level 1")
	_check(ContractManager.get_unmet_requirements(ContractManager.get_definition("fr_photo_archive")).is_empty(), "a level 1 contract is open")
	var skilled: ContractDefinition = ContractDefinition.from_dictionary({
		"id": "test_skilled", "category": "cryptography", "required_skills": {"cryptography": 2},
		"required_hardware": ["gpu_basic"], "stages": [{"puzzle": "cipher", "config": {"pool": "field_notes"}}],
	})
	_check(skilled.required_skills.get("cryptography") == 2 and skilled.required_hardware.size() == 1, "skill and hardware requirements are read from data")
	_check(ContractManager.get_unmet_requirements(skilled).size() == 2, "unmet skill and hardware requirements are both reported")
	var real_checker: Callable = GameEffects.get_requirement_checker(ContractManager.REQUIREMENT_SKILLS)
	var allow_all: Callable = func(_definition: ContractDefinition) -> PackedStringArray: return PackedStringArray()
	ContractManager.register_requirement_checker(ContractManager.REQUIREMENT_SKILLS, allow_all)
	_check(ContractManager.get_unmet_requirements(skilled).size() == 1, "a registered checker decides its own requirement")
	ContractManager.register_requirement_checker(ContractManager.REQUIREMENT_SKILLS, Callable())
	_check(ContractManager.get_unmet_requirements(skilled).size() == 2, "a requirement nobody can check counts as unmet")
	ContractManager.register_requirement_checker(ContractManager.REQUIREMENT_SKILLS, real_checker)
	_check(not ContractManager.can_accept(-5) and not ContractManager.accept_contract(-5), "an unknown offer cannot be accepted")

	# Higher levels unlock more contracts.
	var progression: ProgressionConfig = ProgressionManager.CONFIG
	ProgressionManager.add_xp(progression.get_xp_to_next_level(1) + progression.get_xp_to_next_level(2))
	_check(ProgressionManager.level == 3, "reached level 3")
	var seen_higher: bool = false
	var within_level: bool = true
	for attempt: int in 30:
		ContractManager.advance_time(config.refresh_cooldown_seconds + 0.1)
		ContractManager.refresh_board()
		for offer: Dictionary in ContractManager.get_board():
			var level: int = ContractManager.get_definition(offer["template_id"]).required_level
			if level > 1:
				seen_higher = true
			if level > 3:
				within_level = false
	_check(seen_higher and within_level, "level 3 sees higher-level contracts but none above level 3")


# --- Completion -------------------------------------------------------------

func test_contract_completion() -> void:
	PlayerManager.create_new_player("Contractor")
	var events: Dictionary = {"stages": [], "completed": [], "accepted": 0}
	var on_stage: Callable = func(index: int) -> void: events["stages"].append(index)
	var on_completed: Callable = func(result: Dictionary) -> void: events["completed"].append(result)
	var on_accepted: Callable = func(_offer: Dictionary) -> void: events["accepted"] += 1
	ContractManager.stage_changed.connect(on_stage)
	ContractManager.contract_completed.connect(on_completed)
	ContractManager.contract_accepted.connect(on_accepted)

	var offer: Dictionary = ContractManager.get_board()[0]
	var definition: ContractDefinition = ContractManager.get_definition(offer["template_id"])
	_check(not ContractManager.has_active_contract() and ContractManager.create_stage_logic() == null, "nothing in progress at first")
	_check(ContractManager.accept_contract(offer["offer_id"]), "an offer can be accepted")
	_check(ContractManager.has_active_contract() and events["accepted"] == 1, "the contract is in progress")
	_check(ContractManager.find_offer(offer["offer_id"]).is_empty(), "the accepted offer leaves the board")
	_check(not ContractManager.can_accept(ContractManager.get_board()[0]["offer_id"]), "only one contract at a time")
	_check(is_equal_approx(ContractManager.get_time_remaining(), definition.estimated_duration * ContractManager.CONFIG.time_limit_factor), "the clock starts at the time limit")
	_check(_signature(ContractManager.create_stage_logic()) == _signature(ContractManager.create_stage_logic()), "a stage always rebuilds the same puzzle")

	for stage_index: int in definition.get_stage_count():
		var stage_title: String = definition.stages[stage_index]["title"]
		_check(ContractManager.get_stage_index() == stage_index and ContractManager.get_current_stage()["title"] == stage_title, "stage %d is current" % (stage_index + 1))
		_check(_solve_logic(ContractManager.create_stage_logic()), "stage %d puzzle can be solved" % (stage_index + 1))
		ContractManager.complete_stage()
	_check(not ContractManager.has_active_contract(), "the contract ends after its last stage")
	_check(events["stages"].size() == definition.get_stage_count(), "one stage_changed per stage")
	_check(events["completed"].size() == 1, "contract_completed emitted once")

	var reward: int = offer["reward"]
	var bonus: int = roundi(reward * ContractManager.CONFIG.flawless_bonus_ratio)
	var result: Dictionary = events["completed"][0]
	_check(result["reward"] == reward and result["bonus"] == bonus and bonus > 0, "a flawless run earns the bonus")
	_check(EconomyManager.money == reward + bonus, "payment and bonus reach the balance")
	_check(EconomyManager.get_income_by_category().get(TransactionCategory.CONTRACT) == reward + bonus, "payment is booked as contract income")
	_check(ProgressionManager.total_xp == definition.xp_reward, "XP granted")
	_check(ReputationManager.white_reputation == definition.reputation_white, "reputation granted")
	_check(ContractManager.get_completed_count() == 1 and ContractManager.get_failed_count() == 0, "counters updated")
	var history: Array[Dictionary] = ContractManager.get_history()
	_check(history.size() == 1 and history[0]["name"] == definition.title and history[0]["outcome"] == ContractManager.OUTCOME_COMPLETED, "history records the contract")
	_check(ContractManager.get_board().size() == ContractManager.CONFIG.board_size, "the board is refilled")
	_check(MailManager.has_message("first_contract"), "the first completion triggers mail")
	ContractManager.complete_stage()
	ContractManager.register_mistake()
	ContractManager.abandon_contract()
	_check(ContractManager.get_completed_count() == 1 and ContractManager.get_failed_count() == 0, "stage calls with nothing in progress are ignored")

	# One mistake forfeits the bonus but not the reward.
	var second: Dictionary = ContractManager.get_board()[0]
	var second_reward: int = second["reward"]
	var money_before: int = EconomyManager.money
	ContractManager.accept_contract(second["offer_id"])
	ContractManager.register_mistake()
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()
	_check(EconomyManager.money == money_before + second_reward, "a mistake forfeits the flawless bonus")
	var first_contract_mails: int = 0
	for message: Dictionary in MailManager.get_messages():
		if message["id"] == "first_contract":
			first_contract_mails += 1
	_check(first_contract_mails == 1, "the first-contract mail is not sent twice")

	# An underground contract pays underground reputation and raises heat.
	var grey: ContractDefinition = ContractManager.get_definition("cr_puzzle_hunt")
	ProgressionManager.add_xp(100000)
	ContractManager.load_save_data({"board": [{"offer_id": 500, "template_id": grey.id, "reward": 500, "seed": 9}]})
	var heat_before: float = ReputationManager.heat
	_check(ContractManager.accept_contract(500), "an underground offer can be accepted at the right level")
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()
	_check(ReputationManager.underground_reputation == grey.reputation_underground, "underground reputation granted")
	_check(is_equal_approx(ReputationManager.heat, heat_before + grey.heat), "underground work raises heat")

	ContractManager.stage_changed.disconnect(on_stage)
	ContractManager.contract_completed.disconnect(on_completed)
	ContractManager.contract_accepted.disconnect(on_accepted)


# --- Failure ----------------------------------------------------------------

func test_contract_failure() -> void:
	var failures: Array[Dictionary] = []
	var on_failed: Callable = func(result: Dictionary) -> void: failures.append(result)
	ContractManager.contract_failed.connect(on_failed)
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, 5)
	var config: ContractConfig = ContractManager.CONFIG

	ContractManager.accept_contract(ContractManager.get_board()[0]["offer_id"])
	for index: int in config.max_mistakes - 1:
		ContractManager.register_mistake()
	_check(ContractManager.has_active_contract() and ContractManager.get_mistakes() == config.max_mistakes - 1, "still running below the mistake limit")
	ContractManager.register_mistake()
	_check(not ContractManager.has_active_contract() and failures.size() == 1, "the contract fails at the mistake limit")
	_check(failures[0]["reason"] == ContractManager.REASON_MISTAKES and failures[0]["reward"] == 0, "failure records its reason and pays nothing")
	_check(EconomyManager.money == 0 and ProgressionManager.total_xp == 0, "no money or XP for a failure")
	_check(ReputationManager.white_reputation == 5 - config.failure_reputation_penalty, "failing costs reputation")

	var offer: Dictionary = ContractManager.get_board()[0]
	var limit: float = ContractManager.get_time_limit(ContractManager.get_definition(offer["template_id"]))
	ContractManager.accept_contract(offer["offer_id"])
	ContractManager.advance_time(limit - 1.0)
	_check(ContractManager.has_active_contract() and ContractManager.get_time_remaining() <= 1.01, "still running just before the deadline")
	ContractManager.advance_time(2.0)
	_check(failures.size() == 2 and failures[1]["reason"] == ContractManager.REASON_TIMEOUT, "the contract fails when time runs out")

	ContractManager.accept_contract(ContractManager.get_board()[0]["offer_id"])
	ContractManager.abandon_contract()
	_check(failures.size() == 3 and failures[2]["reason"] == ContractManager.REASON_ABANDONED, "abandoning fails the contract")
	_check(ReputationManager.white_reputation == 0, "reputation cannot go below zero")
	_check(ContractManager.get_failed_count() == 3 and ContractManager.get_history()[0]["outcome"] == ContractManager.OUTCOME_FAILED, "failures are counted and recorded")
	_check(ContractManager.get_board().size() == config.board_size, "the board is refilled after a failure")

	# A failed underground job costs underground reputation and adds heat.
	ProgressionManager.add_xp(100000)
	ContractManager.load_save_data({"board": [{"offer_id": 700, "template_id": "cr_puzzle_hunt", "reward": 500, "seed": 3}]})
	ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, 10)
	ContractManager.accept_contract(700)
	ContractManager.abandon_contract()
	_check(ReputationManager.underground_reputation == 10 - config.failure_reputation_penalty, "a failed underground job costs underground reputation")
	_check(is_equal_approx(ReputationManager.heat, config.failure_heat), "a failed underground job adds heat")

	var guard: int = 0
	while ContractManager.get_history().size() < config.max_history and guard < 500:
		guard += 1
		# At a high level some offers need skills or hardware; take one that does not.
		var accepted: bool = false
		for board_offer: Dictionary in ContractManager.get_board():
			if ContractManager.accept_contract(board_offer["offer_id"]):
				accepted = true
				break
		if accepted:
			ContractManager.abandon_contract()
		else:
			ContractManager.advance_time(config.refresh_cooldown_seconds + 1.0)
			ContractManager.refresh_board()
	for extra: int in 5:
		for board_offer: Dictionary in ContractManager.get_board():
			if ContractManager.accept_contract(board_offer["offer_id"]):
				ContractManager.abandon_contract()
				break
	_check(ContractManager.get_history().size() == config.max_history, "history is capped")
	ContractManager.contract_failed.disconnect(on_failed)


# --- Save and load ----------------------------------------------------------

func test_contract_save() -> void:
	PlayerManager.create_new_player("Saver")
	var first: Dictionary = ContractManager.get_board()[0]
	ContractManager.accept_contract(first["offer_id"])
	ContractManager.abandon_contract()
	var offer: Dictionary = ContractManager.get_board()[1]
	ContractManager.accept_contract(offer["offer_id"])
	ContractManager.complete_stage()
	ContractManager.register_mistake()
	ContractManager.advance_time(7.5)
	ContractManager.refresh_board()
	var board_before: Array[Dictionary] = ContractManager.get_board()
	var time_before: float = ContractManager.get_time_remaining()
	var signature_before: String = _signature(ContractManager.create_stage_logic())

	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(not ContractManager.has_active_contract() and ContractManager.get_history().is_empty(), "reset clears contract state")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(ContractManager.has_active_contract() and ContractManager.get_active_offer()["template_id"] == offer["template_id"], "the contract in progress is restored")
	_check(ContractManager.get_stage_index() == 1 and ContractManager.get_mistakes() == 1, "stage and mistakes restored")
	_check(is_equal_approx(ContractManager.get_time_remaining(), time_before), "remaining time restored")
	_check(_signature(ContractManager.create_stage_logic()) == signature_before, "the same puzzle is rebuilt after loading")
	_check(_offer_ids(ContractManager.get_board()) == _offer_ids(board_before), "the board is restored")
	_check(ContractManager.get_board()[0]["reward"] == board_before[0]["reward"] and ContractManager.get_board()[0]["seed"] == board_before[0]["seed"], "offer rewards and seeds are restored")
	_check(ContractManager.get_failed_count() == 1 and ContractManager.get_history().size() == 1, "history and counters restored")
	_check(not ContractManager.can_refresh_board(), "the refresh cooldown is restored")
	ContractManager.abandon_contract()
	var highest_before: int = 0
	for board_offer: Dictionary in board_before:
		highest_before = maxi(highest_before, board_offer["offer_id"])
	ContractManager.advance_time(ContractManager.CONFIG.refresh_cooldown_seconds + 1.0)
	ContractManager.refresh_board()
	var lowest_new: int = 1 << 30
	for board_offer: Dictionary in ContractManager.get_board():
		lowest_new = mini(lowest_new, board_offer["offer_id"])
	_check(lowest_new > highest_before, "new offers get fresh ids after loading")

	# Damaged data, and saves from before contracts existed.
	ContractManager.load_save_data({
		"board": ["junk", {"template_id": "deleted_contract"}, {"template_id": "fr_photo_archive", "reward": -5, "offer_id": "x"}, 7],
		"active": {"template_id": "does_not_exist", "stage_index": 2},
		"history": ["junk", {"name": 5, "outcome": "exploded", "reward": -100}],
		"completed_count": -3, "refresh_cooldown": 999999,
	})
	_check(not ContractManager.has_active_contract(), "an unknown contract in progress is dropped")
	_check(ContractManager.get_board().size() == ContractManager.CONFIG.board_size, "a damaged board is repaired and refilled")
	_check(ContractManager.get_board()[0]["template_id"] == "fr_photo_archive" and ContractManager.get_board()[0]["reward"] == 0, "usable offers are kept and sanitised")
	var damaged_history: Array[Dictionary] = ContractManager.get_history()
	_check(damaged_history.size() == 1 and damaged_history[0]["outcome"] == ContractManager.OUTCOME_FAILED and damaged_history[0]["reward"] == 0, "damaged history is sanitised")
	_check(ContractManager.get_completed_count() == 0, "counters are clamped")
	_check(ContractManager.get_refresh_cooldown_remaining() <= ContractManager.CONFIG.refresh_cooldown_seconds, "the cooldown is clamped")
	ContractManager.load_save_data({"active": {"template_id": "fr_photo_archive", "offer_id": 3, "stage_index": 99, "mistakes": 99, "time_remaining": -50}})
	_check(ContractManager.get_stage_index() == 1 and ContractManager.get_mistakes() == ContractManager.CONFIG.max_mistakes - 1, "an out-of-range stage and mistake count are clamped")
	_check(ContractManager.get_time_remaining() >= 1.0, "a loaded contract always has time left")
	ContractManager.load_save_data({})
	_check(ContractManager.get_board().size() == ContractManager.CONFIG.board_size and not ContractManager.has_active_contract(), "a save from before contracts existed gets a fresh board")


# --- Helpers ----------------------------------------------------------------

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _offer_ids(offers: Array[Dictionary]) -> Array:
	var ids: Array = []
	for offer: Dictionary in offers:
		ids.append(offer["offer_id"])
	return ids


## Solves a puzzle through its rules alone. Returns true when it ends solved.
func _solve_logic(logic: PuzzleLogic) -> bool:
	if logic is SequencePuzzleLogic:
		var sequence := logic as SequencePuzzleLogic
		for step: int in sequence.get_item_count():
			sequence.try_pick(sequence.get_next_correct_index())
	elif logic is CipherPuzzleLogic:
		(logic as CipherPuzzleLogic).submit((logic as CipherPuzzleLogic).get_correct_shift())
	elif logic is SpotPuzzleLogic:
		var spot := logic as SpotPuzzleLogic
		var selection: Array = []
		for index: int in spot.get_line_count():
			if spot.is_anomaly(index):
				selection.append(index)
		spot.submit(selection)
	elif logic is MatchPuzzleLogic:
		var matching := logic as MatchPuzzleLogic
		for round_index: int in matching.get_round_count():
			matching.try_pick(matching.get_correct_index())
	return logic != null and logic.is_solved()


## Text that identifies the exact puzzle instance, for comparing two of them.
func _signature(logic: PuzzleLogic) -> String:
	if logic is SequencePuzzleLogic:
		return "|".join((logic as SequencePuzzleLogic).get_labels())
	if logic is CipherPuzzleLogic:
		return (logic as CipherPuzzleLogic).get_ciphertext()
	if logic is SpotPuzzleLogic:
		return "|".join((logic as SpotPuzzleLogic).get_lines())
	if logic is MatchPuzzleLogic:
		var matching := logic as MatchPuzzleLogic
		return matching.get_target() + "|" + "|".join(matching.get_options())
	return ""
