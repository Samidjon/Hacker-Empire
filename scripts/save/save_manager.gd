extends Node
## SaveManager (autoload)
##
## Persists game state to versioned JSON slot files.
##
## SaveManager knows nothing about gameplay. Each system registers itself as a
## "section" and must implement:
##   get_save_data() -> Dictionary     data to persist (JSON-compatible)
##   load_save_data(data: Dictionary)  restore, validating every field
##   reset_to_defaults()               state for a brand-new game
##
## Reliability:
##   - Saves are written to a temp file, verified, then swapped in.
##   - The previous good save is kept as "<slot>.bak" and used automatically
##     when the primary file cannot be read.
##   - A file is fully validated before any live state is touched, so a failed
##     load never leaves the game half-loaded.

signal save_completed(slot: int, is_autosave: bool)
signal save_failed(slot: int, reason: String)
signal load_completed(slot: int, recovered_from_backup: bool)
signal load_failed(slot: int, reason: String)
signal slot_deleted(slot: int)

const CONFIG: SaveConfig = preload("res://resources/configurations/save_config.tres")
const SAVE_FORMAT_ID: String = "hacker_empire_save"
## Bump when the file layout changes and add a step to _migrate().
const SAVE_VERSION: int = 1
const NO_SLOT: int = -1
const REQUIRED_SECTION_METHODS: PackedStringArray = [
	"get_save_data", "load_save_data", "reset_to_defaults",
]

## Slot the running session saves to, or NO_SLOT when no session is active.
var active_slot: int = NO_SLOT

var _save_directory: String = ""
var _sections: Dictionary = {} # section id (String) -> provider (Node)
var _summary_provider: Callable = Callable()
var _autosave_timer: Timer


## Result of reading one slot from disk.
class ReadResult:
	extends RefCounted
	var ok: bool = false
	var payload: Dictionary = {}
	var error: String = ""
	var from_backup: bool = false


func _ready() -> void:
	_save_directory = CONFIG.save_directory
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.one_shot = false
	_autosave_timer.wait_time = CONFIG.autosave_interval_seconds
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)


# --- Registration -----------------------------------------------------------

func register_section(section_id: String, provider: Node) -> void:
	if section_id.is_empty() or provider == null:
		push_error("SaveManager: invalid section registration.")
		return
	for method: String in REQUIRED_SECTION_METHODS:
		if not provider.has_method(method):
			push_error("SaveManager: section '%s' is missing %s()." % [section_id, method])
			return
	if _sections.has(section_id):
		push_warning("SaveManager: section '%s' registered twice; replacing." % section_id)
	_sections[section_id] = provider


## The callable returns a small Dictionary shown in slot lists (alias, level...).
func set_summary_provider(provider: Callable) -> void:
	_summary_provider = provider


## Redirects all slot files, e.g. to an isolated directory for tests.
func set_save_directory(directory: String) -> void:
	_save_directory = directory


func get_save_directory() -> String:
	return _save_directory


# --- Session ----------------------------------------------------------------

func begin_session(slot: int) -> void:
	if not is_valid_slot(slot):
		push_error("SaveManager: cannot begin a session on slot %d." % slot)
		return
	active_slot = slot
	if CONFIG.autosave_enabled:
		_autosave_timer.start()


func end_session() -> void:
	active_slot = NO_SLOT
	_autosave_timer.stop()


func has_active_session() -> bool:
	return active_slot != NO_SLOT


## Puts every registered system back into its new-game state.
func reset_all_sections() -> void:
	for section_id: String in _sections:
		var provider: Node = _sections[section_id]
		if is_instance_valid(provider):
			provider.call("reset_to_defaults")


# --- Slot queries -----------------------------------------------------------

func get_slot_count() -> int:
	return CONFIG.slot_count


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= CONFIG.slot_count


func get_slot_path(slot: int) -> String:
	return _save_directory.path_join("slot_%d.json" % slot)


