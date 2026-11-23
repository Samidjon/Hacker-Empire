extends HBoxContainer
## Mail application: inbox list and reading pane. Reading a message marks it
## as read in MailManager.

const UNREAD_MARK: String = "* "
const READ_MARK: String = "   "

var _messages: Array[Dictionary] = []
var _selected_id: String = ""

@onready var _message_list: ItemList = %MessageList
@onready var _subject_label: Label = %SubjectLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _body_text: RichTextLabel = %BodyText


func _ready() -> void:
	_message_list.item_selected.connect(select_message)
	MailManager.inbox_changed.connect(_rebuild_list)
	_rebuild_list()
	_show_empty_pane()


func get_message_count() -> int:
	return _messages.size()


func get_selected_id() -> String:
	return _selected_id


func get_body_text() -> String:
	return _body_text.get_parsed_text()


## Opens the message at `index` (newest first) and marks it read.
func select_message(index: int) -> void:
	if index < 0 or index >= _messages.size():
		return
	var message: Dictionary = _messages[index]
	_selected_id = message["id"]
	_subject_label.text = message["subject"]
	_meta_label.text = "From %s   -   %s" % [
		message["from"], FormatUtils.local_timestamp(message["received_at"])
	]
	_body_text.clear()
	_body_text.add_text(message["body"])
	MailManager.mark_read(_selected_id) # triggers _rebuild_list through inbox_changed


func _rebuild_list() -> void:
	_messages = MailManager.get_messages()
	_message_list.clear()
	for message: Dictionary in _messages:
		var index: int = _message_list.add_item(
			(READ_MARK if message["read"] else UNREAD_MARK) + String(message["subject"])
		)
		if not message["read"]:
			_message_list.set_item_custom_fg_color(index, UIPalette.ACCENT)
		if message["id"] == _selected_id:
			_message_list.select(index)
	if _messages.is_empty():
		_selected_id = ""
		_show_empty_pane()


func _show_empty_pane() -> void:
	if not _selected_id.is_empty():
		return
	_subject_label.text = "Inbox"
	_meta_label.text = "%d message(s)" % _messages.size()
	_body_text.clear()
	_body_text.push_color(UIPalette.TEXT_DIM)
	_body_text.add_text("Select a message to read it." if not _messages.is_empty() else "No mail yet.")
	_body_text.pop()
