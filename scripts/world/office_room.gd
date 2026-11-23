class_name OfficeRoom
extends HackerRoom
## The company office. Unlike the apartment it is built from data: its size
## and number of desks follow the current office tier, and every employee
## sits at a desk where the player can walk up and talk to them.

const INTERACTABLE_SCENE: PackedScene = preload("res://scenes/interaction/Interactable.tscn")
const PLAYER_VISUAL_SCRIPT: GDScript = preload("res://scripts/player/player_visual.gd")
## Desks, chairs and people created by this script (rebuilt when staff change).
const STAFF_GROUP: StringName = &"office_staff"

## Floor size in tiles for offices up to a number of desks.
const ROOM_SIZES: Array[Vector2i] = [Vector2i(2, 8), Vector2i(4, 9), Vector2i(8, 11), Vector2i(14, 13)]
const LARGEST_ROOM_SIZE: int = 16
const FIRST_DESK: Vector2 = Vector2(2.4, 3.3)
const DESK_SPACING: Vector2 = Vector2(2.4, 2.3)
const DESK_SIZE: Vector2 = Vector2(1.4, 0.6)
const DESK_HEIGHT: float = 0.55
const MAX_SIGN_LENGTH: int = 12
const NAME_FONT_SIZE: int = 13
const ROLE_COLORS: Array[Color] = [
	Color("00E5FF"), Color("00FF9C"), Color("FFB020"), Color("FF4560"), Color("E5E7EB"), Color("A855F7"),
]

var _room_tiles: int = 8


func _enter_tree() -> void:
	# The shell reads its size when it becomes ready, so it is set up first.
	var office: OfficeDefinition = OrganizationManager.get_office()
	var capacity: int = office.capacity if office != null else 2
	_room_tiles = LARGEST_ROOM_SIZE
	for entry: Vector2i in ROOM_SIZES:
		if capacity <= entry.x:
			_room_tiles = entry.y
			break
	var shell := get_node("Shell") as RoomShell
	shell.room_size = Vector2i(_room_tiles, _room_tiles)
	shell.rug_rect = Rect2()
	shell.window_span = Vector2(_room_tiles - 3.4, _room_tiles - 1.0)
	shell.sign_span = Vector2(_room_tiles * 0.5 - 1.6, _room_tiles * 0.5 + 1.6)
	var company: String = OrganizationManager.company_name.to_upper()
	shell.sign_text = company if company.length() <= MAX_SIGN_LENGTH and not company.is_empty() else "OFFICE"
	(get_node("Props/Computer") as IsoNode).grid_position = Vector2(_room_tiles - 3.0, 0.5)
	spawn_grid_position = Vector2(1.0, 1.4)


func _ready() -> void:
	_rebuild_staff()
	EmployeeManager.employees_changed.connect(_rebuild_staff)


func get_desk_count() -> int:
	return get_tree().get_nodes_in_group(STAFF_GROUP).filter(func(node: Node) -> bool: return is_ancestor_of(node)).size()


## Names shown above the occupied desks, in desk order.
func get_staff_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for node: Node in _props.get_children():
		if node.is_in_group(STAFF_GROUP) and node.has_meta(&"employee_name"):
			names.append(node.get_meta(&"employee_name"))
	return names


## Floor position (local pixels) in front of the desk at `index`.
func get_desk_approach_position(index: int) -> Vector2:
	return IsoUtils.grid_to_screen(_desk_grid(index) + Vector2(0.0, 1.0))


# --- Internals --------------------------------------------------------------

func _rebuild_staff() -> void:
	for node: Node in _props.get_children():
		if node.is_in_group(STAFF_GROUP):
			_props.remove_child(node)
			node.queue_free()
	var office: OfficeDefinition = OrganizationManager.get_office()
	var staff: Array[Employee] = EmployeeManager.get_employees()
	var capacity: int = office.capacity if office != null else 0
	for index: int in capacity:
		_props.add_child(_build_desk(index, staff[index] if index < staff.size() else null))
	_props.refresh()


func _desk_grid(index: int) -> Vector2:
	var columns: int = maxi(1, floori((_room_tiles - 2.6) / DESK_SPACING.x))
	@warning_ignore("integer_division")
	return FIRST_DESK + Vector2((index % columns) * DESK_SPACING.x, (index / columns) * DESK_SPACING.y)


