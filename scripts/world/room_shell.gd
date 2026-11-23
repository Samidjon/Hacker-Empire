@tool
class_name RoomShell
extends Node2D
## Placeholder room architecture drawn in code: floor, two back walls, a
## window with a city view, neon trim and a neon sign. Also builds the wall
## colliders that keep actors on the floor.
##
## The room occupies grid (0,0)..room_size. The walls stand on the x = 0 edge
## (left on screen) and the y = 0 edge (right on screen).

enum Wall { LEFT, RIGHT }

@export var room_size: Vector2i = Vector2i(8, 8):
	set(value):
		room_size = value
		queue_redraw()
@export_range(1.0, 6.0, 0.1) var wall_height: float = 2.6
@export_group("Colours")
@export var floor_color: Color = Color(0.055, 0.075, 0.125)
@export var floor_line_color: Color = Color(0.0, 0.898, 1.0, 0.14)
@export var wall_color: Color = Color(0.067, 0.094, 0.153)
@export var neon_primary: Color = Color(0.0, 0.898, 1.0)
@export var neon_secondary: Color = Color(0.659, 0.333, 0.969)
@export var rug_color: Color = Color(0.659, 0.333, 0.969, 0.16)
@export_group("Decoration")
## Floor area of the rug, in grid units.
@export var rug_rect: Rect2 = Rect2(2.6, 3.0, 3.0, 2.2)
## Window on the right wall: start and end along the wall, in grid units.
@export var window_span: Vector2 = Vector2(4.9, 7.1)
## Window bottom and top elevation.
@export var window_elevation: Vector2 = Vector2(0.9, 2.1)
@export var sign_text: String = "EMPIRE"
## Neon sign on the left wall: start and end along the wall, in grid units.
@export var sign_span: Vector2 = Vector2(3.6, 6.4)
@export var sign_elevation: Vector2 = Vector2(1.45, 2.15)
@export_range(8, 96) var sign_font_size: int = 34

const COLLIDER_THICKNESS: float = 1.0 # grid units outside the floor
const PULSE_SPEED: float = 1.6
const SKYLINE_HEIGHTS: PackedFloat32Array = [0.55, 0.8, 0.4, 0.95, 0.6, 0.3, 0.75, 0.5]

var _time: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		_create_wall_colliders()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()


## True when a floor position (local pixels) lies inside the room, keeping
## `margin` grid units away from the edges.
func contains_point(local_position: Vector2, margin: float = 0.0) -> bool:
	var grid: Vector2 = IsoUtils.screen_to_grid(local_position)
	return (
		grid.x >= margin and grid.y >= margin
		and grid.x <= room_size.x - margin and grid.y <= room_size.y - margin
	)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * PULSE_SPEED)
	_draw_walls()
	_draw_window()
	_draw_floor()
	_draw_neon_trim(pulse)
	_draw_sign(pulse)


func _draw_walls() -> void:
	var left_wall: PackedVector2Array = [
		_wall_point(Wall.LEFT, 0.0, wall_height), _wall_point(Wall.LEFT, room_size.y, wall_height),
		_wall_point(Wall.LEFT, room_size.y, 0.0), _wall_point(Wall.LEFT, 0.0, 0.0),
	]
	var right_wall: PackedVector2Array = [
		_wall_point(Wall.RIGHT, 0.0, wall_height), _wall_point(Wall.RIGHT, room_size.x, wall_height),
		_wall_point(Wall.RIGHT, room_size.x, 0.0), _wall_point(Wall.RIGHT, 0.0, 0.0),
	]
	draw_colored_polygon(left_wall, wall_color)
	draw_colored_polygon(right_wall, wall_color.darkened(0.25))


