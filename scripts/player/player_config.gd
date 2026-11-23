class_name PlayerConfig
extends Resource
## Rules for the player profile.

@export_range(1, 32) var min_alias_length: int = 3
@export_range(1, 32) var max_alias_length: int = 16
@export var default_alias: String = "Anonymous"
