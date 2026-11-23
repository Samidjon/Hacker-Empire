class_name JsonDataLoader
extends RefCounted
## Reads game data files. Every failure is reported and yields an empty
## result, so a damaged data file disables one feature instead of crashing.


## Returns the file's top-level object, or {} on any problem.
static func load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JsonDataLoader: data file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonDataLoader: cannot open %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("JsonDataLoader: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("JsonDataLoader: %s must contain a JSON object." % path)
		return {}
	return json.data


## Returns the dictionaries stored in the array under `key`.
static func load_entries(path: String, key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Variant in SaveDataReader.get_array(load_dictionary(path), key):
		if entry is Dictionary:
			entries.append(entry)
		else:
			push_warning("JsonDataLoader: skipped a non-object entry in '%s' of %s." % [key, path])
	return entries
