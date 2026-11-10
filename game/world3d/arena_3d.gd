## Arena3D — patio de entrenamiento en 3D, cámara 3/4 y helpers de VFX/SFX.
##
## Mismo contrato que la Arena 2D: build(world) entrega límites y obstáculos a
## [CombatWorld] (en píxeles de sim) y spawnea los actores. Todo lo demás es
## presentación: la simulación no sabe que existe el 3D.
class_name Arena3D
extends Node3D

## Actores como escenas: ábrelas en el editor para ajustar modelo, tinte, nombre...
const PLAYER_SCENE := preload("res://game/actors3d/player_actor.tscn")
const SOLDIER_SCENE := preload("res://game/actors3d/soldier_actor.tscn")
const DUMMY_SCENE := preload("res://game/actors3d/dummy_actor.tscn")

const SIZE := Vector2(960.0, 640.0)
const WALL := 40.0
const BOUNDS := Rect2(WALL, WALL, SIZE.x - WALL * 2.0, SIZE.y - WALL * 2.0)
const WALL_HEIGHT := 1.1
const PILLAR_RADIUS_PX := 21.0

const PILLARS := [
	Vector2(145, 145), Vector2(815, 145),
	Vector2(145, 495), Vector2(815, 495),
	Vector2(185, 320), Vector2(775, 320),
]

const DUMMY_SPAWNS := [
	{"position": Vector2(480, 150), "enemy": true, "level": 1},
	{"position": Vector2(680, 400)},
	{"position": Vector2(280, 420)},
]

# Cámara estilo Battlerite: alta, inclinada ~55°, sigue al jugador con un poco
# de adelanto hacia el ratón.
const CAM_FOV := 40.0
const SHAKE_PX_TO_M := 0.025

const STONE := Color(0.36, 0.37, 0.41)
const STONE_DARK := Color(0.22, 0.23, 0.27)
const GOLD := Color(0.95, 0.72, 0.32)

var world: CombatWorld
var camera: Camera3D
var fx: Node3D
var warrior_actor: WarriorActor3D
var dummy_actors: Array[DummyActor3D] = []
var enemy_actors: Array[WarriorActor3D] = []

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _cam_focus: Vector3 = Vector3.ZERO
## Cámara en tercera persona (estilo Smite): ratón capturado, mira en el centro.
var tp_zoom: float = 1.0
const TP_ZOOM_MIN := 0.3
const TP_ZOOM_MAX := 2.2
## Modo top-down (estilo Battlerite/Albion): cámara aérea fija, ratón libre como puntero.
var topdown: bool = true
## Inclinación de la cámara aérea: 0 = más inclinada (más vista), 1 = casi cenital (más precisa).
var td_tilt: float = 0.5
var tp_yaw: float = 0.0
var tp_pitch: float = -0.35
const TP_OFFSET := Vector3(0.9, 0.5, 4.2)
const TP_SENS := 0.0025
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()
var _torches: Array = []
var _static_parent: Node3D


func build(p_world: CombatWorld) -> void:
	world = p_world
	_rng.seed = 90210
	world.setup_arena(BOUNDS, _obstacles())

	# El escenario estático vive en el editor (hijo "Level" = training_arena.tscn).
	# Si falta, se genera por código (es también lo que usa tools/bake_arena_scene.gd).
	if not has_node("Level"):
		build_static(self)
	_collect_torches()
	_build_emblem(self)
	_build_sfx_pool()

	fx = Node3D.new()
	fx.name = "Fx"
	add_child(fx)

	_build_camera()
	_spawn_actors()


## Piso de la torre (ver MeadowFloor): sin Level del editor, enemigos por campamento.
func build_floor(p_world: CombatWorld, data: Dictionary) -> void:
	world = p_world
	_rng.seed = int(data["seed"])
	var level := get_node_or_null("Level")
	if level != null:
		remove_child(level)
		level.free()
	world.setup_arena(data["bounds"], data["obstacles"])
	world.warrior.position = data["spawn"]
	world.warrior.reset(data["spawn"])
	_static_parent = self
	MeadowFloor.build(self, data)
	_build_sfx_pool()
	fx = Node3D.new()
	fx.name = "Fx"
	add_child(fx)
	_build_camera()
	warrior_actor = PLAYER_SCENE.instantiate() as WarriorActor3D
	warrior_actor.name = "Player"
	add_child(warrior_actor)
	warrior_actor.setup(world.warrior, self)
	var group := 0
	for camp: Dictionary in data["camps"]:
		for e: Dictionary in camp["enemies"]:
			spawn_class_enemy(StringName(String(e["arch"])), e["pos"], int(e["level"]), group, 260.0)
		group += 1


