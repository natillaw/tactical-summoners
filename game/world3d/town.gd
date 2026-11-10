## Town — el pueblo base: herrería, salón de alquimia, taberna y, al norte, los cimientos de la
## Torre con su puerta-portal. generate() da datos puros (testeables); build() instancia lo visual.
## El trazado es fijo (es el hub); la semilla solo cambia la decoración (árboles, flores, rocas).
class_name Town
extends RefCounted

const SIZE := Vector2(2400.0, 1800.0)
const V := "res://assets/models/village/"
const P := "res://assets/models/props_fantasy/"
const N := "res://assets/models/nature/"
const TOWER_CENTER := Vector2(1200.0, 400.0)
const TOWER_RADIUS := 380.0
const PORTAL_POS := Vector2(1200.0, 740.0)
const WALL_H := 3.1

const BUILDINGS := [
	{"id": "blacksmith", "label": "Herrería", "center": Vector2(560.0, 1010.0), "nx": 4, "nz": 4, "yaw": PI * 0.5, "style": "UnevenBrick", "roof": "6x6", "npc": "Brann, el Herrero", "look": {"sex": "male", "skin": "moreno", "hair": "beard", "hair_color": "negro", "outfit": "peasant"}},
	{"id": "alchemy", "label": "Salón de Alquimia", "center": Vector2(1840.0, 1010.0), "nx": 4, "nz": 4, "yaw": -PI * 0.5, "style": "Plaster", "roof": "6x6", "npc": "Elowen, la Alquimista", "look": {"sex": "female", "skin": "claro", "hair": "long", "hair_color": "morado", "outfit": "ranger"}},
	{"id": "tavern", "label": "Taberna", "center": Vector2(1700.0, 1470.0), "nx": 4, "nz": 5, "yaw": -PI * 0.5, "style": "Plaster", "roof": "6x8", "npc": "Gorm, el Tabernero", "look": {"sex": "male", "skin": "trigueño", "hair": "parted", "hair_color": "gris", "outfit": "peasant"}},
	{"id": "leatherworker", "label": "Peletería", "center": Vector2(560.0, 560.0), "nx": 4, "nz": 4, "yaw": PI * 0.5, "style": "Plaster", "roof": "6x6", "npc": "Hilda, la Peletera", "look": {"sex": "female", "skin": "trigueño", "hair": "buns", "hair_color": "pelirrojo", "outfit": "peasant"}},
	{"id": "tailor", "label": "Sastrería", "center": Vector2(560.0, 1480.0), "nx": 4, "nz": 4, "yaw": PI * 0.5, "style": "Plaster", "roof": "6x6", "npc": "Maren, la Sastre", "look": {"sex": "female", "skin": "claro", "hair": "long", "hair_color": "rubio", "outfit": "ranger"}},
	{"id": "carpenter", "label": "Carpintería", "center": Vector2(1840.0, 560.0), "nx": 4, "nz": 4, "yaw": -PI * 0.5, "style": "UnevenBrick", "roof": "6x6", "npc": "Tobin, el Carpintero", "look": {"sex": "male", "skin": "moreno", "hair": "parted", "hair_color": "castaño", "outfit": "peasant"}},
]
## Animación de cada NPC (clips UAL): trabajan o conversan en vez de quedarse en T-pose.
const STATION_ANIM := {
	"blacksmith": "ual2/TreeChopping", "alchemy": "ual2/Farm_Watering", "tavern": "ual2/Idle_FoldArms",
	"leatherworker": "ual1/Interact", "tailor": "ual1/Idle_Talking", "carpenter": "ual2/TreeChopping",
}
const STATION_PROPS := {
	"blacksmith": ["Anvil", "WeaponStand", "Workbench", "Whetstone", "Barrel"],
	"alchemy": ["Cauldron", "Table_Large", "Potion_1", "Potion_2", "Potion_4", "Shelf_Small_Bottles"],
	"tavern": ["Table_Large", "Chair_1", "Chair_1", "Mug", "Barrel_Apples", "Torch_Metal"],
}


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var obstacles: Array = []
	var stations: Array = []
	var buildings: Array = []
	for b: Dictionary in BUILDINGS:
		var center: Vector2 = b["center"]
		var yaw: float = b["yaw"]
		var nx: int = b["nx"]
		var nz: int = b["nz"]
		var hx := float(nx)  # semiancho en metros (módulo = 2 m)
		var hz := float(nz)
		# Colisión solo en los muros (el interior es transitable); la puerta deja un hueco en el frente.
		var wall_spots: Array = []
		for i in range(nx):
			var x := -hx + 1.0 + 2.0 * float(i)
			if i != nx / 2:
				wall_spots.append(Vector2(x, hz))
			wall_spots.append(Vector2(x, -hz))
		for i in range(nz):
			var z := -hz + 1.0 + 2.0 * float(i)
			wall_spots.append(Vector2(-hx, z))
			wall_spots.append(Vector2(hx, z))
		for cx in [-hx, hx]:
			for cz in [-hz, hz]:
				wall_spots.append(Vector2(cx, cz))
		for spot: Vector2 in wall_spots:
			obstacles.append({"position": center + (spot * 40.0).rotated(-yaw), "radius": 38.0})
		# El NPC está dentro, al fondo, mirando a la puerta; el mostrador lo separa del jugador.
		var npc_local := Vector2(0.0, -hz + 2.2) * 40.0
		var npc_pos := center + npc_local.rotated(-yaw)
		obstacles.append({"position": npc_pos, "radius": 22.0})
		stations.append({
			"id": b["id"], "label": b["label"], "npc": b["npc"], "pos": npc_pos, "radius": 150.0,
			"yaw": yaw, "look": b["look"],
		})
		buildings.append(b)
	# Cimientos de la torre: anillo de bloques con hueco al sur (el portal).
	var ring: Array = []
	var segments := 40
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var out_dir := Vector2(cos(angle), sin(angle))
		if out_dir.dot(Vector2(0.0, 1.0)) > 0.93:  # hueco del portal
			continue
		var height := rng.randf_range(1.5, 7.0) if rng.randf() < 0.8 else rng.randf_range(8.0, 12.0)
		ring.append({"angle": angle, "height": height})
		obstacles.append({"position": TOWER_CENTER + out_dir * TOWER_RADIUS, "radius": 52.0})
	# Pilares del portal (colisión).
	for dx in [-110.0, 110.0]:
		obstacles.append({"position": PORTAL_POS + Vector2(dx, 0.0), "radius": 34.0})
	var stations_all := stations.duplicate()
	stations_all.append({"id": "portal", "label": "Portal de la Torre", "pos": PORTAL_POS + Vector2(0.0, 40.0), "radius": 130.0})
	var decor: Array = []
	_scatter(rng, decor, obstacles, stations_all)
	var villagers := _villagers(obstacles)
	return {
		"seed": seed_value, "name": "Pueblo", "bounds": Rect2(Vector2.ZERO, SIZE),
		"spawn": Vector2(1200.0, 1560.0), "buildings": buildings, "stations": stations_all,
		"ring": ring, "obstacles": obstacles, "decor": decor, "villagers": villagers,
	}


