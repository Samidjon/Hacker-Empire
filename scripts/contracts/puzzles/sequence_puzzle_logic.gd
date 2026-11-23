class_name SequencePuzzleLogic
extends PuzzleLogic
## "Put these in order": entries carry a sortable key (file offset, time of
## day, packet number) and must be picked from lowest to highest.
##
## Config: {pool: String, count: int}. Pool: pools.sequence[pool] =
## {key_format: "hex" | "time" | "sequence", ordered: bool, lines: [String]}.
## With `ordered`, the lines tell a story and keep their order.

const MIN_ITEMS: int = 3
const FORMAT_HEX: String = "hex"
const FORMAT_TIME: String = "time"
const SECONDS_PER_DAY: int = 86400

## Display order. Each: {label: String, rank: int, picked: bool}.
var _items: Array[Dictionary] = []
var _next_rank: int = 0


func _init() -> void:
	puzzle_type = PuzzleFactory.TYPE_SEQUENCE
	default_instruction = "Click the entries from the lowest value to the highest."


func generate(config: Dictionary, pools: Dictionary, rng: RandomNumberGenerator) -> bool:
	var pool: Dictionary = SaveDataReader.get_dictionary(
		SaveDataReader.get_dictionary(pools, "sequence"), SaveDataReader.get_string(config, "pool")
	)
	var lines: Array[String] = read_strings(pool, "lines")
	if lines.size() < MIN_ITEMS:
		return false
	var count: int = clampi(SaveDataReader.get_int(config, "count", 5), MIN_ITEMS, lines.size())
	var chosen: Array[String] = pick_some(lines, count, rng, pool.get("ordered") == true)
	var key_format: String = SaveDataReader.get_string(pool, "key_format", "sequence")

	_items.clear()
	_next_rank = 0
	var key: int = _first_key(key_format, rng)
	for rank: int in chosen.size():
		_items.append({"label": "%s   %s" % [_format_key(key_format, key), chosen[rank]], "rank": rank, "picked": false})
		key += _key_step(key_format, rng)

	# Never hand the player an already sorted list.
	for attempt: int in 20:
		shuffle(_items, rng)
		if not _is_display_sorted():
			break
	return true


func get_item_count() -> int:
	return _items.size()


func get_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for item: Dictionary in _items:
		labels.append(item["label"])
	return labels


func is_picked(display_index: int) -> bool:
	return _is_valid_index(display_index) and _items[display_index]["picked"]


## True when `display_index` is the next entry in order. A wrong pick
## changes nothing; picking an entry twice is ignored (and counts as fine).
func try_pick(display_index: int) -> bool:
	if not _is_valid_index(display_index) or _is_solved:
		return false
	var item: Dictionary = _items[display_index]
	if item["picked"]:
		return true
	if item["rank"] != _next_rank:
		return false
	item["picked"] = true
	_next_rank += 1
	_is_solved = _next_rank >= _items.size()
	return true


## Display index of the entry that must be picked next, or -1 when solved.
func get_next_correct_index() -> int:
	for index: int in _items.size():
		if _items[index]["rank"] == _next_rank:
			return index
	return -1


func _is_valid_index(display_index: int) -> bool:
	return display_index >= 0 and display_index < _items.size()


func _is_display_sorted() -> bool:
	for index: int in _items.size():
		if _items[index]["rank"] != index:
			return false
	return true


func _first_key(key_format: String, rng: RandomNumberGenerator) -> int:
	match key_format:
		FORMAT_HEX:
			return rng.randi_range(0, 64) * 16
		FORMAT_TIME:
			return rng.randi_range(0, SECONDS_PER_DAY / 2)
		_:
			return rng.randi_range(1000, 60000)


func _key_step(key_format: String, rng: RandomNumberGenerator) -> int:
	match key_format:
		FORMAT_HEX:
			return rng.randi_range(4, 96) * 16
		FORMAT_TIME:
			return rng.randi_range(5, 900)
		_:
			return rng.randi_range(1, 48)


func _format_key(key_format: String, key: int) -> String:
	match key_format:
		FORMAT_HEX:
			return "0x%05X" % key
		FORMAT_TIME:
			var seconds: int = key % SECONDS_PER_DAY
			@warning_ignore("integer_division")
			return "%02d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
		_:
			return "#%05d" % key
