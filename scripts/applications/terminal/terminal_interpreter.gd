class_name TerminalInterpreter
extends RefCounted
## Command interpreter of the in-game terminal.
##
## Every command is fictional: it reads game state or the virtual file
## system and returns text. Nothing here runs real programs, opens real
## files or touches a network. It has no UI; the Terminal scene displays
## whatever execute() returns.

signal clear_requested
signal open_app_requested(app_id: String)
signal exit_requested

const MAX_HISTORY: int = 50


## Output of one command.
class Result:
	extends RefCounted
	var lines: PackedStringArray = []
	var is_error: bool = false

	static func ok(text_lines: PackedStringArray = []) -> Result:
		var result := Result.new()
		result.lines = text_lines
		return result

	static func error(message: String) -> Result:
		var result := Result.new()
		result.lines = [message]
		result.is_error = true
		return result


var filesystem: VirtualFileSystem
var app_definitions: Array[AppDefinition] = []
var cwd: String = VirtualFileSystem.HOME

## Command name -> {handler: Callable, usage: String, summary: String}.
var _commands: Dictionary = {}
var _history: PackedStringArray = []


func _init() -> void:
	_register("help", _cmd_help, "help", "List every command")
	_register("status", _cmd_status, "status", "Show your profile")
	_register("whoami", _cmd_whoami, "whoami", "Show your alias")
	_register("balance", _cmd_balance, "balance", "Show your money")
	_register("rep", _cmd_rep, "rep", "Show reputation and heat")
	_register("uptime", _cmd_uptime, "uptime", "Show total play time")
	_register("date", _cmd_date, "date", "Show the system date and time")
	_register("pwd", _cmd_pwd, "pwd", "Show the current folder")
	_register("ls", _cmd_ls, "ls [path]", "List a folder")
	_register("cd", _cmd_cd, "cd [path]", "Change folder")
	_register("cat", _cmd_cat, "cat <file>", "Print a text file")
	_register("apps", _cmd_apps, "apps", "List applications")
	_register("open", _cmd_open, "open <app>", "Launch an application")
	_register("mail", _cmd_mail, "mail", "Summarise your inbox")
	_register("contracts", _cmd_contracts, "contracts", "Show the contract board")
	_register("hardware", _cmd_hardware, "hardware", "Show installed hardware")
	_register("skills", _cmd_skills, "skills", "Show learned skills")
	_register("company", _cmd_company, "company", "Show your company and staff")
	_register("research", _cmd_research, "research", "Show research and products")
	_register("story", _cmd_story, "story", "Show your current objectives")
	_register("echo", _cmd_echo, "echo <text>", "Print text")
	_register("history", _cmd_history, "history", "Show previous commands")
	_register("clear", _cmd_clear, "clear", "Clear the screen")
	_register("exit", _cmd_exit, "exit", "Close the terminal")


## Runs one line of input and returns what to print.
func execute(line: String) -> Result:
	var trimmed: String = line.strip_edges()
	if trimmed.is_empty():
		return Result.ok()
	_history.append(trimmed)
	if _history.size() > MAX_HISTORY:
		_history = _history.slice(_history.size() - MAX_HISTORY)

	var parts: PackedStringArray = trimmed.split(" ", false)
	var command_name: String = parts[0].to_lower()
	var arguments: PackedStringArray = parts.slice(1)
	if not _commands.has(command_name):
		return Result.error("%s: command not found. Type 'help' for a list." % command_name)
	var handler: Callable = _commands[command_name]["handler"]
	return handler.call(arguments)


func get_prompt() -> String:
	var shown_path: String = cwd
	if shown_path == VirtualFileSystem.HOME or shown_path.begins_with(VirtualFileSystem.HOME + "/"):
		shown_path = VirtualFileSystem.HOME_SHORTCUT + shown_path.substr(VirtualFileSystem.HOME.length())
	return "%s@empire:%s$" % [PlayerManager.hacker_alias.to_lower(), shown_path]


func get_history() -> PackedStringArray:
	return _history


func get_command_names() -> PackedStringArray:
	return PackedStringArray(_commands.keys())


func _register(command_name: String, handler: Callable, usage: String, summary: String) -> void:
	_commands[command_name] = {"handler": handler, "usage": usage, "summary": summary}


# --- Commands ---------------------------------------------------------------

