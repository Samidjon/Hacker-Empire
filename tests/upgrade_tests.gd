extends RefCounted
## Unit tests for hardware, skills and the shared bonus system. Run by
## tests/test_runner.gd, which resets every system before each test.

var _report: Callable


func _init(report: Callable) -> void:
	_report = report


func _check(condition: bool, description: String) -> void:
	_report.call(condition, description)


# --- GameEffects ------------------------------------------------------------

func test_game_effects() -> void:
	var base: float = GameEffects.get_total("test_effect")
	var provider: Callable = func(effect_id: String) -> float: return 7.5 if effect_id == "test_effect" else 0.0
	GameEffects.register_provider(provider)
	GameEffects.register_provider(provider)
	_check(is_equal_approx(GameEffects.get_total("test_effect"), base + 7.5), "a provider is counted once even if registered twice")
	_check(is_zero_approx(GameEffects.get_total("something_else")), "unknown effects total zero")
	GameEffects.unregister_provider(provider)
	_check(is_equal_approx(GameEffects.get_total("test_effect"), base), "an unregistered provider no longer counts")
	_check(GameEffects.for_category(GameEffects.CONTRACT_REWARD, "cryptography") == "contract_reward:cryptography", "category effect ids")
	_check(GameEffects.describe(GameEffects.CONTRACT_TIME, 12.0) == "+12% time on contracts", "describes a percentage")
	_check(GameEffects.describe("contract_reward:cryptography", 8.0).contains("Cryptography"), "describes a category bonus")
	_check(GameEffects.has_requirement_checker(HardwareManager.REQUIREMENT_KIND) and GameEffects.has_requirement_checker(SkillManager.REQUIREMENT_KIND), "hardware and skills registered their requirement checkers")
	_check(GameEffects.check_requirement("nobody_checks_this", null).is_empty(), "an unchecked requirement kind reports nothing")


# --- Hardware ---------------------------------------------------------------

func test_hardware_data() -> void:
	var items: Array[HardwareItem] = HardwareManager.get_items()
	_check(items.size() >= 30, "at least 30 hardware items")
	var data_ok: bool = true
	for category: String in HardwareCategory.ALL:
		var shop: Array[HardwareItem] = HardwareManager.get_shop_items(category)
		if shop.size() < 4:
			data_ok = false
		for index: int in shop.size():
			var item: HardwareItem = shop[index]
			if item.price <= 0 or item.tier < 1 or item.attributes.is_empty() or item.description.is_empty():
				data_ok = false
			if index > 0:
				var previous: HardwareItem = shop[index - 1]
				if item.tier <= previous.tier or item.price <= previous.price or item.required_level < previous.required_level:
					data_ok = false
	_check(data_ok, "every category sells at least four tiers, each dearer and better gated than the last")
	_check(HardwareManager.get_item("cpu_quadra").describe_attributes() == "Speed +6", "attributes are described")
	_check(HardwareManager.get_item("cpu_pentaline_ii").describe_attributes() == "No bonuses", "starter parts have no bonuses")
	_check(HardwareItem.from_dictionary({"id": "x", "category": "toaster"}) == null, "an unknown category is rejected")


func test_hardware_starting_state() -> void:
	for category: String in [HardwareCategory.CPU, HardwareCategory.RAM, HardwareCategory.SSD, HardwareCategory.NETWORK, HardwareCategory.COOLING, HardwareCategory.MONITOR]:
		var item: HardwareItem = HardwareManager.get_installed(category)
		_check(item != null and item.is_starter and item.tier == 0, "a new game has a starter part in %s" % category)
	_check(HardwareManager.get_installed(HardwareCategory.GPU) == null and HardwareManager.get_installed(HardwareCategory.SERVER) == null, "GPU and server slots start empty")
	_check(HardwareManager.get_installed_tier(HardwareCategory.GPU) == -1, "an empty slot has tier -1")
	var totals: Dictionary = HardwareManager.get_stat_totals()
	var all_zero: bool = true
	for stat: String in HardwareItem.STATS:
		if not is_zero_approx(totals[stat]):
			all_zero = false
	_check(all_zero and HardwareManager.get_spare_items().is_empty(), "the stock machine gives no bonuses and storage is empty")
	_check(ContractManager.get_board_size() == ContractManager.CONFIG.board_size, "contract board has its base size")


