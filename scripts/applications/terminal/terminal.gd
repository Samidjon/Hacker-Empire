extends VBoxContainer
## Terminal application: displays what TerminalInterpreter returns.

const BANNER: PackedStringArray = [
	"EMPIRE OS terminal",
	"Type 'help' for a list of commands.",
	"",
]

var _interpreter: TerminalInterpreter = TerminalInterpreter.new()
var _context: DesktopContext
var _app_id: String = ""
## Position while browsing history with the arrow keys; equals the history
## size when not browsing.
var _history_cursor: int = 0

@onready var _output: RichTextLabel = %Output
@onready var _prompt_label: Label = %PromptLabel
@onready var _command_input: LineEdit = %CommandInput


func _ready() -> void:
	_interpreter.clear_requested.connect(_output.clear)
	_interpreter.exit_requested.connect(_on_exit_requested)
	_command_input.text_submitted.connect(_on_text_submitted)
	_command_input.gui_input.connect(_on_input_gui_input)
	# Stay in typing mode after Enter (Godot 4.3+ property).
	_command_input.set(&"keep_editing_on_text_submit", true)
	visibility_changed.connect(_focus_input)
	for line: String in BANNER:
		_print_line(line, UIPalette.TEXT_DIM)
	_refresh_prompt()
	_focus_input()


## Called by the desktop after the app is placed in its window.
func setup_app(context: DesktopContext, definition: AppDefinition) -> void:
	_context = context
	_app_id = definition.id
	_interpreter.filesystem = context.filesystem
	_interpreter.app_definitions = context.app_definitions
	_interpreter.open_app_requested.connect(context.request_open_app)


## Runs a command exactly as if it had been typed.
func submit_command(line: String) -> void:
	_print_line("%s %s" % [_interpreter.get_prompt(), line], UIPalette.PRIMARY)
	var result: TerminalInterpreter.Result = _interpreter.execute(line)
	for output_line: String in result.lines:
		_print_line(output_line, UIPalette.DANGER if result.is_error else UIPalette.TEXT)
	_history_cursor = _interpreter.get_history().size()
	_refresh_prompt()


func get_output_text() -> String:
	return _output.get_parsed_text()


func get_interpreter() -> TerminalInterpreter:
	return _interpreter


func _on_text_submitted(text: String) -> void:
	_command_input.clear()
	submit_command(text)


## Up / Down walk through previous commands.
func _on_input_gui_input(event: InputEvent) -> void:
	var history: PackedStringArray = _interpreter.get_history()
	if event.is_action_pressed(&"ui_up"):
		_history_cursor = maxi(0, _history_cursor - 1)
	elif event.is_action_pressed(&"ui_down"):
		_history_cursor = mini(history.size(), _history_cursor + 1)
	else:
		return
	_command_input.text = history[_history_cursor] if _history_cursor < history.size() else ""
	_command_input.caret_column = _command_input.text.length()
	_command_input.accept_event()


func _on_exit_requested() -> void:
	if _context != null:
		_context.request_close_app(_app_id)


func _print_line(text: String, color: Color) -> void:
	_output.push_color(color)
	_output.add_text(text)
	_output.pop()
	_output.newline()


func _refresh_prompt() -> void:
	_prompt_label.text = _interpreter.get_prompt()


func _focus_input() -> void:
	if is_visible_in_tree():
		_command_input.grab_focus()
		if _command_input.has_method(&"edit"):
			_command_input.call(&"edit")
