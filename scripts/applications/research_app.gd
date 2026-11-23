extends VBoxContainer
## Research application: research projects on one tab, software products on
## the other. Everything goes through ResearchManager and ProductManager.

enum View { RESEARCH, PRODUCTS }

const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)
const STATUS_TEXT: Dictionary = {
	ProductManager.Status.LOCKED: "locked",
	ProductManager.Status.AVAILABLE: "ready to build",
	ProductManager.Status.DEVELOPING: "in development",
	ProductManager.Status.RELEASED: "on the market",
}

var _view: View = View.RESEARCH
var _projects: Array[ResearchProject] = []
var _products: Array[ProductDefinition] = []
var _selected_project_id: String = ""
var _selected_product_id: String = ""

@onready var _research_tab: Button = %ResearchTabButton
@onready var _products_tab: Button = %ProductsTabButton
@onready var _power_label: Label = %ResearchPowerLabel
@onready var _research_view: Control = %ResearchView
@onready var _products_view: Control = %ProductsView
@onready var _active_label: Label = %ActiveResearchLabel
@onready var _active_bar: ProgressBar = %ActiveResearchBar
@onready var _project_list: ItemList = %ProjectList
@onready var _project_title: Label = %ProjectTitle
@onready var _project_meta: Label = %ProjectMeta
@onready var _project_description: Label = %ProjectDescription
@onready var _project_facts: RichTextLabel = %ProjectFacts
@onready var _project_blockers: Label = %ProjectBlockerLabel
@onready var _start_button: Button = %StartResearchButton
@onready var _product_list: ItemList = %ProductList
@onready var _product_title: Label = %ProductTitle
@onready var _product_meta: Label = %ProductMeta
@onready var _product_description: Label = %ProductDescription
@onready var _product_facts: RichTextLabel = %ProductFacts
@onready var _product_blockers: Label = %ProductBlockerLabel
@onready var _develop_button: Button = %DevelopButton


func _ready() -> void:
	_projects = ResearchManager.get_projects()
	_products = ProductManager.get_products()
	_research_tab.pressed.connect(show_view.bind(View.RESEARCH))
	_products_tab.pressed.connect(show_view.bind(View.PRODUCTS))
	_project_list.item_selected.connect(select_project)
	_product_list.item_selected.connect(select_product)
	_start_button.pressed.connect(start_selected_research)
	_develop_button.pressed.connect(develop_selected_product)
	ResearchManager.research_changed.connect(_rebuild)
	ProductManager.products_changed.connect(_rebuild)
	OrganizationManager.company_changed.connect(_rebuild)
	EmployeeManager.employees_changed.connect(_rebuild)
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_details())
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _rebuild())
	if not _projects.is_empty():
		_selected_project_id = _projects[0].id
	if not _products.is_empty():
		_selected_product_id = _products[0].id
	show_view(View.RESEARCH)


func _process(_delta: float) -> void:
	if _research_view.visible and ResearchManager.has_active_project():
		_refresh_active()


func get_view() -> View:
	return _view


func get_project_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_project_title.text, _project_meta.text, _project_facts.get_parsed_text(), _project_blockers.text
	]


func get_product_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_product_title.text, _product_meta.text, _product_facts.get_parsed_text(), _product_blockers.text
	]


func get_active_text() -> String:
	return _active_label.text


func show_view(view: View) -> void:
	_view = view
	_research_view.visible = view == View.RESEARCH
	_products_view.visible = view == View.PRODUCTS
	_research_tab.set_pressed_no_signal(view == View.RESEARCH)
	_products_tab.set_pressed_no_signal(view == View.PRODUCTS)
	_rebuild()


func select_project(index: int) -> void:
	if index >= 0 and index < _projects.size():
		_selected_project_id = _projects[index].id
		_refresh_details()


func select_project_id(project_id: String) -> void:
	if ResearchManager.get_project(project_id) != null:
		_selected_project_id = project_id
		_rebuild()


func select_product(index: int) -> void:
	if index >= 0 and index < _products.size():
		_selected_product_id = _products[index].id
		_refresh_details()


