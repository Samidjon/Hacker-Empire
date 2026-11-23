class_name HackerDesktop
extends Control
## The simulated operating system: launcher, windows and taskbar.
##
## Applications are listed in data/desktop/apps.json and are ordinary scenes;
## the desktop only wraps them in windows. One window per application:
## launching an app that is already open brings it to the front.

signal log_off_requested
signal app_opened(app_id: String)
signal app_closed(app_id: String)

const WINDOW_SCENE: PackedScene = preload("res://scenes/desktop/AppWindow.tscn")
const ICON_SCENE: PackedScene = preload("res://scenes/desktop/AppIcon.tscn")
const MAIL_APP_ID: String = "mail"
const APP_SETUP_METHOD: StringName = &"setup_app"
## New windows open in a staggered stack.
const CASCADE_ORIGIN: Vector2 = Vector2(28.0, 22.0)
const CASCADE_STEP: Vector2 = Vector2(34.0, 30.0)
const CASCADE_SLOTS: int = 6

var _context: DesktopContext = DesktopContext.new()
var _definitions: Dictionary = {}  # app id -> AppDefinition
var _icons: Dictionary = {}        # app id -> AppIcon
var _windows: Dictionary = {}      # app id -> AppWindow (open or kept-state)
var _task_buttons: Dictionary = {} # app id -> Button
var _active_app_id: String = ""
var _windows_created: int = 0

@onready var _icon_grid: GridContainer = %IconGrid
@onready var _window_area: Control = %WindowArea
@onready var _task_list: HBoxContainer = %TaskList
@onready var _money_label: Label = %TaskbarMoneyLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _log_off_button: Button = %LogOffButton
@onready var _clock_timer: Timer = %ClockTimer


func _ready() -> void:
	_context.filesystem = VirtualFileSystem.load_from_file()
	_context.app_definitions = AppRegistry.load_definitions()
	_context.open_app_requested.connect(open_app)
	_context.close_app_requested.connect(close_app)

	for definition: AppDefinition in _context.app_definitions:
		_definitions[definition.id] = definition
		var icon: AppIcon = ICON_SCENE.instantiate()
		_icon_grid.add_child(icon)
		icon.setup(definition)
		icon.activated.connect(open_app)
		_icons[definition.id] = icon

	_log_off_button.pressed.connect(func() -> void: log_off_requested.emit())
	_clock_timer.timeout.connect(_refresh_clock)
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_money())
	MailManager.unread_count_changed.connect(_on_unread_count_changed)
	_refresh_clock()
	_refresh_money()
	_on_unread_count_changed(MailManager.get_unread_count())


func _input(event: InputEvent) -> void:
	# Clicking anywhere inside a window brings it to the front. The event is
	# not consumed, so the click still reaches the control under the cursor.
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or not is_visible_in_tree():
		return
	for index: int in range(_window_area.get_child_count() - 1, -1, -1):
		var window := _window_area.get_child(index) as AppWindow
		if window != null and window.visible and window.get_global_rect().has_point(button.position):
			focus_app(window.app_id)
			return


# --- Queries ----------------------------------------------------------------

func get_app_ids() -> PackedStringArray:
	return PackedStringArray(_definitions.keys())


func get_definition(app_id: String) -> AppDefinition:
	return _definitions.get(app_id)


func get_icon(app_id: String) -> AppIcon:
	return _icons.get(app_id)


func is_app_open(app_id: String) -> bool:
	var window: AppWindow = _windows.get(app_id)
	return window != null and window.is_open


func is_app_minimized(app_id: String) -> bool:
	return is_app_open(app_id) and not (_windows[app_id] as AppWindow).visible


func get_open_app_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for app_id: String in _windows:
		if is_app_open(app_id):
			ids.append(app_id)
	return ids


func get_active_app_id() -> String:
	return _active_app_id


func get_app_window(app_id: String) -> AppWindow:
	return _windows.get(app_id) if is_app_open(app_id) else null


## The application scene running inside an open window, or null.
func get_app_content(app_id: String) -> Control:
	var window: AppWindow = get_app_window(app_id)
	return window.get_content() if window != null else null


func get_task_button(app_id: String) -> Button:
	return _task_buttons.get(app_id)


# --- Window management ------------------------------------------------------

