extends Node
## ContractManager (autoload)
##
## Owns the contract board, the contract in progress and the contract
## history: generation, requirements, stage progress, mistakes, the time
## limit, rewards and failure penalties. It contains no UI and no puzzle
## rules; puzzles are PuzzleLogic objects it creates for each stage.

signal board_changed
signal contract_accepted(offer: Dictionary)
signal stage_changed(stage_index: int)
signal mistakes_changed(mistakes: int, max_mistakes: int)
signal contract_completed(result: Dictionary)
signal contract_failed(result: Dictionary)

const CONFIG: ContractConfig = preload("res://resources/configurations/contract_config.tres")
const CONTRACTS_PATH: String = "res://data/contracts/contracts.json"
const POOLS_PATH: String = "res://data/contracts/puzzle_pools.json"
const SAVE_SECTION: String = "contracts"

const OUTCOME_COMPLETED: String = "completed"
const OUTCOME_FAILED: String = "failed"
const REASON_MISTAKES: String = "too_many_mistakes"
const REASON_TIMEOUT: String = "timeout"
const REASON_ABANDONED: String = "abandoned"
const REQUIREMENT_SKILLS: String = "skills"
const REQUIREMENT_HARDWARE: String = "hardware"

## Keeps the puzzles of different stages of one offer unrelated.
const STAGE_SEED_STEP: int = 7919
const REWARD_ROUNDING: int = 10
## The refresh cooldown can never be reduced by more than this many percent.
const MAX_COOLDOWN_REDUCTION: float = 80.0

var _definitions: Dictionary = {} # template id -> ContractDefinition
var _definition_order: Array[String] = []
var _pools: Dictionary = {}
## Offers on the board. Each: {offer_id, template_id, reward, seed}.
var _board: Array[Dictionary] = []
var _next_offer_id: int = 1
## The accepted offer plus {stage_index, mistakes, time_remaining}. Empty when idle.
var _active: Dictionary = {}
## Finished contracts, oldest first.
var _history: Array[Dictionary] = []
var _completed_count: int = 0
var _failed_count: int = 0
var _refresh_cooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	SaveManager.register_section(SAVE_SECTION, self)
	ProgressionManager.level_changed.connect(_on_level_changed)
	# More board capacity (hardware, skills) fills in straight away.
	GameEffects.add_change_listener(_on_effects_changed)


func _process(delta: float) -> void:
	advance_time(delta)


## Moves the contract clock and the refresh cooldown forward. Called every
## frame; exposed so tests can fast-forward.
func advance_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_refresh_cooldown = maxf(0.0, _refresh_cooldown - seconds)
	if has_active_contract():
		_active["time_remaining"] = float(_active["time_remaining"]) - seconds
		if float(_active["time_remaining"]) <= 0.0:
			_fail(REASON_TIMEOUT)


# --- Definitions and requirements -------------------------------------------

func get_definition(template_id: String) -> ContractDefinition:
	return _definitions.get(template_id)


func get_definitions() -> Array[ContractDefinition]:
	var definitions: Array[ContractDefinition] = []
	for template_id: String in _definition_order:
		definitions.append(_definitions[template_id])
	return definitions


func get_pools() -> Dictionary:
	return _pools


## Lets a system (skills, hardware) decide its own requirements. The
## callable receives a ContractDefinition and returns the unmet reasons.
## Checkers live in GameEffects so they do not depend on autoload order.
func register_requirement_checker(kind: String, checker: Callable) -> void:
	GameEffects.register_requirement_checker(kind, checker)


## Reasons the player cannot take this contract right now. Empty = allowed.
func get_unmet_requirements(definition: ContractDefinition) -> PackedStringArray:
	var unmet: PackedStringArray = []
	if definition == null:
		unmet.append("Unknown contract")
		return unmet
	if ProgressionManager.level < definition.required_level:
		unmet.append("Requires level %d" % definition.required_level)
	if not definition.required_skills.is_empty():
		unmet.append_array(_check_requirement(REQUIREMENT_SKILLS, definition))
	if not definition.required_hardware.is_empty():
		unmet.append_array(_check_requirement(REQUIREMENT_HARDWARE, definition))
	return unmet


