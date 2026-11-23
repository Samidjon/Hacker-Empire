extends VBoxContainer
## File Manager application: browse the virtual file system and read files.

var _filesystem: VirtualFileSystem
var _current_path: String = VirtualFileSystem.HOME
var _entries: Array[Dictionary] = []

@onready var _up_button: Button = %UpButton
@onready var _home_button: Button = %HomeButton
@onready var _path_label: Label = %PathLabel
@onready var _entry_list: ItemList = %EntryList
@onready var _preview_title: Label = %PreviewTitle
@onready var _preview_text: RichTextLabel = %PreviewText


func _ready() -> void:
	_up_button.pressed.connect(go_up)
	_home_button.pressed.connect(navigate_to.bind(VirtualFileSystem.HOME))
	_entry_list.item_selected.connect(_on_item_selected)
	_entry_list.item_activated.connect(open_entry)
	_clear_preview()


## Called by the desktop after the app is placed in its window.
func setup_app(context: DesktopContext, _definition: AppDefinition) -> void:
	_filesystem = context.filesystem
	navigate_to(_current_path)


func get_current_path() -> String:
	return _current_path


func get_entry_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for entry: Dictionary in _entries:
		names.append(entry["name"])
	return names


func get_preview_text() -> String:
	return _preview_text.get_parsed_text()


## Shows a folder. Returns false (and stays put) when it does not exist.
func navigate_to(path: String) -> bool:
	if _filesystem == null:
		return false
	var target: String = _filesystem.normalize_path(path, _current_path)
	if not _filesystem.is_directory(target):
		return false
	_current_path = target
	_entries = _filesystem.list_directory(target)
	_path_label.text = target
	_up_button.disabled = target == VirtualFileSystem.ROOT
	_entry_list.clear()
	for entry: Dictionary in _entries:
		_entry_list.add_item("[%s]" % entry["name"] if entry["is_directory"] else String(entry["name"]))
	_clear_preview()
	return true


func go_up() -> void:
	if _filesystem != null:
		navigate_to(_filesystem.get_parent_path(_current_path))


## Opens the entry at `index`: enters a folder or previews a file.
func open_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry: Dictionary = _entries[index]
	if entry["is_directory"]:
		navigate_to(entry["path"])
	else:
		_show_file(entry)


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _entries.size() and not _entries[index]["is_directory"]:
		_show_file(_entries[index])


func _show_file(entry: Dictionary) -> void:
	_preview_title.text = "%s  (%d bytes)" % [entry["name"], entry["size"]]
	_preview_text.clear()
	_preview_text.add_text(_filesystem.read_file(entry["path"]))


func _clear_preview() -> void:
	_preview_title.text = "No file selected"
	_preview_text.clear()
	_preview_text.push_color(UIPalette.TEXT_DIM)
	_preview_text.add_text("Select a file to read it. Double-click a folder to open it.")
	_preview_text.pop()
