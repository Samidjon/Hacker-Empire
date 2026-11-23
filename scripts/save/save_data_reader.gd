class_name SaveDataReader
extends RefCounted
## Type-safe accessors for dictionaries parsed from save files.
##
## JSON turns every number into a float and a damaged or hand-edited file can
## hold any type under any key, so every manager reads its section through
## these helpers and falls back to a default instead of crashing.


static func get_int(data: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = data.get(key)
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return default_value


static func get_float(data: Dictionary, key: String, default_value: float = 0.0) -> float:
	var value: Variant = data.get(key)
	if value is int:
		return float(value)
	if value is float and is_finite(value):
		return value
	return default_value


static func get_string(data: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = data.get(key)
	if value is String or value is StringName:
		return String(value)
	return default_value


static func get_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	if value is Dictionary:
		return value
	return {}


static func get_array(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key)
	if value is Array:
		return value
	return []