## Seconds allowed for a contract, including time bonuses.
func get_time_limit(definition: ContractDefinition) -> float:
	var bonus_percent: float = maxf(0.0, GameEffects.get_total(GameEffects.CONTRACT_TIME))
	return definition.estimated_duration * CONFIG.time_limit_factor * (1.0 + bonus_percent / 100.0)


## Number of offers the board holds, including bonuses.
func get_board_size() -> int:
	return CONFIG.board_size + maxi(0, roundi(GameEffects.get_total(GameEffects.BOARD_SIZE)))


## What an offer pays on completion, including pay bonuses for its category.
func get_effective_reward(offer: Dictionary) -> int:
	var definition: ContractDefinition = get_definition(SaveDataReader.get_string(offer, "template_id"))
	if definition == null:
		return 0
	var bonus_percent: float = GameEffects.get_total(GameEffects.CONTRACT_REWARD) + GameEffects.get_total(
		GameEffects.for_category(GameEffects.CONTRACT_REWARD, definition.category)
	)
	return roundi(SaveDataReader.get_int(offer, "reward") * (1.0 + maxf(0.0, bonus_percent) / 100.0))


## XP a contract grants on completion, including XP bonuses.
func get_effective_xp(definition: ContractDefinition) -> int:
	var bonus_percent: float = maxf(0.0, GameEffects.get_total(GameEffects.CONTRACT_XP))
	return roundi(definition.xp_reward * (1.0 + bonus_percent / 100.0))


## Share of the reward paid extra for a run without mistakes.
func get_flawless_bonus_ratio() -> float:
	return CONFIG.flawless_bonus_ratio + maxf(0.0, GameEffects.get_total(GameEffects.FLAWLESS_BONUS)) / 100.0


## Seconds to wait between board refreshes, including bonuses.
func get_refresh_cooldown() -> float:
	var reduction: float = clampf(
		GameEffects.get_total(GameEffects.REFRESH_COOLDOWN), 0.0, MAX_COOLDOWN_REDUCTION
	)
	return CONFIG.refresh_cooldown_seconds * (1.0 - reduction / 100.0)


# --- Board ------------------------------------------------------------------

func get_board() -> Array[Dictionary]:
	return _board.duplicate(true)


func find_offer(offer_id: int) -> Dictionary:
	for offer: Dictionary in _board:
		if offer["offer_id"] == offer_id:
			return offer.duplicate()
	return {}


func get_refresh_cooldown_remaining() -> float:
	return _refresh_cooldown


func can_refresh_board() -> bool:
	return _refresh_cooldown <= 0.0


## Replaces every offer with new ones. Fails while the cooldown is running.
func refresh_board() -> bool:
	if not can_refresh_board():
		return false
	_board.clear()
	_refresh_cooldown = get_refresh_cooldown()
	_fill_board()
	board_changed.emit()
	return true


# --- Active contract --------------------------------------------------------

func has_active_contract() -> bool:
	return not _active.is_empty()


func get_active_offer() -> Dictionary:
	return _active.duplicate()


func get_active_definition() -> ContractDefinition:
	return get_definition(SaveDataReader.get_string(_active, "template_id")) if has_active_contract() else null


func get_stage_index() -> int:
	return SaveDataReader.get_int(_active, "stage_index")


func get_stage_count() -> int:
	var definition: ContractDefinition = get_active_definition()
	return definition.get_stage_count() if definition != null else 0


## The stage in progress: {title, instruction, puzzle, config}, or {}.
func get_current_stage() -> Dictionary:
	var definition: ContractDefinition = get_active_definition()
	if definition == null:
		return {}
	return definition.stages[clampi(get_stage_index(), 0, definition.get_stage_count() - 1)]


func get_mistakes() -> int:
	return SaveDataReader.get_int(_active, "mistakes")


## Mistakes at which a contract fails, including bonuses.
func get_max_mistakes() -> int:
	return CONFIG.max_mistakes + maxi(0, roundi(GameEffects.get_total(GameEffects.EXTRA_MISTAKES)))


func get_time_remaining() -> float:
	return maxf(0.0, SaveDataReader.get_float(_active, "time_remaining"))