## Aldeanos decorativos (fijos): plaza, camino y clientes de la taberna.
static func _villagers(obstacles: Array) -> Array:
	var list: Array = [
		{"model": "peasant_1", "pos": Vector2(1060.0, 1180.0), "yaw": 2.2},
		{"model": "peasant_4", "pos": Vector2(1330.0, 1130.0), "yaw": -1.8},
		{"model": "rich_citizens_2", "pos": Vector2(1290.0, 1260.0), "yaw": 3.6},
		{"model": "peasant_2", "pos": Vector2(980.0, 1010.0), "yaw": 1.2},
		{"model": "city_dwellers_1", "pos": Vector2(1420.0, 960.0), "yaw": -2.6},
		{"model": "peasant_5", "pos": Vector2(840.0, 1210.0), "yaw": 0.6},
		{"model": "queen", "pos": Vector2(1350.0, 860.0), "yaw": 3.1},
		{"model": "peasant_6", "pos": Vector2(740.0, 1090.0), "yaw": 1.9},
	]
	var tavern: Dictionary = BUILDINGS[2]
	for patron in [{"model": "peasant_3", "local": Vector2(-2.6, 2.4), "yaw": 1.4}, {"model": "rich_citizens_4", "local": Vector2(2.9, 3.4), "yaw": -1.2}, {"model": "king", "local": Vector2(-1.4, 3.6), "yaw": 2.6}]:
		var pos: Vector2 = (tavern["center"] as Vector2) + ((patron["local"] as Vector2) * 40.0).rotated(-float(tavern["yaw"]))
		list.append({"model": patron["model"], "pos": pos, "yaw": float(tavern["yaw"]) + float(patron["yaw"])})
	for v: Dictionary in list:
		obstacles.append({"position": v["pos"], "radius": 20.0})
	return list


