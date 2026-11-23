class_name AppRegistry
extends RefCounted
## Loads the desktop's application list from data.

const DEFAULT_DATA_PATH: String = "res://data/desktop/apps.json"


## Definitions in file order. Entries without an id, with a duplicate id, or
## marked debug_only outside a debug build are left out.
static func load_definitions(
	path: String = DEFAULT_DATA_PATH, include_debug: bool = OS.is_debug_build()
) -> Array[AppDefinition]:
	var definitions: Array[AppDefinition] = []
	var seen_ids: Dictionary = {}
	for entry: Dictionary in JsonDataLoader.load_entries(path, "apps"):
		var definition: AppDefinition = AppDefinition.from_dictionary(entry)
		if definition.id.is_empty():
			push_warning("AppRegistry: skipped an app without an id in %s." % path)
			continue
		if seen_ids.has(definition.id):
			push_warning("AppRegistry: duplicate app id '%s' in %s." % [definition.id, path])
			continue
		if definition.debug_only and not include_debug:
			continue
		if not definition.scene_path.is_empty() and not ResourceLoader.exists(definition.scene_path):
			push_warning("AppRegistry: scene for '%s' not found: %s" % [definition.id, definition.scene_path])
		seen_ids[definition.id] = true
		definitions.append(definition)
	return definitions