func _cmd_help(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = ["Available commands:"]
	for command_name: String in _commands:
		var command: Dictionary = _commands[command_name]
		lines.append("  %s %s" % [String(command["usage"]).rpad(14), command["summary"]])
	return Result.ok(lines)


func _cmd_status(_arguments: PackedStringArray) -> Result:
	var xp_text: String = "max level" if ProgressionManager.is_max_level() else "%d / %d XP" % [
		ProgressionManager.current_xp, ProgressionManager.get_xp_required()
	]
	return Result.ok([
		"alias        %s" % PlayerManager.hacker_alias,
		"rank         %s" % ProgressionManager.get_rank_name(),
		"level        %d (%s)" % [ProgressionManager.level, xp_text],
		"balance      %s" % FormatUtils.money(EconomyManager.money),
		"reputation   white %d, underground %d" % [
			ReputationManager.white_reputation, ReputationManager.underground_reputation
		],
		"heat         %d / %d" % [roundi(ReputationManager.heat), roundi(ReputationManager.CONFIG.max_heat)],
		"uptime       %s" % FormatUtils.duration(PlayerManager.playtime_seconds),
	])


func _cmd_whoami(_arguments: PackedStringArray) -> Result:
	return Result.ok([PlayerManager.hacker_alias])


func _cmd_balance(_arguments: PackedStringArray) -> Result:
	return Result.ok([
		"balance  %s" % FormatUtils.money(EconomyManager.money),
		"earned   %s" % FormatUtils.money(EconomyManager.total_earned),
		"spent    %s" % FormatUtils.money(EconomyManager.total_spent),
	])


func _cmd_rep(_arguments: PackedStringArray) -> Result:
	return Result.ok([
		"white        %d" % ReputationManager.white_reputation,
		"underground  %d" % ReputationManager.underground_reputation,
		"heat         %d / %d" % [roundi(ReputationManager.heat), roundi(ReputationManager.CONFIG.max_heat)],
	])


func _cmd_uptime(_arguments: PackedStringArray) -> Result:
	return Result.ok(["up %s" % FormatUtils.duration(PlayerManager.playtime_seconds)])


func _cmd_date(_arguments: PackedStringArray) -> Result:
	return Result.ok([FormatUtils.local_timestamp(int(Time.get_unix_time_from_system()))])


func _cmd_pwd(_arguments: PackedStringArray) -> Result:
	return Result.ok([cwd])


func _cmd_ls(arguments: PackedStringArray) -> Result:
	if filesystem == null:
		return Result.error("ls: no file system mounted")
	var target: String = filesystem.normalize_path(arguments[0] if not arguments.is_empty() else ".", cwd)
	if filesystem.is_file(target):
		return Result.ok([target.get_file()])
	if not filesystem.is_directory(target):
		return Result.error("ls: %s: no such file or folder" % target)
	var lines: PackedStringArray = []
	for entry: Dictionary in filesystem.list_directory(target):
		lines.append("%s/" % entry["name"] if entry["is_directory"] else String(entry["name"]))
	if lines.is_empty():
		lines.append("(empty)")
	return Result.ok(lines)


func _cmd_cd(arguments: PackedStringArray) -> Result:
	if filesystem == null:
		return Result.error("cd: no file system mounted")
	var target: String = filesystem.normalize_path(
		arguments[0] if not arguments.is_empty() else VirtualFileSystem.HOME, cwd
	)
	if filesystem.is_file(target):
		return Result.error("cd: %s: not a folder" % target)
	if not filesystem.is_directory(target):
		return Result.error("cd: %s: no such folder" % target)
	cwd = target
	return Result.ok()


func _cmd_cat(arguments: PackedStringArray) -> Result:
	if filesystem == null:
		return Result.error("cat: no file system mounted")
	if arguments.is_empty():
		return Result.error("usage: cat <file>")
	var target: String = filesystem.normalize_path(arguments[0], cwd)
	if filesystem.is_directory(target):
		return Result.error("cat: %s: is a folder" % target)
	if not filesystem.is_file(target):
		return Result.error("cat: %s: no such file" % target)
	return Result.ok(filesystem.read_file(target).split("\n"))


func _cmd_apps(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = []
	for definition: AppDefinition in app_definitions:
		lines.append("  %s %s" % [
			definition.id.rpad(14), definition.title if definition.is_available() else "(not installed)"
		])
	if lines.is_empty():
		return Result.error("apps: application list unavailable")
	return Result.ok(lines)


func _cmd_open(arguments: PackedStringArray) -> Result:
	if arguments.is_empty():
		return Result.error("usage: open <app>   (see 'apps')")
	var wanted: String = arguments[0].to_lower()
	for definition: AppDefinition in app_definitions:
		if definition.id != wanted:
			continue
		if not definition.is_available():
			return Result.error("open: %s is not installed" % wanted)
		open_app_requested.emit(definition.id)
		return Result.ok(["Launching %s..." % definition.title])
	return Result.error("open: unknown application '%s'" % wanted)


func _cmd_mail(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = [
		"%d message(s), %d unread" % [MailManager.get_message_count(), MailManager.get_unread_count()]
	]
	for message: Dictionary in MailManager.get_messages():
		lines.append("  %s %s" % ["*" if not message["read"] else " ", message["subject"]])
	return Result.ok(lines)


func _cmd_contracts(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = []
	var active: ContractDefinition = ContractManager.get_active_definition()
	if active != null:
		lines.append("in progress: %s (stage %d of %d, %s left)" % [
			active.title, ContractManager.get_stage_index() + 1, active.get_stage_count(),
			FormatUtils.duration(ContractManager.get_time_remaining()).substr(3),
		])
	else:
		lines.append("in progress: none")
	lines.append("on the board:")
	for offer: Dictionary in ContractManager.get_board():
		var definition: ContractDefinition = ContractManager.get_definition(offer["template_id"])
		lines.append("  %s %s" % [FormatUtils.money(offer["reward"]).rpad(8), definition.title])
	lines.append("completed %d, failed %d" % [
		ContractManager.get_completed_count(), ContractManager.get_failed_count()
	])
	return Result.ok(lines)


func _cmd_hardware(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = []
	for category: String in HardwareCategory.ALL:
		var item: HardwareItem = HardwareManager.get_installed(category)
		lines.append("%s %s" % [
			HardwareCategory.get_display_name(category).rpad(16),
			"%s (tier %d)" % [item.title, item.tier] if item != null else "-"
		])
	var totals: Dictionary = HardwareManager.get_stat_totals()
	var parts: PackedStringArray = []
	for stat: String in HardwareItem.STATS:
		parts.append("%s %d" % [String(HardwareItem.STAT_NAMES[stat]).to_lower(), roundi(totals[stat])])
	lines.append("totals: %s" % ", ".join(parts))
	return Result.ok(lines)


func _cmd_skills(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = ["skill points: %d available" % SkillManager.get_available_points()]
	for skill: SkillDefinition in SkillManager.get_skills():
		var level: int = SkillManager.get_level(skill.id)
		if level > 0:
			lines.append("  %s %d/%d" % [skill.title.rpad(26), level, skill.max_level])
	if lines.size() == 1:
		lines.append("  no skills learned yet")
	return Result.ok(lines)


func _cmd_company(_arguments: PackedStringArray) -> Result:
	if not OrganizationManager.is_founded():
		return Result.ok(["no company registered. Open the Organization app to found one."])
	var office: OfficeDefinition = OrganizationManager.get_office()
	var lines: PackedStringArray = [
		"%s  (level %d, reputation %d)" % [
			OrganizationManager.company_name, OrganizationManager.company_level, OrganizationManager.reputation
		],
		"office   %s, %d of %d desks, %s a day" % [
			office.title, EmployeeManager.get_employee_count(), office.capacity, FormatUtils.money(office.rent)
		],
		"payroll  %s a day" % FormatUtils.money(EmployeeManager.get_daily_salary_total()),
		"day      %d" % OrganizationManager.day,
	]
	for employee: Employee in EmployeeManager.get_employees():
		var role: EmployeeRole = EmployeeManager.get_role(employee.role_id)
		var assignment: EmployeeAssignment = EmployeeManager.get_assignment(employee.assignment_id)
		lines.append("  %s %s %s" % [
			employee.display_name.rpad(22), (role.title if role != null else "?").rpad(22),
			assignment.title if assignment != null else "idle"
		])
	return Result.ok(lines)


func _cmd_research(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = ["research power %d per minute" % roundi(ResearchManager.get_research_power())]
	var active: ResearchProject = ResearchManager.get_active_project()
	if active != null:
		lines.append("in progress: %s (%d%%)" % [active.title, roundi(ResearchManager.get_progress_ratio() * 100.0)])
	else:
		lines.append("in progress: none")
	for project: ResearchProject in ResearchManager.get_projects():
		if ResearchManager.is_completed(project.id):
			lines.append("  done  %s" % project.title)
	for product: ProductDefinition in ProductManager.get_products():
		if ProductManager.is_released(product.id):
			lines.append("  selling  %s (%s so far)" % [
				product.title, FormatUtils.money(ProductManager.get_total_revenue(product.id))
			])
	return Result.ok(lines)


func _cmd_story(_arguments: PackedStringArray) -> Result:
	if StoryManager.is_story_complete():
		return Result.ok(["the story is complete. The empire is yours."])
	var chapter: Dictionary = StoryManager.get_current_chapter()
	var lines: PackedStringArray = [
		"chapter %d of %d: %s" % [
			StoryManager.get_chapter_index() + 1, StoryManager.get_chapter_count(), chapter.get("title", "")
		],
		String(chapter.get("summary", "")),
	]
	for objective: Dictionary in StoryManager.get_objectives():
		lines.append("  %s %s (%d/%d)" % [
			"[x]" if objective["done"] else "[ ]", objective["text"], objective["current"], objective["target"]
		])
	return Result.ok(lines)


func _cmd_echo(arguments: PackedStringArray) -> Result:
	return Result.ok([" ".join(arguments)])


func _cmd_history(_arguments: PackedStringArray) -> Result:
	var lines: PackedStringArray = []
	for index: int in _history.size():
		lines.append("%3d  %s" % [index + 1, _history[index]])
	return Result.ok(lines)


func _cmd_clear(_arguments: PackedStringArray) -> Result:
	clear_requested.emit()
	return Result.ok()


func _cmd_exit(_arguments: PackedStringArray) -> Result:
	exit_requested.emit()
	return Result.ok()
