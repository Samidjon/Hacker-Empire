class_name ProgressionConfig
extends Resource
## Level curve and rank table. Edit the .tres to rebalance progression.

@export_range(1, 999) var max_level: int = 50
## XP needed to go from level 1 to level 2.
@export_range(1, 100000) var base_xp: int = 100
## XP to next level = base_xp * level ^ xp_growth_exponent.
@export_range(1.0, 3.0, 0.01) var xp_growth_exponent: float = 1.5
@export var ranks: Array[RankDefinition] = []


## XP needed to advance from `level` to `level + 1`. Zero at max level.
func get_xp_to_next_level(level: int) -> int:
	if level >= max_level:
		return 0
	var clamped_level: int = maxi(1, level)
	return maxi(1, roundi(base_xp * pow(float(clamped_level), xp_growth_exponent)))


func get_rank_name(level: int) -> String:
	var best_name: String = ""
	var best_min_level: int = -1
	for rank: RankDefinition in ranks:
		if rank != null and rank.min_level <= level and rank.min_level > best_min_level:
			best_min_level = rank.min_level
			best_name = rank.rank_name
	return best_name
