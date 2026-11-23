extends HBoxContainer
## Network Map application: the known grid and details of the selected node.
## New nodes are discovered as the player levels up.

var _nodes: Array[NetworkNodeData] = []
var _selected_id: String = ""

@onready var _view: NetworkMapView = %MapView
@onready var _summary_label: Label = %MapSummaryLabel
@onready var _name_label: Label = %NodeNameLabel
@onready var _status_label: Label = %NodeStatusLabel
@onready var _description_label: Label = %NodeDescriptionLabel


func _ready() -> void:
	_nodes = NetworkNodeData.load_all()
	_view.node_selected.connect(select_node)
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _refresh())
	_refresh()


func get_node_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for node: NetworkNodeData in _nodes:
		ids.append(node.id)
	return ids


func get_discovered_count() -> int:
	var count: int = 0
	for node: NetworkNodeData in _nodes:
		if node.is_discovered(ProgressionManager.level):
			count += 1
	return count


func get_selected_id() -> String:
	return _selected_id


func get_details_text() -> String:
	return "%s\n%s\n%s" % [_name_label.text, _status_label.text, _description_label.text]


func select_node(node_id: String) -> void:
	_selected_id = node_id
	_view.set_selected(node_id)
	_refresh_details()


func _refresh() -> void:
	_view.set_nodes(_nodes, ProgressionManager.level)
	_summary_label.text = "%d of %d nodes discovered" % [get_discovered_count(), _nodes.size()]
	_refresh_details()


func _refresh_details() -> void:
	var node: NetworkNodeData = null
	for candidate: NetworkNodeData in _nodes:
		if candidate.id == _selected_id:
			node = candidate
	if node == null:
		_name_label.text = "No node selected"
		_status_label.text = ""
		_description_label.text = "Click a node on the map."
		return
	if node.is_discovered(ProgressionManager.level):
		_name_label.text = node.display_name
		_status_label.text = "%s  -  %d link(s)" % [node.type.to_upper(), node.links.size()]
		_status_label.add_theme_color_override(&"font_color", UIPalette.ACCENT)
		_description_label.text = node.description
	else:
		_name_label.text = NetworkMapView.UNKNOWN_LABEL
		_status_label.text = "UNDISCOVERED"
		_status_label.add_theme_color_override(&"font_color", UIPalette.WARNING)
		_description_label.text = "You will learn about this node at level %d." % node.required_level
