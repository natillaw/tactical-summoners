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

const SIZE := Vector2(1800.0, 1200.0)
const NATURE := "res://assets/models/nature/"
const PROPS := "res://assets/models/props_fantasy/"

## Solo pinos: las hojas de CommonTree/TwistedTree/Bush se ven rojas en Godot (pendiente de investigar).
const TREES := ["Pine_1", "Pine_2", "Pine_3"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const GRASS := ["Grass_Common_Tall", "Grass_Common_Short", "Grass_Wispy_Tall", "Clover_1", "Fern_1"]
const FLOWERS := ["Flower_3_Group", "Flower_4_Group", "Petal_1", "Plant_1_Big"]
const STEPS := ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3", "RockPath_Round_Wide"]

## Campamentos: cada uno elige sus enemigos entre varias composiciones (10 enemigos en total).
const CAMPS := [
	{"name": "La Avanzada", "options": [
		["esbirro", "esbirro", "esbirro", "soldado"],
		["esbirro", "esbirro", "soldado", "soldado"],
	]},
	{"name": "El Claro del Bosque", "options": [
		["guardian", "duelista", "hechicero"],
		["guardian", "cazador", "hechicero"],
	]},
	{"name": "La Cumbre", "options": [
		["cazador", "soldado", "duelista"],
		["hechicero", "soldado", "duelista"],
	]},
]
const KILL_GOAL := 10


static func generate(seed_value: int, floor_number: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spawn := Vector2(170.0, rng.randf_range(450.0, 750.0))
	var path: Array = [spawn]
	var camps: Array = []
	var y := spawn.y
	var base_x := [640.0, 1070.0, 1500.0]
	for i in range(CAMPS.size()):
		y = clampf(y + rng.randf_range(-280.0, 280.0), 280.0, 920.0)
		var center := Vector2(float(base_x[i]) + rng.randf_range(-60.0, 60.0), y)
		path.append(center + Vector2(-270.0, rng.randf_range(-130.0, 130.0)))
		path.append(center)
		var options: Array = CAMPS[i]["options"]
		var roster: Array = options[rng.randi() % options.size()]
		var enemies: Array = []
		for k in range(roster.size()):
			var angle := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(roster.size())
			var radius := rng.randf_range(65.0, 115.0)
			enemies.append({"arch": roster[k], "pos": center + Vector2(cos(angle), sin(angle)) * radius, "level": 1 + int(i == 2)})
		camps.append({"name": CAMPS[i]["name"], "center": center, "enemies": enemies})
	path.append(Vector2(1700.0, y + rng.randf_range(-80.0, 80.0)))

	var decor: Array = []
	var obstacles: Array = []
	var taken: Array = []  # [pos, radio] de lo ya colocado, para que no se solape
	_place_camp_props(rng, camps, decor, obstacles, taken)
	_place_trees(rng, path, camps, spawn, decor, obstacles, taken)
	_place_scatter(rng, path, camps, spawn, decor, obstacles, taken)
	_place_path_stones(rng, path, decor)

	var enemy_total := 0
	for camp: Dictionary in camps:
		enemy_total += (camp["enemies"] as Array).size()
	return {
		"seed": seed_value, "floor": floor_number, "name": "Praderas", "bounds": Rect2(Vector2.ZERO, SIZE),
		"spawn": spawn, "path": path, "camps": camps, "decor": decor, "obstacles": obstacles,
		"quest": {"title": "Limpia las praderas", "kill": KILL_GOAL, "enemies": enemy_total},
	}


# --- Colocación ----------------------------------------------------------------------------


static func _path_distance(point: Vector2, path: Array) -> float:
	var best := INF
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		best = minf(best, point.distance_to(closest))
	return best


static func _is_free(point: Vector2, radius: float, path: Array, camps: Array, spawn: Vector2, taken: Array, path_margin: float = 150.0) -> bool:
	if _path_distance(point, path) < path_margin + radius * 0.5:
		return false
	if point.distance_to(spawn) < 170.0:
		return false
	for camp: Dictionary in camps:
		if point.distance_to(camp["center"]) < 260.0:
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


static func _place_trees(rng: RandomNumberGenerator, path: Array, camps: Array, spawn: Vector2, decor: Array, obstacles: Array, taken: Array) -> void:
	# Bosque dentro de la zona: más denso cuanto más cerca del borde (encierra el nivel).
	for attempt in range(700):
		var point := Vector2(rng.randf_range(40.0, SIZE.x - 40.0), rng.randf_range(40.0, SIZE.y - 40.0))
		var edge := minf(minf(point.x, SIZE.x - point.x), minf(point.y, SIZE.y - point.y))
		var density := lerpf(1.0, 0.12, clampf(edge / 330.0, 0.0, 1.0))
		if rng.randf() > density or not _is_free(point, 26.0, path, camps, spawn, taken):
			continue
		var scale := rng.randf_range(0.9, 1.5)
		_add(decor, NATURE, TREES[rng.randi() % TREES.size()], point, rng.randf() * TAU, scale)
		obstacles.append({"position": point, "radius": 14.0 * scale})
		taken.append([point, 40.0 * scale])
	# Anillo exterior (solo visual, sin colisión) para que no se vea el vacío.
	for attempt in range(520):
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


static func _place_scatter(rng: RandomNumberGenerator, path: Array, camps: Array, spawn: Vector2, decor: Array, obstacles: Array, taken: Array) -> void:
	for attempt in range(60):  # rocas grandes con colisión
		var point := Vector2(rng.randf_range(60.0, SIZE.x - 60.0), rng.randf_range(60.0, SIZE.y - 60.0))
		if _is_free(point, 30.0, path, camps, spawn, taken):
			var scale := rng.randf_range(0.9, 1.6)
			_add(decor, NATURE, ROCKS[rng.randi() % ROCKS.size()], point, rng.randf() * TAU, scale)
			obstacles.append({"position": point, "radius": 24.0 * scale})
			taken.append([point, 38.0 * scale])
			if obstacles.size() > 150:
				break
	for attempt in range(80):  # arbustos (sin colisión)
		var point := Vector2(rng.randf_range(30.0, SIZE.x - 30.0), rng.randf_range(30.0, SIZE.y - 30.0))
		if _path_distance(point, path) > 70.0:
			_add(decor, NATURE, "Fern_1" if rng.randf() < 0.5 else "Clover_1", point, rng.randf() * TAU, rng.randf_range(0.8, 1.4))
	for attempt in range(330):  # hierba por todas partes, flores cerca del camino
		var point := Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(0.0, SIZE.y))
		var near_path := _path_distance(point, path) < 220.0
		if _path_distance(point, path) < 45.0:
			continue
		if near_path and rng.randf() < 0.3:
			_add(decor, NATURE, FLOWERS[rng.randi() % FLOWERS.size()], point, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		else:
			_add(decor, NATURE, GRASS[rng.randi() % GRASS.size()], point, rng.randf() * TAU, rng.randf_range(0.8, 1.5))
	for attempt in range(14):
		var point := Vector2(rng.randf_range(60.0, SIZE.x - 60.0), rng.randf_range(60.0, SIZE.y - 60.0))
		if _path_distance(point, path) > 120.0:
			_add(decor, NATURE, "Mushroom_Common", point, rng.randf() * TAU, rng.randf_range(0.9, 1.5))


static func _place_path_stones(rng: RandomNumberGenerator, path: Array, decor: Array) -> void:
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var length := a.distance_to(b)
		var steps := int(length / 75.0)
		for s in range(steps):
			var t := float(s) / float(maxi(steps, 1))
			var across := (b - a).normalized().orthogonal() * rng.randf_range(-30.0, 30.0)
			_add(decor, NATURE, STEPS[rng.randi() % STEPS.size()], a.lerp(b, t) + across, rng.randf() * TAU, rng.randf_range(0.55, 0.8))


# --- Visual ---------------------------------------------------------------------------------


static func build(parent: Node3D, data: Dictionary) -> void:
	_build_environment(parent)
	_build_ground(parent, data)
	var holder := Node3D.new()
	holder.name = "FloorDecor"
	parent.add_child(holder)
	var cache: Dictionary = {}
	for item: Dictionary in data["decor"]:
		var path := String(item["scene"])
		if not cache.has(path):
			cache[path] = load(path) as PackedScene
			_fix_materials(cache[path])
		var scene: PackedScene = cache[path]
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		node.position = View3D.to3(item["pos"])
		node.rotation.y = float(item["yaw"])
		node.scale = Vector3.ONE * float(item["scale"])
		holder.add_child(node)


## Los glTF del kit traen colores de vértice (viento/AO) que Godot usaría como albedo: salen rojos y azules.
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
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.87, 0.95)
	env.fog_density = 0.006
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 32.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)