## Genera el escenario estático (luces, suelo, muros, pilares, antorchas) bajo `parent`.
func build_static(parent: Node3D) -> void:
	_static_parent = parent
	_build_environment()
	_build_floor()
	_build_walls()
	_update_wall_visibility()
	_build_pillars()
	_build_torches()


func _collect_torches() -> void:
	_torches.clear()
	var i := 0
	for torch: Node in get_tree().get_nodes_in_group("torches") if is_inside_tree() else []:
		var light := torch.get_node_or_null("Light") as OmniLight3D
		var flame := torch.get_node_or_null("Flame") as Node3D
		if light != null and flame != null:
				i += 1


func _obstacles() -> Array:
	var out: Array = []
	for point: Vector2 in PILLARS:
		out.append({"position": point, "radius": PILLAR_RADIUS_PX})
	return out


# --- Escenario ----------------------------------------------------------------


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	# SSAO desactivado: en GPUs integradas cuesta más de lo que aporta con
	# esta cámara tan alta.
	env.ssao_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.13)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	_static_parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Moon"
	sun.light_color = Color(0.80, 0.86, 1.0)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_static_parent.add_child(sun)


func _build_floor() -> void:
	var size_m := Vector2(View3D.meters(SIZE.x), View3D.meters(SIZE.y))
	var center := View3D.to3(SIZE * 0.5)

	# Terreno exterior oscuro, por si la cámara ve más allá de los muros.
	var outside := MeshInstance3D.new()
	var out_plane := PlaneMesh.new()
	out_plane.size = size_m * 3.0
	outside.mesh = out_plane
	var out_mat := StandardMaterial3D.new()
	out_mat.albedo_color = Color(0.06, 0.065, 0.08)
	out_mat.roughness = 1.0
	outside.material_override = out_mat
	outside.name = "Outside"
	outside.position = center + Vector3(0, -0.02, 0)
	_static_parent.add_child(outside)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(View3D.meters(BOUNDS.size.x), View3D.meters(BOUNDS.size.y))
	floor_mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/world3d/stone_floor.gdshader")
	floor_mesh.material_override = mat
	floor_mesh.position = View3D.to3(BOUNDS.get_center())
	_static_parent.add_child(floor_mesh)


func _build_walls() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE_DARK
	mat.roughness = 0.9
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = STONE
	cap_mat.roughness = 0.8
	var w := View3D.meters(WALL)
	var sx := View3D.meters(SIZE.x)
	var sz := View3D.meters(SIZE.y)
	var walls := [
		[Vector3(sx * 0.5, 0, w * 0.5), Vector3(sx, WALL_HEIGHT, w)],
		[Vector3(sx * 0.5, 0, sz - w * 0.5), Vector3(sx, WALL_HEIGHT * 0.45, w)],
		[Vector3(w * 0.5, 0, sz * 0.5), Vector3(w, WALL_HEIGHT, sz)],
		[Vector3(sx - w * 0.5, 0, sz * 0.5), Vector3(w, WALL_HEIGHT, sz)],
	]
	# El muro sur (el más cercano a la cámara) es bajo para no tapar el combate.
	for entry: Array in walls:
		var pos: Vector3 = entry[0]
		var size: Vector3 = entry[1]
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		box.mesh = mesh
		box.material_override = mat
		box.name = "Wall%d" % walls.find(entry)
		box.position = pos + Vector3(0, size.y * 0.5, 0)
		_static_parent.add_child(box)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + 0.08, 0.1, size.z + 0.08)
		cap.mesh = cap_mesh
		cap.material_override = cap_mat
		cap.name = "WallCap%d" % walls.find(entry)
		cap.position = pos + Vector3(0, size.y + 0.05, 0)
		_static_parent.add_child(cap)


