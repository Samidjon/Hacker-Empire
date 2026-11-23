class_name SaveSlotInfo
extends RefCounted
## Read-only description of one save slot, used by slot-selection UI.

enum Status {
	EMPTY,                 ## No file in this slot.
	VALID,                 ## Primary file is readable.
	RECOVERED_FROM_BACKUP, ## Primary file is damaged, backup is readable.
	CORRUPTED,             ## Neither primary nor backup can be read.
}

var slot: int = -1
var status: Status = Status.EMPTY
## Display data written by the summary provider at save time.
var summary: Dictionary = {}
var saved_at_unix: int = 0
## Human-readable reason when status is CORRUPTED.
var error: String = ""


func is_loadable() -> bool:
	return status == Status.VALID or status == Status.RECOVERED_FROM_BACKUP


func is_empty() -> bool:
	return status == Status.EMPTY
