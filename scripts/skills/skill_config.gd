class_name SkillConfig
extends Resource
## Rules for earning skill points.

## Points a new character starts with.
@export_range(0, 20) var starting_points: int = 1
## Points gained with every player level.
@export_range(0, 10) var points_per_level: int = 1