func test_hardware_purchase() -> void:
	_check(HardwareManager.get_purchase_blockers("cpu_quadra")[0].begins_with("Not enough money"), "cannot buy without money")
	_check(not HardwareManager.purchase("cpu_quadra") and not HardwareManager.is_owned("cpu_quadra"), "a blocked purchase changes nothing")
	EconomyManager.add_money(100000, TransactionCategory.OTHER)
	_check(HardwareManager.get_purchase_blockers("cpu_hexon") == PackedStringArray(["Requires level 4"]), "cannot buy above your level")
	_check(HardwareManager.get_purchase_blockers("cpu_pentaline_ii") == PackedStringArray(["Not for sale"]), "starter parts are not for sale")
	_check(not HardwareManager.can_purchase("no_such_part"), "unknown items cannot be bought")

	var events: Array[String] = []
	var on_purchased: Callable = func(item_id: String) -> void: events.append(item_id)
	HardwareManager.item_purchased.connect(on_purchased)
	var money_before: int = EconomyManager.money
	_check(HardwareManager.purchase("cpu_quadra"), "an affordable part can be bought")
	_check(EconomyManager.money == money_before - 400, "the price is charged")
	_check(EconomyManager.get_expenses_by_category().get(TransactionCategory.HARDWARE) == 400, "the purchase is booked as a hardware expense")
	_check(HardwareManager.is_owned("cpu_quadra") and HardwareManager.is_installed("cpu_quadra"), "the new part is owned and installed")
	_check(events == ["cpu_quadra"], "item_purchased is emitted")
	var spares: Array[HardwareItem] = HardwareManager.get_spare_items()
	_check(spares.size() == 1 and spares[0].id == "cpu_pentaline_ii", "the replaced part goes to storage")
	_check(HardwareManager.get_purchase_blockers("cpu_quadra") == PackedStringArray(["Already owned"]) and not HardwareManager.purchase("cpu_quadra"), "a part cannot be bought twice")
	HardwareManager.item_purchased.disconnect(on_purchased)

	_check(HardwareManager.install("cpu_pentaline_ii") and HardwareManager.is_installed("cpu_pentaline_ii"), "a spare part can be put back")
	_check(not HardwareManager.install("cpu_pentaline_ii"), "installing the installed part does nothing")
	_check(not HardwareManager.install("cpu_titan") and not HardwareManager.install("nope"), "parts you do not own cannot be installed")
	_check(HardwareManager.get_owned_items(HardwareCategory.CPU).size() == 2, "both CPUs are still owned")


