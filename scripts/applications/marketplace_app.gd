extends HBoxContainer
## Marketplace application: browse and buy hardware. Buying goes through
## HardwareManager, which charges the money and installs the part.

const ALL_CATEGORIES_LABEL: String = "All parts"
const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)

## "" shows every category.
var _category: String = ""
var _items: Array[HardwareItem] = []
var _selected_id: String = ""

@onready var _category_list: ItemList = %MarketCategoryList
@onready var _item_list: ItemList = %MarketItemList
@onready var _balance_label: Label = %MarketBalanceLabel
@onready var _title_label: Label = %MarketItemTitle
@onready var _meta_label: Label = %MarketItemMeta
@onready var _description_label: Label = %MarketItemDescription
@onready var _facts: RichTextLabel = %MarketItemFacts
@onready var _blocker_label: Label = %MarketBlockerLabel
@onready var _buy_button: Button = %BuyButton


func _ready() -> void:
	_category_list.add_item(ALL_CATEGORIES_LABEL)
	for category: String in HardwareCategory.ALL:
		_category_list.add_item(HardwareCategory.get_display_name(category))
	_category_list.select(0)
	_category_list.item_selected.connect(select_category)
	_item_list.item_selected.connect(select_item)
	_buy_button.pressed.connect(buy_selected)
	HardwareManager.hardware_changed.connect(_rebuild_items)
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_details())
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _rebuild_items())
	_rebuild_items()


func get_item_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for item: HardwareItem in _items:
		ids.append(item.id)
	return ids


func get_selected_item_id() -> String:
	return _selected_id


func get_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_title_label.text, _meta_label.text, _facts.get_parsed_text(), _blocker_label.text
	]


## Index 0 shows everything; 1..n follow HardwareCategory.ALL.
func select_category(index: int) -> void:
	_category = "" if index <= 0 else HardwareCategory.ALL[mini(index, HardwareCategory.ALL.size()) - 1]
	if not _category_list.is_selected(index):
		_category_list.select(index)
	_rebuild_items()


func select_item(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_selected_id = _items[index].id
	if not _item_list.is_selected(index):
		_item_list.select(index)
	_refresh_details()


## Selects an item by id (switching to its category if it is filtered out).
func select_item_id(item_id: String) -> void:
	if not get_item_ids().has(item_id):
		select_category(0)
	select_item(get_item_ids().find(item_id))


## Buys the selected item, exactly as the Buy button does.
func buy_selected() -> bool:
	return HardwareManager.purchase(_selected_id)


func _rebuild_items() -> void:
	_items = HardwareManager.get_shop_items(_category)
	_item_list.clear()
	var selected_index: int = -1
	for index: int in _items.size():
		var item: HardwareItem = _items[index]
		var status: String = ""
		if HardwareManager.is_installed(item.id):
			status = "   [installed]"
		elif HardwareManager.is_owned(item.id):
			status = "   [owned]"
		_item_list.add_item("T%d  %s  %s%s" % [item.tier, FormatUtils.money(item.price).rpad(8), item.title, status])
		if HardwareManager.is_owned(item.id):
			_item_list.set_item_custom_fg_color(index, UIPalette.ACCENT)
		elif ProgressionManager.level < item.required_level:
			_item_list.set_item_custom_fg_color(index, UIPalette.TEXT_DIM)
		if item.id == _selected_id:
			selected_index = index
	if selected_index < 0 and not _items.is_empty():
		selected_index = 0
	if selected_index >= 0:
		select_item(selected_index)
	else:
		_selected_id = ""
		_refresh_details()


func _refresh_details() -> void:
	_balance_label.text = "Balance  %s" % FormatUtils.money(EconomyManager.money)
	var item: HardwareItem = HardwareManager.get_item(_selected_id)
	if item == null:
		_title_label.text = "Nothing selected"
		_meta_label.text = ""
		_description_label.text = ""
		_facts.clear()
		_blocker_label.text = ""
		_buy_button.disabled = true
		return
	_title_label.text = item.title
	_meta_label.text = "%s   -   TIER %d" % [HardwareCategory.get_display_name(item.category).to_upper(), item.tier]
	_description_label.text = item.description

	var installed: HardwareItem = HardwareManager.get_installed(item.category)
	_facts.clear()
	_facts.push_table(2)
	_add_fact("Price", FormatUtils.money(item.price), UIPalette.ACCENT)
	_add_fact("Attributes", item.describe_attributes(), UIPalette.PRIMARY)
	_add_fact("Required level", str(item.required_level), UIPalette.TEXT)
	_add_fact(
		"Currently installed",
		"%s (tier %d): %s" % [installed.title, installed.tier, installed.describe_attributes()]
		if installed != null else "Nothing in this slot",
		UIPalette.TEXT_DIM
	)
	_facts.pop()

	var blockers: PackedStringArray = HardwareManager.get_purchase_blockers(item.id)
	var is_owned: bool = HardwareManager.is_owned(item.id)
	_blocker_label.text = "\n".join(blockers)
	_blocker_label.add_theme_color_override(&"font_color", UIPalette.ACCENT if is_owned else UIPalette.DANGER)
	_buy_button.disabled = not blockers.is_empty()
	_buy_button.text = "Owned" if is_owned else "Buy for %s" % FormatUtils.money(item.price)


func _add_fact(label: String, value: String, value_color: Color) -> void:
	for cell: Array in [[label, UIPalette.TEXT_DIM], [value, value_color]]:
		_facts.push_cell()
		_facts.set_cell_padding(CELL_PADDING)
		_facts.push_color(cell[1])
		_facts.add_text(cell[0])
		_facts.pop()
		_facts.pop()
