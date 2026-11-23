extends Node
## Visual check: opens the real screens in a window and saves PNGs to
## user://screenshots. Must run with a display (not --headless).
## Run: godot --path . res://tests/ScreenshotTour.tscn

const TEST_SAVE_DIRECTORY: String = "user://test_saves_screenshots"
const OUTPUT_DIRECTORY: String = "user://screenshots"
const SETTLE_SECONDS: float = 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.set_save_directory(TEST_SAVE_DIRECTORY)
	_clean(TEST_SAVE_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	await _run()
	_clean(TEST_SAVE_DIRECTORY)
	print("Screenshots saved to: %s" % ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	get_tree().quit()


func _run() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
	await _capture("01_main_menu")

	var menu: Node = get_tree().current_scene
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	await _capture("02_slot_select")

	var first_card: Node = menu.get_node("%SlotList").get_child(0)
	(first_card.get_node("%SelectButton") as Button).pressed.emit()
	(menu.get_node("%AliasEdit") as LineEdit).text = "Zero_Cool"
	await _capture("03_new_game_form")

	(menu.get_node("%StartButton") as Button).pressed.emit()
	await GameManager.scene_transition_finished
	var session: Node = get_tree().current_scene
	var world: GameWorld = session.get_node("%GameWorld")
	var player: Player = world.get_player()
	await _capture("04_world")

	player.teleport(IsoUtils.grid_to_screen(Vector2(0.6, 0.8)))
	await _capture("05_behind_cabinet")
	player.teleport(IsoUtils.grid_to_screen(Vector2(2.7, 6.4)))
	await _capture("06_bed_prompt")
	player.teleport(IsoUtils.grid_to_screen(Vector2(3.0, 1.45)))
	await _capture("07_computer_prompt")

	var computer: ComputerScreen = session.get_node("%ComputerScreen")
	var desktop: HackerDesktop = computer.get_desktop()
	computer.open()
	await _capture("08_desktop_empty")

	desktop.open_app("devtools")
	var debug_buttons: Node = desktop.get_app_content("devtools").get_node("%ButtonList")
	for index: int in [0, 1, 2, 3, 4, 5, 5, 5, 5]:
		(debug_buttons.get_child(index) as Button).pressed.emit()
	desktop.close_app("devtools")
	desktop.open_app("dashboard")
	await _capture("09_dashboard_window")

	desktop.open_app("finance")
	desktop.open_app("mail")
	desktop.get_app_content("mail").call("select_message", 2)
	await _capture("10_finance_mail")

	desktop.minimize_app("dashboard")
	desktop.minimize_app("finance")
	desktop.minimize_app("mail")
	desktop.open_app("network")
	desktop.get_app_content("network").call("select_node", "darknode_bbs")
	desktop.open_app("files")
	desktop.get_app_content("files").call("open_entry", 1)
	desktop.open_app("terminal")
	for command: String in ["help", "status", "cd /docs", "ls", "contracts"]:
		desktop.get_app_content("terminal").call("submit_command", command)
	await _capture("11_network_files_terminal")

	for app_id: String in ["network", "files", "terminal"]:
		desktop.minimize_app(app_id)
	EconomyManager.add_money(9000, TransactionCategory.DEBUG, "Tour funds")
	ProgressionManager.add_xp(4000, "tour")
	desktop.open_app("marketplace")
	desktop.get_app_content("marketplace").call("select_item_id", "cpu_hexon")
	desktop.get_app_content("marketplace").call("buy_selected")
	desktop.get_app_content("marketplace").call("select_item_id", "ram_16gb")
	await _capture("11a1_marketplace")
	desktop.minimize_app("marketplace")
	desktop.open_app("hardware")
	await _capture("11a2_hardware")
	desktop.minimize_app("hardware")
	desktop.open_app("skills")
	for skill_id: String in ["prog_clean_code", "prog_clean_code", "prog_automation", "sec_auditor", "net_fast_routes"]:
		SkillManager.upgrade(skill_id)
	desktop.get_app_content("skills").call("select_skill", "prog_automation")
	await _capture("11a3_skills")
	desktop.minimize_app("skills")
	desktop.open_app("organization")
	await _capture("11a4_founding")
	OrganizationManager.found_company("Zero Cool Systems")
	OrganizationManager.expand_office()
	for candidate: Employee in EmployeeManager.get_candidates().slice(0, 2):
		EmployeeManager.hire(candidate.id)
	if EmployeeManager.get_employee_count() > 1:
		EmployeeManager.assign(EmployeeManager.get_employees()[1].id, "support")
	OrganizationManager.end_day()
	OrganizationManager.end_day()
	await _capture("11a5_organization")
	desktop.minimize_app("organization")
	desktop.open_app("employees")
	await _capture("11a6_staff")
	desktop.get_app_content("employees").call("show_view", 1)
	await _capture("11a7_recruit")
	desktop.minimize_app("employees")
	desktop.open_app("research")
	var research_app: Node = desktop.get_app_content("research")
	ResearchManager.start_project("automated_triage")
	ResearchManager.add_progress(40.0)
	ResearchManager.start_project("log_correlation")
	ResearchManager.add_progress(90.0)
	ResearchManager.start_project("signature_library")
	ResearchManager.add_progress(25.0)
	await _capture("11a8_research")
	ProductManager.start_development("log_lens")
	for day_index: int in 8:
		OrganizationManager.end_day()
	research_app.call("show_view", 1)
	await _capture("11a9_products")
	desktop.minimize_app("research")
	EventManager.trigger_event("employee_resignation")
	await _capture("11a10_event")
	(session.get_node("%EventPopup") as EventPopup).get_choice_buttons()[0].pressed.emit()
	await _capture("11a11_event_outcome")
	(session.get_node("%EventPopup") as EventPopup).close()
	desktop.open_app("contracts")
	await _capture("11b_contract_board")
	var contracts: Node = desktop.get_app_content("contracts")
	for shot: int in 4:
		contracts.call("select_offer", shot)
		contracts.call("accept_selected")
		await _capture("11c_puzzle_%d" % shot)
		ContractManager.abandon_contract()
		(contracts.call("get_runner") as MissionRunner).dismiss_result()
	computer.close()

	await _capture("11d_objectives_hud")
	world.travel_to(GameWorld.ROOM_OFFICE)
	await _capture("11e_office")
	var office_room := world.get_room() as OfficeRoom
	world.get_player().teleport(office_room.get_desk_approach_position(0))
	await _capture("11f_office_talk")
	EconomyManager.add_money(40000, TransactionCategory.DEBUG, "Tour funds")
	OrganizationManager.add_company_xp(4000)
	OrganizationManager.expand_office()
	OrganizationManager.expand_office()
	for candidate: Employee in EmployeeManager.get_candidates():
		EmployeeManager.hire(candidate.id)
	OrganizationManager.end_day()
	for candidate: Employee in EmployeeManager.get_candidates():
		EmployeeManager.hire(candidate.id)
	world.get_player().teleport(IsoUtils.grid_to_screen(Vector2(6.0, 9.4)))
	await _capture("11g_office_bigger")
	(session.get_node("%EndingPopup") as EndingPopup).open()
	await _capture("11h_ending")
	(session.get_node("%EndingPopup") as EndingPopup).close()
	world.travel_to(GameWorld.ROOM_APARTMENT)

	(session.get_node("%Hud").get_node("%MenuButton") as Button).pressed.emit()
	await _capture("12_pause_menu")
	(session.get_node("%PauseMenu").get_node("%SaveAndMenuButton") as Button).pressed.emit()
	await GameManager.scene_transition_finished

	menu = get_tree().current_scene
	(menu.get_node("%LoadGameButton") as Button).pressed.emit()
	await _capture("13_load_game")


func _capture(file_name: String) -> void:
	await get_tree().create_timer(SETTLE_SECONDS, true).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIRECTORY.path_join(file_name + ".png")
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		printerr("Could not save %s (%s)" % [path, error_string(save_error)])


func _clean(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
