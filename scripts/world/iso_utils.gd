@tool
class_name IsoUtils
extends RefCounted
## 2:1 isometric projection shared by everything in the world.
##
## Grid space: x runs toward the lower-right of the screen, y toward the
## lower-left, one unit per floor tile. Elevation is height above the floor.

const TILE_HALF_WIDTH: float = 64.0
const TILE_HALF_HEIGHT: float = 32.0
## Screen pixels per unit of elevation.
const HEIGHT_UNIT: float = 64.0


static func grid_to_screen(grid: Vector2, elevation: float = 0.0) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT - elevation * HEIGHT_UNIT
	)


## Inverse of grid_to_screen() for a point on the floor (elevation 0).
static func screen_to_grid(screen: Vector2) -> Vector2:
	var along_x: float = screen.x / TILE_HALF_WIDTH
	var along_y: float = screen.y / TILE_HALF_HEIGHT
	return Vector2((along_y + along_x) * 0.5, (along_y - along_x) * 0.5)