func test_hardware_effects() -> void:
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	ProgressionManager.add_xp(100000000)
	var definition: ContractDefinition = ContractManager.get_definition("fr_photo_archive")
	var base_limit: float = definition.estimated_duration * ContractManager.CONFIG.time_limit_factor
	_check(is_equal_approx(ContractManager.get_time_limit(definition), base_limit), "no time bonus on the stock machine")

	HardwareManager.purchase("cpu_quadra")  # speed 6
	HardwareManager.purchase("cool_tower")  # speed 3
	_check(is_equal_approx(HardwareManager.get_stat_totals()[HardwareItem.STAT_SPEED], 9.0), "speed adds up over installed parts")
	_check(is_equal_approx(HardwareManager.get_effect(GameEffects.CONTRACT_TIME), 9.0), "speed becomes a contract time bonus")
	_check(is_equal_approx(ContractManager.get_time_limit(definition), base_limit * 1.09), "contracts get more time")
	HardwareManager.install("cpu_pentaline_ii")
	_check(is_equal_approx(ContractManager.get_time_limit(definition), base_limit * 1.03), "removing a part removes its bonus")

	# Capacity adds offers to the contract board, immediately.
	var base_size: int = ContractManager.CONFIG.board_size
	HardwareManager.purchase("ram_8gb") # capacity 15
	_check(ContractManager.get_board_size() == base_size, "a little capacity is not enough for another offer")
	HardwareManager.purchase("ram_32gb") # capacity 80
	_check(ContractManager.get_board_size() == base_size + 1 and ContractManager.get_board().size() == base_size + 1, "enough capacity adds an offer and fills it at once")
	HardwareManager.purchase("srv_datacenter")
	HardwareManager.purchase("mon_holo")
	HardwareManager.purchase("ram_64gb")
	HardwareManager.purchase("ssd_array")
	_check(ContractManager.get_board_size() == base_size + HardwareManager.CONFIG.max_extra_offers, "extra offers from hardware are capped")

	# Network shortens the refresh cooldown.
	var base_cooldown: float = ContractManager.CONFIG.refresh_cooldown_seconds
	HardwareManager.purchase("net_fiber_100") # network 15
	_check(is_equal_approx(ContractManager.get_refresh_cooldown(), base_cooldown * 0.85), "network shortens the wait for new offers")
	ContractManager.refresh_board()
	_check(is_equal_approx(ContractManager.get_refresh_cooldown_remaining(), base_cooldown * 0.85), "the shorter cooldown is what actually runs")

	HardwareManager.purchase("gpu_spark") # research 8
	_check(HardwareManager.get_effect(GameEffects.RESEARCH_POWER) > 8.0, "research hardware adds research power")
	_check(HardwareManager.get_effects_summary().size() == 4, "the effects summary lists all four bonuses")


func test_hardware_requirements() -> void:
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	ProgressionManager.add_xp(100000000)
	var database: ContractDefinition = ContractManager.get_definition("fr_startup_database")
	_check(database.required_hardware == PackedStringArray(["ssd:1"]), "the contract lists a hardware requirement")
	var unmet: PackedStringArray = ContractManager.get_unmet_requirements(database)
	_check(unmet.size() == 1 and unmet[0] == "Requires SSD tier 1 or better", "the stock SSD is not good enough")
	HardwareManager.purchase("ssd_1tb")
	_check(ContractManager.get_unmet_requirements(database).is_empty(), "a better SSD than required also satisfies it")
	HardwareManager.install("ssd_120gb")
	_check(ContractManager.get_unmet_requirements(database).size() == 1, "the part must be installed, not just owned")

	var exact: ContractDefinition = ContractDefinition.from_dictionary({
		"id": "test_exact", "category": "cryptography", "required_hardware": ["gpu_spark"],
		"stages": [{"puzzle": "cipher", "config": {"pool": "field_notes"}}],
	})
	_check(ContractManager.get_unmet_requirements(exact)[0] == "Requires Spark 2G installed", "a specific part can be required")
	HardwareManager.purchase("gpu_spark")
	_check(ContractManager.get_unmet_requirements(exact).is_empty(), "installing that part satisfies it")

	# An offer the player cannot take yet is refused, then accepted.
	HardwareManager.reset_to_defaults()
	ContractManager.load_save_data({"board": [{"offer_id": 900, "template_id": "fr_startup_database", "reward": 600, "seed": 4}]})
	_check(not ContractManager.can_accept(900) and not ContractManager.accept_contract(900), "an offer with an unmet hardware requirement cannot be accepted")
	HardwareManager.purchase("ssd_500gb")
	_check(ContractManager.accept_contract(900), "it can be accepted once the hardware is installed")
	ContractManager.abandon_contract()