func select_product_id(product_id: String) -> void:
	if ProductManager.get_product(product_id) != null:
		_selected_product_id = product_id
		_rebuild()


## Starts the selected project, exactly as the button does.
func start_selected_research() -> bool:
	return ResearchManager.start_project(_selected_project_id)


## Starts developing the selected product, exactly as the button does.
func develop_selected_product() -> bool:
	return ProductManager.start_development(_selected_product_id)


# --- Refreshing -------------------------------------------------------------

func _rebuild() -> void:
	_power_label.text = "Research power %d / min     Development power %d / day" % [
		roundi(ResearchManager.get_research_power()), roundi(ProductManager.get_development_power())
	]
	_project_list.clear()
	for index: int in _projects.size():
		var project: ResearchProject = _projects[index]
		var mark: String = "      "
		var color: Color = UIPalette.TEXT
		if ResearchManager.is_completed(project.id):
			mark = "[done]"
			color = UIPalette.ACCENT
		elif ResearchManager.get_active_project() == project:
			mark = "[ >> ]"
			color = UIPalette.PRIMARY
		elif not ResearchManager.can_start(project.id):
			color = UIPalette.TEXT_DIM
		_project_list.add_item("%s  %s" % [mark, project.title])
		_project_list.set_item_custom_fg_color(index, color)
		if project.id == _selected_project_id:
			_project_list.select(index)

	_product_list.clear()
	for index: int in _products.size():
		var product: ProductDefinition = _products[index]
		var status: ProductManager.Status = ProductManager.get_status(product.id)
		_product_list.add_item("%s   -   %s" % [product.title, STATUS_TEXT[status]])
		var color: Color = UIPalette.TEXT
		if status == ProductManager.Status.RELEASED:
			color = UIPalette.ACCENT
		elif status == ProductManager.Status.DEVELOPING:
			color = UIPalette.PRIMARY
		elif status == ProductManager.Status.LOCKED:
			color = UIPalette.TEXT_DIM
		_product_list.set_item_custom_fg_color(index, color)
		if product.id == _selected_product_id:
			_product_list.select(index)
	_refresh_active()
	_refresh_details()


func _refresh_active() -> void:
	var active: ResearchProject = ResearchManager.get_active_project()
	if active == null:
		_active_label.text = "No research in progress. %d of %d projects finished." % [
			ResearchManager.get_completed_count(), _projects.size()
		]
		_active_bar.value = 0.0
		return
	_active_label.text = "Researching %s   -   %d / %d points   -   about %s left" % [
		active.title, floori(ResearchManager.get_progress()), active.points,
		FormatUtils.duration(ResearchManager.get_minutes_remaining() * 60.0).substr(3)
	]
	_active_bar.value = ResearchManager.get_progress_ratio() * _active_bar.max_value


func _refresh_details() -> void:
	_refresh_project_details()
	_refresh_product_details()


func _refresh_project_details() -> void:
	var project: ResearchProject = ResearchManager.get_project(_selected_project_id)
	if project == null:
		return
	_project_title.text = project.title
	_project_meta.text = "%s   -   %d research points" % [project.field.to_upper(), project.points]
	_project_description.text = project.description
	_project_facts.clear()
	_project_facts.push_table(2)
	_add_fact(_project_facts, "Cost", FormatUtils.money(project.cost), UIPalette.DANGER)
	_add_fact(_project_facts, "Required level", str(project.required_level), UIPalette.TEXT)
	_add_fact(_project_facts, "Unlocks", ", ".join(project.describe_effects()), UIPalette.ACCENT)
	if not project.unlocks_products.is_empty():
		var names: PackedStringArray = []
		for product_id: String in project.unlocks_products:
			var product: ProductDefinition = ProductManager.get_product(product_id)
			names.append(product.title if product != null else product_id)
		_add_fact(_project_facts, "Makes possible", "the product %s" % ", ".join(names), UIPalette.PRIMARY)
	if project.grant > 0:
		_add_fact(_project_facts, "Grant on completion", FormatUtils.money(project.grant), UIPalette.ACCENT)
	_add_fact(_project_facts, "Experience", "+%d XP" % project.xp_reward, UIPalette.SECONDARY)
	_project_facts.pop()
	var blockers: PackedStringArray = ResearchManager.get_start_blockers(project.id)
	var is_done: bool = ResearchManager.is_completed(project.id)
	_project_blockers.text = "\n".join(blockers)
	_project_blockers.add_theme_color_override(
		&"font_color", UIPalette.ACCENT if is_done or ResearchManager.get_active_project() == project else UIPalette.DANGER
	)
	_start_button.disabled = not blockers.is_empty()
	_start_button.text = "Researched" if is_done else "Start Research (%s)" % FormatUtils.money(project.cost)