func can_accept(offer_id: int) -> bool:
	if has_active_contract():
		return false
	var offer: Dictionary = find_offer(offer_id)
	if offer.is_empty():
		return false
	return get_unmet_requirements(get_definition(offer["template_id"])).is_empty()


func accept_contract(offer_id: int) -> bool:
	if not can_accept(offer_id):
		return false
	var offer: Dictionary = find_offer(offer_id)
	for index: int in _board.size():
		if _board[index]["offer_id"] == offer_id:
			_board.remove_at(index)
			break
	_active = offer
	_active["stage_index"] = 0
	_active["mistakes"] = 0
	_active["time_remaining"] = get_time_limit(get_definition(offer["template_id"]))
	board_changed.emit()
	contract_accepted.emit(get_active_offer())
	stage_changed.emit(0)
	mistakes_changed.emit(0, get_max_mistakes())
	return true


## The puzzle for the current stage. The same offer and stage always give
## the same puzzle, so a stage can be rebuilt after loading a save.
func create_stage_logic() -> PuzzleLogic:
	var stage: Dictionary = get_current_stage()
	if stage.is_empty():
		return null
	var stage_rng := RandomNumberGenerator.new()
	stage_rng.seed = SaveDataReader.get_int(_active, "seed") + get_stage_index() * STAGE_SEED_STEP
	return PuzzleFactory.create_logic(stage["puzzle"], stage["config"], _pools, stage_rng)


## Called when the current stage's puzzle is solved.
func complete_stage() -> void:
	if not has_active_contract():
		return
	_active["stage_index"] = get_stage_index() + 1
	if get_stage_index() >= get_stage_count():
		_complete()
	else:
		stage_changed.emit(get_stage_index())


## Called for every wrong move. The contract fails at the mistake limit.
func register_mistake() -> void:
	if not has_active_contract():
		return
	_active["mistakes"] = get_mistakes() + 1
	mistakes_changed.emit(get_mistakes(), get_max_mistakes())
	if get_mistakes() >= get_max_mistakes():
		_fail(REASON_MISTAKES)


## Giving up counts as a failure.
func abandon_contract() -> void:
	if has_active_contract():
		_fail(REASON_ABANDONED)


# --- History ----------------------------------------------------------------

## Finished contracts, newest first.
func get_history() -> Array[Dictionary]:
	var newest_first: Array[Dictionary] = []
	for index: int in range(_history.size() - 1, -1, -1):
		newest_first.append(_history[index].duplicate())
	return newest_first


func get_completed_count() -> int:
	return _completed_count


func get_failed_count() -> int:
	return _failed_count


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"board": _board.duplicate(true),
		"next_offer_id": _next_offer_id,
		"active": _active.duplicate(true),
		"history": _history.duplicate(true),
		"completed_count": _completed_count,
		"failed_count": _failed_count,
		"refresh_cooldown": _refresh_cooldown,
	}


func load_save_data(data: Dictionary) -> void:
	_board.clear()
	var highest_offer_id: int = 0
	for entry: Variant in SaveDataReader.get_array(data, "board"):
		var offer: Dictionary = _sanitize_offer(entry)
		if not offer.is_empty() and _board.size() < get_board_size():
			_board.append(offer)
			highest_offer_id = maxi(highest_offer_id, offer["offer_id"])

	_active = _sanitize_offer(data.get("active"))
	if not _active.is_empty():
		var raw_active: Dictionary = data["active"]
		var definition: ContractDefinition = get_definition(_active["template_id"])
		highest_offer_id = maxi(highest_offer_id, _active["offer_id"])
		_active["stage_index"] = clampi(
			SaveDataReader.get_int(raw_active, "stage_index"), 0, definition.get_stage_count() - 1
		)
		_active["mistakes"] = clampi(SaveDataReader.get_int(raw_active, "mistakes"), 0, get_max_mistakes() - 1)
		_active["time_remaining"] = clampf(
			SaveDataReader.get_float(raw_active, "time_remaining", 1.0), 1.0, get_time_limit(definition)
		)

	_history.clear()
	for entry: Variant in SaveDataReader.get_array(data, "history"):
		if entry is Dictionary:
			_history.append(_sanitize_result(entry))
	_trim_history()
	_completed_count = maxi(0, SaveDataReader.get_int(data, "completed_count"))
	_failed_count = maxi(0, SaveDataReader.get_int(data, "failed_count"))
	_refresh_cooldown = clampf(
		SaveDataReader.get_float(data, "refresh_cooldown"), 0.0, CONFIG.refresh_cooldown_seconds
	)
	_next_offer_id = maxi(SaveDataReader.get_int(data, "next_offer_id", 1), highest_offer_id + 1)

	# Also covers saves made before contracts existed: they get a fresh board.
	_fill_board()
	board_changed.emit()


