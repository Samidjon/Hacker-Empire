class_name SpotPuzzleLogic
extends PuzzleLogic
## "Find what does not belong": a list of lines (settings, processes, code,
## log entries) in which some are problems. The player selects them all and
## submits.
##
## Config: {pool: String, normal: int, anomalies: int}. Pool:
## pools.spot[pool] = {normal: [String], anomalies: [String], keep_order: bool}.
## With `keep_order`, normal lines stay in source order (used for code).

## Display order. Each: {text: String, anomaly: bool}.
var _lines: Array[Dictionary] = []
## Explains the result of the last submit().
var last_feedback: String = ""


func _init() -> void:
	puzzle_type = PuzzleFactory.TYPE_SPOT
	default_instruction = "Select every line that is a problem, then submit."


func generate(config: Dictionary, pools: Dictionary, rng: RandomNumberGenerator) -> bool:
	var pool: Dictionary = SaveDataReader.get_dictionary(
		SaveDataReader.get_dictionary(pools, "spot"), SaveDataReader.get_string(config, "pool")
	)
	var normal_pool: Array[String] = read_strings(pool, "normal")
	var anomaly_pool: Array[String] = read_strings(pool, "anomalies")
	if normal_pool.size() < 2 or anomaly_pool.is_empty():
		return false
	var keep_order: bool = pool.get("keep_order") == true
	var normal: Array[String] = pick_some(
		normal_pool, maxi(2, SaveDataReader.get_int(config, "normal", 6)), rng, keep_order
	)
	var anomalies: Array[String] = pick_some(
		anomaly_pool, maxi(1, SaveDataReader.get_int(config, "anomalies", 1)), rng
	)

	_lines.clear()
	for text: String in normal:
		_lines.append({"text": text, "anomaly": false})
	if keep_order:
		for text: String in anomalies:
			_lines.insert(rng.randi_range(0, _lines.size()), {"text": text, "anomaly": true})
	else:
		for text: String in anomalies:
			_lines.append({"text": text, "anomaly": true})
		shuffle(_lines, rng)
	return true


func get_line_count() -> int:
	return _lines.size()


func get_lines() -> PackedStringArray:
	var texts: PackedStringArray = []
	for line: Dictionary in _lines:
		texts.append(line["text"])
	return texts


func get_anomaly_count() -> int:
	var count: int = 0
	for line: Dictionary in _lines:
		if line["anomaly"]:
			count += 1
	return count


func is_anomaly(index: int) -> bool:
	return index >= 0 and index < _lines.size() and _lines[index]["anomaly"]


## True (and solved) when `selected` holds exactly the problem lines.
func submit(selected: Array) -> bool:
	var found: int = 0
	var wrong: int = 0
	var seen: Dictionary = {}
	for entry: Variant in selected:
		if not entry is int or seen.has(entry):
			continue
		seen[entry] = true
		if is_anomaly(entry):
			found += 1
		else:
			wrong += 1
	var total: int = get_anomaly_count()
	if found == total and wrong == 0:
		_is_solved = true
		last_feedback = "All %d problem(s) found." % total
		return true
	last_feedback = "%d of %d problem(s) found, %d wrong selection(s)." % [found, total, wrong]
	return false
