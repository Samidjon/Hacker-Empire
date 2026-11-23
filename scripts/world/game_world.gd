class_name GameWorld
extends Node2D
## The playable isometric world: the player and the room they are in.
##
## Rooms are separate scenes (the apartment, the company office) and the
## player travels between them through door interactables. The world turns
## what happens into signals and leaves the response (UI, saving) to its
## parent, so it has no UI dependencies.

signal interaction_prompt_changed(prompt_text: String)
signal computer_requested
signal rest_requested
signal message_requested(message: String)
signal storage_requested
signal room_changed(room_id: String)

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const ROOM_APARTMENT: String = "apartment"
const ROOM_OFFICE: String = "office"
const ROOM_SCENES: Dictionary = {
	ROOM_APARTMENT: "res://scenes/world/HackerRoom.tscn",
	ROOM_OFFICE: "res://scenes/world/OfficeRoom.tscn",
}
const NO_OFFICE_MESSAGE: String = "You have no office to go to yet. A company that has moved out of the home office gets one."

var _player: Player
var _room: HackerRoom
var _room_id: String = ""


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate()
	# A saved room that can no longer be entered falls back to the apartment.
	var start_room: String = PlayerManager.world_room if can_enter(PlayerManager.world_room) else ROOM_APARTMENT
	_enter_room(start_room, true)
	_player.interaction_target_changed.connect(_on_interaction_target_changed)
	_player.interacted.connect(_on_interacted)
	OrganizationManager.office_expanded.connect(_on_office_expanded)


func _physics_process(_delta: float) -> void:
	# Keeps the profile current so any save captures where the player stands.
	# Not while leaving: the session's state has already been cleared then.
	if GameManager.is_in_game():
		PlayerManager.set_world_position(_player.position)


func get_player() -> Player:
	return _player


func get_room() -> HackerRoom:
	return _room


func get_room_id() -> String:
	return _room_id


func set_player_input_enabled(value: bool) -> void:
	_player.input_enabled = value
	# No prompt while the player cannot act on it.
	if value:
		_on_interaction_target_changed(_player.get_interaction_target())
	else:
		interaction_prompt_changed.emit("")


## True when the room exists and the player has somewhere to go.
func can_enter(room_id: String) -> bool:
	if not ROOM_SCENES.has(room_id):
		return false
	if room_id == ROOM_OFFICE:
		return OrganizationManager.has_external_office()
	return true


## Moves the player to another room. They arrive at its entrance.
func travel_to(room_id: String) -> bool:
	if not can_enter(room_id):
		return false
	_enter_room(room_id, false)
	room_changed.emit(room_id)
	return true


# --- Internals --------------------------------------------------------------

func _enter_room(room_id: String, use_saved_position: bool) -> void:
	if _room != null:
		_player.clear_interaction_targets()
		_player.get_parent().remove_child(_player)
		remove_child(_room)
		_room.queue_free()
	var scene := load(ROOM_SCENES[room_id]) as PackedScene
	_room = scene.instantiate() as HackerRoom
	add_child(_room)
	_room_id = room_id
	# Actors live among the furniture so they are depth-sorted with it.
	_room.get_actor_parent().add_child(_player)

	var start: Vector2 = _room.get_spawn_position()
	if use_saved_position and PlayerManager.has_world_position:
		if _room.is_position_walkable(PlayerManager.world_position):
			start = PlayerManager.world_position
	_player.teleport(start)
	_room.get_actor_parent().refresh()
	if GameManager.is_in_game():
		PlayerManager.world_room = room_id
		PlayerManager.set_world_position(start)
	interaction_prompt_changed.emit("")


func _on_interaction_target_changed(target: Interactable) -> void:
	if not _player.input_enabled:
		return
	interaction_prompt_changed.emit(target.prompt_text if target != null else "")


func _on_interacted(interactable: Interactable) -> void:
	match interactable.kind:
		Interactable.Kind.COMPUTER:
			computer_requested.emit()
		Interactable.Kind.REST:
			rest_requested.emit()
		Interactable.Kind.INSPECT:
			message_requested.emit(interactable.message)
		Interactable.Kind.STORAGE:
			storage_requested.emit()
		Interactable.Kind.TRAVEL:
			if not travel_to(interactable.travel_target):
				message_requested.emit(NO_OFFICE_MESSAGE)


## A bigger office is a different room: rebuild it around the player.
func _on_office_expanded(_office_id: String) -> void:
	if _room_id == ROOM_OFFICE:
		_enter_room(ROOM_OFFICE, false)
		room_changed.emit(ROOM_OFFICE)
