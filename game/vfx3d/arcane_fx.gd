## ArcaneFx — efectos procedurales de magia arcana (partículas aditivas + luz).
##
## Sin assets externos: todo con CPUParticles3D, mallas esféricas y OmniLight3D, con la
## paleta que pida el tipo de daño (el arcano es violeta). Los usa el actor del jugador.
class_name ArcaneFx
extends RefCounted

const ARCANE := Color(0.78, 0.5, 1.0)


static var _soft: GradientTexture2D


## Punto suave (radial, blanco -> transparente): evita los cuadrados de las partículas.
static func soft_dot() -> GradientTexture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


const PARTICLE_DIR := "res://assets/vfx/particles/"
static var _tex_cache: Dictionary = {}


## Textura de partícula del Kenney Particle Pack (star_04, spark_05, magic_03, slash_02...).
static func particle_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := PARTICLE_DIR + name + ".png"
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else soft_dot()
	return _tex_cache[name]


static func _additive(color: Color, alpha: float = 1.0, tex_name: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = particle_tex(tex_name) if tex_name != "" else soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	return mat


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	return curve


## Partículas de chispas. `one_shot` = explosión; si no, flujo continuo (estela).
static func sparks(color: Color, amount: int, lifetime: float, speed: float, size: float, one_shot: bool, tex_name: String = "star_04") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -0.5 if one_shot else 0.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _fade_curve()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _additive(color, 1.0, tex_name)
	p.mesh = quad
	return p


## Orbe de proyectil: núcleo brillante, halo, estela de chispas y luz.
static func make_orb(color: Color, size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.13 * size
	core_mesh.height = 0.26 * size
	core_mesh.material = _additive(color.lightened(0.5))
	core.mesh = core_mesh
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.3 * size
	halo_mesh.height = 0.6 * size
	halo_mesh.material = _additive(color, 0.28)
	halo.mesh = halo_mesh
	root.add_child(halo)
	root.add_child(sparks(color, 36, 0.45, 0.5, 0.09 * size, false))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	root.add_child(light)
	return root


## Explosión de chispas + destello de luz que se apaga (se libera sola).
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 40, speed: float = 3.5, size: float = 0.14) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	holder.add_child(sparks(color, amount, 0.7, speed, size, true))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 4.0
	holder.add_child(light)
	var tween := holder.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.35)
	tween.tween_interval(0.5)
	tween.tween_callback(holder.queue_free)


## Columna de chispas que sube (aparición/desaparición del Blink, canalizaciones).
static func column(parent: Node, at: Vector3, color: Color, height: float = 2.0) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var p := sparks(color, 60, 0.8, 1.0, 0.1, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = height * 0.8
	p.initial_velocity_max = height * 1.6
	p.gravity = Vector3.ZERO
	holder.add_child(p)
	var tween := holder.create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(holder.queue_free)


## Flecha: asta alargada brillante con estela fina.
static func make_arrow(color: Color) -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.7)
	mesh.material = _additive(color.lightened(0.4))
	(mesh.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	shaft.mesh = mesh
	root.add_child(shaft)
	root.add_child(sparks(color, 18, 0.3, 0.2, 0.05, false))
	return root


# --- Paleta física y de elementos -----------------------------------------------------
const GOLD := Color(1.0, 0.78, 0.35)
const STEEL := Color(0.85, 0.92, 1.0)
const POISON := Color(0.4, 0.95, 0.25)
const FROST := Color(0.6, 0.88, 1.0)


## Chispas de impacto en la dirección del golpe (acero/oro), con gravedad y destello.
static func hit_sparks(parent: Node, at: Vector3, color: Color, dir: Vector3, amount: int = 18, heavy: bool = false) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var p := sparks(color, amount + (14 if heavy else 0), 0.45, 4.5 if heavy else 3.2, 0.07, true)
	p.direction = dir.normalized() + Vector3.UP * 0.35
	p.spread = 40.0
	p.gravity = Vector3(0, -7.0, 0)
	p.emission_sphere_radius = 0.05
	holder.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6 if heavy else 1.0
	light.omni_range = 2.5
	holder.add_child(light)
	var tween := holder.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.18)
	tween.tween_interval(0.5)
	tween.tween_callback(holder.queue_free)