static func _scatter(rng: RandomNumberGenerator, decor: Array, obstacles: Array, stations: Array) -> void:
	var keep_clear: Array = []
	for o: Dictionary in obstacles:
		keep_clear.append([o["position"], float(o["radius"]) + 30.0])
	for s: Dictionary in stations:
		keep_clear.append([s["pos"], 150.0])
	keep_clear.append([Vector2(1200.0, 1560.0), 160.0])
	keep_clear.append([Vector2(1200.0, 1100.0), 330.0])  # plaza
	for b: Dictionary in BUILDINGS:
		keep_clear.append([b["center"], 260.0])
	keep_clear.append([TOWER_CENTER, TOWER_RADIUS + 90.0])
	var pines := ["Pine_1", "Pine_1", "Pine_1", "Pine_2", "Pine_2", "Pine_2", "Pine_3", "Pine_3", "Pine_3", "CommonTree_3", "CommonTree_4"]  # los comunes cuestan mucho GPU: pocos
	var flora := ["Grass_Common_Tall", "Grass_Common_Short", "Flower_3_Group", "Flower_4_Group", "Clover_1", "Fern_1"]
	# Camino de la plaza al portal y del spawn a la plaza (se mantiene despejado).
	var road := [Vector2(1200.0, 1560.0), Vector2(1200.0, 1100.0), PORTAL_POS + Vector2(0.0, 60.0)]
	for attempt in range(380):
		var point := Vector2(rng.randf_range(20.0, SIZE.x - 20.0), rng.randf_range(20.0, SIZE.y - 20.0))
		var edge := minf(minf(point.x, SIZE.x - point.x), minf(point.y, SIZE.y - point.y))
		if rng.randf() > lerpf(1.0, 0.05, clampf(edge / 300.0, 0.0, 1.0)):
			continue
		var ok := true
		for c: Array in keep_clear:
			if point.distance_to(c[0]) < float(c[1]):
				ok = false
				break
		for i in range(road.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1])) < 90.0:
				ok = false
		if not ok:
			continue
		var scale := rng.randf_range(0.9, 1.5)
		decor.append({"scene": N + pines[rng.randi() % pines.size()] + ".gltf", "pos": point, "yaw": rng.randf() * TAU, "scale": scale * 0.55})
		obstacles.append({"position": point, "radius": 14.0 * scale})
		keep_clear.append([point, 38.0 * scale])
	for attempt in range(320):
		var point := Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(0.0, SIZE.y))
		var near_road := false
		for i in range(road.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1])) < 55.0:
				near_road = true
		if near_road or point.distance_to(TOWER_CENTER) < TOWER_RADIUS - 20.0:
			continue
		var skip := false
		for b: Dictionary in BUILDINGS:
			if absf(point.x - (b["center"] as Vector2).x) < 190.0 and absf(point.y - (b["center"] as Vector2).y) < 210.0:
				skip = true
		if skip:
			continue
		decor.append({"scene": N + flora[rng.randi() % flora.size()] + ".gltf", "pos": point, "yaw": rng.randf() * TAU, "scale": rng.randf_range(0.5, 0.8)})


# --- Visual ---------------------------------------------------------------------------------


## Devuelve los edificios (techo y muros delanteros) para ocultarlos al entrar. Ver update_interiors.
static func build(parent: Node3D, data: Dictionary) -> Array:
	_npc_tags.clear()
	MeadowFloor._build_environment(parent)
	_ground(parent)
	var holder := Node3D.new()
	holder.name = "TownDecor"
	parent.add_child(holder)
	MeadowFloor.build_decor(holder, data["decor"])
	var handles: Array = []
	for b: Dictionary in data["buildings"]:
		handles.append(_building(holder, b))
	for st: Dictionary in data["stations"]:
		if st["id"] != "portal":
			_station_props(holder, st, data)
	for v: Dictionary in data["villagers"]:
		_villager(holder, v)
	_tower_foundation(holder, data)
	_portal(holder)
	_lights_and_fences(holder, data)
	return handles


