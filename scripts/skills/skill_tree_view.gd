class_name SkillTreeView
extends Control
## The visual skill tree: one column per branch, one button per skill, and
## lines from each skill to the skills it requires. It only displays
## SkillManager's state and reports which skill was clicked.

signal skill_selected(skill_id: String)

const HEADER_HEIGHT: float = 44.0
const ROW_HEIGHT: float = 118.0
const NODE_HEIGHT: float = 80.0
const NODE_MARGIN: float = 6.0
const NODE_FONT_SIZE: int = 14
const MAX_NODE_WIDTH: float = 190.0
const HEADER_FONT_SIZE: int = 13
const BRANCH_COLORS: Dictionary = {
	SkillBranch.PROGRAMMING: Color("00E5FF"),
	SkillBranch.NETWORKING: Color("00FF9C"),
	SkillBranch.CYBERSECURITY: Color("FFB020"),
	SkillBranch.CRYPTOGRAPHY: Color("A855F7"),
	SkillBranch.REVERSE_ENGINEERING: Color("FF4560"),
	SkillBranch.AI_RESEARCH: Color("E5E7EB"),
}

var _buttons: Dictionary = {} # skill id -> Button
var _selected_id: String = ""


func _ready() -> void:
	for skill: SkillDefinition in SkillManager.get_skills():
		var button := Button.new()
		button.theme_type_variation = &"SmallButton"
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override(&"font_size", NODE_FONT_SIZE)
		button.pressed.connect(func() -> void: skill_selected.emit(skill.id))
		add_child(button)
		_buttons[skill.id] = button
	resized.connect(_layout)
	SkillManager.skills_changed.connect(refresh)
	SkillManager.points_changed.connect(func(_available: int) -> void: refresh())
	_layout()
	refresh()


func get_skill_button(skill_id: String) -> Button:
	return _buttons.get(skill_id)


func set_selected(skill_id: String) -> void:
	_selected_id = skill_id
	refresh()


## Updates every node's text and colour from SkillManager.
func refresh() -> void:
	for skill_id: String in _buttons:
		var skill: SkillDefinition = SkillManager.get_skill(skill_id)
		var button: Button = _buttons[skill_id]
		var level: int = SkillManager.get_level(skill_id)
		button.text = "%s\n%d / %d" % [skill.title, level, skill.max_level]
		var color: Color = UIPalette.TEXT
		if SkillManager.is_maxed(skill_id):
			color = UIPalette.ACCENT
		elif level > 0:
			color = UIPalette.PRIMARY
		elif not SkillManager.is_unlocked(skill_id):
			color = Color(UIPalette.TEXT_DIM, 0.55)
		for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(color_name, color)
		button.modulate = Color(1.0, 1.0, 1.0, 1.0 if SkillManager.is_unlocked(skill_id) or level > 0 else 0.6)
	queue_redraw()


func _layout() -> void:
	if size.x <= 0.0:
		return
	var column_width: float = size.x / SkillBranch.ALL.size()
	var node_width: float = minf(MAX_NODE_WIDTH, column_width - NODE_MARGIN * 2.0)
	for skill_id: String in _buttons:
		var skill: SkillDefinition = SkillManager.get_skill(skill_id)
		var column: int = SkillBranch.ALL.find(skill.branch)
		var button: Button = _buttons[skill_id]
		button.size = Vector2(node_width, NODE_HEIGHT)
		button.position = Vector2(
			column * column_width + (column_width - node_width) * 0.5,
			HEADER_HEIGHT + skill.row * ROW_HEIGHT
		)
	queue_redraw()


func _draw() -> void:
	var column_width: float = size.x / SkillBranch.ALL.size()
	var font: Font = ThemeDB.fallback_font
	for column: int in SkillBranch.ALL.size():
		var branch: String = SkillBranch.ALL[column]
		var color: Color = BRANCH_COLORS.get(branch, UIPalette.PRIMARY)
		if font != null:
			draw_string(
				font, Vector2(column * column_width, 22.0), SkillBranch.get_display_name(branch).to_upper(),
				HORIZONTAL_ALIGNMENT_CENTER, column_width, HEADER_FONT_SIZE, color
			)
		draw_line(
			Vector2(column * column_width + NODE_MARGIN, 32.0),
			Vector2((column + 1) * column_width - NODE_MARGIN, 32.0), Color(color, 0.5), 2.0
		)

	# Prerequisite lines, drawn under the buttons.
	for skill_id: String in _buttons:
		var skill: SkillDefinition = SkillManager.get_skill(skill_id)
		var button: Button = _buttons[skill_id]
		for required_id: String in skill.requires:
			var required_button: Button = _buttons.get(required_id)
			if required_button == null:
				continue
			var is_met: bool = SkillManager.get_level(required_id) >= int(skill.requires[required_id])
			draw_line(
				required_button.position + Vector2(required_button.size.x * 0.5, required_button.size.y),
				button.position + Vector2(button.size.x * 0.5, 0.0),
				Color(BRANCH_COLORS.get(skill.branch, UIPalette.PRIMARY), 0.9 if is_met else 0.25),
				3.0 if is_met else 2.0, true
			)

	var selected: Button = _buttons.get(_selected_id)
	if selected != null:
		draw_rect(Rect2(selected.position - Vector2(4, 4), selected.size + Vector2(8, 8)), UIPalette.TEXT, false, 2.0)
