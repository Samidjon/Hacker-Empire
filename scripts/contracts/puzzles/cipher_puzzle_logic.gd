class_name CipherPuzzleLogic
extends PuzzleLogic
## "Find the letter shift": a phrase is encoded with a Caesar shift and the
## player tries shifts until the text reads as plain English.
##
## Config: {pool: String}. Pool: pools.cipher[pool] = {phrases: [String]}.

const ALPHABET_SIZE: int = 26
const CODE_A: int = 65

var _plaintext: String = ""
var _shift: int = 1


func _init() -> void:
	puzzle_type = PuzzleFactory.TYPE_CIPHER
	default_instruction = "Change the shift until the text reads as plain English, then submit."


func generate(config: Dictionary, pools: Dictionary, rng: RandomNumberGenerator) -> bool:
	var pool: Dictionary = SaveDataReader.get_dictionary(
		SaveDataReader.get_dictionary(pools, "cipher"), SaveDataReader.get_string(config, "pool")
	)
	var phrases: Array[String] = read_strings(pool, "phrases")
	if phrases.is_empty():
		return false
	_plaintext = phrases[rng.randi_range(0, phrases.size() - 1)].to_upper()
	_shift = rng.randi_range(1, ALPHABET_SIZE - 1)
	return true


func get_ciphertext() -> String:
	return shift_text(_plaintext, _shift)


## What the ciphertext reads as when decoded with `candidate_shift`.
func decode(candidate_shift: int) -> String:
	return shift_text(get_ciphertext(), -candidate_shift)


func get_correct_shift() -> int:
	return _shift


## True (and solved) when `candidate_shift` decodes the text.
func submit(candidate_shift: int) -> bool:
	if posmod(candidate_shift, ALPHABET_SIZE) != _shift:
		return false
	_is_solved = true
	return true


## Shifts A-Z by `amount`; every other character is left alone.
static func shift_text(text: String, amount: int) -> String:
	var result: String = ""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= CODE_A and code < CODE_A + ALPHABET_SIZE:
			code = CODE_A + posmod(code - CODE_A + amount, ALPHABET_SIZE)
		result += String.chr(code)
	return result
