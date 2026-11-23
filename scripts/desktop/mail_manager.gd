extends Node
## MailManager (autoload)
##
## Owns the player's inbox. Message texts and the events that deliver them
## come from data/mail/messages.json; the inbox (what arrived, what was read)
## is saved with the game.

signal mail_received(message: Dictionary)
signal unread_count_changed(unread_count: int)
signal inbox_changed

const DATA_PATH: String = "res://data/mail/messages.json"
const SAVE_SECTION: String = "mail"
const TRIGGER_NEW_GAME: String = "new_game"
const TRIGGER_LEVEL: String = "level"
const TRIGGER_CONTRACTS_COMPLETED: String = "contracts_completed"
const TRIGGER_COMPANY_FOUNDED: String = "company_founded"
const TRIGGER_STORY_CHAPTER: String = "story_chapter"
const ALIAS_TOKEN: String = "{alias}"
## For triggers that carry a number: the key in the data that must equal it.
const TRIGGER_VALUE_KEYS: Dictionary = {
	TRIGGER_LEVEL: "level",
	TRIGGER_CONTRACTS_COMPLETED: "count",
	TRIGGER_STORY_CHAPTER: "chapter",
}

## Message id -> definition {id, from, subject, body, trigger}.
var _definitions: Dictionary = {}
## Arrival order, oldest first. Each entry: {id, received_at, read}.
var _inbox: Array[Dictionary] = []


func _ready() -> void:
	_load_definitions()
	SaveManager.register_section(SAVE_SECTION, self)
	ProgressionManager.level_changed.connect(_on_level_changed)
	OrganizationManager.company_founded.connect(deliver_trigger.bind(TRIGGER_COMPANY_FOUNDED))
	StoryManager.chapter_started.connect(
		func(chapter_index: int) -> void: deliver_trigger(TRIGGER_STORY_CHAPTER, chapter_index)
	)
	StoryManager.story_completed.connect(
		func() -> void: deliver_trigger(TRIGGER_STORY_CHAPTER, StoryManager.get_chapter_count())
	)
	ContractManager.contract_completed.connect(
		func(_result: Dictionary) -> void:
			deliver_trigger(TRIGGER_CONTRACTS_COMPLETED, ContractManager.get_completed_count())
	)


## Delivers every message whose trigger matches. `value` is the level for
## TRIGGER_LEVEL or the total for TRIGGER_CONTRACTS_COMPLETED. Returns how
## many new messages arrived.
func deliver_trigger(trigger_type: String, value: int = 0) -> int:
	var delivered: int = 0
	for message_id: String in _definitions:
		var trigger: Dictionary = SaveDataReader.get_dictionary(_definitions[message_id], "trigger")
		if SaveDataReader.get_string(trigger, "type") != trigger_type:
			continue
		if TRIGGER_VALUE_KEYS.has(trigger_type):
			if SaveDataReader.get_int(trigger, TRIGGER_VALUE_KEYS[trigger_type]) != value:
				continue
		if deliver(message_id):
			delivered += 1
	return delivered


## Puts one message in the inbox. A message can only arrive once.
func deliver(message_id: String) -> bool:
	if not _definitions.has(message_id) or has_message(message_id):
		return false
	_inbox.append({
		"id": message_id,
		"received_at": int(Time.get_unix_time_from_system()),
		"read": false,
	})
	mail_received.emit(_compose(_inbox.back()))
	inbox_changed.emit()
	unread_count_changed.emit(get_unread_count())
	return true


## Inbox contents, newest first. Each message:
## {id, from, subject, body, received_at, read}.
func get_messages() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	for index: int in range(_inbox.size() - 1, -1, -1):
		messages.append(_compose(_inbox[index]))
	return messages


func get_message_count() -> int:
	return _inbox.size()


func get_unread_count() -> int:
	var unread: int = 0
	for entry: Dictionary in _inbox:
		if not entry["read"]:
			unread += 1
	return unread


func has_message(message_id: String) -> bool:
	for entry: Dictionary in _inbox:
		if entry["id"] == message_id:
			return true
	return false


func mark_read(message_id: String) -> void:
	for entry: Dictionary in _inbox:
		if entry["id"] == message_id and not entry["read"]:
			entry["read"] = true
			inbox_changed.emit()
			unread_count_changed.emit(get_unread_count())
			return


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"inbox": _inbox.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	_inbox.clear()
	for entry: Variant in SaveDataReader.get_array(data, "inbox"):
		if not entry is Dictionary:
			continue
		var raw: Dictionary = entry
		var message_id: String = SaveDataReader.get_string(raw, "id")
		# Messages removed from the data file, and duplicates, are dropped.
		if not _definitions.has(message_id) or has_message(message_id):
			continue
		_inbox.append({
			"id": message_id,
			"received_at": maxi(0, SaveDataReader.get_int(raw, "received_at")),
			"read": raw.get("read") == true,
		})
	inbox_changed.emit()
	unread_count_changed.emit(get_unread_count())


func reset_to_defaults() -> void:
	_inbox.clear()
	inbox_changed.emit()
	unread_count_changed.emit(0)


# --- Internals --------------------------------------------------------------

func _load_definitions() -> void:
	_definitions.clear()
	for entry: Dictionary in JsonDataLoader.load_entries(DATA_PATH, "messages"):
		var message_id: String = SaveDataReader.get_string(entry, "id")
		if message_id.is_empty() or _definitions.has(message_id):
			push_warning("MailManager: skipped a message with a missing or duplicate id.")
			continue
		_definitions[message_id] = entry


## Merges an inbox entry with its definition and fills in the player's alias.
func _compose(entry: Dictionary) -> Dictionary:
	var definition: Dictionary = _definitions.get(entry["id"], {})
	var player_alias: String = PlayerManager.hacker_alias
	return {
		"id": entry["id"],
		"from": SaveDataReader.get_string(definition, "from", "unknown"),
		"subject": SaveDataReader.get_string(definition, "subject").replace(ALIAS_TOKEN, player_alias),
		"body": SaveDataReader.get_string(definition, "body").replace(ALIAS_TOKEN, player_alias),
		"received_at": entry["received_at"],
		"read": entry["read"],
	}


func _on_level_changed(new_level: int, old_level: int) -> void:
	# Loading and resetting emit level_changed with equal values; only real
	# level-ups deliver mail. A multi-level jump delivers every step.
	for level: int in range(old_level + 1, new_level + 1):
		deliver_trigger(TRIGGER_LEVEL, level)