## Opens an application, or brings it to the front when it is already open.
## Returns false when the app is unknown or not installed.
func open_app(app_id: String) -> bool:
	var definition: AppDefinition = _definitions.get(app_id)
	if definition == null or not definition.is_available():
		return false

	var window: AppWindow = _windows.get(app_id)
	if window == null:
		window = _create_window(definition)
		if window == null:
			return false
	elif not window.is_open:
		window.is_open = true # a kept-state window being reopened
	else:
		window.show()
		focus_app(app_id)
		return true

	window.show()
	_add_task_button(definition)
	focus_app(app_id)
	app_opened.emit(app_id)
	return true


func close_app(app_id: String) -> void:
	var window: AppWindow = _windows.get(app_id)
	if window == null or not window.is_open:
		return
	window.is_open = false
	window.hide()
	var definition: AppDefinition = _definitions[app_id]
	if not definition.keep_state:
		_windows.erase(app_id)
		window.queue_free()
	_remove_task_button(app_id)
	app_closed.emit(app_id)
	_activate_topmost()


func minimize_app(app_id: String) -> void:
	if not is_app_open(app_id):
		return
	(_windows[app_id] as AppWindow).hide()
	_activate_topmost()


## Restores a minimised window if needed and brings it to the front.
func focus_app(app_id: String) -> void:
	if not is_app_open(app_id):
		return
	var window: AppWindow = _windows[app_id]
	window.show()
	_window_area.move_child(window, -1)
	_set_active(app_id)


func close_all_apps() -> void:
	for app_id: String in get_open_app_ids():
		close_app(app_id)


# --- Internals --------------------------------------------------------------

func _create_window(definition: AppDefinition) -> AppWindow:
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		push_error("HackerDesktop: cannot load %s." % definition.scene_path)
		return null
	var content := scene.instantiate() as Control
	if content == null:
		push_error("HackerDesktop: root of %s must be a Control." % definition.scene_path)
		return null

	var window: AppWindow = WINDOW_SCENE.instantiate()
	window.app_id = definition.id
	_window_area.add_child(window)
	window.set_title(definition.title)
	window.set_content(content)
	var slot: int = _windows_created % CASCADE_SLOTS
	window.place(CASCADE_ORIGIN + CASCADE_STEP * slot, definition.default_size)
	_windows_created += 1
	window.close_requested.connect(close_app.bind(definition.id))
	window.minimize_requested.connect(minimize_app.bind(definition.id))
	_windows[definition.id] = window

	if content.has_method(APP_SETUP_METHOD):
		content.call(APP_SETUP_METHOD, _context, definition)
	return window


func _add_task_button(definition: AppDefinition) -> void:
	if _task_buttons.has(definition.id):
		return
	var button := Button.new()
	button.text = definition.title
	button.theme_type_variation = &"SmallButton"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_task_button_pressed.bind(definition.id))
	_task_list.add_child(button)
	_task_buttons[definition.id] = button


func _remove_task_button(app_id: String) -> void:
	var button: Button = _task_buttons.get(app_id)
	if button != null:
		_task_buttons.erase(app_id)
		button.queue_free()


## Taskbar behaviour: the active window minimises, any other comes forward.
func _on_task_button_pressed(app_id: String) -> void:
	if app_id == _active_app_id and not is_app_minimized(app_id):
		minimize_app(app_id)
	else:
		focus_app(app_id)
	_refresh_task_buttons()


func _activate_topmost() -> void:
	for index: int in range(_window_area.get_child_count() - 1, -1, -1):
		var window := _window_area.get_child(index) as AppWindow
		if window != null and window.is_open and window.visible:
			_set_active(window.app_id)
			return
	_set_active("")


func _set_active(app_id: String) -> void:
	_active_app_id = app_id
	for other_id: String in _windows:
		(_windows[other_id] as AppWindow).set_active(other_id == app_id)
	_refresh_task_buttons()


func _refresh_task_buttons() -> void:
	for app_id: String in _task_buttons:
		(_task_buttons[app_id] as Button).set_pressed_no_signal(app_id == _active_app_id)


func _refresh_clock() -> void:
	_clock_label.text = Time.get_time_string_from_system().substr(0, 5)


func _refresh_money() -> void:
	_money_label.text = FormatUtils.money(EconomyManager.money)


func _on_unread_count_changed(unread_count: int) -> void:
	var mail_icon: AppIcon = _icons.get(MAIL_APP_ID)
	if mail_icon != null:
		mail_icon.set_badge(unread_count)
