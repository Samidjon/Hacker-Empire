extends RefCounted
## Unit tests for research, products, world events and daily running costs.
## Run by tests/test_runner.gd, which resets every system before each test.

var _report: Callable


func _init(report: Callable) -> void:
	_report = report


func _check(condition: bool, description: String) -> void:
	_report.call(condition, description)


# --- Helpers ----------------------------------------------------------------

func _rich_and_experienced() -> void:
	ProgressionManager.add_xp(100000000)
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)


func _found() -> void:
	_rich_and_experienced()
	OrganizationManager.found_company("Test Labs")


## Finishes a project regardless of how long it would take.
func _research(project_id: String) -> void:
	ResearchManager.start_project(project_id)
	ResearchManager.add_progress(ResearchManager.get_project(project_id).points)


# --- Research ---------------------------------------------------------------

func test_research_data() -> void:
	var projects: Array[ResearchProject] = ResearchManager.get_projects()
	_check(projects.size() >= 10, "at least 10 research projects")
	var data_ok: bool = true
	var unlocked_products: Dictionary = {}
	for project: ResearchProject in projects:
		if project.cost <= 0 or project.points <= 0 or project.description.is_empty() or project.effects.is_empty():
			data_ok = false
		for required_id: String in project.requires:
			var required: ResearchProject = ResearchManager.get_project(required_id)
			if required == null or required.required_level > project.required_level:
				data_ok = false
		for line: String in project.describe_effects():
			if line.contains("_"):
				data_ok = false
		for product_id: String in project.unlocks_products:
			unlocked_products[product_id] = project.id
	_check(data_ok, "every project has a cost, work, a described unlock and reachable prerequisites")
	var products_ok: bool = true
	for product: ProductDefinition in ProductManager.get_products():
		if unlocked_products.get(product.id) != product.required_research or product.development_cost <= 0:
			products_ok = false
		if product.is_subscription() and (product.price_per_subscriber <= 0 or product.subscriber_cap <= 0 or product.maintenance_cost <= 0):
			products_ok = false
		if not product.is_subscription() and (product.daily_revenue <= 0 or product.decay <= 0.0 or product.decay >= 1.0):
			products_ok = false
	_check(products_ok and ProductManager.get_products().size() >= 5, "every product is unlocked by the project that names it and can earn money")