func _build_pillars() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.85
	var dark := StandardMaterial3D.new()
	dark.albedo_color = STONE_DARK
	dark.roughness = 0.9
	var r := View3D.meters(PILLAR_RADIUS_PX)
	for point: Vector2 in PILLARS:
		var root := Node3D.new()
		root.name = "Pillar%d" % PILLARS.find(point)
		root.position = View3D.to3(point)
		_static_parent.add_child(root)
		var parts := [
			[CylinderMesh.new(), r * 1.35, r * 1.45, 0.28, 0.14, dark],
			[CylinderMesh.new(), r * 0.82, r * 0.9, 2.2, 1.38, stone],
			[CylinderMesh.new(), r * 1.25, r * 1.05, 0.22, 2.55, dark],
		]
		for p: Array in parts:
			var cyl: CylinderMesh = p[0]
			cyl.top_radius = p[1]
			cyl.bottom_radius = p[2]
			cyl.height = p[3]
			cyl.radial_segments = 12
			var mi := MeshInstance3D.new()
			mi.mesh = cyl
			mi.material_override = p[5]
			mi.position.y = p[4]
			root.add_child(mi)


func _build_torches() -> void:
	var spots := [
		Vector2(WALL + 4.0, 172.0), Vector2(WALL + 4.0, 468.0),
		Vector2(SIZE.x - WALL - 4.0, 172.0), Vector2(SIZE.x - WALL - 4.0, 468.0),
		Vector2(330.0, WALL + 4.0), Vector2(630.0, WALL + 4.0),
	]
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.15, 0.15, 0.17)
	metal.metallic = 0.6
	metal.roughness = 0.5
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color(1.0, 0.62, 0.22)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.5, 0.15)
	fire.emission_energy_multiplier = 4.0
	for i: int in range(spots.size()):
		var root := Node3D.new()
		root.name = "Torch%d" % i
		root.add_to_group("torches", true)
		root.position = View3D.to3(spots[i], WALL_HEIGHT + 0.1)
		_static_parent.add_child(root)
		var bowl := MeshInstance3D.new()
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 0.16
		bowl_mesh.bottom_radius = 0.06
		bowl_mesh.height = 0.16
		bowl.mesh = bowl_mesh
		bowl.material_override = metal
		root.add_child(bowl)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.11
		flame_mesh.height = 0.3
		flame.name = "Flame"
		flame.mesh = flame_mesh
		flame.material_override = fire
		flame.position.y = 0.18
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flame)
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.6, 0.28)
		light.light_energy = 2.2
		light.omni_range = 6.5
		light.position.y = 0.4
		light.shadow_enabled = false
		root.add_child(light)
		_torches.append({"light": light, "flame": flame, "phase": float(i) * 1.7})


func _build_emblem(parent: Node3D) -> void:
	var center := BOUNDS.get_center()
	var ring := FxShape.new().setup(FxShape.Mode.RING, View3D.meters(168.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.07))
	ring.set_param("inner", 0.9)
	ring.position = View3D.to3(center, 0.012)
	parent.add_child(ring)
	var inner_ring := FxShape.new().setup(FxShape.Mode.RING, View3D.meters(150.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.04))
	inner_ring.set_param("inner", 0.97)
	inner_ring.position = View3D.to3(center, 0.012)
	parent.add_child(inner_ring)


