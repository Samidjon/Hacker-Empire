class_name InteractionDetector
extends Area2D
## Finds the nearest Interactable in reach of its owner and tracks it as the
## current target.

signal target_changed(target: Interactable)

var _candidates: Array[Interactable] = []
var _target: Interactable = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
	_update_target()


func get_target() -> Interactable:
	return _target


## Forgets everything in reach (the room is about to change).
func clear() -> void:
	_candidates.clear()
	if _target != null:
		if is_instance_valid(_target):
			_target.set_focused(false)
		_target = null
		target_changed.emit(null)


func try_interact(interactor: Node) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	return _target.interact(interactor)


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable != null:
		_candidates.erase(interactable)


func _update_target() -> void:
	var nearest: Interactable = null
	var nearest_distance: float = INF
	for candidate: Interactable in _candidates:
		if not is_instance_valid(candidate) or not candidate.enabled:
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	if nearest == _target:
		return
	if _target != null and is_instance_valid(_target):
		_target.set_focused(false)
	_target = nearest
	if _target != null:
		_target.set_focused(true)
	target_changed.emit(_target)