func reset_to_defaults() -> void:
	_board.clear()
	_next_offer_id = 1
	_active = {}
	_history.clear()
	_completed_count = 0
	_failed_count = 0
	_refresh_cooldown = 0.0
	_fill_board()
	board_changed.emit()


# --- Internals --------------------------------------------------------------

func _load_data() -> void:
	_pools = JsonDataLoader.load_dictionary(POOLS_PATH)
	_definitions.clear()
	_definition_order.clear()
	for entry: Dictionary in JsonDataLoader.load_entries(CONTRACTS_PATH, "contracts"):
		var definition: ContractDefinition = ContractDefinition.from_dictionary(entry)
		if definition == null:
			continue
		if _definitions.has(definition.id):
			push_warning("ContractManager: duplicate contract id '%s'." % definition.id)
			continue
		_definitions[definition.id] = definition
		_definition_order.append(definition.id)


func _check_requirement(kind: String, definition: ContractDefinition) -> PackedStringArray:
	if not GameEffects.has_requirement_checker(kind):
		return PackedStringArray(["Requires %s (system not available)" % kind])
	return GameEffects.check_requirement(kind, definition)


## Tops the board up with offers the player's level allows. Prefers
## contracts that are not already offered or in progress.
func _fill_board() -> bool:
	var added: bool = false
	while _board.size() < get_board_size():
		var eligible: Array[String] = []
		var fresh: Array[String] = []
		for template_id: String in _definition_order:
			var definition: ContractDefinition = _definitions[template_id]
			if definition.required_level > ProgressionManager.level:
				continue
			eligible.append(template_id)
			if not _is_template_in_use(template_id):
				fresh.append(template_id)
		var candidates: Array[String] = fresh if not fresh.is_empty() else eligible
		if candidates.is_empty():
			break
		_board.append(_create_offer(candidates[_rng.randi_range(0, candidates.size() - 1)]))
		added = true
	return added


func _is_template_in_use(template_id: String) -> bool:
	if SaveDataReader.get_string(_active, "template_id") == template_id:
		return true
	for offer: Dictionary in _board:
		if offer["template_id"] == template_id:
			return true
	return false


func _create_offer(template_id: String) -> Dictionary:
	var definition: ContractDefinition = _definitions[template_id]
	var factor: float = _rng.randf_range(1.0 - CONFIG.reward_variance, 1.0 + CONFIG.reward_variance)
	var reward: int = maxi(
		REWARD_ROUNDING, roundi(definition.reward * factor / REWARD_ROUNDING) * REWARD_ROUNDING
	)
	var offer: Dictionary = {
		"offer_id": _next_offer_id,
		"template_id": template_id,
		"reward": reward,
		"seed": int(_rng.randi() >> 1),
	}
	_next_offer_id += 1
	return offer


func _complete() -> void:
	var definition: ContractDefinition = get_active_definition()
	var reward: int = get_effective_reward(_active)
	var mistakes: int = get_mistakes()
	var bonus: int = roundi(reward * get_flawless_bonus_ratio()) if mistakes == 0 else 0
	var xp: int = get_effective_xp(definition)
	var heat_cut: float = clampf(GameEffects.get_total(GameEffects.HEAT_REDUCTION), 0.0, 100.0)
	var heat: float = definition.heat
	if heat > 0.0:
		heat *= 1.0 - heat_cut / 100.0
	var result: Dictionary = _build_result(definition, OUTCOME_COMPLETED, "")
	result["reward"] = reward
	result["bonus"] = bonus
	result["xp"] = xp
	result["white"] = definition.reputation_white
	result["underground"] = definition.reputation_underground
	result["heat"] = heat

	# Clear first: paying out can level the player up, which refills the board.
	_active = {}
	_completed_count += 1
	_record(result)
	EconomyManager.add_money(reward + bonus, TransactionCategory.CONTRACT, definition.title)
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, definition.reputation_white)
	ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, definition.reputation_underground)
	ReputationManager.add_heat(heat)
	ProgressionManager.add_xp(xp, "contract")
	_fill_board()
	board_changed.emit()
	contract_completed.emit(result)