## Escombros que saltan y caen (golpes de suelo).
static func debris(parent: Node, at: Vector3, radius_m: float, color: Color = Color(0.62, 0.52, 0.42)) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius_m * 0.45
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -14.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var cube := BoxMesh.new()
	cube.size = Vector3(0.12, 0.09, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cube.material = mat
	p.mesh = cube
	holder.add_child(p)
	var tween := holder.create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(holder.queue_free)


## Burbujas/humo que suben (veneno): continuo mientras viva `seconds`.
static func rising_puffs(color: Color, amount: int = 24, radius: float = 0.4, size: float = 0.16, speed: float = 0.7) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.scale_amount_curve = _fade_curve()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _additive(color, 0.8)
	p.mesh = quad
	return p


## Aura de efecto en el tiempo sobre un enemigo (burbujas del color del DoT).
## Efecto de daño en el tiempo según el tipo: sangrado = gotas rojas que caen; veneno = burbujas verdes; resto = burbujas del color del daño.
static func dot_aura_for(type: int) -> CPUParticles3D:
	if type == DamageSystem.Type.PHYSICAL:
		var drops := sparks(Color(0.8, 0.04, 0.05), 14, 0.7, 0.5, 0.1, false, "circle_05")
		drops.position.y = 1.3
		drops.emission_sphere_radius = 0.25
		drops.direction = Vector3.DOWN
		drops.spread = 25.0
		drops.gravity = Vector3(0, -4.0, 0)
		drops.damping_min = 0.0
		drops.damping_max = 0.0
		return drops
	return dot_aura(POISON if type == DamageSystem.Type.POISON else DamageSystem.color_of(type))


## Cuchillo giratorio (Mark for Death): hoja que gira sobre su eje de avance, con halo rojo y estela.
static func make_spinning_knife(color: Color) -> Node3D:
	var holder := Node3D.new()
	var spinner := Node3D.new()
	spinner.name = "Spinner"
	holder.add_child(spinner)
	var knife := _knife()
	knife.scale = Vector3(1.6, 1.0, 1.6)
	spinner.add_child(knife)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = _additive(color, 0.9, "star_04")
	halo.mesh = quad
	holder.add_child(halo)
	var trail := sparks(color, 18, 0.35, 0.4, 0.14, false, "spark_05")
	holder.add_child(trail)
	return holder


static func dot_aura(color: Color) -> CPUParticles3D:
	var p := rising_puffs(color, 18, 0.35, 0.13, 0.9)
	p.position.y = 0.2
	return p


## Nube de veneno en el suelo durante `seconds`.
static func poison_cloud(parent: Node, at: Vector3, radius_m: float, seconds: float = 2.5) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var p := rising_puffs(POISON, 50, radius_m * 0.7, 0.34, 0.9)
	p.position.y = 0.1
	holder.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = POISON
	light.light_energy = 1.0
	light.omni_range = radius_m * 2.0
	light.position.y = 0.6
	holder.add_child(light)
	var tween := holder.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(func() -> void: p.emitting = false)
	tween.tween_interval(1.3)
	tween.tween_callback(holder.queue_free)


static func _knife() -> MeshInstance3D:
	var knife := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.015, 0.34)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STEEL
	mat.metallic = 0.8
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = STEEL
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat
	knife.mesh = mesh
	return knife