## One workplace: chair, desk, screen and - when someone sits there - the
## person, their name and a way to talk to them.
func _build_desk(index: int, employee: Employee) -> IsoNode:
	var workplace := IsoNode.new()
	workplace.name = "Desk%d" % (index + 1)
	workplace.grid_position = _desk_grid(index)
	workplace.footprint_size = Vector2(DESK_SIZE.x, 1.3)
	workplace.add_to_group(STAFF_GROUP)

	var chair := IsoBlock.new()
	chair.grid_position = Vector2(0.0, -0.45)
	chair.footprint_size = Vector2(0.5, 0.45)
	chair.height = 0.3
	chair.base_color = Color(0.13, 0.1, 0.22)
	chair.edge_color = Color(UIPalette.SECONDARY, 0.7)
	workplace.add_child(chair)

	if employee != null:
		var role_index: int = maxi(0, EmployeeManager.get_roles().find(EmployeeManager.get_role(employee.role_id)))
		var person := Node2D.new()
		person.set_script(PLAYER_VISUAL_SCRIPT)
		person.set(&"hoodie_color", ROLE_COLORS[role_index % ROLE_COLORS.size()])
		person.position = IsoUtils.grid_to_screen(Vector2(0.0, -0.45), 0.25)
		workplace.add_child(person)

	var desk := IsoBlock.new()
	desk.grid_position = Vector2(0.0, 0.15)
	desk.footprint_size = DESK_SIZE
	desk.height = DESK_HEIGHT
	desk.base_color = Color(0.1, 0.14, 0.23)
	desk.edge_color = Color(UIPalette.PRIMARY, 0.8 if employee != null else 0.25)
	workplace.add_child(desk)

	var screen := IsoBlock.new()
	screen.grid_position = Vector2(0.0, 0.05)
	screen.footprint_size = Vector2(0.7, 0.08)
	screen.height = 0.4
	screen.elevation = DESK_HEIGHT
	screen.base_color = Color(0.04, 0.06, 0.1)
	screen.solid = false
	# The screen faces the person, so from the room only its dark back shows;
	# a lit edge tells an occupied desk from an empty one.
	screen.edge_color = Color(UIPalette.ACCENT, 0.9) if employee != null else Color(UIPalette.TEXT_DIM, 0.3)
	workplace.add_child(screen)

	if employee == null:
		return workplace

	workplace.set_meta(&"employee_name", employee.display_name)
	var name_label := Label.new()
	name_label.text = employee.display_name
	name_label.add_theme_font_size_override(&"font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override(&"font_color", UIPalette.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(180.0, 20.0)
	name_label.position = IsoUtils.grid_to_screen(Vector2(0.0, -0.45), 1.45) - Vector2(90.0, 10.0)
	workplace.add_child(name_label)

	var talk: Interactable = INTERACTABLE_SCENE.instantiate()
	talk.kind = Interactable.Kind.INSPECT
	talk.prompt_text = "Talk to %s" % employee.display_name
	talk.message = _describe(employee)
	talk.grid_position = Vector2(0.0, 1.0)
	talk.marker_elevation = 1.75
	talk.marker_color = UIPalette.PRIMARY
	workplace.add_child(talk)
	return workplace


## What an employee says about themselves when the player walks up.
func _describe(employee: Employee) -> String:
	var role: EmployeeRole = EmployeeManager.get_role(employee.role_id)
	var assignment: EmployeeAssignment = EmployeeManager.get_assignment(employee.assignment_id)
	var mood: String = "doing fine"
	if employee.morale <= 25.0:
		mood = "thinking about leaving"
	elif employee.energy <= 25.0:
		mood = "exhausted"
	elif employee.morale >= 75.0 and employee.energy >= 60.0:
		mood = "in good spirits"
	return "%s, %s (level %d). On %s, %s. Energy %d, morale %d." % [
		employee.display_name, role.title if role != null else "staff", employee.level,
		assignment.title.to_lower() if assignment != null else "nothing in particular", mood,
		roundi(employee.energy), roundi(employee.morale),
	]