static func _stone_material(tint: Color = Color(0.75, 0.72, 0.68)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex := load(V + "T_Brick_BaseColor.png") as Texture2D
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	mat.roughness = 0.95
	return mat


static func _ground(parent: Node3D) -> void:
	MeadowFloor._build_ground_plane(parent, SIZE)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.55, 0.45, 0.33)
	dirt.roughness = 1.0
	# Plaza empedrada y caminos.
	var plaza := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 8.0
	cyl.bottom_radius = 8.0
	cyl.height = 0.04
	cyl.material = _stone_material(Color(0.62, 0.58, 0.52))
	plaza.mesh = cyl
	plaza.position = View3D.to3(Vector2(1200.0, 1100.0), 0.02)
	parent.add_child(plaza)
	var road := [Vector2(1200.0, 1700.0), Vector2(1200.0, 1100.0), PORTAL_POS + Vector2(0.0, 60.0)]
	for i in range(road.size() - 1):
		_strip(parent, road[i], road[i + 1], 4.0, dirt)
	for b: Dictionary in BUILDINGS:
		_strip(parent, Vector2(1200.0, 1100.0), (b["center"] as Vector2) + Vector2(0.0, 0.0).rotated(0.0), 3.0, dirt)


static func _strip(parent: Node3D, a: Vector2, b: Vector2, width: float, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.03, View3D.meters(a.distance_to(b)))
	box.material = mat
	var node := MeshInstance3D.new()
	node.mesh = box
	node.position = View3D.to3((a + b) * 0.5, 0.012)
	var d := View3D.to3(b) - View3D.to3(a)
	node.rotation.y = atan2(d.x, d.z)
	parent.add_child(node)


static func _piece(parent: Node3D, path: String, pos: Vector3, yaw: float, scale: float = 1.0) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node