func get_backup_path(slot: int) -> String:
	return get_slot_path(slot) + ".bak"


func get_slot_info(slot: int) -> SaveSlotInfo:
	var info := SaveSlotInfo.new()
	info.slot = slot
	if not is_valid_slot(slot):
		info.status = SaveSlotInfo.Status.CORRUPTED
		info.error = "Invalid slot."
		return info
	if not _slot_has_files(slot):
		return info
	var result := _read_slot(slot)
	if not result.ok:
		info.status = SaveSlotInfo.Status.CORRUPTED
		info.error = result.error
		return info
	info.status = (
		SaveSlotInfo.Status.RECOVERED_FROM_BACKUP if result.from_backup
		else SaveSlotInfo.Status.VALID
	)
	info.summary = SaveDataReader.get_dictionary(result.payload, "summary")
	info.saved_at_unix = SaveDataReader.get_int(result.payload, "saved_at")
	return info


func get_all_slot_infos() -> Array[SaveSlotInfo]:
	var infos: Array[SaveSlotInfo] = []
	for slot: int in range(1, CONFIG.slot_count + 1):
		infos.append(get_slot_info(slot))
	return infos


## True when any slot holds a file, readable or not.
func has_any_save() -> bool:
	for slot: int in range(1, CONFIG.slot_count + 1):
		if _slot_has_files(slot):
			return true
	return false


## Loadable slot with the newest timestamp, or NO_SLOT.
func get_most_recent_slot() -> int:
	var best_slot: int = NO_SLOT
	var best_time: int = -1
	for info: SaveSlotInfo in get_all_slot_infos():
		if info.is_loadable() and info.saved_at_unix > best_time:
			best_time = info.saved_at_unix
			best_slot = info.slot
	return best_slot


# --- Save -------------------------------------------------------------------

func save_to_slot(slot: int, is_autosave: bool = false) -> bool:
	if not is_valid_slot(slot):
		return _fail_save(slot, "Invalid save slot.")

	var dir_error: Error = DirAccess.make_dir_recursive_absolute(_save_directory)
	if dir_error != OK:
		return _fail_save(slot, "Cannot create save directory (%s)." % error_string(dir_error))

	var path: String = get_slot_path(slot)
	var temp_path: String = path + ".tmp"
	var json_text: String = JSON.stringify(_build_payload(), "\t")

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail_save(
			slot, "Cannot write save file (%s)." % error_string(FileAccess.get_open_error())
		)
	file.store_string(json_text)
	file.close()

	# Never replace a save with a file that cannot be read back.
	var verification := _read_file(temp_path)
	if not verification.ok:
		DirAccess.remove_absolute(temp_path)
		return _fail_save(slot, "Save verification failed: %s" % verification.error)

	if FileAccess.file_exists(path):
		# Only a readable primary may become the backup; a damaged primary
		# must not overwrite an older backup that still works.
		if _read_file(path).ok:
			var copy_error: Error = DirAccess.copy_absolute(path, get_backup_path(slot))
			if copy_error != OK:
				push_warning("SaveManager: could not update backup (%s)." % error_string(copy_error))
		DirAccess.remove_absolute(path)

	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		return _fail_save(slot, "Cannot finalize save file (%s)." % error_string(rename_error))

	save_completed.emit(slot, is_autosave)
	return true


func save_active_slot(is_autosave: bool = false) -> bool:
	if not has_active_session():
		return _fail_save(NO_SLOT, "No active game session.")
	return save_to_slot(active_slot, is_autosave)


# --- Load -------------------------------------------------------------------

