class_name TownMap
extends NavMap
## The town (D-030): a fixed, hand-placed map that is always the same. Buildings come from
## TownTables; every built building is solid and its door cell (bottom centre) is walkable.
## Unbuilt plots stay walkable (dirt) so heroes can cross them.

## Ground kinds for drawing: "#" town wall, "B" building, "p" cobble path, "d" dirt plot, "." grass.
var ground: Array[String] = []


func _init(levels: Dictionary = {}) -> void:
    var w := TownTables.MAP_W
    var h := TownTables.MAP_H
    var cells := []
    for y in h:
        var row := []
        for x in w:
            row.append("#" if x == 0 or y == 0 or x == w - 1 or y == h - 1 else ".")
        cells.append(row)
    # main roads: one east-west avenue and one north-south street through the plaza
    for x in range(1, w - 1):
        for y in [6, 7, 13, 14]:
            cells[y][x] = "p"
    for y in range(1, h - 1):
        for x in [7, 8, 19, 20, 25]:
            cells[y][x] = "p"
    for id in TownTables.ids():
        var plot: Rect2i = TownTables.info(id)["plot"]
        var built := int(levels.get(id, TownTables.info(id)["start"])) > 0
        for y in range(plot.position.y, plot.end.y):
            for x in range(plot.position.x, plot.end.x):
                cells[y][x] = "B" if built else "d"
        var door := TownTables.door_cell(id)
        if door.y < h - 1:
            cells[door.y][door.x] = "p"
    var nav_rows: Array = []
    for y in h:
        var s := ""
        var g := ""
        for x in w:
            var c: String = cells[y][x]
            g += c
            s += "#" if c == "#" or c == "B" else "."
        ground.append(g)
        nav_rows.append(s)
    build_grid(nav_rows)
    var plaza := Vector2i(17, 10)
    goal_cell = plaza
    extract_cell = plaza
    relic_cell = plaza
    for dy in range(-1, 2):
        for dx in range(-2, 3):
            spawn_cells.append(plaza + Vector2i(dx, dy))


## Building id whose footprint contains the cell ("" if none).
func building_at(cell: Vector2i) -> String:
    for id in TownTables.ids():
        var plot: Rect2i = TownTables.info(id)["plot"]
        if plot.has_point(cell):
            return id
    return ""


## Random walkable cell (deterministic for a given rng) used by wandering heroes.
func random_walkable(rng: RandomNumberGenerator) -> Vector2i:
    for i in 200:
        var c := Vector2i(rng.randi_range(1, width - 2), rng.randi_range(1, height - 2))
        if not is_blocked_cell(c):
            return c
    return goal_cell