static func _building(parent: Node3D, b: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = String(b["id"])
	root.position = View3D.to3(b["center"])
	root.rotation.y = float(b["yaw"])
	parent.add_child(root)
	var nx: int = b["nx"]
	var nz: int = b["nz"]
	var hx := float(nx)
	var hz := float(nz)
	var style: String = b["style"]
	var straight := V + "Wall_%s_Straight.gltf" % style
	var door := V + "Wall_%s_Door_Round.gltf" % style
	var window := V + "Wall_%s_Window_Wide_Round.gltf" % style
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(hx * 2.0, 0.1, hz * 2.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.21, 0.13)
	floor_box.material = wood
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = 0.05
	root.add_child(floor_mesh)
	var yaw: float = b["yaw"]
	var camera_walls: Array = []  # muros cuyo exterior mira al sur (hacia la cámara): se ocultan al entrar
	var track := func(node: Node3D, outward_local: Vector3) -> void:
		if node != null and (Basis(Vector3.UP, yaw) * outward_local).z > 0.5:
			camera_walls.append(node)
	for i in range(nx):  # frente (+Z, puerta) y fondo (-Z)
		var x := -hx + 1.0 + 2.0 * float(i)
		var front := door if i == nx / 2 else (window if i % 2 == 1 else straight)
		track.call(_piece(root, front, Vector3(x, 0.0, hz), PI), Vector3(0, 0, 1))
		track.call(_piece(root, window if i % 2 == 0 else straight, Vector3(x, 0.0, -hz), 0.0), Vector3(0, 0, -1))
	for i in range(nz):  # laterales
		var z := -hz + 1.0 + 2.0 * float(i)
		track.call(_piece(root, window if i % 2 == 1 else straight, Vector3(-hx, 0.0, z), PI * 0.5), Vector3(-1, 0, 0))
		track.call(_piece(root, window if i % 2 == 0 else straight, Vector3(hx, 0.0, z), -PI * 0.5), Vector3(1, 0, 0))
	for cx in [-hx, hx]:
		for cz in [-hz, hz]:
			track.call(_piece(root, V + "Corner_Exterior_Wood.gltf", Vector3(cx, 0.0, cz), 0.0), Vector3(cx, 0, cz).normalized())
	var roof := Node3D.new()
	root.add_child(roof)
	_piece(roof, V + "Roof_RoundTiles_%s.gltf" % b["roof"], Vector3(0.0, WALL_H + 0.78, 0.0), 0.0)
	_piece(roof, V + "Prop_Chimney.gltf", Vector3(hx * 0.5, WALL_H + 1.0, -hz * 0.4), 0.0)
	_interior(root, b)
	var sign := Label3D.new()
	sign.text = String(b["label"])
	sign.font_size = 64
	sign.outline_size = 14
	sign.pixel_size = 0.0075
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.modulate = Color(1.0, 0.9, 0.55)
	sign.font = GameTheme.font(true)
	sign.position = Vector3(0.0, WALL_H + 3.0, hz + 0.5)
	root.add_child(sign)
	return {"id": b["id"], "center": b["center"], "yaw": yaw, "hx": hx, "hz": hz, "roof": roof, "walls": camera_walls, "sign": sign}


## Muebles de cada local (en ejes locales del edificio; +Z = puerta).
const INTERIOR := {
	"blacksmith": [["Anvil", -2.4, -1.2, 0.0], ["WeaponStand", 2.6, -3.2, 0.0], ["Workbench", -2.4, -3.0, PI * 0.5], ["Barrel", 2.8, -0.2, 0.0], ["Whetstone", -2.8, 0.8, 0.0], ["Sword_Bronze", 2.6, -2.2, 0.0], ["Pickaxe_Bronze", -3.2, 2.0, 0.0]],
	"alchemy": [["Cauldron", -2.2, -1.0, 0.0], ["Shelf_Small_Bottles", 0.0, -3.7, 0.0], ["Bookcase_2", 3.4, -2.0, -PI * 0.5], ["Table_Large", 2.0, 1.0, 0.0], ["Potion_1", 1.6, 1.0, 0.0], ["Potion_2", 2.1, 1.1, 0.0], ["Potion_4", 2.6, 0.9, 0.0], ["BookStand", -3.0, 2.0, 0.0]],
	"tavern": [["Table_Large", 0.0, -1.2, 0.0], ["Mug", -0.6, -1.2, 0.0], ["Mug", 0.5, -1.1, 0.0], ["Barrel_Apples", 3.2, -4.0, 0.0], ["Barrel", 3.3, -3.0, 0.0], ["Table_Large", -2.2, 2.2, 0.0], ["Chair_1", -2.6, 1.2, 0.0], ["Chair_1", -1.8, 3.2, PI], ["Table_Large", 2.4, 3.0, 0.0], ["Chair_1", 2.2, 2.0, 0.0], ["Torch_Metal", -3.5, -3.5, 0.0], ["Torch_Metal", 3.5, 4.2, 0.0]],
	"leatherworker": [["Peg_Rack", 0.0, -3.5, 0.0], ["Cabinet", 3.4, -1.8, -PI * 0.5], ["Table_Large", -2.0, 1.0, 0.0], ["Pouch_Large", -2.4, 1.0, 0.0], ["Bag", -1.6, 1.0, 0.0], ["Barrel", 3.2, 2.6, 0.0], ["Rope_1", -3.2, -3.0, 0.0], ["Bucket_Metal", 3.0, 0.4, 0.0]],
	"tailor": [["Peg_Rack", 0.0, -3.5, 0.0], ["Cabinet", -3.4, -1.8, PI * 0.5], ["Table_Large", 2.0, 1.2, 0.0], ["Bag", 1.6, 1.2, 0.0], ["Pouch_Large", 2.4, 1.2, 0.0], ["Bookcase_2", 3.4, -2.6, -PI * 0.5], ["Banner_2", -3.5, 2.8, 0.0], ["CandleStick_Triple", 2.0, 0.9, 0.0]],
	"carpenter": [["Workbench", -2.4, -3.0, PI * 0.5], ["Workbench", 2.4, -3.0, -PI * 0.5], ["Crate_Wooden", 3.2, 1.0, 0.0], ["Crate_Wooden", 3.2, 2.2, 0.0], ["Barrel", -3.2, 2.2, 0.0], ["Bucket_Wooden_1", -3.0, 0.6, 0.0], ["Rope_1", 0.0, -3.7, 0.0], ["Shelf_Simple", -3.7, -0.4, PI * 0.5]],
}


static func _interior(root: Node3D, b: Dictionary) -> void:
	for entry: Array in INTERIOR[b["id"]]:
		_piece(root, P + String(entry[0]) + ".gltf", Vector3(float(entry[1]), 0.1, float(entry[2])), float(entry[3]))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.6, 0.0)
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 10.0
	root.add_child(lamp)


