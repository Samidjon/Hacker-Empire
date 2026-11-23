class_name RankDefinition
extends Resource
## A named rank that applies from min_level until the next rank begins.

@export var rank_name: String = ""
@export_range(1, 999) var min_level: int = 1
