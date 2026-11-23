class_name HackerRoom
extends Node2D
## The starting apartment. Exposes what GameWorld needs from any room:
## where actors live, where to spawn, and which floor positions are valid.

## Where a new player appears, in grid units.
@export var spawn_grid_position: Vector2 = Vector2(4.0, 4.0)
## Distance from the walls a restored position must keep, in grid units.
@export_range(0.0, 2.0, 0.05) var walkable_margin: float = 0.2

@onready var _shell: RoomShell = %Shell
@onready var _props: IsoDepthSorter = %Props


## Actors must be children of this node so they are depth-sorted with the furniture.
func get_actor_parent() -> IsoDepthSorter:
	return _props


func get_spawn_position() -> Vector2:
	return IsoUtils.grid_to_screen(spawn_grid_position)


## True when an actor may stand at `local_position`: on the floor and not
## inside a piece of furniture.
func is_position_walkable(local_position: Vector2) -> bool:
	if not _shell.contains_point(local_position, walkable_margin):
		return false
	var grid: Vector2 = IsoUtils.screen_to_grid(local_position)
	for child: Node in _props.get_children():
		if child is IsoNode and not child.is_in_group(IsoDepthSorter.ACTOR_GROUP):
			if (child as IsoNode).get_grid_bounds().grow(walkable_margin).has_point(grid):
				return false
	return true
