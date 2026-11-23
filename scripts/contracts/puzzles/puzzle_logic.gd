class_name PuzzleLogic
extends RefCounted
## Base class for the rules of one mission puzzle.
##
## A logic object generates one puzzle instance from its stage config, the
## shared content pools and a seeded random generator, then judges the
## player's moves. It has no UI: the matching MissionPuzzle scene shows it.
## The same seed always produces the same puzzle, so a contract can be
## resumed after loading a save.

var puzzle_type: String = ""
## Shown when the contract stage does not provide its own instruction.
var default_instruction: String = ""

var _is_solved: bool = false


## Builds the puzzle. Returns false when the config or pools cannot produce
## a solvable instance.
func generate(_config: Dictionary, _pools: Dictionary, _rng: RandomNumberGenerator) -> bool:
	return false


func is_solved() -> bool:
	return _is_solved


# --- Helpers for subclasses -------------------------------------------------

## Fisher-Yates shuffle driven by the puzzle's own generator.
static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[other]
		items[other] = held


## The strings stored under `key`; anything else in the array is ignored.
static func read_strings(data: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in SaveDataReader.get_array(data, key):
		if entry is String and not String(entry).is_empty():
			result.append(entry)
	return result


## `count` random elements. With `keep_order` they stay in source order.
static func pick_some(
	source: Array[String], count: int, rng: RandomNumberGenerator, keep_order: bool = false
) -> Array[String]:
	var indices: Array = range(source.size())
	shuffle(indices, rng)
	indices = indices.slice(0, clampi(count, 0, source.size()))
	if keep_order:
		indices.sort()
	var result: Array[String] = []
	for index: int in indices:
		result.append(source[index])
	return result
