extends HBoxContainer
## Skills application: the skill tree and the details of the selected skill.
## Spending points goes through SkillManager.

var _selected_id: String = ""

@onready var _tree: SkillTreeView = %SkillTree
@onready var _points_label: Label = %SkillPointsLabel
@onready var _name_label: Label = %SkillNameLabel
@onready var _meta_label: Label = %SkillMetaLabel
@onready var _description_label: Label = %SkillDescriptionLabel
@onready var _effects_label: Label = %SkillEffectsLabel
@onready var _blocker_label: Label = %SkillBlockerLabel
@onready var _upgrade_button: Button = %UpgradeButton


func _ready() -> void:
	_tree.skill_selected.connect(select_skill)
	_upgrade_button.pressed.connect(upgrade_selected)
	SkillManager.skills_changed.connect(_refresh)
	SkillManager.points_changed.connect(func(_available: int) -> void: _refresh())
	_refresh()


func get_tree_view() -> SkillTreeView:
	return _tree


func get_selected_id() -> String:
	return _selected_id


func get_points_text() -> String:
	return _points_label.text


func get_details_text() -> String:
	return "%s\n%s\n%s\n%s" % [
		_name_label.text, _meta_label.text, _effects_label.text, _blocker_label.text
	]


func select_skill(skill_id: String) -> void:
	_selected_id = skill_id
	_tree.set_selected(skill_id)
	_refresh()


## Raises the selected skill, exactly as the Upgrade button does.
func upgrade_selected() -> bool:
	return SkillManager.upgrade(_selected_id)


func _refresh() -> void:
	_points_label.text = "Skill points: %d available  (%d spent of %d earned)" % [
		SkillManager.get_available_points(), SkillManager.get_spent_points(), SkillManager.get_earned_points()
	]
	var skill: SkillDefinition = SkillManager.get_skill(_selected_id)
	if skill == null:
		_name_label.text = "No skill selected"
		_meta_label.text = ""
		_description_label.text = "Click a skill in the tree. You earn one skill point for every level."
		_effects_label.text = ""
		_blocker_label.text = ""
		_upgrade_button.disabled = true
		_upgrade_button.text = "Upgrade"
		return

	var level: int = SkillManager.get_level(skill.id)
	_name_label.text = skill.title
	_meta_label.text = "%s   -   LEVEL %d / %d" % [
		SkillBranch.get_display_name(skill.branch).to_upper(), level, skill.max_level
	]
	_description_label.text = skill.description

	var lines: PackedStringArray = []
	if level > 0:
		lines.append("Now:   %s" % ", ".join(skill.describe_effects(level)))
	if level < skill.max_level:
		lines.append("Next:  %s" % ", ".join(skill.describe_effects(level + 1)))
		lines.append("Cost:  %d skill point(s)" % skill.cost_per_level)
	_effects_label.text = "\n".join(lines)

	var blockers: PackedStringArray = SkillManager.get_upgrade_blockers(skill.id)
	var is_maxed: bool = SkillManager.is_maxed(skill.id)
	_blocker_label.text = "\n".join(blockers)
	_blocker_label.add_theme_color_override(&"font_color", UIPalette.ACCENT if is_maxed else UIPalette.DANGER)
	_upgrade_button.disabled = not blockers.is_empty()
	_upgrade_button.text = "Maxed" if is_maxed else ("Learn" if level == 0 else "Upgrade to level %d" % (level + 1))