func _refresh_product_details() -> void:
	var product: ProductDefinition = ProductManager.get_product(_selected_product_id)
	if product == null:
		return
	var status: ProductManager.Status = ProductManager.get_status(product.id)
	_product_title.text = product.title
	_product_meta.text = "%s   -   %s" % [
		"SUBSCRIPTION SERVICE" if product.is_subscription() else "ONE-TIME LICENCE", String(STATUS_TEXT[status]).to_upper()
	]
	_product_description.text = product.description
	_product_facts.clear()
	_product_facts.push_table(2)
	_add_fact(_product_facts, "Development budget", FormatUtils.money(product.development_cost), UIPalette.DANGER)
	_add_fact(_product_facts, "Development work", "%d points (about %d days at your current power)" % [
		product.development_points, ceili(product.development_points / maxf(1.0, ProductManager.get_development_power()))
	], UIPalette.TEXT)
	if product.is_subscription():
		_add_fact(_product_facts, "Income", "%s per subscriber per day, up to %d subscribers" % [
			FormatUtils.money(product.price_per_subscriber), product.subscriber_cap
		], UIPalette.ACCENT)
		_add_fact(_product_facts, "Server maintenance", "%s per day" % FormatUtils.money(product.maintenance_cost), UIPalette.DANGER)
	else:
		_add_fact(_product_facts, "Income", "%s on launch day, then %d%% of the day before" % [
			FormatUtils.money(product.daily_revenue), roundi(product.decay * 100.0)
		], UIPalette.ACCENT)
	if status == ProductManager.Status.DEVELOPING:
		_add_fact(_product_facts, "Progress", "%d%%" % roundi(ProductManager.get_development_ratio() * 100.0), UIPalette.PRIMARY)
	if status == ProductManager.Status.RELEASED:
		_add_fact(_product_facts, "Days on the market", str(ProductManager.get_days_on_market(product.id)), UIPalette.TEXT)
		if product.is_subscription():
			_add_fact(_product_facts, "Subscribers", str(ProductManager.get_subscribers(product.id)), UIPalette.PRIMARY)
		_add_fact(_product_facts, "Expected today", FormatUtils.money(ProductManager.get_expected_revenue(product.id)), UIPalette.ACCENT)
		_add_fact(_product_facts, "Earned so far", FormatUtils.money(ProductManager.get_total_revenue(product.id)), UIPalette.ACCENT)
	_product_facts.pop()
	var blockers: PackedStringArray = ProductManager.get_development_blockers(product.id)
	_product_blockers.text = "\n".join(blockers)
	_product_blockers.add_theme_color_override(
		&"font_color", UIPalette.DANGER if status in [ProductManager.Status.LOCKED, ProductManager.Status.AVAILABLE] else UIPalette.ACCENT
	)
	_develop_button.disabled = not blockers.is_empty()
	_develop_button.text = "Develop (%s)" % FormatUtils.money(product.development_cost)


func _add_fact(table: RichTextLabel, label: String, value: String, value_color: Color) -> void:
	for cell: Array in [[label, UIPalette.TEXT_DIM], [value, value_color]]:
		table.push_cell()
		table.set_cell_padding(CELL_PADDING)
		table.push_color(cell[1])
		table.add_text(cell[0])
		table.pop()
		table.pop()
