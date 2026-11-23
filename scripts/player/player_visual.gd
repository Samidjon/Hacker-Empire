class_name PlayerVisual
extends Node2D
## Placeholder character art drawn in code: a hooded figure with a neon visor.
## Replace this node with an AnimatedSprite2D exposing set_motion() to use
## real art; Player depends on nothing else here.

const MOVING_THRESHOLD: float = 5.0
const BOB_SPEED: float = 11.0
const BOB_PIXELS: float = 3.0
const BODY_WIDTH: float = 26.0
const BODY_HEIGHT: float = 38.0
const HEAD_RADIUS: float = 11.0

@export var hoodie_color: Color = Color(0.659, 0.333, 0.969)
@export var trim_color: Color = Color(0.0, 0.898, 1.0)
@export var skin_color: Color = Color(0.11, 0.13, 0.2)

var _is_moving: bool = false
var _facing: float = 1.0 # 1 = right, -1 = left
var _walk_time: float = 0.0


func set_motion(motion: Vector2) -> void:
	_is_moving = motion.length() > MOVING_THRESHOLD
	if absf(motion.x) > MOVING_THRESHOLD:
		_facing = signf(motion.x)


func _process(delta: float) -> void:
	if _is_moving:
		_walk_time += delta
	queue_redraw()


func _draw() -> void:
	var bob: float = absf(sin(_walk_time * BOB_SPEED)) * BOB_PIXELS if _is_moving else 0.0

	# Ground shadow (a circle squashed to the floor plane).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(Vector2.ZERO, 22.0, Color(trim_color, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var half_width: float = BODY_WIDTH * 0.5
	var feet: float = -2.0 - bob
	var shoulders: float = feet - BODY_HEIGHT
	var body: PackedVector2Array = [
		Vector2(-half_width * 0.7, feet), Vector2(half_width * 0.7, feet),
		Vector2(half_width, feet - BODY_HEIGHT * 0.55), Vector2(half_width * 0.8, shoulders),
		Vector2(-half_width * 0.8, shoulders), Vector2(-half_width, feet - BODY_HEIGHT * 0.55),
	]
	draw_colored_polygon(body, hoodie_color.darkened(0.35))
	var outline: PackedVector2Array = body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, hoodie_color, 2.0, true)
	# Zip line.
	draw_line(
		Vector2(0.0, shoulders + 4.0), Vector2(0.0, feet - 6.0), Color(trim_color, 0.6), 1.5, true
	)

	# Hooded head with a visor facing the walking direction.
	var head_center: Vector2 = Vector2(0.0, shoulders - HEAD_RADIUS + 3.0)
	draw_circle(head_center, HEAD_RADIUS + 2.0, hoodie_color.darkened(0.2))
	draw_circle(head_center + Vector2(_facing * 2.0, 1.0), HEAD_RADIUS - 2.0, skin_color)
	var visor_start: Vector2 = head_center + Vector2(_facing * -3.0, 0.0)
	var visor_end: Vector2 = head_center + Vector2(_facing * 9.0, 0.0)
	draw_line(visor_start, visor_end, Color(trim_color, 0.3), 7.0, true)
	draw_line(visor_start, visor_end, trim_color, 3.0, true)