func _build_sfx_pool() -> void:
	for i: int in range(14):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%02d" % i
		player.volume_db = -8.0
		add_child(player)
		_sfx_pool.append(player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42.0 if topdown else 70.0
	camera.near = 0.3
	camera.far = 120.0
	add_child(camera)
	_cam_focus = View3D.to3(world.warrior.position)
	_place_camera(Vector3.ZERO)
	camera.make_current()


## Lee los Marker3D de Level/Spawns (meta: enemy, level, hp). Sin ellos usa DUMMY_SPAWNS.
func _read_spawns() -> Array:
	var spawns := get_node_or_null("Level/Spawns")
	if spawns == null:
		return DUMMY_SPAWNS
	var out: Array = []
	for marker: Node in spawns.get_children():
		if marker is Node3D:
			out.append({
				"position": View3D.to2((marker as Node3D).position),
				"enemy": bool(marker.get_meta("enemy", false)),
				"enemy_class": String(marker.get_meta("enemy_class", "")),
				"level": int(marker.get_meta("level", 1)),
				"hp": float(marker.get_meta("hp", 4000.0)),
			})
	return out


## Enemigo que juega una clase (mismos skills que un jugador) con IA y nivel.
func spawn_class_enemy(class_id: StringName, at: Vector2, level: int = 1, group: int = -1, aggro: float = 0.0) -> WarriorSim:
	var fighter := world.add_archetype(String(class_id), 1, at, level)  # acepta arquetipo o clase
	fighter.brain.group = group
	fighter.brain.aggro_range = aggro
	var actor := PLAYER_SCENE.instantiate() as WarriorActor3D
	actor.enemy_mode = true
	actor.name = "Enemy_" + fighter.display_name
	add_child(actor)
	actor.setup(fighter, self)
	enemy_actors.append(actor)
	return fighter


func spawn_swarm(archetype_id: String, count: int, center: Vector2, level: int = 1) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1))
		spawn_class_enemy(StringName(archetype_id), center + Vector2(cos(angle), sin(angle)) * 90.0, level)


func _spawn_actors() -> void:
	warrior_actor = PLAYER_SCENE.instantiate() as WarriorActor3D
	warrior_actor.name = "Player"
	add_child(warrior_actor)
	warrior_actor.setup(world.warrior, self)

	for spawn: Dictionary in _read_spawns():
		var dummy_sim: DummySim
		if String(spawn.get("enemy_class", "")) != "":
			spawn_class_enemy(StringName(String(spawn["enemy_class"])), spawn["position"], int(spawn.get("level", 1)))
			continue
		if bool(spawn.get("enemy", false)):
			dummy_sim = world.add_enemy(spawn["position"], int(spawn.get("level", 1)))
		else:
			dummy_sim = world.add_dummy(spawn["position"], false)
			dummy_sim.max_health = float(spawn.get("hp", 4000.0))
			dummy_sim.health = dummy_sim.max_health
		var dummy: DummyActor3D = (SOLDIER_SCENE if dummy_sim is EnemySim else DUMMY_SCENE).instantiate() as DummyActor3D
		dummy.name = "Dummy"
		add_child(dummy)
		dummy.setup(dummy_sim, self)
		dummy_actors.append(dummy)


# --- Por frame ----------------------------------------------------------------


func _process(delta: float) -> void:
	if world == null or camera == null:
		return

	var target := View3D.to3(world.warrior.position)
	_cam_focus = _cam_focus.lerp(target, 1.0 - exp(-8.0 * delta))

	var shake := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var ratio := _shake_time / maxf(_shake_duration, 0.001)
		var amount := _shake_strength * SHAKE_PX_TO_M * ratio * ratio
		shake = Vector3(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount) * 0.5, _rng.randf_range(-amount, amount))
		if _shake_time <= 0.0:
			_shake_strength = 0.0
			_shake_duration = 0.0
	_place_camera(shake)

	var t := Time.get_ticks_msec() * 0.001
	for torch: Dictionary in _torches:
		var phase: float = torch["phase"]
		var flick := 0.85 + 0.12 * sin(t * 11.0 + phase) + 0.05 * sin(t * 23.0 + phase * 2.0)
		(torch["light"] as OmniLight3D).light_energy = 2.2 * flick
		(torch["flame"] as Node3D).scale = Vector3(1.0, flick, 1.0)


func toggle_topdown() -> void:
	topdown = not topdown
	camera.fov = 42.0 if topdown else 70.0
	_update_wall_visibility()


## Incrementa/decrementa la inclinación de la cámara top-down.
func tilt_topdown(step: float) -> void:
	td_tilt = clampf(td_tilt + step, 0.0, 1.0)


## En top-down el muro sur (el más cercano a la cámara) se oculta para no tapar el combate.
func _update_wall_visibility() -> void:
	for wall_name in ["Wall1", "WallCap1"]:
		var wall := _static_parent.get_node_or_null(wall_name) as Node3D
		if wall != null:
			wall.visible = not topdown