func _fail(reason: String) -> void:
	var definition: ContractDefinition = get_active_definition()
	var is_underground: bool = definition.alignment == ContractDefinition.ALIGNMENT_UNDERGROUND
	var result: Dictionary = _build_result(definition, OUTCOME_FAILED, reason)
	var penalty: int = -CONFIG.failure_reputation_penalty
	result["white"] = 0 if is_underground else penalty
	result["underground"] = penalty if is_underground else 0
	result["heat"] = CONFIG.failure_heat if is_underground else 0.0

	_active = {}
	_failed_count += 1
	_record(result)
	ReputationManager.add_reputation(ReputationManager.Kind.WHITE, result["white"])
	ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, result["underground"])
	ReputationManager.add_heat(result["heat"])
	_fill_board()
	board_changed.emit()
	contract_failed.emit(result)


func _build_result(definition: ContractDefinition, outcome: String, reason: String) -> Dictionary:
	return {
		"template_id": definition.id,
		"name": definition.title,
		"category": definition.category,
		"outcome": outcome,
		"reason": reason,
		"reward": 0,
		"bonus": 0,
		"xp": 0,
		"white": 0,
		"underground": 0,
		"heat": 0.0,
		"mistakes": get_mistakes(),
		"finished_at": int(Time.get_unix_time_from_system()),
	}


func _record(result: Dictionary) -> void:
	_history.append(result.duplicate())
	_trim_history()


func _trim_history() -> void:
	var overflow: int = _history.size() - CONFIG.max_history
	if overflow > 0:
		_history = _history.slice(overflow)


## A clean offer, or {} when the data is unusable or its contract is gone.
func _sanitize_offer(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var data: Dictionary = raw
	var template_id: String = SaveDataReader.get_string(data, "template_id")
	if not _definitions.has(template_id):
		return {}
	return {
		"offer_id": maxi(1, SaveDataReader.get_int(data, "offer_id", 1)),
		"template_id": template_id,
		"reward": maxi(0, SaveDataReader.get_int(data, "reward")),
		"seed": maxi(0, SaveDataReader.get_int(data, "seed")),
	}


func _sanitize_result(raw: Dictionary) -> Dictionary:
	var outcome: String = SaveDataReader.get_string(raw, "outcome", OUTCOME_FAILED)
	return {
		"template_id": SaveDataReader.get_string(raw, "template_id"),
		"name": SaveDataReader.get_string(raw, "name", "Unknown contract"),
		"category": SaveDataReader.get_string(raw, "category"),
		"outcome": outcome if outcome == OUTCOME_COMPLETED else OUTCOME_FAILED,
		"reason": SaveDataReader.get_string(raw, "reason"),
		"reward": maxi(0, SaveDataReader.get_int(raw, "reward")),
		"bonus": maxi(0, SaveDataReader.get_int(raw, "bonus")),
		"xp": maxi(0, SaveDataReader.get_int(raw, "xp")),
		"white": SaveDataReader.get_int(raw, "white"),
		"underground": SaveDataReader.get_int(raw, "underground"),
		"heat": SaveDataReader.get_float(raw, "heat"),
		"mistakes": maxi(0, SaveDataReader.get_int(raw, "mistakes")),
		"finished_at": maxi(0, SaveDataReader.get_int(raw, "finished_at")),
	}


func _on_effects_changed() -> void:
	if _fill_board():
		board_changed.emit()


func _on_level_changed(new_level: int, old_level: int) -> void:
	# Newly unlocked contracts can fill empty board slots straight away.
	if new_level > old_level and _fill_board():
		board_changed.emit()
