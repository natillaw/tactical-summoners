## MeadowFloor — Piso 1 de la torre: las Praderas.
##
## Procedural pero diseñado: la estructura es siempre la misma (un camino sinuoso de oeste a este con
## tres campamentos de enemigos y un bosque que encierra la zona), y la semilla varía la altura del
## camino, la posición de los campamentos, qué enemigos los ocupan y toda la decoración.
##
## generate() devuelve datos puros (testeables sin escena): límites, obstáculos con colisión,
## decoración, campamentos con sus enemigos y la misión. build() instancia la parte visual.
class_name MeadowFloor
extends RefCounted

const SIZE := Vector2(3200.0, 2200.0)
const NATURE := "res://assets/models/nature/"
const PROPS := "res://assets/models/props_fantasy/"

## Pinos y árboles comunes (verdes). Los árboles rojos (TwistedTree, Bush_Common) y los secos grises (DeadTree) quedan reservados para el tier +10; no se usan en los pisos 1-10.
## Los árboles comunes (copas redondas) cuestan ~12x más GPU que un pino por sobredibujado: solo ~18% de los árboles.
const TREES := ["Pine_1", "Pine_1", "Pine_1", "Pine_2", "Pine_2", "Pine_2", "Pine_3", "Pine_3", "Pine_3", "CommonTree_3", "CommonTree_4"]
const AUTUMN_TREES := ["TwistedTree_1", "TwistedTree_2"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const GRASS := ["Grass_Common_Tall", "Grass_Common_Short", "Grass_Wispy_Tall", "Clover_1", "Fern_1"]
const FLOWERS := ["Flower_3_Group", "Flower_4_Group", "Petal_1", "Plant_1_Big"]
const STEPS := ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3", "RockPath_Round_Wide"]

## Campamentos: cada uno elige sus enemigos entre varias composiciones (10 enemigos en total).
const CAMPS := [
	{"name": "La Avanzada", "options": [
		["esbirro", "esbirro", "esbirro"],
		["esbirro", "esbirro", "esbirro_arquero"],
	]},
	{"name": "El Claro del Bosque", "options": [
		["esbirro", "esbirro", "esbirro_arquero"],
		["esbirro", "esbirro", "esbirro_mago"],
	]},
	{"name": "La Cumbre", "options": [
		["esbirro", "esbirro", "esbirro", "esbirro_mago"],
		["esbirro", "esbirro", "esbirro_arquero", "esbirro_mago"],
	]},
]
const KILL_GOAL := 10
const CAMP_NAMES := ["La Avanzada", "El Claro del Bosque", "La Cumbre", "El Vado", "La Hondonada"]
const MAX_FLOOR := 10  # pisos 1-10: praderas; los siguientes cambiarán de temática


## Composición de un campamento.
##  Piso 1 (tutorial): solo esbirros, las listas de CAMPS (10 en total, 3-4 por campamento).
##  Pisos 2-3: esbirros + 1 élite solo en el último campamento.
##  Pisos 4-7: 1 élite en cada campamento menos el primero. Pisos 8+: 2 en el último.
##  Campeones desde el piso 6. Coloso (jefe con fases) en el último campamento de los pisos 5 y 10.
static func _roster(rng: RandomNumberGenerator, floor_number: int, camp_index: int, camp_total: int) -> Array:
	if floor_number <= 1:
		var options: Array = CAMPS[mini(camp_index, CAMPS.size() - 1)]["options"]
		return options[rng.randi() % options.size()]
	var minion_pool := ["esbirro", "esbirro", "esbirro_arquero", "esbirro_mago"]
	var elite_pool := ["soldado", "guardian", "duelista", "hechicero", "cazador"]
	if floor_number >= 6:
		elite_pool.append("campeon")
	var last := camp_index == camp_total - 1
	var boss_here := floor_number % 5 == 0 and last
	var roster: Array = []
	var minions := mini(3 + floor_number / 3, 6) - (1 if camp_index > 0 and floor_number >= 4 else 0)
	var elites := 0
	if floor_number <= 3:
		elites = 1 if last else 0
	elif camp_index > 0:
		elites = 2 if last and floor_number >= 8 else 1
	if boss_here:
		elites = 0  # el jefe ya trae sus esbirros; sin élites al lado
		minions = 2
	for i in range(minions):
		roster.append(minion_pool[rng.randi() % minion_pool.size()])
	for i in range(elites):
		roster.append(elite_pool[rng.randi() % elite_pool.size()])
	if boss_here:
		roster.append("coloso")
	return roster


## Mundo abierto: claros ("salas") cercados de árboles repartidos por un bosque con manchas de densidad,
## unidos por senderos suaves que no son obligatorios. 3 claros con campamento, el resto de salas
## (spawn, hallazgos) vacías. Nada fuerza un pasillo: se puede cruzar el bosque por cualquier lado.
static func generate(seed_value: int, floor_number: int = 1, force_mission: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var clearings: Array = []  # {center, radius}
	var spawn := Vector2(rng.randf_range(260.0, 420.0), rng.randf_range(600.0, 1600.0))
	clearings.append({"center": spawn, "radius": 200.0})
	var tries := 0
	var clearing_goal := 7 + floor_number / 3
	while clearings.size() < clearing_goal and tries < 600:
		tries += 1
		var radius := rng.randf_range(220.0, 300.0)
		var center := Vector2(rng.randf_range(520.0, SIZE.x - 300.0), rng.randf_range(320.0, SIZE.y - 320.0))
		var ok := true
		for c: Dictionary in clearings:
			if center.distance_to(c["center"]) < float(c["radius"]) + radius + 260.0:
				ok = false
		if ok:
			clearings.append({"center": center, "radius": radius})
	# Tres salas a distintas distancias del spawn tienen campamento (cerca, media, lejos).
	var order: Array = clearings.slice(1)
	order.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return spawn.distance_to(x["center"]) < spawn.distance_to(y["center"]))
	var camp_clearings: Array = []
	var n := order.size()
	var camp_count := mini(3 + floor_number / 4, n)
	for k in range(camp_count):
		var pick: Variant = order[int(round(float(k) * float(n - 1) / float(maxi(camp_count - 1, 1))))]
		if not camp_clearings.has(pick):
			camp_clearings.append(pick)
	var camps: Array = []
	for i in range(camp_clearings.size()):
		var center: Vector2 = camp_clearings[i]["center"]
		var roster: Array = _roster(rng, floor_number, i, camp_clearings.size())
		var enemies: Array = []
		for k in range(roster.size()):
			var angle := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(roster.size())
			enemies.append({"arch": roster[k], "pos": center + Vector2(cos(angle), sin(angle)) * rng.randf_range(65.0, 115.0), "level": floor_number})
		camps.append({"name": CAMP_NAMES[i % CAMP_NAMES.size()], "center": center, "enemies": enemies})
	# Salida al piso siguiente: en la sala más lejana sin campamento (o la más lejana de todas).
	var exit_pos := Vector2.ZERO
	var exit_dist := -1.0
	for c: Dictionary in order:
		var has_camp := camp_clearings.has(c)
		var d := spawn.distance_to(c["center"]) - (100000.0 if has_camp else 0.0)  # la salida va siempre en una sala sin campamento (si existe)
		if d > exit_dist:
			exit_dist = d
			exit_pos = (c["center"] as Vector2) + Vector2(0.0, -95.0)
	# Senderos: cada sala se une con la más cercana ya conectada (árbol de expansión), con curvas.
	var trails: Array = []
	var linked: Array = [clearings[0]]
	var rest: Array = clearings.slice(1)
	while not rest.is_empty():
		var best_a: Dictionary = {}
		var best_b: Dictionary = {}
		var best_d := INF
		for l: Dictionary in linked:
			for r: Dictionary in rest:
				var d: float = (l["center"] as Vector2).distance_to(r["center"])
				if d < best_d:
					best_d = d
					best_a = l
					best_b = r
		trails.append(_trail(rng, best_a["center"], best_b["center"]))
		linked.append(best_b)
		rest.erase(best_b)

	# Misión del piso: tipo por semilla (o forzado en tests); puede añadir campamentos extra, interactuables y un claro oculto.
	var mission_rng := RandomNumberGenerator.new()
	mission_rng.seed = seed_value ^ 0x51ED
	var mission_type := force_mission if force_mission != "" else MissionCatalog.pick_type(seed_value, floor_number)
	var design := MissionLayout.design(mission_type, mission_rng, floor_number, {"clearings": clearings, "camps": camps, "spawn": spawn, "exit": exit_pos})
	if not (design["hidden"] as Dictionary).is_empty():
		clearings.append(design["hidden"])  # sin sendero: solo se llega cruzando el bosque

	var decor: Array = []
	var obstacles: Array = []
	var taken: Array = []
	var ctx := {"clearings": clearings, "trails": trails, "spawn": spawn}
	_place_camp_props(rng, camps, decor, obstacles, taken)
	_place_rooms(rng, clearings, camps, spawn, decor, obstacles, taken)
	_place_trees(rng, ctx, decor, obstacles, taken)
	_place_scatter(rng, ctx, decor, obstacles, taken)
	_place_trail_stones(rng, trails, decor)
	var gather: Array = []
	_place_gather(rng, ctx, gather, taken, floor_number)
	_place_chests(rng, clearings, camps, spawn, gather)
	var trapped: bool = design["spec"]["type"] == "ambush"
	var chest_count := 0
	for g: Dictionary in gather:
		if g["kind"] == "chest":
			g["trapped"] = trapped
			chest_count += 1
	design["spec"]["chests_total"] = chest_count
	if not (design["hidden"] as Dictionary).is_empty():
		gather.append({"kind": "chest", "mat": "", "pos": design["hidden"]["center"], "amount": 1, "yaw": 0.0, "secret": true, "trapped": false})

	var enemy_total := 0
	for camp: Dictionary in camps:
		enemy_total += (camp["enemies"] as Array).size()
	return {
		"seed": seed_value, "floor": floor_number, "name": "Praderas", "bounds": Rect2(Vector2.ZERO, SIZE),
		"spawn": spawn, "clearings": clearings, "trails": trails, "camps": camps, "decor": decor, "obstacles": obstacles, "gather": gather,
		"exit": exit_pos, "mission": design["spec"], "interacts": design["interacts"], "quest": {"title": "Limpia las praderas", "kill": enemy_total, "enemies": enemy_total},
	}


static func _trail(rng: RandomNumberGenerator, a: Vector2, b: Vector2) -> Array:
	var points: Array = [a]
	var normal := (b - a).normalized().orthogonal()
	var segments := maxi(int(a.distance_to(b) / 220.0), 2)
	var sway := rng.randf_range(-140.0, 140.0)
	for i in range(1, segments):
		var t := float(i) / float(segments)
		points.append(a.lerp(b, t) + normal * (sin(t * PI) * sway + rng.randf_range(-30.0, 30.0)))
	points.append(b)
	return points


# --- Colocación ----------------------------------------------------------------------------


static func _trail_distance(point: Vector2, trails: Array) -> float:
	var best := INF
	for trail: Array in trails:
		for i in range(trail.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, trail[i], trail[i + 1])
			best = minf(best, point.distance_to(closest))
	return best


## Distancia al borde del claro más cercano (negativa = dentro de un claro).
static func _clearing_gap(point: Vector2, clearings: Array) -> float:
	var best := INF
	for c: Dictionary in clearings:
		best = minf(best, point.distance_to(c["center"]) - float(c["radius"]))
	return best


static func _is_free(point: Vector2, radius: float, ctx: Dictionary, taken: Array, trail_margin: float = 70.0) -> bool:
	if _trail_distance(point, ctx["trails"]) < trail_margin + radius * 0.5:
		return false
	if _clearing_gap(point, ctx["clearings"]) < 45.0:
		return false
	for item: Array in taken:
		if point.distance_to(item[0]) < float(item[1]) + radius:
			return false
	return true


## Los modelos del kit son enormes para esta cámara (un árbol mide 7 m, el héroe 1.8 m): se reducen por tipo.
const MODEL_SCALE := {"Tree": 0.55, "Pine": 0.55, "Rock_": 0.4, "Grass": 0.5, "Fern": 0.5, "Clover": 0.6, "Bush": 0.5, "Mushroom": 0.6, "Flower": 0.6, "Petal": 0.6, "Plant": 0.6}


static func _add(decor: Array, folder: String, name: String, pos: Vector2, yaw: float, scale: float) -> void:
	var factor := 1.0
	for key: String in MODEL_SCALE:
		if name.contains(key):
			factor = float(MODEL_SCALE[key])
			break
	decor.append({"scene": folder + name + ".gltf", "pos": pos, "yaw": yaw, "scale": scale * factor})


static func _place_camp_props(rng: RandomNumberGenerator, camps: Array, decor: Array, obstacles: Array, taken: Array) -> void:
	for camp: Dictionary in camps:
		var c: Vector2 = camp["center"]
		_add(decor, PROPS, "Cauldron", c, rng.randf() * TAU, 1.0)
		obstacles.append({"position": c, "radius": 20.0})
		taken.append([c, 40.0])
		for prop in ["Barrel", "Barrel", "Crate_Wooden", "Crate_Wooden", "Chest_Wood", "Bench", "Banner_1", "Bucket_Wooden_1"]:
			var angle := rng.randf() * TAU
			var pos := c + Vector2(cos(angle), sin(angle)) * rng.randf_range(150.0, 185.0)
			_add(decor, PROPS, prop, pos, angle + PI * 0.5, 1.0)
			if prop in ["Barrel", "Crate_Wooden", "Chest_Wood"]:
				obstacles.append({"position": pos, "radius": 14.0})
			taken.append([pos, 24.0])


static func _place_rooms(rng: RandomNumberGenerator, clearings: Array, camps: Array, spawn: Vector2, decor: Array, obstacles: Array, taken: Array) -> void:
	# Salas sin campamento: algo que encontrar (cofre, banco, bandera) en el centro.
	for c: Dictionary in clearings:
		var center: Vector2 = c["center"]
		var is_camp := false
		for camp: Dictionary in camps:
			if camp["center"] == center:
				is_camp = true
		if is_camp or center == spawn:
			continue
		obstacles.append({"position": center, "radius": 16.0})  # el cofre (nodo de recolección) se coloca en _place_chests
		taken.append([center, 40.0])
		for prop in ["Bench", "Banner_1", "Barrel", "Stool"]:
			var angle := rng.randf() * TAU
			_add(decor, PROPS, prop, center + Vector2(cos(angle), sin(angle)) * rng.randf_range(70.0, 120.0), angle, 1.0)


static func _place_trees(rng: RandomNumberGenerator, ctx: Dictionary, decor: Array, obstacles: Array, taken: Array) -> void:
	var clearings: Array = ctx["clearings"]
	# 1) Muro de árboles alrededor de cada sala; los senderos abren las entradas.
	for c: Dictionary in clearings:
		var center: Vector2 = c["center"]
		var radius: float = c["radius"]
		var count := int(TAU * (radius + 40.0) / 52.0)
		var gap_dir := 0.0
		if c.has("hidden"):  # el claro oculto deja una entrada (hacia el claro más cercano), pero sin sendero
			var nearest: Vector2 = center
			var best := INF
			for other: Dictionary in clearings:
				if not other.has("hidden") and center.distance_to(other["center"]) < best:
					best = center.distance_to(other["center"])
					nearest = other["center"]
			gap_dir = (nearest - center).angle()
		for k in range(count):
			var angle := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / float(count)
			if c.has("hidden") and absf(angle_difference(angle, gap_dir)) < 0.5:
				continue
			var point := center + Vector2(cos(angle), sin(angle)) * (radius + rng.randf_range(20.0, 75.0))
			if not Rect2(Vector2(30, 30), SIZE - Vector2(60, 60)).has_point(point):
				continue
			if _trail_distance(point, ctx["trails"]) < 62.0 or _clearing_gap(point, clearings) < -6.0:
				continue
			_tree(rng, point, decor, obstacles, taken)
	# 2) Bosque con manchas: el ruido decide dónde es denso y dónde pradera abierta.
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.0022
	for attempt in range(850):
		var point := Vector2(rng.randf_range(30.0, SIZE.x - 30.0), rng.randf_range(30.0, SIZE.y - 30.0))
		var edge := minf(minf(point.x, SIZE.x - point.x), minf(point.y, SIZE.y - point.y))
		var patch := clampf(noise.get_noise_2dv(point) * 1.6 + 0.35, 0.0, 1.0)
		var density := clampf(patch + lerpf(0.9, 0.0, clampf(edge / 380.0, 0.0, 1.0)), 0.0, 1.0)
		if rng.randf() > density or not _is_free(point, 26.0, ctx, taken):
			continue
		_tree(rng, point, decor, obstacles, taken)
	# 3) Anillo exterior (solo visual) para que no se vea el vacío.
	for attempt in range(180):
		var side := rng.randi() % 4
		var depth := rng.randf_range(10.0, 380.0)
		var along := rng.randf()
		var point: Vector2
		match side:
			0: point = Vector2(along * SIZE.x, -depth)
			1: point = Vector2(along * SIZE.x, SIZE.y + depth)
			2: point = Vector2(-depth, along * SIZE.y)
			_: point = Vector2(SIZE.x + depth, along * SIZE.y)
		_add(decor, NATURE, TREES[rng.randi() % TREES.size()], point, rng.randf() * TAU, rng.randf_range(1.0, 1.7))


static func _tree(rng: RandomNumberGenerator, point: Vector2, decor: Array, obstacles: Array, taken: Array) -> void:
	var scale := rng.randf_range(0.9, 1.5)
	_add(decor, NATURE, TREES[rng.randi() % TREES.size()], point, rng.randf() * TAU, scale)
	obstacles.append({"position": point, "radius": 14.0 * scale})
	taken.append([point, 28.0 * scale])


static func _place_scatter(rng: RandomNumberGenerator, ctx: Dictionary, decor: Array, obstacles: Array, taken: Array) -> void:
	var trails: Array = ctx["trails"]
	for attempt in range(120):  # rocas con colisión
		var point := Vector2(rng.randf_range(60.0, SIZE.x - 60.0), rng.randf_range(60.0, SIZE.y - 60.0))
		if _is_free(point, 30.0, ctx, taken):
			var scale := rng.randf_range(0.9, 1.6)
			_add(decor, NATURE, ROCKS[rng.randi() % ROCKS.size()], point, rng.randf() * TAU, scale)
			obstacles.append({"position": point, "radius": 24.0 * scale})
			taken.append([point, 38.0 * scale])
	for attempt in range(420):  # hierba y flores: densas en claros y senderos, ralas en el bosque
		var point := Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(0.0, SIZE.y))
		var gap := _clearing_gap(point, ctx["clearings"])
		if _trail_distance(point, trails) < 35.0:
			continue
		if gap > 120.0 and rng.randf() < 0.45:
			continue
		if rng.randf() < 0.05:
			_add(decor, NATURE, "Bush_Common_Flowers", point, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		elif rng.randf() < 0.22:
			_add(decor, NATURE, FLOWERS[rng.randi() % FLOWERS.size()], point, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		else:
			_add(decor, NATURE, GRASS[rng.randi() % GRASS.size()], point, rng.randf() * TAU, rng.randf_range(0.8, 1.5))
	for attempt in range(26):
		var point := Vector2(rng.randf_range(60.0, SIZE.x - 60.0), rng.randf_range(60.0, SIZE.y - 60.0))
		if _clearing_gap(point, ctx["clearings"]) > 60.0:
			_add(decor, NATURE, "Mushroom_Common", point, rng.randf() * TAU, rng.randf_range(0.9, 1.5))


## Nodos de recolección comunes del piso 1: minerales en rocas, hierbas y flores cerca de claros y
## senderos, hongos en el bosque, troncos secos y fibras repartidos.
static func _place_gather(rng: RandomNumberGenerator, ctx: Dictionary, gather: Array, taken: Array, floor_number: int = 1) -> void:
	var plan := {"ore": 9, "stone": 8, "herb": 16, "flower": 10, "mushroom": 8, "fiber": 14, "wood": 8}
	for kind: String in plan:
		var placed := 0
		var tries := 0
		var quota := maxi(int(plan[kind]) + rng.randi_range(-3, 4), 3)  # la abundancia cambia con la semilla
		while placed < quota and tries < 600:
			tries += 1
			var point := Vector2(rng.randf_range(80.0, SIZE.x - 80.0), rng.randf_range(80.0, SIZE.y - 80.0))
			var gap := _clearing_gap(point, ctx["clearings"])
			var trail := _trail_distance(point, ctx["trails"])
			match kind:
				"herb", "flower":
					if gap > 220.0 and trail > 160.0:
						continue
				"mushroom", "ore", "wood":
					if gap < 70.0:
						continue
				_:
					if gap < 40.0:
						continue
			if not _is_free(point, 24.0, ctx, taken, 40.0):
				continue
			var spec: Dictionary = Materials.NODES[kind]
			var amount: Array = spec["amount"]
			gather.append({"kind": kind, "mat": Materials.node_material(kind, floor_number, rng), "pos": point, "amount": rng.randi_range(int(amount[0]), int(amount[1])), "yaw": rng.randf() * TAU})
			taken.append([point, 34.0])
			placed += 1


## Cofres: uno en el centro de cada sala sin campamento (el botín sale del azar de la semilla al abrirlo).
static func _place_chests(rng: RandomNumberGenerator, clearings: Array, camps: Array, spawn: Vector2, gather: Array) -> void:
	for c: Dictionary in clearings:
		var center: Vector2 = c["center"]
		var occupied := center == spawn or c.has("hidden")
		for camp: Dictionary in camps:
			if camp["center"] == center:
				occupied = true
		if not occupied:
			gather.append({"kind": "chest", "mat": "", "pos": center, "amount": 1, "yaw": rng.randf() * TAU})


static func _place_trail_stones(rng: RandomNumberGenerator, trails: Array, decor: Array) -> void:
	for trail: Array in trails:
		for i in range(trail.size() - 1):
			var a: Vector2 = trail[i]
			var b: Vector2 = trail[i + 1]
			var steps := int(a.distance_to(b) / 75.0)
			for k in range(steps):
				var across := (b - a).normalized().orthogonal() * rng.randf_range(-28.0, 28.0)
				_add(decor, NATURE, STEPS[rng.randi() % STEPS.size()], a.lerp(b, float(k) / float(maxi(steps, 1))) + across, rng.randf() * TAU, rng.randf_range(0.55, 0.8))


const CELL := 360.0  # px: tamaño de chunk (permite que la cámara descarte lo lejano)
const NO_SHADOW := ["Pine", "Tree", "Rock_", "Bush", "Grass", "Fern", "Clover", "Flower", "Petal", "Plant", "RockPath", "Mushroom"]


## Decoración en MultiMesh: una sola draw call por (modelo, malla, chunk) en vez de un nodo por objeto.
static func build(parent: Node3D, data: Dictionary) -> void:
	_build_environment(parent)
	_build_ground(parent, data)
	var holder := Node3D.new()
	holder.name = "FloorDecor"
	parent.add_child(holder)
	build_decor(holder, data["decor"])


static func build_decor(holder: Node3D, decor: Array) -> void:
	var groups: Dictionary = {}  # "ruta|cx|cy" -> Array de transforms
	for item: Dictionary in decor:
		var pos: Vector2 = item["pos"]
		var key := "%s|%d|%d" % [item["scene"], floori(pos.x / CELL), floori(pos.y / CELL)]
		var xf := Transform3D(Basis(Vector3.UP, float(item["yaw"])).scaled(Vector3.ONE * float(item["scale"])), View3D.to3(pos))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(xf)
	var protos: Dictionary = {}  # ruta -> Array de [mesh, transform local]
	for key: String in groups:
		var path := key.split("|")[0]
		if not protos.has(path):
			protos[path] = _mesh_parts(path)
		for part: Array in protos[path]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			var list: Array = groups[key]
			var origin := Vector3.ZERO
			for xf: Transform3D in list:
				origin += xf.origin
			origin /= float(list.size())
			origin.y = 0.0
			mm.instance_count = list.size()
			for n in range(list.size()):
				var local := list[n] as Transform3D
				local.origin -= origin
				mm.set_instance_transform(n, local * (part[1] as Transform3D))
			var node := MultiMeshInstance3D.new()
			node.position = origin
			node.multimesh = mm
			node.name = path.get_file().get_basename()
			var shadowless := false
			for tag: String in NO_SHADOW:
				if path.contains(tag):
					shadowless = true
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if shadowless else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# Distancia de dibujo por tipo (el chunk se mide desde su centro): calidad cerca, ahorro lejos.
			var reach := 42.0
			if path.contains("Grass") or path.contains("Fern") or path.contains("Clover") or path.contains("Flower") or path.contains("Petal") or path.contains("Plant") or path.contains("Mushroom"):
				reach = 30.0
			elif path.contains("RockPath"):
				reach = 40.0
			node.visibility_range_end = reach + CELL / 80.0  # + semidiagonal del chunk en metros
			node.visibility_range_end_margin = 3.0
			holder.add_child(node)


static func _mesh_parts(path: String) -> Array:
	var scene := load(path) as PackedScene
	var out: Array = []
	if scene == null:
		return out
	_fix_materials(scene)
	var root := scene.instantiate() as Node3D
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := Transform3D.IDENTITY
		var walker: Node3D = mi
		while walker != null and walker != root:
			local = walker.transform * local
			walker = walker.get_parent() as Node3D
		out.append([mi.mesh, local])
	root.free()
	return out


## Los glTF del kit traen colores de vértice (viento/AO) que Godot usaría como albedo: salen rojos y azules.
## Nodos recolectables como nodos propios (se ocultan al recogerlos) con un destello del color del material.
static func build_gather(parent: Node3D, data: Dictionary) -> Array:
	var out: Array = []
	var holder := Node3D.new()
	holder.name = "GatherNodes"
	parent.add_child(holder)
	for entry: Dictionary in data["gather"]:
		var spec: Dictionary = Materials.NODES[entry["kind"]]
		var path := (PROPS if entry["kind"] == "chest" else NATURE) + String(spec["model"]) + ".gltf"
		var scene := load(path) as PackedScene
		var root := Node3D.new()
		root.position = View3D.to3(entry["pos"])
		holder.add_child(root)
		if scene != null:
			_fix_materials(scene)
			var model := scene.instantiate() as Node3D
			model.rotation.y = float(entry["yaw"])
			model.scale = Vector3.ONE * float(spec["scale"])
			root.add_child(model)
		var color: Color = Color(1.0, 0.85, 0.35) if entry["kind"] == "chest" else Materials.DEFS[entry["mat"]]["color"]
		var glint := ArcaneFx.sparks(color, 7, 1.8, 0.35, 0.12, false)
		glint.position.y = 0.5
		root.add_child(glint)
		out.append({"data": entry, "node": root, "left": true, "amount": int(entry["amount"])})
	return out


static func _fix_materials(scene: PackedScene) -> void:
	if scene == null:
		return
	var probe := scene.instantiate()
	for node in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in range(mesh.get_surface_count()):
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				var fresh := StandardMaterial3D.new()
				fresh.albedo_texture = mat.albedo_texture
				fresh.roughness = 1.0
				fresh.cull_mode = BaseMaterial3D.CULL_DISABLED
				if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					fresh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					fresh.alpha_scissor_threshold = 0.5
					fresh.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE  # bordes de hojas nítidos con MSAA
				mesh.surface_set_material(i, fresh)
	probe.free()


static func _build_environment(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.55, 0.88)
	sky_material.sky_horizon_color = Color(0.78, 0.87, 0.95)
	sky_material.ground_horizon_color = Color(0.62, 0.72, 0.62)
	sky_material.ground_bottom_color = Color(0.3, 0.4, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true  # más contraste y color: menos lavado
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.87, 0.95)
	env.fog_density = 0.0022
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 32.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35.0
	parent.add_child(sun)


static func _build_ground(parent: Node3D, data: Dictionary) -> void:
	_build_ground_plane(parent, SIZE)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.50, 0.38, 0.25)
	dirt.roughness = 1.0
	_build_trails(parent, data, dirt)


static func _build_ground_plane(parent: Node3D, size: Vector2) -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.20, 0.40, 0.14))
	gradient.set_color(1, Color(0.42, 0.62, 0.24))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = gradient
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_texture = texture
	ground_mat.roughness = 1.0
	ground_mat.uv1_scale = Vector3((size.x / 40.0 + 80.0) / 10.0, (size.y / 40.0 + 80.0) / 10.0, 1.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size / 40.0 + Vector2(80.0, 80.0)
	ground.mesh = plane
	ground.material_override = ground_mat
	ground.position = Vector3(size.x / 80.0, 0.0, size.y / 80.0)
	parent.add_child(ground)


static func _build_trails(parent: Node3D, data: Dictionary, dirt: Material) -> void:
	for trail: Array in data["trails"]:
		for i in range(trail.size() - 1):
			var a: Vector2 = trail[i]
			var b: Vector2 = trail[i + 1]
			var segment := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.4, 0.03, View3D.meters(a.distance_to(b)) + 1.4)
			box.material = dirt
			segment.mesh = box
			segment.position = View3D.to3((a + b) * 0.5, 0.012)
			segment.rotation.y = atan2(View3D.to3(b).x - View3D.to3(a).x, View3D.to3(b).z - View3D.to3(a).z)
			parent.add_child(segment)
			var joint := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 1.2
			disc.bottom_radius = 1.2
			disc.height = 0.03
			disc.material = dirt
			joint.mesh = disc
			joint.position = View3D.to3(b, 0.012)
			parent.add_child(joint)
	# Suelo de tierra apisonada en cada claro.
	for c: Dictionary in data["clearings"]:
		var floor_disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = View3D.meters(float(c["radius"])) * 0.4
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.02
		cyl.material = dirt
		floor_disc.mesh = cyl
		floor_disc.position = View3D.to3(c["center"], 0.008)
		parent.add_child(floor_disc)
