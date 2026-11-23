extends Node
## End-to-end test of the real scenes: main menu -> new game -> walk around
## the room -> use the computer -> dashboard -> save -> pause -> exit ->
## continue -> load -> delete.
## Drives real input actions and buttons, so broken node paths, signals,
## collisions and interactions fail here.

const TEST_SAVE_DIRECTORY: String = "user://test_saves_flow"
const TIMEOUT_SECONDS: float = 60.0
const TEST_ALIAS: String = "Flow_Tester"
const COMPUTER_SPOT: Vector2 = Vector2(3.0, 1.45)
const STORAGE_SPOT: Vector2 = Vector2(1.5, 2.1)
const BED_SPOT: Vector2 = Vector2(2.7, 6.4)
const PARKING_SPOT: Vector2 = Vector2(6.0, 5.0)
const DOOR_SPOT: Vector2 = Vector2(0.9, 0.75)

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS, true).timeout.connect(_on_timeout)
	SaveManager.set_save_directory(TEST_SAVE_DIRECTORY)
	_clean_test_directory()
	await _run()
	_release_all_actions()
	_clean_test_directory()
	print("\n==== flow test: %d passed, %d failed ====" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> void:
	# --- Main menu, no saves ---
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
	await _frames(3)
	var menu: Node = get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "main menu loads")
	if menu == null:
		return
	_check(_button(menu, "ContinueButton").disabled, "Continue disabled without saves")
	_check(_button(menu, "LoadGameButton").disabled, "Load Game disabled without saves")

	# --- New game flow through the real UI ---
	_button(menu, "NewGameButton").pressed.emit()
	await _frames(2)
	_check(_control(menu, "SlotPanel").visible, "slot list shown")
	var slot_list: Node = menu.get_node("%SlotList")
	_check(slot_list.get_child_count() == SaveManager.get_slot_count(), "one card per slot")
	var first_card: SaveSlotCard = slot_list.get_child(0)
	_check(_button(first_card, "SelectButton").text == "Start Here", "empty slot offers Start Here")
	_check(not _button(first_card, "DeleteButton").visible, "empty slot has no Delete")
	_button(first_card, "SelectButton").pressed.emit()
	await _frames(2)
	_check(_control(menu, "NewGamePanel").visible, "alias form shown")

	var alias_edit: LineEdit = menu.get_node("%AliasEdit")
	alias_edit.text = "!!"
	_button(menu, "StartButton").pressed.emit()
	await _frames(1)
	_check(not (menu.get_node("%AliasErrorLabel") as Label).text.is_empty(), "invalid alias shows an error")
	_check(not GameManager.is_in_game(), "invalid alias does not start a game")

	alias_edit.text = TEST_ALIAS
	_button(menu, "StartButton").pressed.emit()
	await GameManager.scene_transition_finished
	await _frames(2)

	# --- In game: session and world ---
	var session: Node = get_tree().current_scene
	_check(session != null and session.name == "GameSession", "game session loads")
	if session == null:
		return
	_check(GameManager.is_in_game() and SaveManager.active_slot == 1, "session active on slot 1")
	_check(SaveManager.get_slot_info(1).status == SaveSlotInfo.Status.VALID, "new game written to disk")

	var world: GameWorld = session.get_node("%GameWorld")
	var hud: WorldHud = session.get_node("%Hud")
	var prompt: InteractionPrompt = session.get_node("%InteractionPrompt")
	var computer: ComputerScreen = session.get_node("%ComputerScreen")
	var pause_menu: PauseMenu = session.get_node("%PauseMenu")
	var toasts: ToastNotifier = session.get_node("%Toasts")
	var player: Player = world.get_player()
	var room: HackerRoom = world.get_room()
	var shell: RoomShell = room.get_node("%Shell")
	var starting_money: int = EconomyManager.CONFIG.starting_money

	_check(player != null and player.is_inside_tree(), "player exists in the world")
	_check(player.position.distance_to(room.get_spawn_position()) < 1.0, "new player starts at the spawn point")
	_check(not computer.visible and prompt.get_prompt().is_empty(), "no computer screen or prompt at spawn")
	_check(_label(hud, "HudAliasLabel").text == TEST_ALIAS, "HUD shows alias")
	_check(_label(hud, "HudMoneyLabel").text == FormatUtils.money(starting_money), "HUD shows money")
	_check(hud.get_objectives_text().contains("CHAPTER 1 - BEDROOM OPERATOR") and hud.get_objectives_text().contains("[ ] Complete a contract"), "HUD shows the first chapter and its objectives")
	_check(world.get_room_id() == GameWorld.ROOM_APARTMENT, "a new game starts in the apartment")

	# --- Movement ---
	var before: Vector2 = player.position
	Input.action_press(Player.ACTION_RIGHT)
	await _physics_frames(20)
	Input.action_release(Player.ACTION_RIGHT)
	_check(player.position.x > before.x + 30.0, "move_right moves the player right")
	_check(absf(player.position.y - before.y) < 1.0, "horizontal movement stays level")

	before = player.position
	Input.action_press(Player.ACTION_DOWN)
	await _physics_frames(20)
	Input.action_release(Player.ACTION_DOWN)
	var vertical_step: float = player.position.y - before.y
	_check(vertical_step > 10.0, "move_down moves the player down")
	await _physics_frames(2)
	before = player.position
	await _physics_frames(10)
	_check(player.position.is_equal_approx(before), "player stops when input is released")

	# --- Walls: holding a direction never leaves the floor ---
	for actions: Array in [
		[Player.ACTION_LEFT, Player.ACTION_UP], [Player.ACTION_RIGHT, Player.ACTION_DOWN],
		[Player.ACTION_UP], [Player.ACTION_LEFT, Player.ACTION_DOWN], [Player.ACTION_RIGHT],
	]:
		for action: StringName in actions:
			Input.action_press(action)
		await _physics_frames(260)
		for action: StringName in actions:
			Input.action_release(action)
		_check(shell.contains_point(player.position), "walls hold against %s" % str(actions))

	# --- Furniture blocks movement ---
	player.teleport(IsoUtils.grid_to_screen(Vector2(3.0, 2.2)))
	await _physics_frames(2)
	Input.action_press(Player.ACTION_UP)   # up + right walks along -y on the grid,
	Input.action_press(Player.ACTION_RIGHT) # straight into the desk
	await _physics_frames(150)
	Input.action_release(Player.ACTION_UP)
	Input.action_release(Player.ACTION_RIGHT)
	var grid_after_push: Vector2 = IsoUtils.screen_to_grid(player.position)
	_check(grid_after_push.y >= 1.0, "desk blocks the player (stopped at grid y %.2f)" % grid_after_push.y)
	_check(grid_after_push.y < 2.0, "player did reach the desk")

	# --- Depth sorting ---
	var computer_prop: Node2D = room.get_node("%Props/Computer")
	var storage_prop: Node2D = room.get_node("%Props/Storage")
	player.teleport(IsoUtils.grid_to_screen(COMPUTER_SPOT))
	await _frames(2)
	_check(player.z_index > computer_prop.z_index, "player draws in front of the desk when standing before it")
	player.teleport(IsoUtils.grid_to_screen(Vector2(0.5, 0.7)))
	await _frames(2)
	_check(player.z_index < storage_prop.z_index, "player draws behind the cabinet when standing behind it")

	# --- The door, before there is an office ---
	player.teleport(IsoUtils.grid_to_screen(DOOR_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Go to the Office", "prompt appears at the door")
	var toasts_before_door: int = toasts.get_total_shown()
	await _tap(Player.ACTION_INTERACT)
	_check(world.get_room_id() == GameWorld.ROOM_APARTMENT and toasts.get_total_shown() == toasts_before_door + 1, "without an office the door explains why you stay home")

	# --- Interaction: computer ---
	player.teleport(IsoUtils.grid_to_screen(COMPUTER_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Use Computer", "prompt appears near the computer")
	_check(player.get_interaction_target() != null and player.get_interaction_target().is_focused(), "target is highlighted")
	await _tap(Player.ACTION_INTERACT)
	_check(computer.visible, "interact opens the computer")
	_check(prompt.get_prompt().is_empty(), "prompt hidden while using the computer")
	_check(not hud.visible, "HUD hidden while using the computer")
	_check(not get_tree().paused, "using the computer does not pause the game")

	before = player.position
	Input.action_press(Player.ACTION_DOWN)
	await _physics_frames(20)
	Input.action_release(Player.ACTION_DOWN)
	_check(player.position.is_equal_approx(before), "player cannot walk while at the computer")
	await _tap(Player.ACTION_INTERACT)
	_check(computer.visible, "interact key does nothing while at the computer")

	# --- Desktop: launcher ---
	var desktop: HackerDesktop = computer.get_desktop()
	_check(desktop.is_visible_in_tree(), "desktop is shown at the computer")
	var all_listed: bool = true
	for required_id: String in [
		"dashboard", "terminal", "contracts", "marketplace", "files", "mail", "hardware",
		"skills", "network", "finance", "organization", "employees", "research",
	]:
		if desktop.get_definition(required_id) == null or desktop.get_icon(required_id) == null:
			all_listed = false
	_check(all_listed, "all 13 applications are listed on the launcher")
	_check(desktop.get_open_app_ids().is_empty(), "no windows open at first")
	var all_installed: bool = true
	for app_id: String in desktop.get_app_ids():
		if desktop.get_icon(app_id).disabled:
			all_installed = false
	_check(all_installed, "every listed application is installed")
	_check(not desktop.open_app("no_such_app"), "an unknown app cannot be opened")
	_check(desktop.get_icon("mail").get_badge() == 2, "mail icon shows two unread welcome messages")
	_check(_label(desktop, "TaskbarMoneyLabel").text == FormatUtils.money(starting_money), "taskbar shows money")

	# --- Desktop: opening and switching ---
	desktop.get_icon("dashboard").pressed.emit()
	await _frames(2)
	_check(desktop.is_app_open("dashboard"), "launcher icon opens the Dashboard")
	_check(desktop.get_active_app_id() == "dashboard", "new window is active")
	_check(desktop.get_task_button("dashboard") != null, "open app appears on the taskbar")
	desktop.get_icon("terminal").pressed.emit()
	await _frames(2)
	_check(desktop.get_active_app_id() == "terminal", "second app becomes active")
	_check(desktop.get_open_app_ids().size() == 2, "two apps open")
	desktop.get_icon("dashboard").pressed.emit()
	await _frames(1)
	_check(desktop.get_open_app_ids().size() == 2, "launching an open app does not duplicate it")
	_check(desktop.get_active_app_id() == "dashboard", "launching an open app brings it forward")

	desktop.get_task_button("terminal").pressed.emit()
	await _frames(1)
	_check(desktop.get_active_app_id() == "terminal", "taskbar switches to another app")
	_check(desktop.get_task_button("terminal").button_pressed, "taskbar highlights the active app")
	desktop.get_task_button("terminal").pressed.emit()
	await _frames(1)
	_check(desktop.is_app_minimized("terminal"), "taskbar minimises the active app")
	_check(desktop.is_app_open("terminal") and desktop.get_active_app_id() == "dashboard", "minimised app stays open; next window takes focus")
	desktop.get_task_button("terminal").pressed.emit()
	await _frames(1)
	_check(not desktop.is_app_minimized("terminal") and desktop.get_active_app_id() == "terminal", "taskbar restores a minimised app")

	# --- Desktop: window controls ---
	var terminal_window: AppWindow = desktop.get_app_window("terminal")
	var window_area: Control = terminal_window.get_parent()
	var size_before: Vector2 = terminal_window.size
	_button(terminal_window, "MaximizeButton").pressed.emit()
	await _frames(2)
	_check(terminal_window.is_maximized() and terminal_window.size.is_equal_approx(window_area.size), "maximise fills the desktop")
	_button(terminal_window, "MaximizeButton").pressed.emit()
	await _frames(2)
	_check(not terminal_window.is_maximized() and terminal_window.size.is_equal_approx(size_before), "restore returns to the previous size")
	terminal_window.place(Vector2(-9000.0, 9000.0), terminal_window.size)
	var title_rect: Rect2 = Rect2(terminal_window.position, Vector2(terminal_window.size.x, AppWindow.TITLE_BAR_HEIGHT))
	_check(Rect2(Vector2.ZERO, window_area.size).intersects(title_rect), "a window cannot be moved out of reach")
	terminal_window.place(Vector2(300.0, 200.0), terminal_window.size)
	_button(terminal_window, "MinimizeButton").pressed.emit()
	await _frames(1)
	_check(desktop.is_app_minimized("terminal"), "minimise button hides the window")
	desktop.focus_app("terminal")

	# A real mouse click on a window behind brings it to the front.
	var dashboard_window: AppWindow = desktop.get_app_window("dashboard")
	dashboard_window.place(Vector2(0.0, 0.0), dashboard_window.size)
	terminal_window.place(Vector2(500.0, 300.0), Vector2(600.0, 300.0))
	await _frames(2)
	await _click(dashboard_window.get_global_rect().position + Vector2(200.0, 400.0))
	_check(desktop.get_active_app_id() == "dashboard", "clicking a window brings it to the front")

	# --- Terminal ---
	desktop.focus_app("terminal")
	var terminal: Node = desktop.get_app_content("terminal")
	terminal.call("submit_command", "help")
	_check(String(terminal.call("get_output_text")).contains("Available commands"), "terminal: help lists commands")
	terminal.call("submit_command", "status")
	_check(String(terminal.call("get_output_text")).contains(TEST_ALIAS), "terminal: status shows the profile")
	terminal.call("submit_command", "cd /docs")
	terminal.call("submit_command", "ls")
	_check(String(terminal.call("get_output_text")).contains("terminal_guide.txt"), "terminal: cd and ls browse the file system")
	terminal.call("submit_command", "cat rules_of_engagement.txt")
	_check(String(terminal.call("get_output_text")).contains("RULES OF ENGAGEMENT"), "terminal: cat prints a file")
	terminal.call("submit_command", "sudo rm -rf /")
	_check(String(terminal.call("get_output_text")).contains("command not found"), "terminal: unknown commands are rejected")
	var command_input: LineEdit = terminal.get_node("%CommandInput")
	command_input.text = "echo typed-by-hand"
	command_input.text_submitted.emit(command_input.text)
	await _frames(1)
	_check(String(terminal.call("get_output_text")).contains("typed-by-hand") and command_input.text.is_empty(), "terminal: typing a command and pressing Enter runs it")

	# State preservation: the terminal keeps its screen and folder when closed.
	_button(terminal_window, "CloseButton").pressed.emit()
	await _frames(2)
	_check(not desktop.is_app_open("terminal") and desktop.get_task_button("terminal") == null, "close button closes the app")
	desktop.open_app("terminal")
	await _frames(2)
	terminal = desktop.get_app_content("terminal")
	_check(String(terminal.call("get_output_text")).contains("RULES OF ENGAGEMENT"), "terminal keeps its screen after closing")
	terminal.call("submit_command", "pwd")
	_check(String(terminal.call("get_output_text")).ends_with("/docs\n"), "terminal keeps its folder after closing")

	terminal.call("submit_command", "open nosuchapp")
	_check(String(terminal.call("get_output_text")).contains("unknown application"), "terminal: cannot open an app that does not exist")
	terminal.call("submit_command", "open mail")
	await _frames(2)
	_check(desktop.is_app_open("mail") and desktop.get_active_app_id() == "mail", "terminal: open launches another app")
	terminal.call("submit_command", "exit")
	await _frames(2)
	_check(not desktop.is_app_open("terminal"), "terminal: exit closes the terminal")

	# --- Mail ---
	var mail: Node = desktop.get_app_content("mail")
	_check(int(mail.call("get_message_count")) == 2, "mail lists the welcome messages")
	mail.call("select_message", 0)
	await _frames(1)
	_check(String(mail.call("get_body_text")).contains(TEST_ALIAS), "mail body is addressed to the player")
	_check(desktop.get_icon("mail").get_badge() == 1, "reading a message lowers the unread badge")
	mail.call("select_message", 1)
	await _frames(1)
	_check(desktop.get_icon("mail").get_badge() == 0 and MailManager.get_unread_count() == 0, "badge clears when everything is read")

	# --- File Manager ---
	desktop.open_app("files")
	await _frames(2)
	var files: Node = desktop.get_app_content("files")
	_check(String(files.call("get_current_path")) == VirtualFileSystem.HOME, "file manager starts in the home folder")
	var names: PackedStringArray = files.call("get_entry_names")
	_check(names.has("notes") and names.has("welcome.txt"), "file manager lists folders and files")
	files.call("open_entry", names.find("welcome.txt"))
	_check(String(files.call("get_preview_text")).contains("EMPIRE OS"), "file manager previews a file")
	files.call("open_entry", names.find("notes"))
	_check(String(files.call("get_current_path")) == "/home/user/notes", "file manager enters a folder")
	_button(files, "UpButton").pressed.emit()
	_check(String(files.call("get_current_path")) == VirtualFileSystem.HOME, "Up returns to the parent folder")
	_check(not files.call("navigate_to", "/no/such/folder"), "file manager refuses a missing folder")

	# --- Network Map ---
	desktop.open_app("network")
	await _frames(2)
	var network: Node = desktop.get_app_content("network")
	_check(int(network.call("get_discovered_count")) == 3, "network map shows level 1 nodes as discovered")
	network.call("select_node", "home_rig")
	_check(String(network.call("get_details_text")).contains("Your Rig"), "network map shows details of a known node")
	network.call("select_node", "aegis_citadel")
	_check(String(network.call("get_details_text")).contains("UNDISCOVERED"), "network map hides undiscovered nodes")

	# --- Dashboard and Finance, driven by Dev Tools ---
	desktop.open_app("finance")
	desktop.open_app("devtools")
	await _frames(2)
	var finance: Node = desktop.get_app_content("finance")
	_check(String(finance.call("get_income_text")).contains("Starting Funds"), "finance lists income by source")
	var dashboard: Node = desktop.get_app_content("dashboard")
	_check(_label(dashboard, "AliasLabel").text == TEST_ALIAS, "dashboard shows alias")
	_check(_label(dashboard, "RankLabel").text == "BEGINNER", "dashboard shows rank")
	_check(_card(dashboard, "BalanceCard").get_value_text() == FormatUtils.money(starting_money), "dashboard shows starting funds")

	# Dev tools drive the real manager APIs.
	var debug_buttons: Node = desktop.get_app_content("devtools").get_node("%ButtonList")
	_check(debug_buttons.get_child_count() == 7, "dev tools built")
	(debug_buttons.get_child(0) as Button).pressed.emit() # +250 XP
	(debug_buttons.get_child(1) as Button).pressed.emit() # +$500
	(debug_buttons.get_child(2) as Button).pressed.emit() # spend $200
	(debug_buttons.get_child(3) as Button).pressed.emit() # +5 white rep
	(debug_buttons.get_child(5) as Button).pressed.emit() # +10 heat
	await _frames(2)
	var expected_money: int = starting_money + 300
	_check(EconomyManager.money == expected_money, "dev tools changed money")
	_check(ProgressionManager.level == 2, "250 XP reached level 2")
	_check(_card(dashboard, "BalanceCard").get_value_text() == FormatUtils.money(expected_money), "balance card updated live")
	_check(_label(dashboard, "LevelLabel").text.begins_with("LEVEL 2"), "level label updated live")
	_check(_card(dashboard, "WhiteRepCard").get_value_text() == "5", "reputation card updated live")
	_check(_card(dashboard, "HeatCard").get_value_text().begins_with("10"), "heat card updated live")
	_check(not (dashboard.get_node("%TransactionLog") as RichTextLabel).get_parsed_text().is_empty(), "transaction log filled")
	_check(toasts.get_total_shown() > 0, "level-up toast shown")
	_check(String(finance.call("get_expense_text")).contains("Dev Tools"), "finance updates expenses live")
	_check(String(finance.call("get_history_text")).contains("Dev expense"), "finance lists the transaction history")
	_check(_label(desktop, "TaskbarMoneyLabel").text == FormatUtils.money(expected_money), "taskbar money updates live")

	# Reaching level 2 delivers mail and discovers a network node.
	_check(MailManager.get_message_count() == 3, "levelling up delivers new mail")
	_check(desktop.get_icon("mail").get_badge() == 1, "new mail raises the badge")
	_check(int(mail.call("get_message_count")) == 3, "open mail app shows the new message")
	_check(int(network.call("get_discovered_count")) == 4, "levelling up discovers a network node")

	# --- Marketplace: buy a part ---
	desktop.open_app("marketplace")
	desktop.open_app("hardware")
	await _frames(2)
	var market: Node = desktop.get_app_content("marketplace")
	var hardware_app: Node = desktop.get_app_content("hardware")
	_check(PackedStringArray(market.call("get_item_ids")).size() == HardwareManager.get_shop_items().size(), "marketplace lists everything for sale")
	market.call("select_category", 1)
	_check(PackedStringArray(market.call("get_item_ids")).size() == HardwareManager.get_shop_items(HardwareCategory.CPU).size(), "the category filter narrows the list")
	market.call("select_item_id", "cpu_titan")
	_check(_button(market, "BuyButton").disabled and String(market.call("get_details_text")).contains("Requires level"), "a part above your level cannot be bought and says why")
	market.call("select_item_id", "cpu_quadra")
	_check(String(market.call("get_details_text")).contains("Speed +6") and String(market.call("get_details_text")).contains("Pentaline II"), "details show the part and what it would replace")
	var price: int = HardwareManager.get_item("cpu_quadra").price
	var limit_definition: ContractDefinition = ContractManager.get_definition("fr_photo_archive")
	var limit_before: float = ContractManager.get_time_limit(limit_definition)
	var money_before_purchase: int = EconomyManager.money
	var toasts_before_purchase: int = toasts.get_total_shown()
	_button(market, "BuyButton").pressed.emit()
	await _frames(2)
	_check(EconomyManager.money == money_before_purchase - price, "Buy charges the price")
	_check(HardwareManager.is_installed("cpu_quadra"), "the bought part is installed")
	_check(_button(market, "BuyButton").disabled and _button(market, "BuyButton").text == "Owned", "an owned part cannot be bought again")
	_check(toasts.get_total_shown() == toasts_before_purchase + 1, "buying shows a toast")
	_check(String(finance.call("get_expense_text")).contains("Hardware"), "finance shows the hardware expense")
	_check(ContractManager.get_time_limit(limit_definition) > limit_before, "the new CPU gives contracts more time")

	# --- Hardware: slots, totals, swapping parts ---
	_check(String(hardware_app.call("get_slot_text", 0)).contains("Quadra-4"), "hardware app shows the new CPU in its slot")
	_check(String(hardware_app.call("get_totals_text")).contains("+6% time on contracts"), "hardware app shows what the machine's stats give")
	hardware_app.call("select_slot", 0)
	_check(PackedStringArray(hardware_app.call("get_owned_ids")).size() == 2, "the old CPU is listed as an owned part")
	hardware_app.call("select_owned", 0)
	_button(hardware_app, "InstallButton").pressed.emit()
	await _frames(2)
	_check(HardwareManager.is_installed("cpu_pentaline_ii") and is_equal_approx(ContractManager.get_time_limit(limit_definition), limit_before), "a spare part can be swapped back in, and the bonus goes with it")
	hardware_app.call("select_owned", 1)
	_button(hardware_app, "InstallButton").pressed.emit()
	await _frames(2)
	_check(HardwareManager.is_installed("cpu_quadra"), "and swapped out again")

	# --- Skills: spend a point in the tree ---
	desktop.open_app("skills")
	await _frames(2)
	var skills_app: Node = desktop.get_app_content("skills")
	var tree: SkillTreeView = skills_app.call("get_tree_view")
	var points_before: int = SkillManager.get_available_points()
	_check(points_before == 2 and String(skills_app.call("get_points_text")).contains("2 available"), "level 2 has two skill points")
	_check(tree.get_skill_button("prog_clean_code") != null and tree.get_skill_button("ai_predictive_models") != null, "the tree has a node for every skill")
	tree.get_skill_button("prog_automation").pressed.emit()
	await _frames(1)
	_check(String(skills_app.call("get_selected_id")) == "prog_automation" and _button(skills_app, "UpgradeButton").disabled, "a locked skill can be inspected but not learned")
	_check(String(skills_app.call("get_details_text")).contains("Requires Clean Code level 1"), "a locked skill says what it needs")
	tree.get_skill_button("net_fast_routes").pressed.emit()
	await _frames(1)
	var cooldown_before: float = ContractManager.get_refresh_cooldown()
	_button(skills_app, "UpgradeButton").pressed.emit()
	await _frames(2)
	_check(SkillManager.get_level("net_fast_routes") == 1 and SkillManager.get_available_points() == points_before - 1, "Learn spends a point and raises the skill")
	_check(tree.get_skill_button("net_fast_routes").text.contains("1 / 3"), "the tree node shows the new level")
	_check(ContractManager.get_refresh_cooldown() < cooldown_before, "the skill's bonus applies at once")
	_check(String(skills_app.call("get_details_text")).contains("15% shorter wait"), "details show the current bonus")

	# --- Contracts: play one through the real UI ---
	desktop.get_icon("contracts").pressed.emit()
	await _frames(2)
	var contracts: Node = desktop.get_app_content("contracts")
	var runner: MissionRunner = contracts.call("get_runner")
	_check(int(contracts.call("get_offer_count")) == ContractManager.CONFIG.board_size, "contract board lists the offers")
	_check(String(contracts.call("get_details_text")).contains("Payment"), "offer details are shown")
	contracts.call("select_offer", 1)
	var chosen_offer: Dictionary = ContractManager.find_offer(int(contracts.call("get_selected_offer_id")))
	_check(not chosen_offer.is_empty() and chosen_offer["offer_id"] == ContractManager.get_board()[1]["offer_id"], "selecting an offer shows it")
	var chosen_reward: int = chosen_offer["reward"]
	var money_before_contract: int = EconomyManager.money
	var xp_before_contract: int = ProgressionManager.total_xp
	var chapter_before_contract: int = StoryManager.get_chapter_index()
	_button(contracts, "AcceptButton").pressed.emit()
	await _frames(2)
	_check(ContractManager.has_active_contract(), "Accept starts the contract")
	_check(int(contracts.call("get_view")) == 1 and runner.get_puzzle() != null, "the mission opens with a puzzle")
	_check(_button(contracts, "AcceptButton").disabled, "a second contract cannot be accepted meanwhile")

	await _make_mistake(runner)
	_check(ContractManager.get_mistakes() == 1, "a wrong move counts as a mistake")
	_check(not runner.get_feedback_text().is_empty(), "a wrong move is explained")
	_check(_label(runner, "MistakesLabel").text.ends_with("2"), "mistake counter updates")

	var stages_played: int = 0
	while ContractManager.has_active_contract() and stages_played < 10:
		var stage_before: int = ContractManager.get_stage_index()
		await _solve_current(runner)
		stages_played += 1
		if ContractManager.has_active_contract():
			_check(ContractManager.get_stage_index() == stage_before + 1, "solving a puzzle advances to stage %d" % (stage_before + 2))
	var played_definition: ContractDefinition = ContractManager.get_definition(chosen_offer["template_id"])
	_check(stages_played == played_definition.get_stage_count(), "every stage was played")
	_check(runner.is_showing_result() and runner.get_result_text().contains("COMPLETED"), "result screen shows success")
	var first_chapter: Dictionary = StoryManager.get_chapter(chapter_before_contract)
	_check(StoryManager.get_chapter_index() == chapter_before_contract + 1, "finishing the first contract at level 2 completes the first story chapter")
	_check(EconomyManager.money == money_before_contract + chosen_reward + int(first_chapter["reward_money"]), "contract pays its reward (no flawless bonus after a mistake) and the chapter pays its own")
	_check(ProgressionManager.total_xp == xp_before_contract + played_definition.xp_reward + int(first_chapter["reward_xp"]), "contract and chapter grant their XP")
	_check(hud.get_objectives_text().contains("CHAPTER 2 - TOOLS OF THE TRADE") and MailManager.has_message("story_tools"), "the HUD moves to the next chapter and a mail introduces it")
	_check(ContractManager.get_completed_count() == 1 and MailManager.has_message("first_contract"), "first completion is recorded and triggers mail")
	_check(String(finance.call("get_income_text")).contains("Contract"), "finance shows contract income")
	_button(runner, "ResultCloseButton").pressed.emit()
	await _frames(2)
	_check(int(contracts.call("get_view")) == 0, "closing the result returns to the board")
	_check(int(contracts.call("get_offer_count")) == ContractManager.CONFIG.board_size, "the board is refilled")
	_check(String(contracts.call("get_history_text")).contains("COMPLETED"), "history lists the finished contract")

	# Three mistakes fail a contract.
	var money_before_failure: int = EconomyManager.money
	contracts.call("select_offer", 0)
	_button(contracts, "AcceptButton").pressed.emit()
	await _frames(2)
	for attempt: int in ContractManager.CONFIG.max_mistakes:
		if ContractManager.has_active_contract():
			await _make_mistake(runner)
	_check(not ContractManager.has_active_contract() and ContractManager.get_failed_count() == 1, "three mistakes fail the contract")
	_check(runner.get_result_text().contains("FAILED") and EconomyManager.money == money_before_failure, "a failed contract pays nothing")
	_button(runner, "ResultCloseButton").pressed.emit()
	await _frames(2)

	# Abandoning also fails it.
	contracts.call("select_offer", 0)
	_button(contracts, "AcceptButton").pressed.emit()
	await _frames(2)
	_button(runner, "AbandonButton").pressed.emit()
	await _frames(2)
	_check(not ContractManager.has_active_contract() and ContractManager.get_failed_count() == 2, "Abandon fails the contract")
	_button(runner, "ResultCloseButton").pressed.emit()
	await _frames(2)

	# --- Organization: found a company through the app ---
	desktop.open_app("organization")
	desktop.open_app("employees")
	await _frames(2)
	var organization: Node = desktop.get_app_content("organization")
	var employees_app: Node = desktop.get_app_content("employees")
	_check(_control(organization, "FoundingView").visible and not _control(organization, "CompanyView").visible, "the Organization app starts with the founding form")
	_check(_label(employees_app, "NoCompanyLabel").visible, "the Employees app says a company is needed")
	organization.call("set_company_name_text", "Flow Test Systems")
	_check(_button(organization, "FoundButton").disabled and String(organization.call("get_founding_text")).contains("Requires level"), "founding is blocked below the required level, with the reason")
	ProgressionManager.add_xp(ProgressionManager.get_xp_required(), "flow test")
	EconomyManager.add_money(6000, TransactionCategory.OTHER, "Flow test capital")
	await _frames(2)
	_check(not _button(organization, "FoundButton").disabled, "founding is allowed once level and money are enough")
	var money_before_founding: int = EconomyManager.money
	_button(organization, "FoundButton").pressed.emit()
	await _frames(2)
	_check(OrganizationManager.is_founded() and OrganizationManager.company_name == "Flow Test Systems", "Found Company creates the company")
	_check(EconomyManager.money == money_before_founding - OrganizationManager.CONFIG.founding_cost, "the registration fee is charged")
	_check(_control(organization, "CompanyView").visible and _label(organization, "CompanyNameLabel").text == "Flow Test Systems", "the app switches to the company overview")
	_check(String(organization.call("get_office_text")).contains("Home Office"), "the overview shows the office")
	_check(MailManager.has_message("company_founded"), "founding sends a confirmation mail")

	# --- Employees: recruit, assign, and run a business day ---
	employees_app.call("show_view", 1)
	await _frames(1)
	var candidate_ids: PackedStringArray = employees_app.call("get_candidate_ids")
	_check(candidate_ids.size() == EmployeeManager.CONFIG.candidate_count and _control(employees_app, "RecruitView").visible, "the Recruit tab lists candidates")
	employees_app.call("select_candidate", 1)
	var recruit: Employee = EmployeeManager.get_candidate(candidate_ids[1])
	_check(String(employees_app.call("get_candidate_details_text")).contains(recruit.display_name) and String(employees_app.call("get_candidate_details_text")).contains("Salary"), "candidate details show the person")
	var money_before_hire: int = EconomyManager.money
	_button(employees_app, "HireButton").pressed.emit()
	await _frames(2)
	_check(EmployeeManager.get_employee(recruit.id) != null, "Hire adds the candidate to the staff")
	_check(EconomyManager.money == money_before_hire - recruit.salary * EmployeeManager.CONFIG.signing_fee_days, "the signing fee is charged")
	_check(_button(employees_app, "HireButton").disabled and String(employees_app.call("get_candidate_details_text")).contains("No free desk"), "a full office blocks further hiring, with the reason")

	_button(organization, "ExpandButton").pressed.emit()
	await _frames(2)
	_check(OrganizationManager.get_office().id == "shared_desk" and not _button(employees_app, "HireButton").disabled, "expanding the office frees a desk")

	employees_app.call("show_view", 0)
	await _frames(1)
	_check(PackedStringArray(employees_app.call("get_employee_ids")) == PackedStringArray([recruit.id]), "the Staff tab lists the new employee")
	_check(String(employees_app.call("get_employee_details_text")).contains("Energy"), "staff details show energy and morale")
	var recruit_role: EmployeeRole = EmployeeManager.get_role(recruit.role_id)
	var support_effect: String = recruit_role.support_effects.keys()[0]
	var effect_before: float = GameEffects.get_total(support_effect)
	(employees_app.get_node("%AssignmentList") as ItemList).item_selected.emit(1)
	await _frames(1)
	_check(recruit.assignment_id == "support" and GameEffects.get_total(support_effect) > effect_before, "clicking a task assigns it; supporting you gives a bonus at once")
	(employees_app.get_node("%AssignmentList") as ItemList).item_selected.emit(0)
	await _frames(1)
	_check(recruit.assignment_id == "client_work", "and they can be put back on client work")

	var expected_income: int = EmployeeManager.get_expected_income(recruit)
	var money_before_day: int = EconomyManager.money
	var toasts_before_day: int = toasts.get_total_shown()
	OrganizationManager.advance_time(OrganizationManager.get_seconds_until_next_day() + 0.01)
	await _frames(2)
	var day_net: int = expected_income - recruit.salary - OrganizationManager.get_daily_rent() - HardwareManager.get_daily_power_cost()
	_check(HardwareManager.get_daily_power_cost() > 0 and String(organization.call("get_report_text")).is_empty() == false, "the upgraded CPU has an electricity cost")
	_check(OrganizationManager.day == 1 and EconomyManager.money == money_before_day + day_net, "when the business day ends, staff income, salary and rent are settled")
	_check(String(organization.call("get_report_text")).contains("Client work") and String(organization.call("get_report_text")).contains("Salaries"), "the daily report lists income and costs")
	_check(toasts.get_total_shown() > toasts_before_day, "the day's result is announced")
	_check(String(finance.call("get_income_text")).contains("Maintenance Contract") and String(finance.call("get_expense_text")).contains("Salary"), "finance shows staff income and salaries")
	_check(PackedStringArray(employees_app.call("get_candidate_ids")) != candidate_ids, "new candidates apply the next day")

	_check(String(organization.call("get_report_text")).contains("Electricity"), "the daily report lists electricity")

	# --- Research: a project, a product, and an event ---
	desktop.open_app("research")
	await _frames(2)
	var research_app: Node = desktop.get_app_content("research")
	research_app.call("select_project_id", "log_correlation")
	_check(_button(research_app, "StartResearchButton").disabled and String(research_app.call("get_project_details_text")).contains("Requires Automated Triage"), "a project with an unfinished prerequisite is blocked, with the reason")
	research_app.call("select_project_id", "automated_triage")
	var triage: ResearchProject = ResearchManager.get_project("automated_triage")
	var money_before_research: int = EconomyManager.money
	_button(research_app, "StartResearchButton").pressed.emit()
	await _frames(2)
	_check(ResearchManager.get_active_project() == triage and EconomyManager.money == money_before_research - triage.cost, "Start Research pays the cost and starts the project")
	_check(String(research_app.call("get_active_text")).contains("Automated Triage"), "the app shows the project in progress")
	var time_bonus_before: float = GameEffects.get_total(GameEffects.CONTRACT_TIME)
	ResearchManager.advance_time(ResearchManager.get_minutes_remaining() * 60.0 + 1.0)
	await _frames(2)
	_check(ResearchManager.is_completed("automated_triage") and GameEffects.get_total(GameEffects.CONTRACT_TIME) > time_bonus_before, "the project finishes with time and its technology applies")
	_check(String(research_app.call("get_active_text")).contains("1 of"), "the app counts the finished project")

	research_app.call("select_project_id", "log_correlation")
	_button(research_app, "StartResearchButton").pressed.emit()
	await _frames(1)
	ResearchManager.advance_time(ResearchManager.get_minutes_remaining() * 60.0 + 1.0)
	await _frames(2)
	research_app.call("show_view", 1)
	research_app.call("select_product_id", "vault_keeper")
	_check(_button(research_app, "DevelopButton").disabled and String(research_app.call("get_product_details_text")).contains("Requires research"), "a product whose research is missing cannot be developed")
	research_app.call("select_product_id", "log_lens")
	EconomyManager.add_money(2000, TransactionCategory.OTHER, "Flow test capital")
	await _frames(1)
	var log_lens: ProductDefinition = ProductManager.get_product("log_lens")
	var money_before_product: int = EconomyManager.money
	_button(research_app, "DevelopButton").pressed.emit()
	await _frames(2)
	_check(ProductManager.get_status("log_lens") == ProductManager.Status.DEVELOPING and EconomyManager.money == money_before_product - log_lens.development_cost, "Develop pays the budget and starts development")
	var guard_days: int = 0
	while not ProductManager.is_released("log_lens") and guard_days < 40:
		OrganizationManager.end_day()
		guard_days += 1
	await _frames(2)
	_check(ProductManager.is_released("log_lens"), "the product is released after enough business days")
	OrganizationManager.end_day()
	await _frames(2)
	_check(String(organization.call("get_report_text")).contains("Software sales"), "a released product brings in software sales")
	_check(String(research_app.call("get_product_details_text")).contains("Earned so far"), "the app shows what the product has earned")
	_check(String(finance.call("get_income_text")).contains("Software Sales") and String(finance.call("get_expense_text")).contains("Research"), "finance shows software sales and research costs")

	var event_popup: EventPopup = session.get_node("%EventPopup")
	_check(not event_popup.is_open(), "no event dialog at first")
	_check(EventManager.trigger_event("new_client"), "a world event occurs")
	await _frames(2)
	_check(event_popup.is_open() and get_tree().paused, "the event dialog opens and pauses the game")
	_check(event_popup.get_choice_buttons().size() == 2 and _label(event_popup, "EventTitle").text == "NEW CLIENT OPPORTUNITY", "the dialog shows the event and its choices")
	await _tap(&"ui_cancel")
	_check(event_popup.is_open() and not pause_menu.visible, "Esc cannot dodge the decision or open the pause menu under it")
	var money_before_event: int = EconomyManager.money
	event_popup.get_choice_buttons()[0].pressed.emit()
	await _frames(2)
	_check(EconomyManager.money == money_before_event + 350 and not event_popup.get_outcome_text().is_empty(), "choosing applies the consequences and shows the outcome")
	_button(event_popup, "EventContinueButton").pressed.emit()
	await _frames(2)
	_check(not event_popup.is_open() and not get_tree().paused, "Continue closes the dialog and resumes the game")

	_button(employees_app, "DismissButton").pressed.emit()
	await _frames(1)
	_check(EmployeeManager.get_employee_count() == 1 and _button(employees_app, "DismissButton").text.contains("again"), "Dismiss asks for a second click")
	var company_day: int = OrganizationManager.day
	var staff_snapshot: Dictionary = recruit.to_dictionary()

	# Leave one contract in progress to prove it survives saving.
	contracts.call("select_offer", 0)
	_button(contracts, "AcceptButton").pressed.emit()
	await _frames(2)
	await _solve_current(runner)
	var saved_template: String = ContractManager.get_active_offer()["template_id"]
	var saved_stage: int = ContractManager.get_stage_index()
	_check(saved_stage == 1, "a contract is left in progress on stage 2")
	expected_money = EconomyManager.money
	var expected_level: int = ProgressionManager.level
	var expected_white: int = ReputationManager.white_reputation
	var expected_heat: float = ReputationManager.heat

	# Windows survive leaving the computer.
	var open_before: PackedStringArray = desktop.get_open_app_ids()

	# Esc logs off instead of opening the pause menu.
	await _tap(&"ui_cancel")
	_check(not computer.visible, "Esc closes the computer")
	_check(not pause_menu.visible and not get_tree().paused, "Esc at the computer does not pause")
	_check(hud.visible, "HUD returns after logging off")
	_check(prompt.get_prompt() == "Use Computer", "prompt returns after logging off")
	_check(_label(hud, "HudMoneyLabel").text == FormatUtils.money(expected_money), "HUD money updated")
	_check(_label(hud, "HudLevelLabel").text.begins_with("LV %d" % ProgressionManager.level), "HUD level updated")

	# Log Off button works too.
	await _tap(Player.ACTION_INTERACT)
	_check(computer.visible, "computer reopens")
	_check(desktop.get_open_app_ids() == open_before, "windows are still open after returning to the computer")
	_button(desktop, "LogOffButton").pressed.emit()
	await _frames(1)
	_check(not computer.visible and player.input_enabled, "Log Off returns control to the player")

	# Walking away clears the prompt.
	player.teleport(IsoUtils.grid_to_screen(PARKING_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt().is_empty(), "prompt disappears away from objects")
	await _tap(Player.ACTION_INTERACT)
	_check(not computer.visible, "interact does nothing with no target")

	# --- Interaction: inspect ---
	player.teleport(IsoUtils.grid_to_screen(STORAGE_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Open Storage", "prompt appears near the storage")
	var toast_count: int = toasts.get_total_shown()
	await _tap(Player.ACTION_INTERACT)
	_check(toasts.get_total_shown() == toast_count + 1, "inspecting shows a message")

	# --- Interaction: bed rests and saves ---
	EconomyManager.add_money(40, TransactionCategory.OTHER, "Flow test")
	expected_money += 40
	player.teleport(IsoUtils.grid_to_screen(BED_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Rest (Save Game)", "prompt appears near the bed")
	toast_count = toasts.get_total_shown()
	await _tap(Player.ACTION_INTERACT)
	_check(SaveDataReader.get_int(SaveManager.get_slot_info(1).summary, "money") == expected_money, "resting saves the game")
	_check(toasts.get_total_shown() == toast_count + 1, "resting shows a save toast")

	# --- The office ---
	player.teleport(IsoUtils.grid_to_screen(DOOR_SPOT))
	await _physics_frames(5)
	await _frames(1)
	await _tap(Player.ACTION_INTERACT)
	await _frames(2)
	var office := world.get_room() as OfficeRoom
	_check(world.get_room_id() == GameWorld.ROOM_OFFICE and office != null, "with rented desks the door leads to the office")
	_check(PlayerManager.world_room == GameWorld.ROOM_OFFICE, "the profile knows the player is at the office")
	_check(office.get_desk_count() == OrganizationManager.get_desk_capacity(), "the office has a desk for every place")
	_check(office.get_staff_names() == PackedStringArray([recruit.display_name]), "the employee you hired is sitting there")
	player = world.get_player()
	player.teleport(office.get_desk_approach_position(0))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Talk to %s" % recruit.display_name, "you can walk up to an employee")
	toast_count = toasts.get_total_shown()
	await _tap(Player.ACTION_INTERACT)
	_check(toasts.get_total_shown() == toast_count + 1, "talking to them tells you how they are doing")
	var office_computer: IsoNode = office.get_node("%Props/Computer")
	player.teleport(IsoUtils.grid_to_screen(office_computer.grid_position + Vector2(0.0, 0.95)))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Use Computer", "the office has a workstation")
	await _tap(Player.ACTION_INTERACT)
	_check(computer.visible and desktop.get_open_app_ids() == open_before, "it opens the same desktop, windows and all")
	await _tap(&"ui_cancel")
	for direction: StringName in [Player.ACTION_LEFT, Player.ACTION_UP]:
		Input.action_press(direction)
	await _physics_frames(200)
	for direction: StringName in [Player.ACTION_LEFT, Player.ACTION_UP]:
		Input.action_release(direction)
	_check((office.get_node("%Shell") as RoomShell).contains_point(player.position), "the office walls hold too")
	player.teleport(IsoUtils.grid_to_screen(DOOR_SPOT))
	await _physics_frames(5)
	await _frames(1)
	_check(prompt.get_prompt() == "Go Home", "the office door leads home")
	await _tap(Player.ACTION_INTERACT)
	await _frames(2)
	_check(world.get_room_id() == GameWorld.ROOM_APARTMENT and PlayerManager.world_room == GameWorld.ROOM_APARTMENT, "and takes you back to the apartment")
	player = world.get_player()

	# --- The ending screen ---
	var ending: EndingPopup = session.get_node("%EndingPopup")
	ending.open()
	await _frames(1)
	_check(ending.is_open() and get_tree().paused and ending.get_stats_text().contains("Flow Test Systems"), "the ending screen summarises the run and pauses the game")
	_button(ending, "EndingContinueButton").pressed.emit()
	await _frames(1)
	_check(not ending.is_open() and not get_tree().paused, "Keep Playing returns to the game")

	# --- Playtime, HUD save, pause ---
	var playtime_before: float = PlayerManager.playtime_seconds
	await _frames(10)
	_check(PlayerManager.playtime_seconds > playtime_before, "playtime advances in game")

	toast_count = toasts.get_total_shown()
	_button(hud, "SaveButton").pressed.emit()
	await _frames(1)
	_check(toasts.get_total_shown() == toast_count + 1, "HUD save shows a toast")

	await _tap(&"ui_cancel")
	_check(pause_menu.visible and get_tree().paused, "Esc opens the pause menu in the world")
	var paused_playtime: float = PlayerManager.playtime_seconds
	before = player.position
	Input.action_press(Player.ACTION_RIGHT)
	await _frames(10)
	Input.action_release(Player.ACTION_RIGHT)
	_check(is_equal_approx(PlayerManager.playtime_seconds, paused_playtime), "playtime frozen while paused")
	_check(player.position.is_equal_approx(before), "player frozen while paused")
	_button(pause_menu, "ResumeButton").pressed.emit()
	await _frames(1)
	_check(not pause_menu.visible and not get_tree().paused, "resume unpauses")

	# Unsaved change and a new position, then Save & Exit must persist both.
	EconomyManager.add_money(1000, TransactionCategory.CONTRACT, "Flow test payout")
	expected_money += 1000
	var parked_position: Vector2 = IsoUtils.grid_to_screen(PARKING_SPOT)
	player.teleport(parked_position)
	await _physics_frames(3)
	_button(hud, "MenuButton").pressed.emit()
	await _frames(1)
	_check(pause_menu.visible, "HUD menu button opens the pause menu")
	var expected_mail: int = MailManager.get_message_count()
	var expected_unread: int = MailManager.get_unread_count()
	_button(pause_menu, "SaveAndMenuButton").pressed.emit()
	await GameManager.scene_transition_finished
	await _frames(2)

	# --- Back in the menu ---
	menu = get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "returned to main menu")
	_check(not get_tree().paused, "tree unpaused after leaving")
	_check(not GameManager.is_in_game() and not SaveManager.has_active_session(), "session ended")
	_check(EconomyManager.money == 0 and ProgressionManager.level == 1, "live state cleared in menu")
	_check(not PlayerManager.has_world_position, "world position cleared in menu")
	_check(not _button(menu, "ContinueButton").disabled, "Continue enabled with a save")
	_check(not _button(menu, "LoadGameButton").disabled, "Load Game enabled with a save")

	# New Game on an occupied slot asks before overwriting.
	_button(menu, "NewGameButton").pressed.emit()
	await _frames(2)
	first_card = menu.get_node("%SlotList").get_child(0)
	_check(_button(first_card, "SelectButton").text == "Overwrite", "occupied slot offers Overwrite")
	_button(first_card, "SelectButton").pressed.emit()
	await _frames(1)
	var confirm: ConfirmPopup = menu.get_node("%ConfirmPopup")
	_check(confirm.visible, "overwrite needs confirmation")
	_button(confirm, "CancelButton").pressed.emit()
	await _frames(1)
	_check(not confirm.visible and _control(menu, "SlotPanel").visible, "cancel keeps the save")
	_button(menu, "SlotBackButton").pressed.emit()
	await _frames(1)

	# --- Continue ---
	_button(menu, "ContinueButton").pressed.emit()
	await GameManager.scene_transition_finished
	await _frames(2)
	session = get_tree().current_scene
	_check(session != null and session.name == "GameSession", "Continue enters the game")
	_check(PlayerManager.hacker_alias == TEST_ALIAS, "alias restored")
	_check(EconomyManager.money == expected_money, "money restored (incl. Save & Exit change)")
	_check(ProgressionManager.level == expected_level, "level restored")
	_check(ReputationManager.white_reputation == expected_white, "reputation restored")
	_check(is_equal_approx(ReputationManager.heat, expected_heat), "heat restored")
	_check(PlayerManager.playtime_seconds > 0.0, "playtime restored")
	world = session.get_node("%GameWorld")
	player = world.get_player()
	_check(player.position.distance_to(parked_position) < 2.0, "player position restored")
	_check(MailManager.get_message_count() == expected_mail and MailManager.get_unread_count() == expected_unread, "inbox restored")
	_check(ContractManager.has_active_contract() and ContractManager.get_active_offer()["template_id"] == saved_template, "contract in progress restored")
	_check(ContractManager.get_stage_index() == saved_stage, "contract stage restored")
	_check(ContractManager.get_completed_count() == 1 and ContractManager.get_failed_count() == 2, "contract counters restored")
	_check(HardwareManager.is_installed("cpu_quadra") and HardwareManager.get_spare_items().size() == 1, "hardware restored")
	_check(OrganizationManager.is_founded() and OrganizationManager.company_name == "Flow Test Systems" and OrganizationManager.get_office().id == "shared_desk", "company and office restored")
	_check(OrganizationManager.day >= company_day and OrganizationManager.get_reports().size() >= 1, "business day and reports restored")
	_check(ResearchManager.is_completed("automated_triage") and ResearchManager.is_completed("log_correlation") and ProductManager.is_released("log_lens"), "research and products restored")
	_check(EventManager.get_history().size() == 1, "event history restored")
	_check(StoryManager.get_chapter_index() == 1 and world.get_room_id() == GameWorld.ROOM_APARTMENT, "story chapter and room restored")
	_check(EmployeeManager.get_employee_count() == 1 and EmployeeManager.get_employees()[0].display_name == staff_snapshot["name"] and EmployeeManager.get_employees()[0].role_id == staff_snapshot["role"], "staff restored")
	_check(SkillManager.get_level("net_fast_routes") == 1 and SkillManager.get_spent_points() == 1, "skills restored")
	desktop = (session.get_node("%ComputerScreen") as ComputerScreen).get_desktop()
	desktop.open_app("contracts")
	await _frames(2)
	contracts = desktop.get_app_content("contracts")
	runner = contracts.call("get_runner")
	_check(int(contracts.call("get_view")) == 1 and runner.get_puzzle() != null, "the Contracts app resumes the contract in progress")
	desktop.close_app("contracts")
	_check(desktop.get_open_app_ids().is_empty(), "a loaded session starts with a clean desktop")
	_check(desktop.get_icon("mail").get_badge() == expected_unread, "mail badge restored")
	desktop.open_app("dashboard")
	await _frames(2)
	dashboard = desktop.get_app_content("dashboard")
	_check(_card(dashboard, "BalanceCard").get_value_text() == FormatUtils.money(expected_money), "dashboard shows loaded money")
	_check(_label(dashboard, "AliasLabel").text == TEST_ALIAS, "dashboard shows loaded alias")

	GameManager.return_to_main_menu(true)
	await GameManager.scene_transition_finished
	await _frames(2)

	# --- Load Game list, then delete ---
	menu = get_tree().current_scene
	_button(menu, "LoadGameButton").pressed.emit()
	await _frames(2)
	slot_list = menu.get_node("%SlotList")
	first_card = slot_list.get_child(0)
	var second_card: SaveSlotCard = slot_list.get_child(1)
	_check(not _button(first_card, "SelectButton").disabled, "saved slot can be loaded")
	_check(_button(second_card, "SelectButton").disabled, "empty slot cannot be loaded")
	_check(_label(first_card, "DetailLabel").text.contains(TEST_ALIAS), "slot card shows summary")
	_button(first_card, "DeleteButton").pressed.emit()
	await _frames(1)
	confirm = menu.get_node("%ConfirmPopup")
	_check(confirm.visible, "delete needs confirmation")
	_button(confirm, "ConfirmButton").pressed.emit()
	await _frames(2)
	_check(SaveManager.get_slot_info(1).is_empty(), "slot deleted from disk")
	_check(_control(menu, "MainPanel").visible, "menu returns to main page when no saves remain")
	_check(_button(menu, "ContinueButton").disabled, "Continue disabled again")


# --- Helpers ----------------------------------------------------------------

func _button(owner_node: Node, unique_name: String) -> Button:
	return owner_node.get_node("%" + unique_name) as Button


func _label(owner_node: Node, unique_name: String) -> Label:
	return owner_node.get_node("%" + unique_name) as Label


func _control(owner_node: Node, unique_name: String) -> Control:
	return owner_node.get_node("%" + unique_name) as Control


func _card(owner_node: Node, unique_name: String) -> StatCard:
	return owner_node.get_node("%" + unique_name) as StatCard


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


## Sends a real press and release of an input action through the viewport,
## exactly as a key press would arrive.
func _tap(action: StringName) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = is_pressed
		Input.parse_input_event(event)
		await _frames(2)


## Makes one wrong move in the current puzzle, through the puzzle screen.
func _make_mistake(runner: MissionRunner) -> void:
	var puzzle: MissionPuzzle = runner.get_puzzle()
	var logic: PuzzleLogic = puzzle.get_logic()
	if logic is SequencePuzzleLogic:
		var sequence := logic as SequencePuzzleLogic
		for index: int in sequence.get_item_count():
			if index != sequence.get_next_correct_index() and not sequence.is_picked(index):
				puzzle.call("pick", index)
				break
	elif logic is CipherPuzzleLogic:
		puzzle.call("set_shift", (logic as CipherPuzzleLogic).get_correct_shift() + 1)
		puzzle.call("submit")
	elif logic is SpotPuzzleLogic:
		for index: int in puzzle.call("get_selected"):
			puzzle.call("toggle", index)
		puzzle.call("submit") # nothing selected
	elif logic is MatchPuzzleLogic:
		var matching := logic as MatchPuzzleLogic
		for index: int in matching.get_options().size():
			if index != matching.get_correct_index() and not puzzle.call("is_option_ruled_out", index):
				puzzle.call("pick", index)
				break
	await _frames(3)


## Solves the current puzzle through the puzzle screen, as a player would.
func _solve_current(runner: MissionRunner) -> void:
	var puzzle: MissionPuzzle = runner.get_puzzle()
	var logic: PuzzleLogic = puzzle.get_logic()
	if logic is SequencePuzzleLogic:
		while not logic.is_solved():
			puzzle.call("pick", (logic as SequencePuzzleLogic).get_next_correct_index())
	elif logic is CipherPuzzleLogic:
		puzzle.call("set_shift", (logic as CipherPuzzleLogic).get_correct_shift())
		puzzle.call("submit")
	elif logic is SpotPuzzleLogic:
		var spot := logic as SpotPuzzleLogic
		var selected: Array = puzzle.call("get_selected")
		for index: int in spot.get_line_count():
			if spot.is_anomaly(index) != selected.has(index):
				puzzle.call("toggle", index)
		puzzle.call("submit")
	elif logic is MatchPuzzleLogic:
		while not logic.is_solved():
			puzzle.call("pick", (logic as MatchPuzzleLogic).get_correct_index())
	await _frames(3)


## Sends a left click at a viewport position through the normal input
## pipeline. Pushed in viewport coordinates so the result does not depend on
## the size of the (headless) OS window.
func _click(at: Vector2) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = at
		event.global_position = at
		get_tree().root.push_input(event, true)
		await _frames(2)


func _release_all_actions() -> void:
	for action: StringName in [
		Player.ACTION_LEFT, Player.ACTION_RIGHT, Player.ACTION_UP, Player.ACTION_DOWN,
	]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % description)
	else:
		_failed += 1
		printerr("[FAIL] %s" % description)


func _on_timeout() -> void:
	printerr("[FAIL] flow test timed out after %.0f seconds" % TIMEOUT_SECONDS)
	get_tree().quit(1)


func _clean_test_directory() -> void:
	var directory := DirAccess.open(TEST_SAVE_DIRECTORY)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
