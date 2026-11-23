class_name NetworkMapView
extends Control
## Draws the network graph and reports which node was clicked.
## Nodes the player has not discovered yet are shown as unknown.

signal node_selected(node_id: String)

const NODE_RADIUS: float = 15.0
const HIT_RADIUS: float = 26.0
const PADDING: Vector2 = Vector2(90.0, 60.0)
const LABEL_FONT_SIZE: int = 14
const UNKNOWN_LABEL: String = "Unknown"
const TYPE_COLORS: Dictionary = {
	"home": Color("00FF9C"),
	"gateway": Color("00E5FF"),
	"community": Color("A855F7"),
	"shop": Color("FFB020"),
	"training": Color("00E5FF"),
	"research": Color("A855F7"),
	"enterprise": Color("FF4560"),
}

var _nodes: Array[NetworkNodeData] = []
var _player_level: int = 1
var _selected_id: String = ""


func _ready() -> void:
	resized.connect(queue_redraw)


func set_nodes(nodes: Array[NetworkNodeData], player_level: int) -> void:
	_nodes = nodes
	_player_level = player_level
	queue_redraw()


func set_selected(node_id: String) -> void:
	_selected_id = node_id
	queue_redraw()


## Where a node is drawn, in this control's local pixels.
func get_node_point(node: NetworkNodeData) -> Vector2:
	return PADDING + node.map_position * (size - PADDING * 2.0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	for node: NetworkNodeData in _nodes:
		if get_node_point(node).distance_to(button.position) <= HIT_RADIUS:
			node_selected.emit(node.id)
			accept_event()
			return


func _draw() -> void:
	var by_id: Dictionary = {}
	for node: NetworkNodeData in _nodes:
		by_id[node.id] = node

	for node: NetworkNodeData in _nodes:
		for link: String in node.links:
			var other: NetworkNodeData = by_id.get(link)
			if other == null:
				continue
			var both_known: bool = node.is_discovered(_player_level) and other.is_discovered(_player_level)
			draw_line(
				get_node_point(node), get_node_point(other),
				Color(UIPalette.PRIMARY, 0.55) if both_known else Color(UIPalette.TEXT_DIM, 0.18),
				2.0 if both_known else 1.0, true
			)

	var font: Font = ThemeDB.fallback_font
	for node: NetworkNodeData in _nodes:
		var point: Vector2 = get_node_point(node)
		var is_known: bool = node.is_discovered(_player_level)
		var color: Color = TYPE_COLORS.get(node.type, UIPalette.PRIMARY) if is_known else UIPalette.TEXT_DIM
		if node.id == _selected_id:
			draw_arc(point, NODE_RADIUS + 8.0, 0.0, TAU, 40, UIPalette.TEXT, 2.0, true)
		draw_circle(point, NODE_RADIUS + 6.0, Color(color, 0.15 if is_known else 0.06))
		draw_circle(point, NODE_RADIUS, Color(UIPalette.BACKGROUND, 1.0))
		draw_arc(point, NODE_RADIUS, 0.0, TAU, 32, Color(color, 1.0 if is_known else 0.45), 2.5, true)
		if is_known:
			draw_circle(point, NODE_RADIUS * 0.4, color)
		if font != null:
			var label: String = node.display_name if is_known else UNKNOWN_LABEL
			var label_width: float = 220.0
			draw_string(
				font, point + Vector2(-label_width * 0.5, NODE_RADIUS + 22.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, label_width, LABEL_FONT_SIZE,
				UIPalette.TEXT if is_known else Color(UIPalette.TEXT_DIM, 0.6)
			)
