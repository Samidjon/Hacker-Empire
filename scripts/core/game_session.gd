extends Node
## Root of an active play session. Owns the world and the session UI and
## connects them: world events become UI or GameManager actions here, so the
## world and the UI scenes never reference each other.

const MESSAGE_TOAST_SECONDS: float = 5.0

@onready var _world: GameWorld = %GameWorld
@onready var _hud: WorldHud = %Hud
@onready var _prompt: InteractionPrompt = %InteractionPrompt
@onready var _computer_screen: ComputerScreen = %ComputerScreen
@onready var _toasts: ToastNotifier = %Toasts
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _event_popup: EventPopup = %EventPopup
@onready var _ending_popup: EndingPopup = %EndingPopup


func _ready() -> void:
	# Opening this scene directly (e.g. F6 in the editor) has no session to show.
	if not GameManager.is_in_game():
		GameManager.return_to_main_menu.call_deferred(false)
		return

	_hud.save_pressed.connect(func() -> void: GameManager.save_game())
	_hud.menu_pressed.connect(_pause_menu.open)

	_world.interaction_prompt_changed.connect(_prompt.set_prompt)
	_world.computer_requested.connect(_computer_screen.open)
	_world.rest_requested.connect(_on_rest_requested)
	_world.message_requested.connect(_on_message_requested)
	_world.storage_requested.connect(_on_storage_requested)
	_world.room_changed.connect(_on_room_changed)
	StoryManager.chapter_completed.connect(_on_chapter_completed)
	StoryManager.story_completed.connect(_on_story_completed)
	# Objectives that were already met when the game was loaded count now.
	StoryManager.check_progress.call_deferred()

	_computer_screen.opened.connect(_on_computer_opened)
	_computer_screen.closed.connect(_on_computer_closed)

	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.save_failed.connect(_on_save_failed)
	ProgressionManager.level_changed.connect(_on_level_changed)
	ProgressionManager.rank_changed.connect(_on_rank_changed)
	EconomyManager.transaction_failed.connect(_on_transaction_failed)
	MailManager.mail_received.connect(_on_mail_received)
	ContractManager.contract_completed.connect(_on_contract_completed)
	ContractManager.contract_failed.connect(_on_contract_failed)
	HardwareManager.item_purchased.connect(_on_item_purchased)
	SkillManager.skill_upgraded.connect(_on_skill_upgraded)
	OrganizationManager.company_founded.connect(_on_company_founded)
	OrganizationManager.company_level_changed.connect(_on_company_level_changed)
	OrganizationManager.day_finished.connect(_on_day_finished)
	EmployeeManager.employee_left.connect(_on_employee_left)
	ResearchManager.research_completed.connect(_on_research_completed)
	ProductManager.product_released.connect(_on_product_released)
	EventManager.event_triggered.connect(_on_event_triggered)
	_event_popup.closed.connect(func() -> void: _pause_menu.can_open = not _computer_screen.is_open())
	# A decision that was waiting when the game was saved is asked again.
	if EventManager.has_pending_event():
		_on_event_triggered.call_deferred(EventManager.get_pending_event_id())


# --- World events -----------------------------------------------------------

func _on_rest_requested() -> void:
	# Success and failure are both reported by the save signal handlers below.
	GameManager.save_game()


func _on_message_requested(message: String) -> void:
	if not message.is_empty():
		_toasts.show_toast(message, UIPalette.TEXT, MESSAGE_TOAST_SECONDS)


func _on_storage_requested() -> void:
	var spares: Array[HardwareItem] = HardwareManager.get_spare_items()
	if spares.is_empty():
		_toasts.show_toast("Storage: empty shelves and a tangle of old cables.", UIPalette.TEXT, MESSAGE_TOAST_SECONDS)
		return
	var names: PackedStringArray = []
	for item: HardwareItem in spares:
		names.append(item.title)
	_toasts.show_toast(
		"Storage holds %d spare part(s): %s. Swap parts in the Hardware app." % [spares.size(), ", ".join(names)],
		UIPalette.TEXT, MESSAGE_TOAST_SECONDS
	)


func _on_computer_opened() -> void:
	_world.set_player_input_enabled(false)
	_pause_menu.can_open = false # Esc logs off instead of pausing
	_hud.hide()


func _on_computer_closed() -> void:
	_world.set_player_input_enabled(true)
	_pause_menu.can_open = true
	_hud.show()


# --- Notifications ----------------------------------------------------------

func _on_save_completed(_slot: int, is_autosave: bool) -> void:
	_toasts.show_toast("Autosaved" if is_autosave else "Game saved", UIPalette.ACCENT)