func test_research_flow() -> void:
	var config: ResearchConfig = ResearchManager.CONFIG
	_check(is_equal_approx(ResearchManager.get_research_power(), config.base_research_power), "a new player has the base research power")
	var blockers: PackedStringArray = ResearchManager.get_start_blockers("automated_triage")
	_check(blockers.size() == 2 and not ResearchManager.start_project("automated_triage"), "a new player lacks the level and the money")
	_rich_and_experienced()
	_check(ResearchManager.get_start_blockers("log_correlation") == PackedStringArray(["Requires Automated Triage"]), "a prerequisite is enforced")

	var events: Dictionary = {"started": [], "completed": []}
	var on_started: Callable = func(project_id: String) -> void: events["started"].append(project_id)
	var on_completed: Callable = func(project_id: String) -> void: events["completed"].append(project_id)
	ResearchManager.research_started.connect(on_started)
	ResearchManager.research_completed.connect(on_completed)
	var project: ResearchProject = ResearchManager.get_project("automated_triage")
	var money_before: int = EconomyManager.money
	_check(ResearchManager.start_project(project.id), "a project can be started")
	_check(EconomyManager.money == money_before - project.cost and EconomyManager.get_expenses_by_category().get(TransactionCategory.RESEARCH_COST) == project.cost, "the cost is charged as research cost")
	_check(ResearchManager.get_active_project() == project and events["started"] == [project.id], "it becomes the active project")
	_check(ResearchManager.get_start_blockers("signature_library")[0] == "Finish Automated Triage first" and ResearchManager.get_start_blockers(project.id) == PackedStringArray(["In progress"]), "one project at a time")

	# Progress follows research power and play time.
	ResearchManager.advance_time(60.0)
	_check(is_equal_approx(ResearchManager.get_progress(), config.base_research_power), "one minute gives research power in points")
	_check(is_equal_approx(ResearchManager.get_minutes_remaining(), (project.points - config.base_research_power) / config.base_research_power), "time remaining is estimated")
	var time_before: float = GameEffects.get_total(GameEffects.CONTRACT_TIME)
	var xp_before: int = ProgressionManager.total_xp
	ResearchManager.advance_time(ResearchManager.get_minutes_remaining() * 60.0 + 0.1)
	_check(ResearchManager.is_completed(project.id) and not ResearchManager.has_active_project() and events["completed"] == [project.id], "the project completes when its points are reached")
	_check(is_equal_approx(GameEffects.get_total(GameEffects.CONTRACT_TIME), time_before + 5.0), "the technology applies at once and for good")
	_check(ProgressionManager.total_xp == xp_before + project.xp_reward, "research gives experience")
	_check(ResearchManager.get_start_blockers(project.id) == PackedStringArray(["Already researched"]), "a finished project cannot be repeated")
	ResearchManager.advance_time(1000.0)
	_check(is_zero_approx(ResearchManager.get_progress()), "nothing accrues with no project running")

	# Grants are research rewards; hardware speeds research up.
	_research("assistant_model")
	_check(EconomyManager.get_income_by_category().get(TransactionCategory.RESEARCH_REWARD) == ResearchManager.get_project("assistant_model").grant, "a sponsored project pays its grant as a research reward")
	HardwareManager.purchase("gpu_spark")
	_check(is_equal_approx(ResearchManager.get_research_power(), config.base_research_power + 8.0), "a GPU raises research power")
	ResearchManager.start_project("signature_library")
	ResearchManager.add_progress(-500.0)
	_check(is_zero_approx(ResearchManager.get_progress()), "progress cannot go below zero")
	ResearchManager.research_started.disconnect(on_started)
	ResearchManager.research_completed.disconnect(on_completed)


func test_research_save() -> void:
	_rich_and_experienced()
	_research("automated_triage")
	ResearchManager.start_project("log_correlation")
	ResearchManager.add_progress(33.0)
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(ResearchManager.get_completed_count() == 0 and is_zero_approx(GameEffects.get_total(GameEffects.CONTRACT_TIME)), "reset forgets all research and its bonuses")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(ResearchManager.is_completed("automated_triage") and ResearchManager.get_active_project().id == "log_correlation", "finished and active projects restored")
	_check(is_equal_approx(ResearchManager.get_progress(), 33.0) and is_equal_approx(GameEffects.get_total(GameEffects.CONTRACT_TIME), 5.0), "progress and bonuses restored")

	ResearchManager.load_save_data({"completed": ["automated_triage", "automated_triage", "time_travel", 4], "active": "automated_triage", "progress": 999})
	_check(ResearchManager.get_completed_count() == 1 and not ResearchManager.has_active_project(), "duplicates, unknown projects and a finished 'active' project are dropped")
	ResearchManager.load_save_data({"active": "signature_library", "progress": 999999})
	_check(ResearchManager.has_active_project() and ResearchManager.get_progress_ratio() < 1.0, "a loaded project is never already complete")
	ResearchManager.load_save_data({})
	_check(ResearchManager.get_completed_count() == 0 and not ResearchManager.has_active_project(), "a save from before research existed has none")


# --- Products ---------------------------------------------------------------