func _draw_window() -> void:
	var bottom: float = window_elevation.x
	var top: float = window_elevation.y
	var glass: PackedVector2Array = [
		_wall_point(Wall.RIGHT, window_span.x, top), _wall_point(Wall.RIGHT, window_span.y, top),
		_wall_point(Wall.RIGHT, window_span.y, bottom), _wall_point(Wall.RIGHT, window_span.x, bottom),
	]
	# Night sky: purple at the top fading to a cyan horizon glow.
	var sky_top: Color = Color(neon_secondary, 0.55).darkened(0.55)
	var sky_bottom: Color = Color(neon_primary, 0.6).darkened(0.35)
	draw_polygon(glass, PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))

	# Skyline silhouettes with blinking lights.
	var building_count: int = SKYLINE_HEIGHTS.size()
	var building_width: float = (window_span.y - window_span.x) / building_count
	for index: int in building_count:
		var start: float = window_span.x + building_width * index
		var roof: float = bottom + (top - bottom) * SKYLINE_HEIGHTS[index]
		draw_colored_polygon(PackedVector2Array([
			_wall_point(Wall.RIGHT, start, roof), _wall_point(Wall.RIGHT, start + building_width, roof),
			_wall_point(Wall.RIGHT, start + building_width, bottom), _wall_point(Wall.RIGHT, start, bottom),
		]), Color(0.02, 0.03, 0.06, 0.92))
		var blink: float = 0.5 + 0.5 * sin(_time * (0.9 + index * 0.37) + index * 1.7)
		var light_color: Color = neon_primary if index % 2 == 0 else Color(1.0, 0.69, 0.125)
		draw_circle(
			_wall_point(Wall.RIGHT, start + building_width * 0.5, lerpf(bottom, roof, 0.6)),
			2.5, Color(light_color, 0.35 + 0.65 * blink)
		)

	var frame: PackedVector2Array = glass.duplicate()
	frame.append(glass[0])
	draw_polyline(frame, Color(neon_primary, 0.8), 2.5, true)
	var middle: float = (window_span.x + window_span.y) * 0.5
	draw_line(
		_wall_point(Wall.RIGHT, middle, top), _wall_point(Wall.RIGHT, middle, bottom),
		Color(neon_primary, 0.5), 2.0, true
	)


func _draw_floor() -> void:
	var floor_polygon: PackedVector2Array = [
		IsoUtils.grid_to_screen(Vector2.ZERO),
		IsoUtils.grid_to_screen(Vector2(room_size.x, 0.0)),
		IsoUtils.grid_to_screen(Vector2(room_size)),
		IsoUtils.grid_to_screen(Vector2(0.0, room_size.y)),
	]
	draw_colored_polygon(floor_polygon, floor_color)

	if rug_rect.has_area():
		draw_colored_polygon(PackedVector2Array([
			IsoUtils.grid_to_screen(rug_rect.position),
			IsoUtils.grid_to_screen(Vector2(rug_rect.end.x, rug_rect.position.y)),
			IsoUtils.grid_to_screen(rug_rect.end),
			IsoUtils.grid_to_screen(Vector2(rug_rect.position.x, rug_rect.end.y)),
		]), rug_color)

	for column: int in range(0, room_size.x + 1):
		draw_line(
			IsoUtils.grid_to_screen(Vector2(column, 0.0)),
			IsoUtils.grid_to_screen(Vector2(column, room_size.y)),
			floor_line_color, 1.0, true
		)
	for row: int in range(0, room_size.y + 1):
		draw_line(
			IsoUtils.grid_to_screen(Vector2(0.0, row)),
			IsoUtils.grid_to_screen(Vector2(room_size.x, row)),
			floor_line_color, 1.0, true
		)
	# Open front edges of the floor.
	draw_polyline(PackedVector2Array([
		floor_polygon[1], floor_polygon[2], floor_polygon[3],
	]), Color(neon_primary, 0.45), 2.0, true)