## Fan of Knives: cuchillos que salen disparados en abanico en todas direcciones.
static func knife_fan(parent: Node, at: Vector3, radius_m: float, count: int = 14, tint: Color = POISON, stagger: float = 0.0) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var knife := _knife()
		parent.add_child(knife)
		knife.global_position = at + Vector3(0, 1.0, 0) + dir * 0.4
		knife.rotation.y = angle
		var trail := sparks(tint, 14, 0.3, 0.3, 0.06, false)
		knife.add_child(trail)
		knife.visible = false
		var tween := knife.create_tween()
		tween.tween_interval(stagger * float(i) / float(count))
		tween.tween_callback(func() -> void: knife.visible = true)
		tween.set_parallel(true)
		tween.tween_property(knife, "global_position", at + Vector3(0, 0.9, 0) + dir * radius_m, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(knife, "scale", Vector3.ONE * 0.2, 0.28).set_delay(0.12)
		tween.chain().tween_callback(knife.queue_free)
	burst(parent, at + Vector3(0, 1.0, 0), tint, 24, 3.0, 0.1)


## Lluvia de flechas sobre un área: caen del cielo en orden escalonado.
static func arrow_rain(parent: Node, at: Vector3, radius_m: float, count: int = 26) -> void:
	for i in range(count):
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if offset.length() > 1.0:
			offset = offset.normalized() * randf()
		var target := at + offset * radius_m
		var arrow := make_arrow(Color(1.0, 0.9, 0.55))
		parent.add_child(arrow)
		arrow.global_position = target + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6))
		arrow.rotation.x = deg_to_rad(80.0)  # apuntando hacia abajo
		var tween := arrow.create_tween()
		tween.tween_interval(randf_range(0.0, 0.45))
		tween.tween_property(arrow, "global_position", target + Vector3(0, 0.1, 0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			hit_sparks(parent, target + Vector3(0, 0.15, 0), Color(1.0, 0.85, 0.5), Vector3.UP, 8, false))
		tween.tween_interval(0.6)
		tween.tween_callback(arrow.queue_free)


## Cristales de hielo que brotan del suelo (Frost Trap).
static func ice_shards(parent: Node, at: Vector3, radius_m: float, count: int = 16, tint: Color = FROST) -> void:
	for i in range(count):
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if offset.length() > 1.0:
			offset = offset.normalized() * randf()
		var shard := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.18, randf_range(0.5, 1.1), 0.18)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 1.2
		mesh.material = mat
		shard.mesh = mesh
		parent.add_child(shard)
		shard.global_position = at + offset * radius_m
		shard.scale = Vector3(1, 0.05, 1)
		shard.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		var tween := shard.create_tween()
		tween.tween_property(shard, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(1.4)
		tween.tween_property(shard, "scale", Vector3(1, 0.02, 1), 0.3)
		tween.tween_callback(shard.queue_free)
	burst(parent, at + Vector3(0, 0.3, 0), tint, 36, 3.0, 0.1)


## Destello en la boca del arma (disparo).
static func muzzle(parent: Node, at: Vector3, dir: Vector3, color: Color) -> void:
	hit_sparks(parent, at, color, dir, 8, false)


## Rayo/cadena entre dos puntos (Arcane Pull): barra brillante que se desvanece y chispas a lo largo.
static func beam(parent: Node, from: Vector3, to: Vector3, color: Color, seconds: float = 0.3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = (from + to) * 0.5
	holder.look_at(to, Vector3.UP)
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, length)
	var mat := _additive(color.lightened(0.4))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mesh.material = mat
	bar.mesh = mesh
	holder.add_child(bar)
	for i in range(6):
		var spark := sparks(color, 8, 0.4, 0.4, 0.1, true)
		spark.position = Vector3(0, 0, lerpf(-length * 0.5, length * 0.5, float(i) / 5.0))
		holder.add_child(spark)
	var tween := holder.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(holder.queue_free)


## Zona persistente (Time Rift): anillo que gira, remolino de partículas y se apaga tras `seconds`.
## Destello con textura (billboard) que crece y se desvanece: cortes, impactos, fogonazos.
static func flash_sprite(parent: Node, at: Vector3, tex_name: String, color: Color, size_m: float, seconds: float = 0.2, roll: float = 0.0) -> void:
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size_m, size_m)
	var mat := _additive(color, 1.0, tex_name)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	quad.material = mat
	sprite.mesh = quad
	parent.add_child(sprite)
	sprite.global_position = at
	sprite.rotation.z = roll
	sprite.scale = Vector3.ONE * 0.5
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.1, seconds * 0.6)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(sprite.queue_free)


## Círculo mágico en el suelo (decal horizontal giratorio) para hechizos de zona.
static func ground_decal(parent: Node, at: Vector3, tex_name: String, color: Color, radius_m: float, seconds: float) -> void:
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius_m * 2.0, radius_m * 2.0)
	var mat := _additive(color, 0.9, tex_name)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	decal.mesh = quad
	parent.add_child(decal)
	decal.global_position = at + Vector3(0, 0.04, 0)
	decal.rotation.x = -PI * 0.5
	var tween := decal.create_tween()
	tween.tween_property(decal, "rotation:z", TAU * 0.5, seconds)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, seconds).set_delay(seconds * 0.6)
	tween.tween_callback(decal.queue_free)


static func swirl_zone(parent: Node, at: Vector3, radius_m: float, color: Color, seconds: float) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at + Vector3(0, 0.05, 0)
	ground_decal(parent, at, "magic_03", color, radius_m * 1.05, seconds)
	var ring := FxShape.new().setup(FxShape.Mode.RING, radius_m, color)
	ring.set_param("inner", 0.88)
	ring.set_param("fill", 0.14)
	ring.set_param("pulse", 1.0)
	holder.add_child(ring)
	var swirl := rising_puffs(color, 40, radius_m * 0.8, 0.28, 0.5)
	holder.add_child(swirl)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = radius_m * 2.0
	light.position.y = 0.6
	holder.add_child(light)
	var tween := holder.create_tween()
	tween.tween_property(holder, "rotation:y", TAU, seconds)
	tween.parallel().tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(func() -> void: swirl.emitting = false)
	tween.tween_interval(1.2)
	tween.tween_callback(holder.queue_free)


## Anillo de atadura bajo los pies mientras dura el root (se destruye al terminar).
static func bind_ring(color: Color = Color(0.8, 0.5, 1.0)) -> Node3D:
	var holder := Node3D.new()
	var ring := FxShape.new().setup(FxShape.Mode.RING, 0.9, color)
	ring.set_param("inner", 0.78)
	ring.set_param("fill", 0.2)
	ring.set_param("pulse", 1.0)
	ring.position.y = 0.04
	holder.add_child(ring)
	holder.add_child(rising_puffs(color, 14, 0.5, 0.12, 0.4))
	return holder