func _place_camera(shake: Vector3) -> void:
	if topdown:
		var offset := Vector3(0.0, lerpf(9.0, 17.0, td_tilt), lerpf(11.0, 2.0, td_tilt))
		camera.position = _cam_focus + offset * tp_zoom + shake
		camera.look_at(_cam_focus + Vector3(0, 0.4, 0) + shake)
		return
	var basis := Basis.from_euler(Vector3(tp_pitch, tp_yaw, 0.0))
	camera.position = _cam_focus + Vector3(0, 1.4, 0) + basis * (TP_OFFSET * tp_zoom) + shake
	camera.basis = basis


func tp_zoom_by(step: float) -> void:
	tp_zoom = clampf(tp_zoom * (1.0 + step), TP_ZOOM_MIN, TP_ZOOM_MAX)


func tp_look(relative: Vector2) -> void:
	tp_yaw -= relative.x * TP_SENS
	tp_pitch = clampf(tp_pitch - relative.y * TP_SENS, -1.1, 0.5)


## Dirección horizontal hacia la que mira la cámara, en coordenadas de sim.
func cam_forward_sim() -> Vector2:
	var f := -camera.global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


## Punto del suelo (y = 0) bajo la mira central, o null si el rayo no lo corta.
func mouse_world() -> Variant:
	if camera == null:
		return null
	# Tercera persona: mira central. Top-down: el puntero del ratón.
	var mouse := get_viewport().get_mouse_position() if topdown else get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var t := -origin.y / normal.y if absf(normal.y) > 0.0001 else -1.0
	if t < 0.0:
		var fwd := -camera.global_transform.basis.z
		fwd.y = 0.0
		return View3D.to3(world.warrior.position) + fwd.normalized() * 30.0
	return origin + normal * t


## Posición del ratón en coordenadas de simulación (píxeles).
func mouse_sim() -> Variant:
	var point: Variant = mouse_world()
	if point == null:
		return null
	return View3D.to2(point)


# --- Helpers de presentación -------------------------------------------------


func add_fx(node: Node3D, at: Vector3) -> Node3D:
	fx.add_child(node)
	node.global_position = at
	return node


## Barrido de espada en forma de media luna a la altura del pecho.
func spawn_swipe(
		at: Vector2, direction: Vector2, radius_px: float, arc_deg: float,
		color: Color, sweep_time: float = 0.08, fade_time: float = 0.16,
		height: float = 0.95, sweep_dir: float = 1.0, inner: float = 0.45
) -> FxShape:
	var shape := FxShape.new().setup(FxShape.Mode.SECTOR, View3D.meters(radius_px), color)
	shape.set_param("arc", deg_to_rad(arc_deg))
	shape.set_param("inner", inner)
	shape.set_param("fill", 0.55)
	shape.set_param("edge", 0.12)
	shape.set_param("head", 1.2)
	shape.set_param("trail", 0.7)
	shape.set_param("sweep_dir", sweep_dir)
	add_fx(shape, View3D.to3(at, height))
	shape.rotation.y = View3D.yaw_for(direction)
	shape.animate_sweep(sweep_time, fade_time)
	return shape


## Estocada: un rectángulo que se alarga desde el pecho.
func spawn_thrust(at: Vector2, direction: Vector2, length_px: float, width_px: float, color: Color) -> FxShape:
	var shape := FxShape.new().setup(FxShape.Mode.RECT, Vector2(View3D.meters(width_px), View3D.meters(length_px)), color)
	shape.set_param("fill", 0.22)
	shape.set_param("edge", 0.1)
	shape.set_param("head", 1.0)
	shape.set_param("taper", 0.25)
	add_fx(shape, View3D.to3(at, 1.0))
	shape.rotation.y = View3D.yaw_for(direction)
	shape.animate_sweep(0.07, 0.15)
	return shape


## Onda expansiva en el suelo.
func spawn_shockwave(at: Vector2, radius_px: float, color: Color, duration: float = 0.45, inner: float = 0.78) -> FxShape:
	var shape := FxShape.new().setup(FxShape.Mode.RING, View3D.meters(radius_px), color)
	shape.set_param("inner", inner)
	add_fx(shape, View3D.to3(at, 0.04))
	shape.animate_burst(duration, 0.15)
	return shape