func test_product_development() -> void:
	_check(ProductManager.get_status("log_lens") == ProductManager.Status.LOCKED, "products start locked")
	_rich_and_experienced()
	var blockers: PackedStringArray = ProductManager.get_development_blockers("log_lens")
	_check(blockers.size() == 2 and blockers[0].contains("registered company") and blockers[1] == "Requires research: Log Correlation Engine", "a product needs a company and its research")
	OrganizationManager.found_company("Test Labs")
	_research("automated_triage")
	_research("log_correlation")
	_check(ProductManager.get_status("log_lens") == ProductManager.Status.AVAILABLE, "research makes the product available")

	var product: ProductDefinition = ProductManager.get_product("log_lens")
	var money_before: int = EconomyManager.money
	_check(ProductManager.start_development("log_lens"), "development can start")
	_check(EconomyManager.money == money_before - product.development_cost and ProductManager.get_status("log_lens") == ProductManager.Status.DEVELOPING, "the budget is paid and the product is in development")
	_check(ProductManager.get_development_blockers("log_lens") == PackedStringArray(["In development"]), "it cannot be started twice")

	var power: float = ProductManager.get_development_power()
	_check(is_equal_approx(power, ProductManager.CONFIG.base_development_power), "the founder alone has the base development power")
	OrganizationManager.end_day()
	_check(is_equal_approx(ProductManager.get_development_ratio(), power / product.development_points), "each business day adds development power in points")

	# Staff on Product Development make it faster.
	OrganizationManager.expand_office()
	var candidate: Employee = EmployeeManager.get_candidates()[0]
	EmployeeManager.hire(candidate.id)
	EmployeeManager.assign(candidate.id, "development")
	_check(ProductManager.get_development_power() > power, "staff assigned to development add development power")
	EmployeeManager.assign(candidate.id, "research")
	_check(ResearchManager.get_research_power() > ResearchManager.CONFIG.base_research_power and is_equal_approx(ProductManager.get_development_power(), power), "staff assigned to research add research power instead")
	EmployeeManager.dismiss(candidate.id)

	var released: Array[String] = []
	var on_released: Callable = func(product_id: String) -> void: released.append(product_id)
	ProductManager.product_released.connect(on_released)
	var days: int = 1
	while not ProductManager.is_released("log_lens") and days < 50:
		OrganizationManager.end_day()
		days += 1
	_check(released == ["log_lens"] and days == ceili(product.development_points / power), "the product ships after the expected number of days")
	_check(Array(OrganizationManager.get_last_report()["notes"]).has("LogLens has been released."), "the release is noted in the daily report")
	_check(ProductManager.get_development_blockers("log_lens") == PackedStringArray(["Already on the market"]), "a released product cannot be built again")
	ProductManager.product_released.disconnect(on_released)


func test_product_revenue() -> void:
	_found()
	for project_id: String in ["automated_triage", "log_correlation", "signature_library", "traffic_classifier"]:
		_research(project_id)
	ProductManager.load_save_data({"released": {"log_lens": {}, "net_sentinel": {}}})
	_check(ProductManager.get_released_count() == 2, "two products on the market")
	var one_time: ProductDefinition = ProductManager.get_product("log_lens")
	var service: ProductDefinition = ProductManager.get_product("net_sentinel")

	var money_before: int = EconomyManager.money
	OrganizationManager.end_day()
	var report: Dictionary = OrganizationManager.get_last_report()
	var first_subscribers: int = service.subscriber_growth
	_check(report["income"][ProductManager.SALES_LABEL] == one_time.daily_revenue, "a one-time product sells its launch-day amount first")
	_check(report["income"][ProductManager.SUBSCRIPTION_LABEL] == first_subscribers * service.price_per_subscriber and ProductManager.get_subscribers("net_sentinel") == first_subscribers, "a subscription earns price x subscribers")
	_check(report["expenses"][ProductManager.MAINTENANCE_LABEL] == service.maintenance_cost, "a running subscription costs server maintenance every day")
	_check(EconomyManager.money == money_before + report["net"], "the balance moves by the day's net")
	var income: Dictionary = EconomyManager.get_income_by_category()
	_check(income.get(TransactionCategory.SOFTWARE_SALES) == one_time.daily_revenue and income.get(TransactionCategory.SUBSCRIPTION) == first_subscribers * service.price_per_subscriber, "income is booked as software sales and subscriptions")
	_check(EconomyManager.get_expenses_by_category().get(TransactionCategory.SERVER_MAINTENANCE) == service.maintenance_cost, "maintenance is booked as server maintenance")

	OrganizationManager.end_day()
	report = OrganizationManager.get_last_report()
	_check(report["income"][ProductManager.SALES_LABEL] == roundi(one_time.daily_revenue * one_time.decay), "one-time sales fade day by day")
	_check(report["income"][ProductManager.SUBSCRIPTION_LABEL] == first_subscribers * 2 * service.price_per_subscriber, "subscriptions grow day by day")
	for index: int in 60:
		OrganizationManager.end_day()
	_check(ProductManager.get_subscribers("net_sentinel") == service.subscriber_cap, "subscribers stop at the cap")
	_check(ProductManager.get_expected_revenue("log_lens") >= one_time.minimum_daily_revenue, "old one-time products keep a small trickle of sales")
	_check(ProductManager.get_total_revenue("net_sentinel") > service.development_cost, "a subscription pays back its development")
	_check(OrganizationManager.company_level > 1, "product revenue builds the company")
	_check(ProductManager.get_expected_revenue("net_sentinel") > service.subscriber_cap * service.price_per_subscriber, "a higher company level sells for more")

	# Save and load.
	var subscribers: int = ProductManager.get_subscribers("net_sentinel")
	var earned: int = ProductManager.get_total_revenue("log_lens")
	ProductManager.start_development("vault_keeper")
	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(ProductManager.get_released_count() == 0, "reset takes every product off the market")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(ProductManager.get_subscribers("net_sentinel") == subscribers and ProductManager.get_total_revenue("log_lens") == earned, "released products and their numbers are restored")
	ProductManager.load_save_data({"released": {"net_sentinel": {"subscribers": 999999, "days_on_market": -4}, "made_up": {}, "log_lens": "junk"}, "developing": "net_sentinel"})
	_check(ProductManager.get_released_count() == 1 and ProductManager.get_subscribers("net_sentinel") == service.subscriber_cap and ProductManager.get_days_on_market("net_sentinel") == 0, "damaged product data is sanitised")
	_check(not ProductManager.has_product_in_development(), "a released product cannot also be in development")
	OrganizationManager.reset_to_defaults()
	ProductManager.load_save_data({"released": {"log_lens": {}}})
	_check(ProductManager.get_released_count() == 0, "products cannot exist without a company")


