class_name IsoDepthSorter
extends Node2D
## Draw-order manager for an isometric room.
##
## Plain Y-sorting breaks for long furniture, so this node assigns z_index
## itself. Its IsoNode children ("props") are ordered back to front once;
## each frame every actor (group ACTOR_GROUP) is slotted just behind the
## first prop it is standing behind.

const ACTOR_GROUP: StringName = &"iso_actor"
## Tolerance so an actor touching a prop's front edge counts as in front.
const EDGE_TOLERANCE: float = 0.05

var _props: Array[IsoNode] = []
var _props_dirty: bool = true


func _ready() -> void:
	child_order_changed.connect(func() -> void: _props_dirty = true)


func _process(_delta: float) -> void:
	if _props_dirty:
		_rebuild_props()
	for child: Node in get_children():
		if child is Node2D and child.is_in_group(ACTOR_GROUP):
			(child as Node2D).z_index = _actor_z_index(child as Node2D)


## Immediately recomputes all draw orders (used after teleporting an actor).
func refresh() -> void:
	_rebuild_props()
	_process(0.0)


func _rebuild_props() -> void:
	_props.clear()
	for child: Node in get_children():
		if child is IsoNode and not child.is_in_group(ACTOR_GROUP):
			_props.append(child as IsoNode)
	# Props nearer the back corner are drawn first.
	_props.sort_custom(func(a: IsoNode, b: IsoNode) -> bool:
		var bounds_a: Rect2 = a.get_grid_bounds()
		var bounds_b: Rect2 = b.get_grid_bounds()
		return bounds_a.position.x + bounds_a.position.y < bounds_b.position.x + bounds_b.position.y
	)
	# Even slots for props, odd slots between them for actors.
	for index: int in _props.size():
		_props[index].z_index = (index + 1) * 2
	_props_dirty = false


func _actor_z_index(actor: Node2D) -> int:
	# An actor is behind a prop when it has passed neither of the prop's two
	# front edges. It must be drawn before the first such prop, so it takes
	# the slot just below it; with none, it is in front of everything.
	var grid: Vector2 = IsoUtils.screen_to_grid(actor.position)
	for index: int in _props.size():
		var bounds: Rect2 = _props[index].get_grid_bounds()
		var is_behind: bool = (
			grid.x < bounds.end.x - EDGE_TOLERANCE and grid.y < bounds.end.y - EDGE_TOLERANCE
		)
		if is_behind:
			return (index + 1) * 2 - 1
	return _props.size() * 2 + 1