## Mancha de suelo que se apaga (zona de daño).
func spawn_ground_flash(at: Vector2, radius_px: float, color: Color, duration: float = 0.35) -> FxShape:
	var shape := FxShape.new().setup(FxShape.Mode.DISC, View3D.meters(radius_px), color)
	shape.set_param("fill", 0.35)
	shape.set_param("edge", 0.06)
	add_fx(shape, View3D.to3(at, 0.03))
	shape.animate_fade(duration)
	return shape


func spawn_impact(at: Vector2, color: Color, heavy: bool = false, height: float = 1.1, size: float = 1.0) -> void:
	var impact := ImpactFx.new()
	add_fx(impact, View3D.to3(at, height))
	impact.setup(color, heavy, size)


func spawn_dust(at: Vector2, amount: int = 10, spread: float = 0.6) -> void:
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = amount
	dust.lifetime = 0.55
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = spread * 0.5
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 2.0
	dust.gravity = Vector3(0, -1.5, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	dust.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.48, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	dust.mesh = mesh
	add_fx(dust, View3D.to3(at, 0.1))
	dust.emitting = true
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


func spawn_damage_number(at: Vector2, amount: float, critical: bool = false, height: float = 2.0, color: Color = Color(1.0, 0.92, 0.75)) -> void:
	var number := DamageNumber3D.new()
	number.setup(amount, critical, color)
	add_fx(number, View3D.to3(at, height))
	number.launch()


func play_sfx(stream: AudioStream, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## strength en "píxeles" (misma escala que el prototipo 2D).
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time = maxf(_shake_time, duration)


func dummy_actor_for(sim: Object) -> DummyActor3D:
	for actor: DummyActor3D in dummy_actors:
		if actor.sim == sim:
			return actor
	return null


# --- Marcador de skills de suelo ---------------------------------------------------

var _ground_marker: FxShape
var _range_ring: FxShape
var _aim_line: FxShape


func set_ground_marker(active: bool, at: Vector2, radius_px: float, range_center: Vector2 = Vector2.ZERO, range_px: float = 0.0) -> void:
	if _ground_marker == null:
		_ground_marker = FxShape.new().setup(FxShape.Mode.RING, 1.0, Color(1.0, 0.7, 0.3, 0.9))
		_ground_marker.set_param("inner", 0.9)
		_ground_marker.set_param("fill", 0.12)
		_ground_marker.set_param("pulse", 1.0)
		_ground_marker.visible = false
		add_child(_ground_marker)
		_range_ring = FxShape.new().setup(FxShape.Mode.RING, 1.0, Color(1.0, 1.0, 1.0, 0.45))
		_range_ring.set_param("inner", 0.985)
		_range_ring.set_param("fill", 0.0)
		_range_ring.visible = false
		add_child(_range_ring)
	_ground_marker.visible = active
	_range_ring.visible = active and range_px > 0.0
	if active:
		_ground_marker.position = View3D.to3(at, 0.05)
		_ground_marker.scale = Vector3.ONE * View3D.meters(radius_px)
		if range_px > 0.0:
			_range_ring.position = View3D.to3(range_center, 0.04)  # alcance de la skill alrededor del jugador
			_range_ring.scale = Vector3.ONE * View3D.meters(range_px)


## Línea tenue desde el jugador hacia el cursor (solo top-down).
func set_aim_indicator(active: bool, from: Vector2, direction: Vector2) -> void:
	if _aim_line == null:
		_aim_line = FxShape.new().setup(FxShape.Mode.SECTOR, 3.2, Color(1.0, 1.0, 1.0, 0.5))
		_aim_line.set_param("arc", deg_to_rad(5.0))
		_aim_line.set_param("fill", 0.4)
		_aim_line.set_param("edge", 0.05)
		_aim_line.set_param("trail", 0.0)
		_aim_line.visible = false
		add_child(_aim_line)
	_aim_line.visible = active
	if active:
		_aim_line.position = View3D.to3(from, 0.03)
		_aim_line.rotation.y = View3D.yaw_for(direction)