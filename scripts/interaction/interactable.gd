class_name Interactable
extends Area2D
## Something the player can walk up to and use.
##
## It only announces that it was used; what happens is decided by whoever
## listens (GameWorld), based on `kind`. A floating neon marker shows where
## it is and brightens while it is the player's current target.

signal interacted(interactable: Interactable, interactor: Node)
signal focus_changed(is_focused: bool)

enum Kind {
	COMPUTER, ## Opens the workstation.
	REST,     ## Rest and save the game.
	INSPECT,  ## Shows `message`.
	STORAGE,  ## Shows what is kept in storage.
	TRAVEL,   ## A door: moves the player to `travel_target`.
}

const GROUP: StringName = &"interactable"
const MARKER_SIZE: float = 9.0
const MARKER_BOB_PIXELS: float = 5.0
const MARKER_BOB_SPEED: float = 2.4

@export var kind: Kind = Kind.INSPECT
## Shown in the prompt after the key, e.g. "Use Computer".
@export var prompt_text: String = "Inspect"
@export_multiline var message: String = ""
## Room id for Kind.TRAVEL (see GameWorld.ROOM_SCENES).
@export var travel_target: String = ""
@export var enabled: bool = true
@export_group("Placement")
## Floor position in grid units, relative to the parent.
@export var grid_position: Vector2 = Vector2.ZERO
@export var use_grid_position: bool = true
## Height of the floating marker above the floor.
@export_range(0.0, 5.0, 0.05) var marker_elevation: float = 1.3
@export var marker_color: Color = Color(0.0, 1.0, 0.612)

var _is_focused: bool = false
var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if use_grid_position:
		position = IsoUtils.grid_to_screen(grid_position)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var bob: float = sin(_time * MARKER_BOB_SPEED) * MARKER_BOB_PIXELS
	var center: Vector2 = Vector2(0.0, -marker_elevation * IsoUtils.HEIGHT_UNIT + bob)
	var marker_size: float = MARKER_SIZE * (1.35 if _is_focused else 1.0)
	var diamond: PackedVector2Array = [
		center + Vector2(0.0, -marker_size), center + Vector2(marker_size * 0.7, 0.0),
		center + Vector2(0.0, marker_size), center + Vector2(-marker_size * 0.7, 0.0),
	]
	var alpha: float = 1.0 if _is_focused else 0.45
	draw_circle(center, marker_size * 1.9, Color(marker_color, 0.12 * alpha))
	draw_colored_polygon(diamond, Color(marker_color, alpha))


func interact(interactor: Node) -> bool:
	if not enabled:
		return false
	interacted.emit(self, interactor)
	return true


func set_focused(value: bool) -> void:
	if _is_focused == value:
		return
	_is_focused = value
	focus_changed.emit(_is_focused)


func is_focused() -> bool:
	return _is_focused
