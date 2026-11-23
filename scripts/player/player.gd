class_name Player
extends CharacterBody2D
## The player's character in the isometric world: movement and triggering
## interactions. Appearance lives in PlayerVisual, profile data in PlayerManager.

signal interaction_target_changed(target: Interactable)
## Emitted after the player has used something.
signal interacted(target: Interactable)

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_INTERACT: StringName = &"interact"

## Horizontal speed in pixels per second.
@export_range(50.0, 800.0, 10.0) var move_speed: float = 250.0
## Vertical speed relative to horizontal, matching the 2:1 projection so
## diagonal input follows the floor grid.
@export_range(0.1, 1.0, 0.05) var vertical_speed_ratio: float = 0.5

## When false the character ignores movement and interaction input
## (e.g. while sitting at the computer).
var input_enabled: bool = true

@onready var _visual: PlayerVisual = %Visual
@onready var _detector: InteractionDetector = %InteractionDetector
@onready var _camera: Camera2D = %Camera


func _ready() -> void:
	add_to_group(IsoDepthSorter.ACTOR_GROUP)
	_detector.target_changed.connect(
		func(target: Interactable) -> void: interaction_target_changed.emit(target)
	)


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	if input_enabled:
		direction = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	velocity = Vector2(direction.x, direction.y * vertical_speed_ratio) * move_speed
	move_and_slide()
	_visual.set_motion(get_real_velocity())


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed(ACTION_INTERACT):
		var target: Interactable = _detector.get_target()
		if _detector.try_interact(self):
			get_viewport().set_input_as_handled()
			interacted.emit(target)


func get_interaction_target() -> Interactable:
	return _detector.get_target()


## Call before the room around the player is replaced.
func clear_interaction_targets() -> void:
	_detector.clear()


## Moves instantly without the camera gliding across the room.
func teleport(new_position: Vector2) -> void:
	position = new_position
	velocity = Vector2.ZERO
	_camera.reset_smoothing()