# --- Running costs ----------------------------------------------------------

func test_running_costs() -> void:
	_check(HardwareManager.get_daily_power_cost() == 0, "the stock machine uses no billable power")
	_found()
	HardwareManager.purchase("cpu_quadra")  # tier 1
	HardwareManager.purchase("ram_16gb")    # tier 2
	var per_tier: int = HardwareManager.CONFIG.power_cost_per_tier
	_check(HardwareManager.get_daily_power_cost() == 3 * per_tier, "electricity follows the tiers of installed parts")
	var money_before: int = EconomyManager.money
	OrganizationManager.end_day()
	var report: Dictionary = OrganizationManager.get_last_report()
	_check(report["expenses"][HardwareManager.ELECTRICITY_LABEL] == 3 * per_tier and EconomyManager.money == money_before - 3 * per_tier, "electricity is charged every business day")
	_check(EconomyManager.get_expenses_by_category().get(TransactionCategory.ELECTRICITY) == 3 * per_tier, "and booked as electricity")
	_research("cold_storage")
	_check(HardwareManager.get_daily_power_cost() == roundi(3 * per_tier * 0.75), "efficiency research lowers the bill")
	HardwareManager.install("cpu_pentaline_ii")
	_check(HardwareManager.get_daily_power_cost() == roundi(2 * per_tier * 0.75), "swapping in a lower tier lowers it too")

	# A bill that cannot be paid becomes overdue instead of a negative balance.
	EconomyManager.spend_money(EconomyManager.money, TransactionCategory.OTHER)
	OrganizationManager.end_day()
	_check(EconomyManager.money == 0 and OrganizationManager.rent_arrears == HardwareManager.get_daily_power_cost(), "an unpaid bill is added to the overdue total")
	_check(Array(OrganizationManager.get_last_report()["notes"]).size() == 1, "and noted in the report")

	var labels: PackedStringArray = []
	for cost: Dictionary in GameEffects.get_daily_costs():
		labels.append(cost["label"])
	_check(labels.has(HardwareManager.ELECTRICITY_LABEL) and labels.has(ProductManager.MAINTENANCE_LABEL), "electricity and server maintenance are registered running costs")


# --- Events -----------------------------------------------------------------