## Oculta techo y muros del lado de la cámara cuando el jugador está dentro (como WoW al entrar).
static func update_interiors(handles: Array, player_px: Vector2) -> String:
	var inside_id := ""
	for h: Dictionary in handles:
		var local := (player_px - (h["center"] as Vector2)).rotated(float(h["yaw"])) / 40.0
		var inside := absf(local.x) < float(h["hx"]) + 0.3 and absf(local.y) < float(h["hz"]) + 0.3
		(h["roof"] as Node3D).visible = not inside
		if inside:
			inside_id = String(h["id"])
		var tag: Label3D = _npc_tags.get(String(h["id"]))
		if is_instance_valid(tag):  # el letrero del NPC solo se ve de cerca o dentro (no flota sobre los techos)
			tag.visible = inside or player_px.distance_to(h["center"]) < 300.0
		for w: Node3D in h["walls"]:
			w.visible = not inside
	return inside_id


static func _station_props(parent: Node3D, station: Dictionary, _data: Dictionary) -> void:
	var rig := HumanoidRig.new()
	rig.position = View3D.to3(station["pos"])
	rig.rotation.y = float(station["yaw"])  # mira hacia la puerta (+Z local)
	parent.add_child(rig)
	rig.setup_model(CharacterBuilder.build(station["look"]))
	var clip: String = STATION_ANIM.get(String(station["id"]), "ual1/Idle")
	if rig.has(clip):
		rig.player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		rig.player.play(clip, 0.0, 0.8 + randf() * 0.3)  # desfase de ritmo para que no vayan sincronizados
		rig.player.seek(randf() * 1.5, true)
	else:
		rig.play("ual1/Idle")
	var tag := Label3D.new()
	tag.text = "%s
<%s>" % [station["npc"], station["label"]]
	tag.font_size = 44
	tag.outline_size = 10
	tag.pixel_size = 0.008
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(1.0, 0.92, 0.45)
	tag.font = GameTheme.font(true)
	tag.position = View3D.to3(station["pos"], 2.6)
	parent.add_child(tag)
	_npc_tags[String(station["id"])] = tag


static var _people_mat: StandardMaterial3D
static var _npc_tags: Dictionary = {}


## Aldeano de Craftpix (FBX en T-pose): se le bajan los brazos y se le pone la textura compartida.
static func _villager(parent: Node3D, v: Dictionary) -> void:
	var scene := load("res://assets/models/people/%s.fbx" % v["model"]) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	node.position = View3D.to3(v["pos"])
	node.rotation.y = float(v["yaw"])
	parent.add_child(node)
	if _people_mat == null:
		_people_mat = StandardMaterial3D.new()
		_people_mat.albedo_texture = load("res://assets/texture/people_texture_map.png") as Texture2D
		_people_mat.roughness = 0.9
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _people_mat
	var sk := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for bone_name in ["Upperarm_R", "Upperarm_L"]:
		var b := sk.find_bone(bone_name)
		var parent_idx := sk.get_bone_parent(b)
		var parent_basis := sk.get_bone_global_pose(parent_idx).basis
		var global_basis := parent_basis * Basis(sk.get_bone_rest(b).basis)
		var side := signf(sk.get_bone_global_pose(b).origin.x)
		var lowered := Basis(Vector3(0, 0, 1), -side * 1.25) * global_basis
		sk.set_bone_pose_rotation(b, (parent_basis.inverse() * lowered).get_rotation_quaternion())
	# Respira: leve vaivén para que no parezcan estatuas.
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "rotation:y", float(v["yaw"]) + 0.12, 2.5 + randf()).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "rotation:y", float(v["yaw"]) - 0.12, 2.5 + randf()).set_trans(Tween.TRANS_SINE)