func _draw_neon_trim(pulse: float) -> void:
	var top_trim: PackedVector2Array = [
		_wall_point(Wall.LEFT, room_size.y, wall_height),
		_wall_point(Wall.LEFT, 0.0, wall_height),
		_wall_point(Wall.RIGHT, room_size.x, wall_height),
	]
	draw_polyline(top_trim, Color(neon_primary, 0.25 * pulse), 8.0, true) # soft glow
	draw_polyline(top_trim, Color(neon_primary, pulse), 2.5, true)

	var base_trim: PackedVector2Array = [
		_wall_point(Wall.LEFT, room_size.y, 0.0),
		_wall_point(Wall.LEFT, 0.0, 0.0),
		_wall_point(Wall.RIGHT, room_size.x, 0.0),
	]
	draw_polyline(base_trim, Color(neon_secondary, 0.7 * pulse), 2.0, true)
	draw_line(
		_wall_point(Wall.LEFT, 0.0, 0.0), _wall_point(Wall.LEFT, 0.0, wall_height),
		Color(neon_primary, 0.35), 2.0, true
	)


func _draw_sign(pulse: float) -> void:
	if sign_text.is_empty():
		return
	var glow: Color = Color(neon_secondary, pulse)
	var frame: PackedVector2Array = [
		_wall_point(Wall.LEFT, sign_span.y, sign_elevation.y),
		_wall_point(Wall.LEFT, sign_span.x, sign_elevation.y),
		_wall_point(Wall.LEFT, sign_span.x, sign_elevation.x),
		_wall_point(Wall.LEFT, sign_span.y, sign_elevation.x),
		_wall_point(Wall.LEFT, sign_span.y, sign_elevation.y),
	]
	draw_polyline(frame, Color(neon_secondary, 0.25 * pulse), 8.0, true)
	draw_polyline(frame, glow, 2.0, true)

	# Skew the text onto the wall plane. The left wall runs toward the lower
	# left, so text starts at the far end of the span to read left-to-right.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var slope: float = IsoUtils.TILE_HALF_HEIGHT / IsoUtils.TILE_HALF_WIDTH
	var span_pixels: float = (sign_span.y - sign_span.x) * IsoUtils.TILE_HALF_WIDTH
	var baseline_elevation: float = lerpf(sign_elevation.x, sign_elevation.y, 0.28)
	var origin: Vector2 = _wall_point(Wall.LEFT, sign_span.y, baseline_elevation)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, -slope), Vector2(0.0, 1.0), origin))
	draw_string(
		font, Vector2.ZERO, sign_text, HORIZONTAL_ALIGNMENT_CENTER, span_pixels,
		sign_font_size, Color(neon_primary, 0.6 + 0.4 * pulse)
	)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A point on a wall plane: `along` grid units from the back corner, `elevation` up.
func _wall_point(wall: Wall, along: float, elevation: float) -> Vector2:
	var grid: Vector2 = Vector2(0.0, along) if wall == Wall.LEFT else Vector2(along, 0.0)
	return IsoUtils.grid_to_screen(grid, elevation)


# --- Collision --------------------------------------------------------------

func _create_wall_colliders() -> void:
	var body := StaticBody2D.new()
	body.name = "WallColliders"
	var width: float = room_size.x
	var depth: float = room_size.y
	var t: float = COLLIDER_THICKNESS
	# One strip outside each floor edge, overlapping at the corners.
	var strips: Array[Rect2] = [
		Rect2(-t, -t, width + 2.0 * t, t),   # y = 0 edge
		Rect2(-t, depth, width + 2.0 * t, t), # y = depth edge
		Rect2(-t, -t, t, depth + 2.0 * t),   # x = 0 edge
		Rect2(width, -t, t, depth + 2.0 * t), # x = width edge
	]
	for strip: Rect2 in strips:
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = PackedVector2Array([
			IsoUtils.grid_to_screen(strip.position),
			IsoUtils.grid_to_screen(Vector2(strip.end.x, strip.position.y)),
			IsoUtils.grid_to_screen(strip.end),
			IsoUtils.grid_to_screen(Vector2(strip.position.x, strip.end.y)),
		])
		body.add_child(polygon)
	add_child(body)