func test_hardware_save() -> void:
	EconomyManager.add_money(100000, TransactionCategory.OTHER)
	HardwareManager.purchase("cpu_quadra")
	HardwareManager.purchase("ram_8gb")
	HardwareManager.install("ram_4gb")
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(not HardwareManager.is_owned("cpu_quadra") and HardwareManager.is_installed("cpu_pentaline_ii"), "reset returns to the stock machine")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(HardwareManager.is_installed("cpu_quadra"), "installed part restored")
	_check(HardwareManager.is_owned("ram_8gb") and HardwareManager.is_installed("ram_4gb"), "a spare part and the chosen installed part are restored")
	_check(HardwareManager.get_spare_items().size() == 2, "storage contents restored")

	HardwareManager.load_save_data({
		"owned": ["cpu_titan", "ghost_part", 7, "cpu_titan"],
		"installed": {"cpu": "cpu_titan", "ram": "ram_64gb", "gpu": "cpu_titan", "ssd": 12},
	})
	_check(HardwareManager.is_installed("cpu_titan"), "a valid owned part is installed")
	_check(HardwareManager.get_owned_items(HardwareCategory.CPU).size() == 2, "unknown and duplicate owned entries are dropped")
	_check(HardwareManager.is_installed("ram_4gb"), "a part that is not owned cannot be installed by a save file")
	_check(HardwareManager.get_installed(HardwareCategory.GPU) == null, "a part cannot be installed in the wrong slot")
	_check(HardwareManager.is_installed("ssd_120gb"), "a damaged slot keeps the starter part")
	HardwareManager.load_save_data({})
	_check(HardwareManager.is_installed("cpu_pentaline_ii") and HardwareManager.get_spare_items().is_empty(), "a save from before hardware existed gets the stock machine")


# --- Skills -----------------------------------------------------------------

func test_skill_data() -> void:
	var skills: Array[SkillDefinition] = SkillManager.get_skills()
	_check(skills.size() >= 18, "at least 18 skills")
	var data_ok: bool = true
	for branch: String in SkillBranch.ALL:
		if SkillManager.get_skills(branch).size() < 3:
			data_ok = false
	_check(data_ok, "all six branches have at least three skills")
	var links_ok: bool = true
	var effects_ok: bool = true
	for skill: SkillDefinition in skills:
		if skill.max_level < 1 or skill.cost_per_level < 1 or skill.description.is_empty():
			links_ok = false
		for required_id: String in skill.requires:
			var required: SkillDefinition = SkillManager.get_skill(required_id)
			if required == null or required.branch != skill.branch or int(skill.requires[required_id]) > required.max_level:
				links_ok = false
		for line: String in skill.describe_effects(1):
			# An effect nobody knows how to describe falls back to its raw id.
			if line.contains("_"):
				effects_ok = false
	_check(links_ok, "prerequisites exist, are reachable and stay inside their branch")
	_check(effects_ok, "every skill effect is a known, described bonus")
	_check(SkillDefinition.from_dictionary({"id": "x", "branch": "juggling", "effects": {"contract_time": 1}}) == null, "an unknown branch is rejected")
	_check(SkillDefinition.from_dictionary({"id": "x", "branch": "programming"}) == null, "a skill that grants nothing is rejected")