static func _tower_foundation(parent: Node3D, data: Dictionary) -> void:
	var stone := _stone_material(Color(0.7, 0.68, 0.66))
	var center := View3D.to3(TOWER_CENTER)
	var radius_m := View3D.meters(TOWER_RADIUS)
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius_m
	disc.bottom_radius = radius_m + 0.6
	disc.height = 0.5
	disc.material = _stone_material(Color(0.5, 0.48, 0.47))
	floor_disc.mesh = disc
	floor_disc.position = center + Vector3(0.0, 0.2, 0.0)
	parent.add_child(floor_disc)
	var chord := TAU * radius_m / 40.0 + 0.4
	for seg: Dictionary in data["ring"]:
		var angle: float = seg["angle"]
		var height: float = seg["height"]
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(chord, height, 2.2)
		box.material = stone
		block.mesh = box
		block.position = center + Vector3(cos(angle) * radius_m, height * 0.5, sin(angle) * radius_m)
		block.rotation.y = -angle + PI * 0.5
		parent.add_child(block)
		if height > 8.0:  # almenas rotas sobre los muñones altos
			var cap := MeshInstance3D.new()
			var cap_box := BoxMesh.new()
			cap_box.size = Vector3(chord * 0.5, 1.2, 2.6)
			cap_box.material = stone
			cap.mesh = cap_box
			cap.position = block.position + Vector3(0.0, height * 0.5 + 0.5, 0.0)
			cap.rotation.y = block.rotation.y
			parent.add_child(cap)
	# Columnas interiores y escombros: la torre apenas empezó a levantarse.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["seed"]) + 77
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var col := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.9
		cyl.bottom_radius = 1.1
		cyl.height = rng.randf_range(2.0, 5.0)
		cyl.material = stone
		col.mesh = cyl
		col.position = center + Vector3(cos(a) * radius_m * 0.55, cyl.height * 0.5 + 0.4, sin(a) * radius_m * 0.55)
		parent.add_child(col)
	for i in range(18):
		var rubble := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.2))
		rb.material = stone
		rubble.mesh = rb
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.2, 1.15) * radius_m
		rubble.position = center + Vector3(cos(ang) * dist, 0.5, sin(ang) * dist)
		rubble.rotation.y = rng.randf() * TAU
		parent.add_child(rubble)
	var glow := OmniLight3D.new()
	glow.position = center + Vector3(0.0, 4.0, 0.0)
	glow.light_color = Color(0.7, 0.55, 1.0)
	glow.light_energy = 1.2
	glow.omni_range = 20.0
	parent.add_child(glow)


const PORTAL_SHADER := "shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
uniform vec4 tint : source_color = vec4(0.65, 0.4, 1.0, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5, 0.5);
	uv.y *= 0.8;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float w = sin(a * 5.0 + TIME * 2.2 - r * 20.0) * 0.5 + 0.5;
	float body = smoothstep(0.5, 0.3, r);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.9, 1.0), w * 0.6 * body) * (0.6 + 0.9 * body);
	ALPHA = body * (0.45 + 0.55 * w);
}
"


static func _portal(parent: Node3D) -> void:
	make_portal(parent, PORTAL_POS, Color(0.65, 0.4, 1.0), 1.0)


## Arco de piedra con vórtice: el portal del pueblo (violeta) y la salida de cada piso (verde, más pequeña).
static func make_portal(parent: Node3D, pos_px: Vector2, tint: Color, size: float) -> Node3D:
	var stone := _stone_material(Color(0.62, 0.6, 0.62))
	var root := Node3D.new()
	root.name = "Portal"
	root.position = View3D.to3(pos_px)
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	for dx in [-2.75, 2.75]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.3, 7.0, 1.3)
		box.material = stone
		pillar.mesh = box
		pillar.position = Vector3(dx, 3.5, 0.0)
		root.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lbox := BoxMesh.new()
	lbox.size = Vector3(7.4, 1.2, 1.5)
	lbox.material = stone
	lintel.mesh = lbox
	lintel.position = Vector3(0.0, 7.5, 0.0)
	root.add_child(lintel)
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.4, 6.6)
	var shader := Shader.new()
	shader.code = PORTAL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	quad.material = mat
	sheet.mesh = quad
	sheet.position = Vector3(0.0, 3.5, 0.0)
	root.add_child(sheet)
	var motes := ArcaneFx.sparks(Color(0.8, 0.6, 1.0), 40, 2.4, 1.2, 0.14, false)
	motes.position = Vector3(0.0, 3.0, 0.3)
	motes.emission_sphere_radius = 2.2
	root.add_child(motes)
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 3.5, 2.0)
	light.light_color = Color(0.7, 0.5, 1.0)
	light.light_energy = 3.0
	light.omni_range = 14.0
	root.add_child(light)
	return root


static func _lights_and_fences(parent: Node3D, data: Dictionary) -> void:
	# Antorchas a lo largo del camino principal.
	for y in [1450.0, 1250.0, 900.0]:
		for dx in [-170.0, 170.0]:
			_piece(parent, P + "Torch_Metal.gltf", View3D.to3(Vector2(1200.0 + dx, y)), 0.0)
			var light := OmniLight3D.new()
			light.position = View3D.to3(Vector2(1200.0 + dx, y), 2.2)
			light.light_color = Color(1.0, 0.7, 0.35)
			light.light_energy = 1.0
			light.omni_range = 6.0
			parent.add_child(light)