func test_event_data() -> void:
	var ids: PackedStringArray = EventManager.get_event_ids()
	for required: String in ["server_failure", "employee_resignation", "new_client", "competitor_recruitment", "hardware_malfunction", "research_breakthrough"]:
		_check(ids.has(required), "event %s exists" % required)
	_check(not EventManager.is_eligible("new_client"), "a level 1 player gets no client rush")
	_check(EventManager.is_eligible("hardware_malfunction") and EventManager.is_eligible("power_cut"), "some events can happen to anyone")
	_check(not EventManager.is_eligible("employee_resignation") and not EventManager.is_eligible("research_breakthrough") and not EventManager.is_eligible("server_failure") and not EventManager.is_eligible("product_review"), "events about staff, research, servers and products wait for those to exist")
	_check(not EventManager.is_eligible("made_up") and not EventManager.trigger_event("made_up"), "unknown events never happen")

	# Every event offers at least two choices, and each choice does something.
	_found()
	OrganizationManager.expand_office()
	EmployeeManager.hire(EmployeeManager.get_candidates()[0].id)
	_research("automated_triage")
	ResearchManager.start_project("signature_library")
	HardwareManager.purchase("srv_closet")
	ProductManager.load_save_data({"released": {"log_lens": {}}})
	var all_ok: bool = true
	for event_id: String in ids:
		# An earlier event may have made the only employee leave.
		if EmployeeManager.get_employee_count() == 0:
			EmployeeManager.hire(EmployeeManager.get_candidates()[0].id)
		if not ResearchManager.has_active_project():
			ResearchManager.start_project("vault_core")
		if not EventManager.trigger_event(event_id):
			all_ok = false
			printerr("    could not trigger %s" % event_id)
			continue
		var event: Dictionary = EventManager.get_pending_event()
		var choices: Array = event["choices"]
		if choices.size() < 2 or String(event["description"]).contains("{") or String(event["title"]).is_empty():
			all_ok = false
		for choice: Dictionary in choices:
			if String(choice["label"]).is_empty() or String(choice["label"]).contains("{"):
				all_ok = false
		var outcomes: Array = []
		var on_resolved: Callable = func(_id: String, _index: int, outcome: PackedStringArray) -> void: outcomes.append(outcome)
		EventManager.event_resolved.connect(on_resolved)
		if not EventManager.choose(choices.size() - 1) or outcomes.is_empty() or (outcomes[0] as PackedStringArray).is_empty() or (outcomes[0] as PackedStringArray)[0] == "Nothing changes.":
			all_ok = false
			printerr("    last choice of %s did nothing" % event_id)
		EventManager.event_resolved.disconnect(on_resolved)
	_check(all_ok, "every event can occur, reads cleanly and has at least two choices with consequences")


