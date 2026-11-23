extends VBoxContainer
## Hardware application: what is installed in each slot, what the machine's
## totals are worth, and swapping in spare parts.

const EMPTY_SLOT_TEXT: String = "(empty)"
const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 26.0, 2.0)

var _selected_category: String = HardwareCategory.CPU
var _owned_in_slot: Array[HardwareItem] = []
var _selected_owned_id: String = ""

@onready var _totals: RichTextLabel = %HardwareTotals
@onready var _slot_list: ItemList = %SlotList
@onready var _owned_title: Label = %OwnedTitle
@onready var _owned_list: ItemList = %OwnedList
@onready var _owned_details: Label = %OwnedDetails
@onready var _install_button: Button = %InstallButton


func _ready() -> void:
	_slot_list.item_selected.connect(select_slot)
	_owned_list.item_selected.connect(select_owned)
	_install_button.pressed.connect(install_selected)
	HardwareManager.hardware_changed.connect(refresh)
	refresh()


func get_totals_text() -> String:
	return _totals.get_parsed_text()


func get_slot_text(index: int) -> String:
	return _slot_list.get_item_text(index) if index >= 0 and index < _slot_list.item_count else ""


func get_owned_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for item: HardwareItem in _owned_in_slot:
		ids.append(item.id)
	return ids


## Shows the slot at `index` of HardwareCategory.ALL.
func select_slot(index: int) -> void:
	if index < 0 or index >= HardwareCategory.ALL.size():
		return
	_selected_category = HardwareCategory.ALL[index]
	_selected_owned_id = ""
	refresh()


func select_owned(index: int) -> void:
	if index < 0 or index >= _owned_in_slot.size():
		return
	_selected_owned_id = _owned_in_slot[index].id
	if not _owned_list.is_selected(index):
		_owned_list.select(index)
	_refresh_owned_details()


## Installs the selected spare part, exactly as the Install button does.
func install_selected() -> bool:
	return HardwareManager.install(_selected_owned_id)


func refresh() -> void:
	_refresh_totals()
	_slot_list.clear()
	for index: int in HardwareCategory.ALL.size():
		var category: String = HardwareCategory.ALL[index]
		var item: HardwareItem = HardwareManager.get_installed(category)
		_slot_list.add_item("%s  %s" % [
			HardwareCategory.get_display_name(category).rpad(16),
			"%s  (tier %d)" % [item.title, item.tier] if item != null else EMPTY_SLOT_TEXT
		])
		if item == null:
			_slot_list.set_item_custom_fg_color(index, UIPalette.TEXT_DIM)
		if category == _selected_category:
			_slot_list.select(index)

	_owned_title.text = "OWNED %s PARTS" % HardwareCategory.get_display_name(_selected_category).to_upper()
	_owned_in_slot = HardwareManager.get_owned_items(_selected_category)
	_owned_list.clear()
	for index: int in _owned_in_slot.size():
		var item: HardwareItem = _owned_in_slot[index]
		var is_installed: bool = HardwareManager.is_installed(item.id)
		_owned_list.add_item("T%d  %s%s" % [item.tier, item.title, "   [installed]" if is_installed else ""])
		if is_installed:
			_owned_list.set_item_custom_fg_color(index, UIPalette.ACCENT)
		if item.id == _selected_owned_id:
			_owned_list.select(index)
	_refresh_owned_details()


func _refresh_totals() -> void:
	var stats: Dictionary = HardwareManager.get_stat_totals()
	var effects: Dictionary = HardwareManager.get_effects_summary()
	_totals.clear()
	_totals.push_table(4)
	# Each row: a stat total and the bonus it currently gives.
	var rows: Array = [
		[HardwareItem.STAT_SPEED, GameEffects.CONTRACT_TIME],
		[HardwareItem.STAT_CAPACITY, GameEffects.BOARD_SIZE],
		[HardwareItem.STAT_NETWORK, GameEffects.REFRESH_COOLDOWN],
		[HardwareItem.STAT_RESEARCH, GameEffects.RESEARCH_POWER],
	]
	for row: Array in rows:
		_add_cell(HardwareItem.STAT_NAMES[row[0]], UIPalette.TEXT_DIM)
		_add_cell("%d" % roundi(stats[row[0]]), UIPalette.PRIMARY)
		_add_cell("gives", UIPalette.TEXT_DIM)
		var note: String = "  (used by Research, MVP 7)" if row[1] == GameEffects.RESEARCH_POWER else ""
		_add_cell(GameEffects.describe(row[1], effects[row[1]]) + note, UIPalette.ACCENT)
	_totals.pop()


func _refresh_owned_details() -> void:
	var item: HardwareItem = HardwareManager.get_item(_selected_owned_id)
	if item == null:
		_owned_details.text = "Select a part to see it. Buy parts in the Marketplace."
		_install_button.disabled = true
		return
	_owned_details.text = "%s\n%s" % [item.describe_attributes(), item.description]
	_install_button.disabled = HardwareManager.is_installed(item.id)
	_install_button.text = "Installed" if HardwareManager.is_installed(item.id) else "Install"


func _add_cell(text: String, color: Color) -> void:
	_totals.push_cell()
	_totals.set_cell_padding(CELL_PADDING)
	_totals.push_color(color)
	_totals.add_text(text)
	_totals.pop()
	_totals.pop()
