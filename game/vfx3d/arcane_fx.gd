## ArcaneFx — efectos procedurales de magia arcana (partículas aditivas + luz).
##
## Sin assets externos: todo con CPUParticles3D, mallas esféricas y OmniLight3D, con la
## paleta que pida el tipo de daño (el arcano es violeta). Los usa el actor del jugador.
class_name ArcaneFx
extends RefCounted

const ARCANE := Color(0.78, 0.5, 1.0)


static func _additive(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
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
static func sparks(color: Color, amount: int, lifetime: float, speed: float, size: float, one_shot: bool) -> CPUParticles3D:
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
	quad.material = _additive(color)
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