static func _build_ground(parent: Node3D, data: Dictionary) -> void:
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
	ground_mat.uv1_scale = Vector3(14.0, 14.0, 1.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150.0, 120.0)
	ground.mesh = plane
	ground.material_override = ground_mat
	ground.position = Vector3(SIZE.x / 80.0, 0.0, SIZE.y / 80.0)
	parent.add_child(ground)
	# Camino de tierra: un tramo plano por segmento de la ruta.
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.50, 0.38, 0.25)
	dirt.roughness = 1.0
	var path: Array = data["path"]
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var segment := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 0.03, View3D.meters(a.distance_to(b)) + 1.4)
		box.material = dirt
		segment.mesh = box
		var mid := View3D.to3((a + b) * 0.5, 0.012)
		segment.position = mid
		segment.rotation.y = atan2(View3D.to3(b).x - View3D.to3(a).x, View3D.to3(b).z - View3D.to3(a).z)
		parent.add_child(segment)
		var joint := MeshInstance3D.new()  # junta redondeada entre tramos
		var disc := CylinderMesh.new()
		disc.top_radius = 1.3
		disc.bottom_radius = 1.3
		disc.height = 0.03
		disc.material = dirt
		joint.mesh = disc
		joint.position = View3D.to3(b, 0.012)
		parent.add_child(joint)
