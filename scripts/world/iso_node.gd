@tool
class_name IsoNode
extends Node2D
## A node placed by grid coordinates instead of pixels.
##
## `grid_position` is the centre of the footprint, relative to the parent.
## IsoDepthSorter uses the footprint to decide what is drawn in front.

@export var grid_position: Vector2 = Vector2.ZERO:
	set(value):
		grid_position = value
		_apply_grid_position()

## Floor area covered, in tiles (x, y).
@export var footprint_size: Vector2 = Vector2.ONE:
	set(value):
		footprint_size = value
		queue_redraw()


func _ready() -> void:
	_apply_grid_position()


func get_grid_bounds() -> Rect2:
	return Rect2(grid_position - footprint_size * 0.5, footprint_size)


func _apply_grid_position() -> void:
	position = IsoUtils.grid_to_screen(grid_position)
