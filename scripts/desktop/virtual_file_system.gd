class_name VirtualFileSystem
extends RefCounted
## The fictional, read-only file system of the in-game computer.
## Content comes from data/desktop/filesystem.json; nothing here touches the
## real disk.

const DEFAULT_DATA_PATH: String = "res://data/desktop/filesystem.json"
const ROOT: String = "/"
const HOME: String = "/home/user"
const HOME_SHORTCUT: String = "~"

## Directory node: {"children": {name: node}}. File node: {"content": String}.
var _root: Dictionary = {"children": {}}


static func load_from_file(path: String = DEFAULT_DATA_PATH) -> VirtualFileSystem:
	var file_system := VirtualFileSystem.new()
	file_system._root = _build_directory(JsonDataLoader.load_dictionary(path))
	return file_system


## Resolves `path` (absolute, relative to `cwd`, or starting with ~) into a
## clean absolute path. Does not check that it exists.
func normalize_path(path: String, cwd: String = ROOT) -> String:
	var combined: String = path.strip_edges()
	if combined == HOME_SHORTCUT or combined.begins_with(HOME_SHORTCUT + "/"):
		combined = HOME + combined.substr(HOME_SHORTCUT.length())
	elif not combined.begins_with(ROOT):
		combined = cwd + "/" + combined
	var parts: PackedStringArray = []
	for segment: String in combined.split("/", false):
		if segment == ".":
			continue
		if segment == "..":
			if not parts.is_empty():
				parts.remove_at(parts.size() - 1)
			continue
		parts.append(segment)
	return ROOT + "/".join(parts)


func exists(absolute_path: String) -> bool:
	return not _find(absolute_path).is_empty()


func is_directory(absolute_path: String) -> bool:
	return _find(absolute_path).has("children")


func is_file(absolute_path: String) -> bool:
	return _find(absolute_path).has("content")


## File text, or an empty string when `absolute_path` is not a file.
func read_file(absolute_path: String) -> String:
	return SaveDataReader.get_string(_find(absolute_path), "content")


## Entries of a directory, folders first, each as
## {name, path, is_directory, size}. Empty when it is not a directory.
func list_directory(absolute_path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var children: Dictionary = SaveDataReader.get_dictionary(_find(absolute_path), "children")
	for child_name: String in children:
		var child: Dictionary = children[child_name]
		var is_child_directory: bool = child.has("children")
		entries.append({
			"name": child_name,
			"path": normalize_path(child_name, absolute_path),
			"is_directory": is_child_directory,
			"size": 0 if is_child_directory else SaveDataReader.get_string(child, "content").length(),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_directory"] != b["is_directory"]:
			return a["is_directory"]
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0
	)
	return entries


func get_parent_path(absolute_path: String) -> String:
	return normalize_path("..", absolute_path)


# --- Internals --------------------------------------------------------------

## Returns the node at a path, or {} when nothing is there.
func _find(absolute_path: String) -> Dictionary:
	var node: Dictionary = _root
	for segment: String in normalize_path(absolute_path).split("/", false):
		var children: Dictionary = SaveDataReader.get_dictionary(node, "children")
		if not children.has(segment):
			return {}
		node = children[segment]
	return node


static func _build_directory(raw: Dictionary) -> Dictionary:
	var children: Dictionary = {}
	for entry: Variant in SaveDataReader.get_array(raw, "children"):
		if not entry is Dictionary:
			continue
		var raw_child: Dictionary = entry
		var child_name: String = SaveDataReader.get_string(raw_child, "name")
		if child_name.is_empty() or child_name.contains("/"):
			push_warning("VirtualFileSystem: skipped an entry with an invalid name.")
			continue
		if raw_child.has("children"):
			children[child_name] = _build_directory(raw_child)
		else:
			children[child_name] = {"content": SaveDataReader.get_string(raw_child, "content")}
	return {"children": children}