func test_skill_points_and_upgrades() -> void:
	var config: SkillConfig = SkillManager.CONFIG
	_check(SkillManager.get_earned_points() == config.starting_points and SkillManager.get_spent_points() == 0, "a new character has the starting points")
	_check(SkillManager.get_upgrade_blockers("prog_automation").size() == 2, "a locked skill lists its level and prerequisite")
	_check(not SkillManager.is_unlocked("prog_automation") and SkillManager.is_unlocked("prog_clean_code"), "is_unlocked ignores points")
	_check(not SkillManager.upgrade("prog_automation") and SkillManager.get_level("prog_automation") == 0, "a locked skill cannot be learned")
	_check(not SkillManager.can_upgrade("no_such_skill"), "unknown skills cannot be learned")

	var events: Array = []
	var on_upgraded: Callable = func(skill_id: String, level: int) -> void: events.append([skill_id, level])
	SkillManager.skill_upgraded.connect(on_upgraded)
	_check(SkillManager.upgrade("prog_clean_code"), "an open skill can be learned")
	_check(SkillManager.get_level("prog_clean_code") == 1 and SkillManager.get_available_points() == config.starting_points - 1, "learning spends a point")
	_check(events == [["prog_clean_code", 1]], "skill_upgraded is emitted")
	_check(SkillManager.get_upgrade_blockers("prog_clean_code")[0].begins_with("Needs 1 skill point"), "no points, no upgrade")
	SkillManager.skill_upgraded.disconnect(on_upgraded)

	var points_seen: Array[int] = []
	var on_points: Callable = func(available: int) -> void: points_seen.append(available)
	SkillManager.points_changed.connect(on_points)
	ProgressionManager.add_xp(ProgressionManager.get_xp_required())
	_check(SkillManager.get_available_points() == config.points_per_level and points_seen.has(config.points_per_level), "levelling up grants a point and announces it")
	SkillManager.points_changed.disconnect(on_points)

	ProgressionManager.add_xp(100000000)
	_check(SkillManager.get_earned_points() == config.starting_points + 49 * config.points_per_level, "points follow the player level")
	SkillManager.upgrade("prog_clean_code")
	SkillManager.upgrade("prog_clean_code")
	_check(SkillManager.is_maxed("prog_clean_code") and SkillManager.get_level("prog_clean_code") == 3, "a skill stops at its maximum level")
	_check(not SkillManager.upgrade("prog_clean_code") and SkillManager.get_upgrade_blockers("prog_clean_code") == PackedStringArray(["Already at maximum level"]), "a maxed skill cannot be raised")
	_check(SkillManager.upgrade("prog_automation"), "the prerequisite opens the next skill")
	_check(not SkillManager.can_upgrade("prog_tooling"), "a higher prerequisite level is enforced")
	SkillManager.upgrade("prog_automation")
	var spent_before: int = SkillManager.get_spent_points()
	_check(SkillManager.upgrade("prog_tooling") and SkillManager.get_spent_points() == spent_before + 2, "a dearer skill costs more points")


func test_skill_effects() -> void:
	ProgressionManager.add_xp(100000000)
	var debugging: Dictionary = {"offer_id": 1, "template_id": "sd_checkout_crash", "reward": 1000, "seed": 1}
	var crypto: Dictionary = {"offer_id": 2, "template_id": "cr_locked_diary", "reward": 1000, "seed": 1}
	_check(ContractManager.get_effective_reward(debugging) == 1000, "no pay bonus without skills")
	SkillManager.upgrade("prog_clean_code")
	SkillManager.upgrade("prog_clean_code")
	_check(ContractManager.get_effective_reward(debugging) == 1160, "two levels of Clean Code pay 16% more for debugging")
	_check(ContractManager.get_effective_reward(crypto) == 1000, "a category bonus does not apply to other categories")

	# The bonus is really paid, and the flawless bonus is computed on top of it.
	ContractManager.load_save_data({"board": [debugging]})
	ContractManager.accept_contract(1)
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()
	_check(EconomyManager.money == 1160 + 116, "the boosted reward and the flawless bonus are paid out")

	var base_xp: int = ContractManager.get_definition("cr_locked_diary").xp_reward
	SkillManager.upgrade("prog_automation")
	SkillManager.upgrade("prog_automation")
	SkillManager.upgrade("prog_tooling")
	_check(ContractManager.get_effective_xp(ContractManager.get_definition("cr_locked_diary")) == roundi(base_xp * 1.05), "Custom Tooling adds contract XP")
	var definition: ContractDefinition = ContractManager.get_definition("cr_locked_diary")
	_check(is_equal_approx(ContractManager.get_time_limit(definition), definition.estimated_duration * ContractManager.CONFIG.time_limit_factor * 1.12), "Automation adds contract time")

	SkillManager.upgrade("sec_auditor")
	SkillManager.upgrade("sec_auditor")
	SkillManager.upgrade("sec_second_look")
	_check(ContractManager.get_max_mistakes() == ContractManager.CONFIG.max_mistakes + 1, "Second Look allows one more mistake")
	ContractManager.load_save_data({"board": [crypto]})
	ContractManager.accept_contract(2)
	for index: int in ContractManager.CONFIG.max_mistakes:
		ContractManager.register_mistake()
	_check(ContractManager.has_active_contract(), "the extra mistake really keeps the contract alive")
	ContractManager.register_mistake()
	_check(not ContractManager.has_active_contract(), "and the one after that fails it")

	SkillManager.upgrade("cry_frequency")
	SkillManager.upgrade("cry_steady_hands")
	_check(is_equal_approx(ContractManager.get_flawless_bonus_ratio(), ContractManager.CONFIG.flawless_bonus_ratio + 0.05), "Steady Hands raises the flawless bonus")

	var base_size: int = ContractManager.get_board_size()
	SkillManager.upgrade("net_fast_routes")
	SkillManager.upgrade("net_fast_routes")
	_check(is_equal_approx(ContractManager.get_refresh_cooldown(), ContractManager.CONFIG.refresh_cooldown_seconds * 0.7), "Fast Routes shortens the refresh cooldown")
	SkillManager.upgrade("net_wide_net")
	_check(ContractManager.get_board_size() == base_size + 1 and ContractManager.get_board().size() == base_size + 1, "Wide Net adds an offer and fills it at once")

	# Clean Tracks reduces heat from underground work.
	SkillManager.upgrade("cry_clean_tracks")
	var grey: ContractDefinition = ContractManager.get_definition("cr_puzzle_hunt")
	ContractManager.load_save_data({"board": [{"offer_id": 3, "template_id": grey.id, "reward": 500, "seed": 2}]})
	var heat_before: float = ReputationManager.heat
	ContractManager.accept_contract(3)
	for stage_index: int in ContractManager.get_stage_count():
		ContractManager.complete_stage()
	_check(is_equal_approx(ReputationManager.heat - heat_before, grey.heat * 0.8), "Clean Tracks cuts the heat from underground contracts")

	SkillManager.upgrade("ai_ml_basics")
	_check(is_equal_approx(GameEffects.get_total(GameEffects.RESEARCH_POWER), 10.0), "AI skills add research power")


