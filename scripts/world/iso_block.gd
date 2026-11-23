@tool
class_name IsoBlock
extends IsoNode
## Placeholder furniture: a neon-edged isometric box drawn in code.
##
## To use real art later, replace an IsoBlock node with a Sprite2D under an
## IsoNode of the same footprint; nothing else depends on how it is drawn.

enum ScreenFace { NONE, FACING_Y, FACING_X }

@export_range(0.0, 10.0, 0.01) var height: float = 1.0:
	set(value):
		height = value
		queue_redraw()
## Height of the block's underside above the floor (e.g. a monitor on a desk).
@export_range(0.0, 10.0, 0.01) var elevation: float = 0.0:
	set(value):
		elevation = value
		queue_redraw()
@export var base_color: Color = Color(0.09, 0.13, 0.21):
	set(value):
		base_color = value
		queue_redraw()
@export var edge_color: Color = Color(0.0, 0.898, 1.0, 0.8):
	set(value):
		edge_color = value
		queue_redraw()
@export_range(0.0, 6.0, 0.5) var edge_width: float = 2.0
## Blocks the player. The collider is the floor footprint.
@export var solid: bool = true
## Draws a glowing panel on one visible side (monitor screens, lamps).
@export var screen_face: ScreenFace = ScreenFace.NONE:
	set(value):
		screen_face = value
		queue_redraw()
@export var screen_color: Color = Color(0.0, 1.0, 0.612, 0.9):
	set(value):
		screen_color = value
		queue_redraw()

const TOP_LIGHTEN: float = 0.18
const SIDE_DARKEN: float = 0.3
const SCREEN_INSET: float = 0.12


func _ready() -> void:
	super()
	if solid and not Engine.is_editor_hint():
		_create_collider()


func _draw() -> void:
	var half: Vector2 = footprint_size * 0.5
	# Footprint corners: back, right, front, left (as seen on screen).
	var corners: Array[Vector2] = [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	]
	var bottom: PackedVector2Array = []
	var top: PackedVector2Array = []
	for corner: Vector2 in corners:
		bottom.append(IsoUtils.grid_to_screen(corner, elevation))
		top.append(IsoUtils.grid_to_screen(corner, elevation + height))

	var face_y: PackedVector2Array = [top[3], top[2], bottom[2], bottom[3]]
	var face_x: PackedVector2Array = [top[2], top[1], bottom[1], bottom[2]]
	draw_colored_polygon(face_y, base_color)
	draw_colored_polygon(face_x, base_color.darkened(SIDE_DARKEN))
	draw_colored_polygon(top, base_color.lightened(TOP_LIGHTEN))

	if screen_face == ScreenFace.FACING_Y:
		draw_colored_polygon(_inset_quad(face_y), screen_color)
	elif screen_face == ScreenFace.FACING_X:
		draw_colored_polygon(_inset_quad(face_x), screen_color)

	if edge_width > 0.0:
		var outline: PackedVector2Array = top.duplicate()
		outline.append(top[0])
		draw_polyline(outline, edge_color, edge_width, true)
		var side_color: Color = Color(edge_color, edge_color.a * 0.45)
		for index: int in [1, 2, 3]:
			draw_line(top[index], bottom[index], side_color, edge_width, true)


## Shrinks a quad (top-left, top-right, bottom-right, bottom-left) toward its centre.
func _inset_quad(quad: PackedVector2Array) -> PackedVector2Array:
	var center: Vector2 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
	var result: PackedVector2Array = []
	for point: Vector2 in quad:
		result.append(point.lerp(center, SCREEN_INSET * 2.0))
	return result


func _create_collider() -> void:
	var half: Vector2 = footprint_size * 0.5
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		IsoUtils.grid_to_screen(Vector2(-half.x, -half.y)),
		IsoUtils.grid_to_screen(Vector2(half.x, -half.y)),
		IsoUtils.grid_to_screen(Vector2(half.x, half.y)),
		IsoUtils.grid_to_screen(Vector2(-half.x, half.y)),
	])
	var body := StaticBody2D.new()
	body.name = "Collider"
	body.add_child(polygon)
	add_child(body)