func test_event_choices() -> void:
	_rich_and_experienced()
	var triggered: Array[String] = []
	var on_triggered: Callable = func(event_id: String) -> void: triggered.append(event_id)
	EventManager.event_triggered.connect(on_triggered)
	_check(not EventManager.has_pending_event() and EventManager.get_pending_event().is_empty(), "no event is waiting at first")
	_check(EventManager.trigger_event("new_client") and triggered == ["new_client"], "an eligible event can occur")
	_check(not EventManager.trigger_event("power_cut") and not EventManager.trigger_random_event(), "only one event waits for a decision at a time")
	var money_before: int = EconomyManager.money
	var rep_before: int = ReputationManager.white_reputation
	_check(not EventManager.choose(7) and not EventManager.choose(-1) and EventManager.has_pending_event(), "an invalid choice is refused")
	_check(EventManager.choose(0), "a choice can be made")
	_check(EconomyManager.money == money_before + 350 and ReputationManager.white_reputation == rep_before + 1, "the first choice pays and builds reputation")
	_check(not EventManager.has_pending_event() and not EventManager.choose(0), "the event is over after the choice")
	var history: Array[Dictionary] = EventManager.get_history()
	_check(history.size() == 1 and history[0]["id"] == "new_client" and history[0]["choice"] == "Take the rush job" and Array(history[0]["outcome"]).size() == 3, "the decision and its outcome are recorded")

	# The other choice has different consequences.
	EventManager.trigger_event("new_client")
	money_before = EconomyManager.money
	EventManager.choose(1)
	_check(EconomyManager.money == money_before and ReputationManager.white_reputation == rep_before + 3, "the second choice trades the money for more reputation")

	# A choice that costs money is disabled when it cannot be afforded.
	EconomyManager.spend_money(EconomyManager.money - 50, TransactionCategory.OTHER)
	EventManager.trigger_event("hardware_malfunction")
	var event: Dictionary = EventManager.get_pending_event()
	_check(event["choices"][0]["cost"] == 200 and not event["choices"][0]["enabled"] and not String(event["choices"][0]["blocker"]).is_empty(), "an unaffordable choice is disabled and says why")
	_check(not EventManager.choose(0) and EconomyManager.money == 50, "and cannot be chosen")
	_check(event["choices"][1]["enabled"] and EventManager.choose(1), "the free choice is always open")

	# Events about a person name that person and act on them.
	EconomyManager.add_money(1000000, TransactionCategory.OTHER)
	OrganizationManager.found_company("Test Labs")
	var employee: Employee = EmployeeManager.get_candidates()[0]
	EmployeeManager.hire(employee.id)
	employee.morale = 50.0
	EventManager.trigger_event("employee_resignation")
	_check(String(EventManager.get_pending_event()["description"]).begins_with(employee.display_name), "the event names the employee")
	EventManager.choose(0)
	_check(is_equal_approx(employee.morale, 70.0) and EmployeeManager.get_employee_count() == 1, "a counter-offer keeps them and lifts their morale")
	EventManager.trigger_event("employee_resignation")
	EventManager.choose(1)
	_check(EmployeeManager.get_employee_count() == 0, "letting them go removes them from the staff")

	ResearchManager.start_project("automated_triage")
	EventManager.trigger_event("research_breakthrough")
	EventManager.choose(1)
	_check(ResearchManager.is_completed("automated_triage"), "a breakthrough can finish the research")
	EventManager.event_triggered.disconnect(on_triggered)


func test_event_timing_and_save() -> void:
	var config: EventConfig = EventManager.CONFIG
	EventManager.advance_time(config.grace_period_seconds - 1.0)
	_check(not EventManager.has_pending_event(), "nothing happens during the grace period")
	# With enough rolls an event is certain to occur.
	var rolls: int = 0
	while not EventManager.has_pending_event() and rolls < 400:
		EventManager.advance_time(config.check_interval_seconds)
		rolls += 1
	_check(EventManager.has_pending_event(), "events occur by themselves as time passes")
	var pending_id: String = EventManager.get_pending_event_id()
	EventManager.advance_time(config.check_interval_seconds * 50.0)
	_check(EventManager.get_pending_event_id() == pending_id, "time stands still for events while one is waiting")

	_check(SaveManager.save_to_slot(1), "save succeeds")
	SaveManager.reset_all_sections()
	_check(not EventManager.has_pending_event(), "reset clears the waiting event")
	_check(SaveManager.load_from_slot(1), "load succeeds")
	_check(EventManager.get_pending_event_id() == pending_id, "a waiting decision survives save and load")
	EventManager.choose(1)
	for index: int in config.max_history + 4:
		EventManager.trigger_event("hardware_malfunction")
		EventManager.choose(1)
	_check(EventManager.get_history().size() == config.max_history, "the history is capped")
	_check(SaveManager.save_to_slot(1) and SaveManager.load_from_slot(1) and EventManager.get_history().size() == config.max_history, "the history is saved")
	EventManager.load_save_data({"pending": {"id": "alien_invasion"}, "seconds_until_check": -99, "history": ["junk", {"id": 3, "outcome": [1, "ok"]}]})
	_check(not EventManager.has_pending_event(), "an unknown waiting event is dropped")
	_check(EventManager.get_history().size() == 1 and EventManager.get_history()[0]["outcome"] == ["ok"], "damaged history is sanitised")
	EventManager.advance_time(0.5)
	_check(not EventManager.has_pending_event(), "a damaged timer does not fire at once")
