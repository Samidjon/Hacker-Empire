class_name AppDefinition
extends RefCounted
## One entry of the desktop's application list (data/desktop/apps.json).

const DEFAULT_SIZE: Vector2 = Vector2(900.0, 600.0)

var id: String = ""
var title: String = ""
## Short text icon shown on the launcher, e.g. ">_".
var glyph: String = ""
## Scene instanced inside the window. Empty when the app is not installed.
var scene_path: String = ""
var default_size: Vector2 = DEFAULT_SIZE
## Closing hides the window instead of destroying it, so the app keeps its
## state (terminal scrollback, current folder) for the rest of the session.
var keep_state: bool = false
## Only listed in debug builds.
var debug_only: bool = false
## Explanation shown on the launcher when the app cannot be opened.
var locked_note: String = ""


## True when the app has a scene that exists and can be opened.
func is_available() -> bool:
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


static func from_dictionary(data: Dictionary) -> AppDefinition:
	var definition := AppDefinition.new()
	definition.id = SaveDataReader.get_string(data, "id")
	definition.title = SaveDataReader.get_string(data, "title", definition.id.capitalize())
	definition.glyph = SaveDataReader.get_string(data, "glyph", "[ ]")
	definition.scene_path = SaveDataReader.get_string(data, "scene")
	definition.keep_state = data.get("keep_state") == true
	definition.debug_only = data.get("debug_only") == true
	definition.locked_note = SaveDataReader.get_string(data, "locked_note", "Not installed.")
	var size_values: Array = SaveDataReader.get_array(data, "size")
	if size_values.size() == 2 and (size_values[0] is float or size_values[0] is int) \
			and (size_values[1] is float or size_values[1] is int):
		definition.default_size = Vector2(float(size_values[0]), float(size_values[1]))
	return definition
