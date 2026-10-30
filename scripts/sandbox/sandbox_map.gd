class_name SandboxMap
extends RefCounted
## Fixed curated test map (T-004). "#" = wall, "." = floor. Pathfinding via AStarGrid2D.
## Provides full property compatibility with ProceduralMap (`spawn_cells`, `goal_cell`, `enemy_spawn_cells`).

const CELL := 48
const ROWS := [
    "########################################",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "#..........................#.....#.....#",
    "#.....##...................#.....#.....#",
    "#.....##...................#...........#",
    "#............#.............#...........#",
    "#............#.........................#",
    "#............#.........................#",
    "#............#.........................#",
    "#............######...######...........#",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "#..........................#...........#",
    "#..........................#......##...#",
    "#..........................#...........#",
    "#....#.......#......##.................#",
    "#....#.......#.........................#",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "#............#.............#...........#",
    "########################################"
]
const SPAWN_CELLS := [Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(2, 11), Vector2i(4, 11)]
const GOAL_CELL := Vector2i(36, 12)
const ENEMY_CELLS := [Vector2i(20, 6), Vector2i(22, 9), Vector2i(24, 14), Vector2i(34, 10), Vector2i(35, 14)]

var width: int
var height: int
var grid: AStarGrid2D
var spawn_cells: Array[Vector2i] = SPAWN_CELLS
var goal_cell: Vector2i = GOAL_CELL
var enemy_spawn_cells: Array[Vector2i] = ENEMY_CELLS
var treasure_cells: Array[Vector2i] = [Vector2i(15, 6)]


func _init() -> void:
    height = ROWS.size()
    width = String(ROWS[0]).length()
    grid = AStarGrid2D.new()
    grid.region = Rect2i(0, 0, width, height)
    grid.cell_size = Vector2(CELL, CELL)
    grid.offset = Vector2(CELL, CELL) * 0.5      # path points are cell centers
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for y in height:
        for x in width:
            if String(ROWS[y])[x] == "#":
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
    var pts := grid.get_point_path(start, goal)
    for i in pts.size():
        if i == 0 and pts.size() > 1:
            continue          # we are already standing in the first cell
        out.append(pts[i])
    # land on the exact requested spot (formation offsets) when it is walkable
    if not out.is_empty() and not is_blocked(b) and cell_of(b) == goal:
        out[out.size() - 1] = b
    return out
