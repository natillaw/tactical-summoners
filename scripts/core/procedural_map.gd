class_name ProceduralMap
extends NavMap
## Robust procedural dungeon generator supporting both tower floors and peaceful Headquarters layouts.
## Preserves complete backward compatibility for all public properties and navigation methods.

var seed_value: int = 12345
var floor_number: int = 1
var grid_rows: Array[String] = []
var objective_cells: Array[Vector2i] = []


func _init(p_width: int = 100, p_height: int = 100, seed_val: int = 12345, floor_num: int = 1) -> void:
	width = clampi(p_width, 40, 200)
	height = clampi(p_height, 40, 200)
	seed_value = seed_val
	floor_number = floor_num
	_generate_with_retry()


func _generate_with_retry() -> void:
	var rng := RandomNumberGenerator.new()
	var attempts := 0
	while attempts < 10:
		rng.seed = seed_value + absi(floor_number) * 997 + attempts * 31
		if _try_generate(rng):
			if _validate_map():
				_set_mission_cells()
				return
		attempts += 1
	_force_fallback_generate(rng)


## Relic in the far room (goal), extraction back in the start room (F-003: never the same cell).
func _set_mission_cells() -> void:
	relic_cell = goal_cell
	extract_cell = spawn_cells[0] if not spawn_cells.is_empty() else goal_cell


func _try_generate(rng: RandomNumberGenerator) -> bool:
	var map_grid := []
	for y in height:
		var row := []
		for x in width:
			row.append("#")
		map_grid.append(row)

	# Headquarters (floor_number <= 0) gets a spacious open layout, tower gets multi-room dungeons
	var is_hq := (floor_number <= 0)
	objective_cells.clear()
	var target_rooms := 1 if is_hq else clampi(10 + floor_number * 2, 12, 30)
	var rooms: Array[Rect2i] = []

	if is_hq:
		# Headquarters open hall layout
		var hq_room := Rect2i(3, 3, width - 6, height - 6)
		rooms.append(hq_room)
		for y in range(hq_room.position.y, hq_room.end.y):
			for x in range(hq_room.position.x, hq_room.end.x):
				map_grid[y][x] = "."
	else:
		var max_placement_attempts := target_rooms * 20
		var placed := 0
		for i in range(max_placement_attempts):
			if placed >= target_rooms:
				break
			var rw := rng.randi_range(7, 16)
			var rh := rng.randi_range(7, 16)
			var rx := rng.randi_range(2, width - rw - 2)
			var ry := rng.randi_range(2, height - rh - 2)
			var candidate := Rect2i(rx, ry, rw, rh)

			var overlap := false
			for r in rooms:
				if candidate.grow(2).intersects(r):
					overlap = true
					break
			if not overlap:
				rooms.append(candidate)
				placed += 1
				for y in range(candidate.position.y, candidate.end.y):
					for x in range(candidate.position.x, candidate.end.x):
						map_grid[y][x] = "."

		if rooms.size() < 4:
			return false

		rooms.sort_custom(func(a, b): return a.position.x + a.position.y < b.position.x + b.position.y)

		for i in range(1, rooms.size()):
			var p1 := rooms[i - 1].get_center()
			var p2 := rooms[i].get_center()
			_carve_corridor(map_grid, p1, p2)

		for i in range(maxi(1, rooms.size() / 3)):
			var r1 = rooms[rng.randi_range(0, rooms.size() - 1)]
			var r2 = rooms[rng.randi_range(0, rooms.size() - 1)]
			if r1 != r2:
				_carve_corridor(map_grid, r1.get_center(), r2.get_center())

	var start_room := rooms[0]
	var end_room := rooms[rooms.size() - 1]

	spawn_cells.clear()
	for i in maxi(5, Game.PARTY_SIZE):
		var sx := start_room.position.x + 1 + (i % 4)
		var sy := start_room.position.y + 1 + int(i / 4)
		if in_bounds(Vector2i(sx, sy)):
			spawn_cells.append(Vector2i(sx, sy))
			map_grid[sy][sx] = "."

	goal_cell = end_room.get_center()
	map_grid[goal_cell.y][goal_cell.x] = "."
	if not is_hq:
		objective_cells.append(goal_cell)

	enemy_spawn_cells.clear()
	treasure_cells.clear()

	if not is_hq:
		var cfg := TowerExpedition.get_floor_config(floor_number)
		var target_enemies: int = int(cfg.get("enemies", 8))
		for i in range(1, rooms.size() - 1):
			var rm := rooms[i]
			var enemies_in_room := rng.randi_range(1, 2)
			for e in enemies_in_room:
				if enemy_spawn_cells.size() < target_enemies:
					var ex := rng.randi_range(rm.position.x + 1, rm.end.x - 2)
					var ey := rng.randi_range(rm.position.y + 1, rm.end.y - 2)
					if map_grid[ey][ex] == ".":
						enemy_spawn_cells.append(Vector2i(ex, ey))
			
			if rng.randf() < 0.4 and treasure_cells.size() < 4:
				var tx := rm.get_center().x + rng.randi_range(-1, 1)
				var ty := rm.get_center().y + rng.randi_range(-1, 1)
				if map_grid[ty][tx] == ".":
					treasure_cells.append(Vector2i(tx, ty))

	grid_rows.clear()
	for y in height:
		var row_str := ""
		for x in width:
			row_str += String(map_grid[y][x])
		grid_rows.append(row_str)

	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				grid.set_point_solid(Vector2i(x, y), true)

	return true


func _force_fallback_generate(_rng: RandomNumberGenerator) -> void:
	var map_grid := []
	for y in height:
		var row := []
		for x in width:
			row.append("#" if (x == 0 or y == 0 or x == width - 1 or y == height - 1) else ".")
		map_grid.append(row)

	spawn_cells = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 3)]
	goal_cell = Vector2i(width - 4, height - 4)
	if floor_number > 0:
		enemy_spawn_cells = [Vector2i(width / 2, height / 2), Vector2i(width / 2 + 2, height / 2)]
		treasure_cells = [Vector2i(width / 3, height / 3)]
	else:
		enemy_spawn_cells.clear()
		treasure_cells.clear()

	grid_rows.clear()
	for y in height:
		var row_str := ""
		for x in width:
			row_str += String(map_grid[y][x])
		grid_rows.append(row_str)

	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				grid.set_point_solid(Vector2i(x, y), true)
	_set_mission_cells()


func _validate_map() -> bool:
	if spawn_cells.is_empty():
		return false
	var test_grid := AStarGrid2D.new()
	test_grid.region = Rect2i(0, 0, width, height)
	test_grid.cell_size = Vector2(CELL, CELL)
	test_grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				test_grid.set_point_solid(Vector2i(x, y), true)
	var path := test_grid.get_point_path(spawn_cells[0], goal_cell)
	return path.size() > 0


func _carve_corridor(map_grid: Array, p1: Vector2i, p2: Vector2i) -> void:
	var cx := p1.x
	var cy := p1.y
	var horizontal_first := (seed_value % 2 == 0)
	if horizontal_first:
		while cx != p2.x:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "."
			cx += 1 if p2.x > cx else -1
		while cy != p2.y:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "."
			cy += 1 if p2.y > cy else -1
	else:
		while cy != p2.y:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "."
			cy += 1 if p2.y > cy else -1
		while cx != p2.x:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "."
			cx += 1 if p2.x > cx else -1
