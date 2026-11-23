extends Node
## PlayerManager (autoload)
##
## Owns the player's identity and profile-level state. Money, XP and
## reputation live in their own managers.

signal profile_changed

const CONFIG: PlayerConfig = preload("res://resources/configurations/player_config.tres")
const SAVE_SECTION: String = "player"
const DEFAULT_ROOM: String = "apartment"

var hacker_alias: String = ""
var player_id: String = ""
var created_at_unix: int = 0
var playtime_seconds: float = 0.0
## Where the character stands in the world (room-local pixels). Only
## meaningful when has_world_position is true.
var world_position: Vector2 = Vector2.ZERO
var has_world_position: bool = false
## Id of the room the character is in (see GameWorld.ROOM_SCENES).
var world_room: String = DEFAULT_ROOM


func _ready() -> void:
	reset_to_defaults()
	SaveManager.register_section(SAVE_SECTION, self)


## Returns an error message for the player, or an empty string when valid.
func validate_alias(candidate: String) -> String:
	var trimmed: String = candidate.strip_edges()
	if trimmed.length() < CONFIG.min_alias_length:
		return "Alias must be at least %d characters." % CONFIG.min_alias_length
	if trimmed.length() > CONFIG.max_alias_length:
		return "Alias must be at most %d characters." % CONFIG.max_alias_length
	for index: int in trimmed.length():
		var code: int = trimmed.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_upper: bool = code >= 65 and code <= 90
		var is_lower: bool = code >= 97 and code <= 122
		var is_separator: bool = code == 95 or code == 45 # _ and -
		if not (is_digit or is_upper or is_lower or is_separator):
			return "Alias may only contain letters, numbers, '_' and '-'."
	return ""


func create_new_player(new_alias: String) -> void:
	hacker_alias = new_alias.strip_edges()
	player_id = _generate_player_id()
	created_at_unix = int(Time.get_unix_time_from_system())
	playtime_seconds = 0.0
	has_world_position = false
	world_room = DEFAULT_ROOM
	profile_changed.emit()


func add_playtime(seconds: float) -> void:
	if seconds > 0.0:
		playtime_seconds += seconds


func set_world_position(new_position: Vector2) -> void:
	if new_position.is_finite():
		world_position = new_position
		has_world_position = true


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"alias": hacker_alias,
		"player_id": player_id,
		"created_at": created_at_unix,
		"playtime_seconds": playtime_seconds,
	}
	if has_world_position:
		data["world_position"] = {"x": world_position.x, "y": world_position.y}
		data["world_room"] = world_room
	return data


func load_save_data(data: Dictionary) -> void:
	var loaded_alias: String = SaveDataReader.get_string(data, "alias", CONFIG.default_alias)
	hacker_alias = loaded_alias if validate_alias(loaded_alias).is_empty() else CONFIG.default_alias
	player_id = SaveDataReader.get_string(data, "player_id")
	if player_id.is_empty():
		player_id = _generate_player_id()
	created_at_unix = maxi(0, SaveDataReader.get_int(data, "created_at"))
	playtime_seconds = maxf(0.0, SaveDataReader.get_float(data, "playtime_seconds"))

	# Optional: saves from before the world existed have no position. The
	# world still checks that the spot is walkable before using it.
	var saved_position: Dictionary = SaveDataReader.get_dictionary(data, "world_position")
	var has_both_axes: bool = (
		_is_number(saved_position.get("x")) and _is_number(saved_position.get("y"))
	)
	has_world_position = has_both_axes
	world_position = Vector2(
		SaveDataReader.get_float(saved_position, "x"), SaveDataReader.get_float(saved_position, "y")
	) if has_both_axes else Vector2.ZERO
	# The world checks that the room can still be entered before using it.
	world_room = SaveDataReader.get_string(data, "world_room", DEFAULT_ROOM)
	profile_changed.emit()


func reset_to_defaults() -> void:
	hacker_alias = CONFIG.default_alias
	player_id = ""
	created_at_unix = 0
	playtime_seconds = 0.0
	world_position = Vector2.ZERO
	has_world_position = false
	world_room = DEFAULT_ROOM
	profile_changed.emit()


func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


func _generate_player_id() -> String:
	return "%08x%08x" % [randi(), randi()]