func _on_save_failed(_slot: int, reason: String) -> void:
	_toasts.show_toast("Save failed: %s" % reason, UIPalette.DANGER)


func _on_level_changed(new_level: int, old_level: int) -> void:
	if new_level > old_level:
		_toasts.show_toast("LEVEL UP - you are now level %d" % new_level, UIPalette.PRIMARY)


func _on_rank_changed(new_rank: String) -> void:
	# Also emitted on load/reset; only announce during an established session.
	if is_node_ready() and ProgressionManager.level > ProgressionManager.STARTING_LEVEL:
		_toasts.show_toast("New rank: %s" % new_rank, UIPalette.SECONDARY)


func _on_mail_received(message: Dictionary) -> void:
	_toasts.show_toast("New mail: %s" % SaveDataReader.get_string(message, "subject"), UIPalette.PRIMARY)


func _on_item_purchased(item_id: String) -> void:
	var item: HardwareItem = HardwareManager.get_item(item_id)
	if item != null:
		_toasts.show_toast("Installed: %s" % item.title, UIPalette.ACCENT)


func _on_skill_upgraded(skill_id: String, new_level: int) -> void:
	var skill: SkillDefinition = SkillManager.get_skill(skill_id)
	if skill != null:
		_toasts.show_toast("%s is now level %d" % [skill.title, new_level], UIPalette.SECONDARY)


func _on_company_founded() -> void:
	_toasts.show_toast("%s is open for business" % OrganizationManager.company_name, UIPalette.ACCENT)


func _on_company_level_changed(new_level: int) -> void:
	_toasts.show_toast("Company level %d" % new_level, UIPalette.SECONDARY)


func _on_day_finished(report: Dictionary) -> void:
	var net: int = SaveDataReader.get_int(report, "net")
	_toasts.show_toast(
		"Day %d closed: %s" % [SaveDataReader.get_int(report, "day"), FormatUtils.signed_money(net)],
		UIPalette.ACCENT if net >= 0 else UIPalette.WARNING
	)


func _on_employee_left(employee_name: String, reason: String) -> void:
	if reason == EmployeeManager.REASON_RESIGNED:
		_toasts.show_toast("%s has resigned" % employee_name, UIPalette.DANGER, MESSAGE_TOAST_SECONDS)


func _on_research_completed(project_id: String) -> void:
	var project: ResearchProject = ResearchManager.get_project(project_id)
	if project != null:
		_toasts.show_toast("Research finished: %s" % project.title, UIPalette.ACCENT, MESSAGE_TOAST_SECONDS)


func _on_product_released(product_id: String) -> void:
	var product: ProductDefinition = ProductManager.get_product(product_id)
	if product != null:
		_toasts.show_toast("%s is on the market" % product.title, UIPalette.ACCENT, MESSAGE_TOAST_SECONDS)


func _on_event_triggered(_event_id: String) -> void:
	# The pause menu must not open underneath the decision.
	_pause_menu.close()
	_pause_menu.can_open = false
	_event_popup.show_pending_event()


func _on_room_changed(room_id: String) -> void:
	if room_id == GameWorld.ROOM_OFFICE:
		var office: OfficeDefinition = OrganizationManager.get_office()
		_toasts.show_toast("You arrive at %s: %s" % [OrganizationManager.company_name, office.title], UIPalette.PRIMARY)
	else:
		_toasts.show_toast("You are home", UIPalette.PRIMARY)


func _on_chapter_completed(chapter_index: int) -> void:
	var chapter: Dictionary = StoryManager.get_chapter(chapter_index)
	_toasts.show_toast(
		"Chapter complete: %s  (%s)" % [
			chapter.get("title", ""), FormatUtils.signed_money(SaveDataReader.get_int(chapter, "reward_money"))
		],
		UIPalette.SECONDARY, MESSAGE_TOAST_SECONDS
	)


func _on_story_completed() -> void:
	# After whatever the player is doing right now has finished drawing.
	_ending_popup.open.call_deferred()


func _on_contract_completed(result: Dictionary) -> void:
	var payment: int = SaveDataReader.get_int(result, "reward") + SaveDataReader.get_int(result, "bonus")
	_toasts.show_toast("Contract completed: %s" % FormatUtils.signed_money(payment), UIPalette.ACCENT)


func _on_contract_failed(result: Dictionary) -> void:
	_toasts.show_toast(
		"Contract failed: %s" % SaveDataReader.get_string(result, "name"), UIPalette.DANGER
	)


func _on_transaction_failed(_amount: int, _category: String, reason: String) -> void:
	if reason == EconomyManager.FAILURE_INSUFFICIENT_FUNDS:
		_toasts.show_toast("Insufficient funds", UIPalette.WARNING)