func load_from_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return _fail_load(slot, "Invalid save slot.")
	if not _slot_has_files(slot):
		return _fail_load(slot, "Save slot is empty.")

	var result := _read_slot(slot)
	if not result.ok:
		return _fail_load(slot, result.error)

	var sections: Dictionary = SaveDataReader.get_dictionary(result.payload, "sections")
	for section_id: String in _sections:
		var provider: Node = _sections[section_id]
		if not is_instance_valid(provider):
			continue
		# A section missing from an older save simply keeps its defaults.
		provider.call("reset_to_defaults")
		provider.call("load_save_data", SaveDataReader.get_dictionary(sections, section_id))

	load_completed.emit(slot, result.from_backup)
	return true


func delete_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	var success: bool = true
	for path: String in [get_slot_path(slot), get_backup_path(slot), get_slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			push_warning("SaveManager: could not delete %s." % path)
			success = false
	if success:
		slot_deleted.emit(slot)
	return success


# --- Internals --------------------------------------------------------------

func _build_payload() -> Dictionary:
	var sections: Dictionary = {}
	for section_id: String in _sections:
		var provider: Node = _sections[section_id]
		if is_instance_valid(provider):
			sections[section_id] = provider.call("get_save_data")

	var summary: Dictionary = {}
	if _summary_provider.is_valid():
		var provided: Variant = _summary_provider.call()
		if provided is Dictionary:
			summary = provided

	return {
		"format": SAVE_FORMAT_ID,
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"summary": summary,
		"sections": sections,
	}


func _slot_has_files(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot)) or FileAccess.file_exists(get_backup_path(slot))


## Reads a slot, falling back to its backup when the primary is unusable.
func _read_slot(slot: int) -> ReadResult:
	var primary := _read_file(get_slot_path(slot))
	if primary.ok:
		return primary
	var backup := _read_file(get_backup_path(slot))
	if backup.ok:
		backup.from_backup = true
		push_warning("SaveManager: slot %d recovered from backup (%s)." % [slot, primary.error])
		return backup
	# Report the primary's problem; it is the more useful message.
	return primary


func _read_file(path: String) -> ReadResult:
	var result := ReadResult.new()
	if not FileAccess.file_exists(path):
		result.error = "Save file not found."
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = "Cannot open save file (%s)." % error_string(FileAccess.get_open_error())
		return result
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		result.error = "Save file is corrupted (invalid JSON)."
		return result

	var validation_error: String = _validate_payload(json.data)
	if not validation_error.is_empty():
		result.error = validation_error
		return result

	result.payload = _migrate(json.data)
	result.ok = true
	return result


## Returns an empty string when the parsed data is a usable save.
func _validate_payload(parsed: Variant) -> String:
	if not parsed is Dictionary:
		return "Save file is corrupted (unexpected structure)."
	var payload: Dictionary = parsed
	if SaveDataReader.get_string(payload, "format") != SAVE_FORMAT_ID:
		return "File is not a Hacker Empire save."
	var version: int = SaveDataReader.get_int(payload, "version", 0)
	if version < 1:
		return "Save file is corrupted (missing version)."
	if version > SAVE_VERSION:
		return "Save was created by a newer version of the game."
	if not payload.get("sections") is Dictionary:
		return "Save file is corrupted (missing data sections)."
	return ""


## Upgrades an older payload step by step to the current layout.
func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = SaveDataReader.get_int(payload, "version", SAVE_VERSION)
	while version < SAVE_VERSION:
		match version:
			# Example for the future:
			# 1: payload = _migrate_v1_to_v2(payload)
			_:
				push_warning("SaveManager: no migration defined from version %d." % version)
		version += 1
	payload["version"] = SAVE_VERSION
	return payload


func _fail_save(slot: int, reason: String) -> bool:
	push_warning("SaveManager: save failed - %s" % reason)
	save_failed.emit(slot, reason)
	return false


func _fail_load(slot: int, reason: String) -> bool:
	push_warning("SaveManager: load failed - %s" % reason)
	load_failed.emit(slot, reason)
	return false


func _on_autosave_timeout() -> void:
	if has_active_session():
		save_to_slot(active_slot, true)
