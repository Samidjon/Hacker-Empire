class_name MatchPuzzleLogic
extends PuzzleLogic
## "Find the identical one": a target code (checksum, signature) and several
## candidates that differ from it by a single character, except one.
##
## Config: {length: int, options: int, rounds: int}. Uses no content pool.

const CHARSET: String = "0123456789ABCDEF"
const GROUP_SIZE: int = 4
const MIN_LENGTH: int = 8
const MAX_LENGTH: int = 32
const MIN_OPTIONS: int = 3
const MAX_OPTIONS: int = 8

var _rng: RandomNumberGenerator
var _length: int = 16
var _option_count: int = 5
var _round_count: int = 1
var _round: int = 0
var _target: String = ""
var _options: PackedStringArray = []
var _correct_index: int = -1


func _init() -> void:
	puzzle_type = PuzzleFactory.TYPE_MATCH
	default_instruction = "Find the entry that is identical to the target."


func generate(config: Dictionary, _pools: Dictionary, rng: RandomNumberGenerator) -> bool:
	_rng = rng
	_length = clampi(SaveDataReader.get_int(config, "length", 16), MIN_LENGTH, MAX_LENGTH)
	_option_count = clampi(SaveDataReader.get_int(config, "options", 5), MIN_OPTIONS, MAX_OPTIONS)
	_round_count = clampi(SaveDataReader.get_int(config, "rounds", 1), 1, 5)
	_round = 0
	_build_round()
	return true


## The target, grouped for reading ("3FA9 02BC ...").
func get_target() -> String:
	return format_code(_target)


func get_options() -> PackedStringArray:
	var formatted: PackedStringArray = []
	for option: String in _options:
		formatted.append(format_code(option))
	return formatted


func get_correct_index() -> int:
	return _correct_index


## Zero-based round the player is on.
func get_round() -> int:
	return _round


func get_round_count() -> int:
	return _round_count


## True when `index` is the identical entry. A correct pick starts the next
## round, or solves the puzzle after the last one.
func try_pick(index: int) -> bool:
	if _is_solved or index != _correct_index:
		return false
	_round += 1
	if _round >= _round_count:
		_is_solved = true
	else:
		_build_round()
	return true


static func format_code(code: String) -> String:
	var groups: PackedStringArray = []
	for start: int in range(0, code.length(), GROUP_SIZE):
		groups.append(code.substr(start, GROUP_SIZE))
	return " ".join(groups)


func _build_round() -> void:
	_target = ""
	for index: int in _length:
		_target += CHARSET[_rng.randi_range(0, CHARSET.length() - 1)]

	var decoys: Dictionary = {}
	while decoys.size() < _option_count - 1:
		decoys[_mutate(_target)] = true
	var candidates: Array = decoys.keys()
	candidates.append(_target)
	shuffle(candidates, _rng)
	_options = PackedStringArray(candidates)
	_correct_index = _options.find(_target)


## A copy of `code` with exactly one character changed.
func _mutate(code: String) -> String:
	var position: int = _rng.randi_range(0, code.length() - 1)
	var replacement: String = code[position]
	while replacement == code[position]:
		replacement = CHARSET[_rng.randi_range(0, CHARSET.length() - 1)]
	return code.substr(0, position) + replacement + code.substr(position + 1)
