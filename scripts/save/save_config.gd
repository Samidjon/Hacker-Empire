class_name SaveConfig
extends Resource
## Tunable settings for the save system.

## Number of manual save slots offered to the player (slots are 1-based).
@export_range(1, 10) var slot_count: int = 3
## Directory that holds the slot files.
@export var save_directory: String = "user://saves"
@export var autosave_enabled: bool = true
## Seconds between autosaves while a session is active.
@export_range(10.0, 3600.0) var autosave_interval_seconds: float = 120.0