func test_skill_requirements_and_save() -> void:
	ProgressionManager.add_xp(100000000)
	var payroll: ContractDefinition = ContractManager.get_definition("sd_legacy_payroll")
	_check(ContractManager.get_unmet_requirements(payroll) == PackedStringArray(["Requires skill Clean Code level 2"]), "a contract can require a skill level")
	SkillManager.upgrade("prog_clean_code")
	_check(ContractManager.get_unmet_requirements(payroll).size() == 1, "one level short is still unmet")
	SkillManager.upgrade("prog_clean_code")
	_check(ContractManager.get_unmet_requirements(payroll).is_empty(), "the required level satisfies it")
	var tabletop: ContractDefinition = ContractManager.get_definition("ii_breach_tabletop")
	_check(ContractManager.get_unmet_requirements(tabletop).size() == 3, "skill and hardware requirements are listed together")

	SkillManager.upgrade("net_fast_routes")
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(SkillManager.get_level("prog_clean_code") == 0 and SkillManager.get_spent_points() == 0, "reset forgets every skill")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(SkillManager.get_level("prog_clean_code") == 2 and SkillManager.get_level("net_fast_routes") == 1, "skill levels restored")
	_check(SkillManager.get_spent_points() == 3, "spent points follow from the restored skills")
	_check(is_equal_approx(ContractManager.get_refresh_cooldown(), ContractManager.CONFIG.refresh_cooldown_seconds * 0.85), "bonuses apply again after loading")

	SkillManager.load_save_data({"levels": {"prog_clean_code": 99, "forgotten_skill": 2, "net_packet_sense": -4, "sec_auditor": "lots"}})
	_check(SkillManager.get_level("prog_clean_code") == 3, "a level above the maximum is clamped")
	_check(SkillManager.get_level("forgotten_skill") == 0 and SkillManager.get_level("net_packet_sense") == 0 and SkillManager.get_level("sec_auditor") == 0, "unknown skills and bad values are dropped")
	SkillManager.load_save_data({})
	_check(SkillManager.get_spent_points() == 0, "a save from before skills existed has no skills")
