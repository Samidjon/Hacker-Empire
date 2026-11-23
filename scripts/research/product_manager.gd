extends Node
## ProductManager (autoload)
##
## Owns the company's software products: which are in development, which are
## on the market, and what they earn. Development and sales happen once per
## business day, in OrganizationManager.day_processing. One-time products
## bring in software sales that fade; subscriptions build up subscribers and
## cost server maintenance every day.

signal products_changed
signal development_started(product_id: String)
signal product_released(product_id: String)

enum Status { LOCKED, AVAILABLE, DEVELOPING, RELEASED }

const CONFIG: ResearchConfig = preload("res://resources/configurations/research_config.tres")
const DATA_PATH: String = "res://data/products/products.json"
const SAVE_SECTION: String = "products"
const SALES_LABEL: String = "Software sales"
const SUBSCRIPTION_LABEL: String = "Subscriptions"
const MAINTENANCE_LABEL: String = "Server maintenance"

var _products: Dictionary = {} # product id -> ProductDefinition
var _product_order: Array[String] = []
var _developing_id: String = ""
var _development_progress: float = 0.0
## Released products: id -> {days_on_market, subscribers, total_revenue}.
var _released: Dictionary = {}


func _ready() -> void:
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "products"):
		var product: ProductDefinition = ProductDefinition.from_dictionary(entry)
		if product != null and not _products.has(product.id):
			_products[product.id] = product
			_product_order.append(product.id)
	SaveManager.register_section(SAVE_SECTION, self)
	GameEffects.register_daily_cost(
		MAINTENANCE_LABEL, TransactionCategory.SERVER_MAINTENANCE, get_daily_maintenance_cost
	)
	OrganizationManager.day_processing.connect(_on_day_processing)
	ResearchManager.research_changed.connect(func() -> void: products_changed.emit())


# --- Catalogue --------------------------------------------------------------

func get_products() -> Array[ProductDefinition]:
	var products: Array[ProductDefinition] = []
	for product_id: String in _product_order:
		products.append(_products[product_id])
	return products


func get_product(product_id: String) -> ProductDefinition:
	return _products.get(product_id)


# --- State ------------------------------------------------------------------

func get_status(product_id: String) -> Status:
	var product: ProductDefinition = get_product(product_id)
	if product == null:
		return Status.LOCKED
	if _released.has(product_id):
		return Status.RELEASED
	if _developing_id == product_id:
		return Status.DEVELOPING
	if ResearchManager.is_completed(product.required_research):
		return Status.AVAILABLE
	return Status.LOCKED


func is_released(product_id: String) -> bool:
	return _released.has(product_id)


func get_released_count() -> int:
	return _released.size()


func has_product_in_development() -> bool:
	return not _developing_id.is_empty()


func get_developing_product() -> ProductDefinition:
	return get_product(_developing_id)


## 0.0 - 1.0 through the product in development.
func get_development_ratio() -> float:
	var product: ProductDefinition = get_developing_product()
	return clampf(_development_progress / product.development_points, 0.0, 1.0) if product != null else 0.0


## Development points produced per business day.
func get_development_power() -> float:
	return CONFIG.base_development_power + maxf(0.0, GameEffects.get_total(GameEffects.DEVELOPMENT_POWER))


func get_subscribers(product_id: String) -> int:
	return SaveDataReader.get_int(SaveDataReader.get_dictionary(_released, product_id), "subscribers")


func get_days_on_market(product_id: String) -> int:
	return SaveDataReader.get_int(SaveDataReader.get_dictionary(_released, product_id), "days_on_market")


func get_total_revenue(product_id: String) -> int:
	return SaveDataReader.get_int(SaveDataReader.get_dictionary(_released, product_id), "total_revenue")


## What a released product will bring in at the end of the current day.
func get_expected_revenue(product_id: String) -> int:
	var product: ProductDefinition = get_product(product_id)
	if product == null or not is_released(product_id):
		return 0
	var base: float
	if product.is_subscription():
		base = float(mini(product.subscriber_cap, get_subscribers(product_id) + product.subscriber_growth) * product.price_per_subscriber)
	else:
		base = maxf(
			float(product.minimum_daily_revenue),
			product.daily_revenue * pow(product.decay, float(get_days_on_market(product_id)))
		)
	var company_bonus: float = CONFIG.revenue_bonus_per_company_level * (OrganizationManager.company_level - 1)
	return roundi(base * (1.0 + company_bonus))


## Server costs of every running subscription, per business day.
func get_daily_maintenance_cost() -> int:
	var total: int = 0
	for product_id: String in _released:
		var product: ProductDefinition = get_product(product_id)
		if product != null and product.is_subscription():
			total += product.maintenance_cost
	return total


