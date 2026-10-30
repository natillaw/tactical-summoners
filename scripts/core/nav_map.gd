class_name NavMap
extends RefCounted
## Common base for every walkable mission map (fixed SandboxMap, procedural tower floors).
## Combat, enemies and map drawing take a NavMap, so any floor type works with them (F-002).
## "#" cells are solid; pathing uses AStarGrid2D on CELL-sized cells.

const CELL := 48

var width: int = 0
var height: int = 0
var grid: AStarGrid2D
var spawn_cells: Array[Vector2i] = []
var goal_cell: Vector2i = Vector2i.ZERO
var enemy_spawn_cells: Array[Vector2i] = []
var treasure_cells: Array[Vector2i] = []
var relic_cell: Vector2i = Vector2i.ZERO      # where the mission relic starts
var extract_cell: Vector2i = Vector2i.ZERO    # where the squad extracts (never the relic cell)


## Builds the A* grid from rows of "#" (wall) and "." (floor).
func build_grid(rows: Array) -> void:
    height = rows.size()
    width = String(rows[0]).length() if height > 0 else 0
    grid = AStarGrid2D.new()
    grid.region = Rect2i(0, 0, width, height)
    grid.cell_size = Vector2(CELL, CELL)
    grid.offset = Vector2(CELL, CELL) * 0.5      # path points are cell centers
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for y in height:
        var row := String(rows[y])
        for x in width:
            if row[x] == "#":
                grid.set_point_solid(Vector2i(x, y), true)


func world_size() -> Vector2:
    return Vector2(width, height) * CELL


func cell_of(world: Vector2) -> Vector2i:
    return Vector2i(floori(world.x / CELL), floori(world.y / CELL))


func center_of(cell: Vector2i) -> Vector2:
    return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_blocked_cell(cell: Vector2i) -> bool:
    return not in_bounds(cell) or grid.is_point_solid(cell)


func is_blocked(world: Vector2) -> bool:
    return is_blocked_cell(cell_of(world))


## Closest walkable cell center to a world point (searches outward in rings).
func nearest_walkable(world: Vector2) -> Vector2:
    var c := cell_of(world)
    c = Vector2i(clampi(c.x, 0, width - 1), clampi(c.y, 0, height - 1))
    if not is_blocked_cell(c):
        return world if not is_blocked(world) else center_of(c)
    for r in range(1, maxi(width, height)):
        var best := Vector2.ZERO
        var best_d := INF
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if maxi(absi(dx), absi(dy)) != r:
                    continue
                var n := c + Vector2i(dx, dy)
                if is_blocked_cell(n):
                    continue
                var d := center_of(n).distance_to(world)
                if d < best_d:
                    best_d = d
                    best = center_of(n)
        if best_d < INF:
            return best
    return center_of(c)


## Path of world waypoints from a to b (b is snapped to a walkable cell). Empty if unreachable.
func find_path(a: Vector2, b: Vector2) -> Array[Vector2]:
    var out: Array[Vector2] = []
    var start := cell_of(nearest_walkable(a))
    var goal := cell_of(nearest_walkable(b))
    if is_blocked_cell(start) or is_blocked_cell(goal):
        return out
    var pts := grid.get_point_path(start, goal)
    for i in pts.size():
        if i == 0 and pts.size() > 1:
            continue          # we are already standing in the first cell
        out.append(pts[i])
    # land on the exact requested spot (formation offsets) when it is walkable
    if not out.is_empty() and not is_blocked(b) and cell_of(b) == goal:
        out[out.size() - 1] = b
    return out
