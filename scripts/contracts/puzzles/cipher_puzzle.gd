extends MissionPuzzle
## Screen for CipherPuzzleLogic: step through letter shifts and watch the
## decoded text change, then submit the one that reads as English.

var _shift: int = 0

@onready var _cipher_label: Label = %CipherText
@onready var _decoded_label: Label = %DecodedText
@onready var _shift_label: Label = %ShiftLabel
@onready var _shift_down_button: Button = %ShiftDownButton
@onready var _shift_up_button: Button = %ShiftUpButton
@onready var _submit_button: Button = %CipherSubmitButton


func _ready() -> void:
	_shift_down_button.pressed.connect(func() -> void: set_shift(_shift - 1))
	_shift_up_button.pressed.connect(func() -> void: set_shift(_shift + 1))
	_submit_button.pressed.connect(submit)
	for label: Label in [_cipher_label, _decoded_label]:
		label.add_theme_font_override(&"font", MONO_FONT)


func _build() -> void:
	_cipher_label.text = (_logic as CipherPuzzleLogic).get_ciphertext()
	set_shift(0)


func get_shift() -> int:
	return _shift


## Sets the shift being tried (wraps around the alphabet).
func set_shift(value: int) -> void:
	_shift = posmod(value, CipherPuzzleLogic.ALPHABET_SIZE)
	_shift_label.text = "Shift %d" % _shift
	_decoded_label.text = (_logic as CipherPuzzleLogic).decode(_shift)


## Submits the current shift, exactly as the Submit button does.
func submit() -> void:
	var logic := _logic as CipherPuzzleLogic
	if logic.is_solved():
		return
	if logic.submit(_shift):
		_submit_button.disabled = true
		solved.emit()
	else:
		mistake_made.emit("Shift %d still gives gibberish." % _shift)