## Reasons development cannot start now. Empty = it can.
func get_development_blockers(product_id: String) -> PackedStringArray:
	var blockers: PackedStringArray = []
	var product: ProductDefinition = get_product(product_id)
	if product == null:
		blockers.append("Unknown product")
		return blockers
	if is_released(product_id):
		blockers.append("Already on the market")
		return blockers
	if _developing_id == product_id:
		blockers.append("In development")
		return blockers
	if not OrganizationManager.is_founded():
		blockers.append("Only a registered company can sell software")
	if has_product_in_development():
		blockers.append("Finish %s first" % get_developing_product().title)
	if not ResearchManager.is_completed(product.required_research):
		var research: ResearchProject = ResearchManager.get_project(product.required_research)
		blockers.append("Requires research: %s" % (research.title if research != null else product.required_research))
	if not EconomyManager.can_afford(product.development_cost):
		blockers.append("Not enough money (%s short)" % FormatUtils.money(product.development_cost - EconomyManager.money))
	return blockers


func can_start_development(product_id: String) -> bool:
	return get_development_blockers(product_id).is_empty()


## Pays the development budget and starts building the product.
func start_development(product_id: String) -> bool:
	if not can_start_development(product_id):
		return false
	var product: ProductDefinition = get_product(product_id)
	if product.development_cost > 0 and not EconomyManager.spend_money(
		product.development_cost, TransactionCategory.RESEARCH_COST, "Development: %s" % product.title
	):
		return false
	_developing_id = product_id
	_development_progress = 0.0
	development_started.emit(product_id)
	products_changed.emit()
	return true


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"developing": _developing_id,
		"development_progress": _development_progress,
		"released": _released.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_released.clear()
	var saved: Dictionary = SaveDataReader.get_dictionary(data, "released")
	# Products exist only inside a company; the company is loaded first.
	if OrganizationManager.is_founded():
		for product_id: String in _product_order:
			if not saved.get(product_id) is Dictionary:
				continue
			var product: ProductDefinition = _products[product_id]
			var entry: Dictionary = saved[product_id]
			_released[product_id] = {
				"days_on_market": maxi(0, SaveDataReader.get_int(entry, "days_on_market")),
				"subscribers": clampi(SaveDataReader.get_int(entry, "subscribers"), 0, product.subscriber_cap),
				"total_revenue": maxi(0, SaveDataReader.get_int(entry, "total_revenue")),
			}
	_developing_id = SaveDataReader.get_string(data, "developing")
	_development_progress = 0.0
	if not _products.has(_developing_id) or _released.has(_developing_id) or not OrganizationManager.is_founded():
		_developing_id = ""
	else:
		_development_progress = clampf(
			SaveDataReader.get_float(data, "development_progress"), 0.0,
			get_developing_product().development_points - 0.01
		)
	products_changed.emit()


func reset_to_defaults() -> void:
	_developing_id = ""
	_development_progress = 0.0
	_released.clear()
	products_changed.emit()


# --- Business day -----------------------------------------------------------

func _on_day_processing(report: Dictionary) -> void:
	var notes: Array = report["notes"]
	var day: int = SaveDataReader.get_int(report, "day")

	# 1. Products already on the market sell.
	var sales: int = 0
	var subscriptions: int = 0
	for product_id: String in _released:
		var product: ProductDefinition = get_product(product_id)
		var state: Dictionary = _released[product_id]
		var revenue: int = get_expected_revenue(product_id)
		if product.is_subscription():
			state["subscribers"] = mini(product.subscriber_cap, int(state["subscribers"]) + product.subscriber_growth)
			subscriptions += revenue
		else:
			sales += revenue
		state["days_on_market"] = int(state["days_on_market"]) + 1
		state["total_revenue"] = int(state["total_revenue"]) + revenue
	if sales > 0:
		EconomyManager.add_money(sales, TransactionCategory.SOFTWARE_SALES, "%s, day %d" % [SALES_LABEL, day])
		report["income"][SALES_LABEL] = sales
	if subscriptions > 0:
		EconomyManager.add_money(subscriptions, TransactionCategory.SUBSCRIPTION, "%s, day %d" % [SUBSCRIPTION_LABEL, day])
		report["income"][SUBSCRIPTION_LABEL] = subscriptions
	if sales + subscriptions > 0:
		OrganizationManager.add_company_xp(roundi((sales + subscriptions) * CONFIG.company_xp_per_revenue))

	# 2. The product in development moves forward, and ships when it is done.
	var developing: ProductDefinition = get_developing_product()
	if developing != null:
		_development_progress += get_development_power()
		if _development_progress >= developing.development_points:
			_released[developing.id] = {"days_on_market": 0, "subscribers": 0, "total_revenue": 0}
			_developing_id = ""
			_development_progress = 0.0
			notes.append("%s has been released." % developing.title)
			product_released.emit(developing.id)
	products_changed.emit()
