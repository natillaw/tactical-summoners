## DummyActor3D — muñeco de entrenamiento: el maniquí de UAL con sus animaciones.
##
## Lee [DummySim]; nunca lo modifica. Muestra el cono de telegraph en el suelo
## (con relleno de progreso), reacciona a los golpes, muere y reaparece.
class_name DummyActor3D
extends Node3D

const MODEL := "res://assets/models/anims/UAL1_Standard.glb"

const SFX_ALERT := preload("res://assets/audio/sfx/ninja/Alert/Alert2.wav")
const SFX_SWING := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Whoosh.wav")
const SFX_IMPACT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact2.wav")

const ANIM_IDLE := "ual1/Idle"
const ANIM_HIT := "ual1/Hit_Chest"
const ANIM_DEATH := "ual1/Death01"
const CLIP_PUNCH := {"clip": "ual1/Punch_Cross", "from": 0.0, "to": 0.55, "contact": 0.22}

const BAR_WIDTH := 0.9
const BAR_HEIGHT := 2.25

var sim: DummySim
var arena: Arena3D
var rig: HumanoidRig

var _yaw: float = 0.0
var _was_alive: bool = true
var _telegraph: FxShape
var _dot_aura: CPUParticles3D
var _stun_fx: CPUParticles3D
var _root_fx: Node3D
var _dot_aura_type: int = -2
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_mat: StandardMaterial3D
## Sobrescribibles por subclases (EnemyActor3D) antes de setup().
var model_path: String = MODEL
var anim_idle: String = ANIM_IDLE
var attack_clip: Dictionary = CLIP_PUNCH


func setup(p_sim: DummySim, p_arena: Arena3D) -> void:
	sim = p_sim
	arena = p_arena

	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(model_path)
	_dress()


	_telegraph = FxShape.new().setup(FxShape.Mode.SECTOR, View3D.meters(DummySim.ATTACK_RANGE), Color(1.0, 0.25, 0.15, 1.0))
	_telegraph.set_param("arc", deg_to_rad(DummySim.ATTACK_ARC))
	_telegraph.set_param("fill", 0.18)
	_telegraph.set_param("edge", 0.05)
	_telegraph.set_param("trail", 0.0)
	_telegraph.position.y = 0.035
	_telegraph.visible = false
	add_child(_telegraph)

	_build_health_bar()

	_yaw = View3D.yaw_for(sim.facing)
	rig.rotation.y = _yaw
	rig.play(anim_idle, 0.0)
	position = View3D.to3(sim.position)
	_was_alive = sim.alive

	sim.telegraph_started.connect(_on_telegraph_started)
	sim.attack_landed.connect(_on_attack_landed)
	sim.attack_missed.connect(_on_attack_missed)
	sim.died.connect(_on_died)
	sim.revived.connect(_on_revived)
	sim.staggered.connect(_on_staggered)


## Aspecto del muñeco (tinte + peana); EnemyActor3D lo sustituye.
func _dress() -> void:
	_tint(Color(0.85, 0.62, 0.42) if sim.auto_attack else Color(0.72, 0.68, 0.62))
	var stand := MeshInstance3D.new()
	var stand_mesh := CylinderMesh.new()
	stand_mesh.top_radius = 0.42
	stand_mesh.bottom_radius = 0.48
	stand_mesh.height = 0.08
	stand.mesh = stand_mesh
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.25, 0.18, 0.12)
	stand.material_override = stand_mat
	stand.position.y = 0.04
	add_child(stand)


func _tint(color: Color) -> void:
	for mi in rig.meshes:
		for i in range(mi.get_surface_override_material_count()):
			var base := mi.mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_color = mat.albedo_color * color
				mi.set_surface_override_material(i, mat)


func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = BAR_HEIGHT
	add_child(_bar_root)
	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH + 0.06, 0.14)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.04, 0.04, 0.06, 0.9)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 5
	bg.material_override = bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(bg)

	_bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(BAR_WIDTH, 0.09)
	_bar_fill.mesh = fill_mesh
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.albedo_color = Color(0.55, 0.82, 0.38)
	_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_mat.no_depth_test = true
	_bar_mat.render_priority = 6
	_bar_fill.material_override = _bar_mat
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(_bar_fill)


func _process(delta: float) -> void:
	if sim == null:
		return
	position = View3D.to3(sim.position)

	if sim.alive and not _was_alive:
		_on_revived()
	_was_alive = sim.alive

	var target := sim.attack_direction if sim.is_telegraphing() else sim.facing
	if sim.alive and target.length_squared() > 0.0001:
		_yaw = lerp_angle(_yaw, View3D.yaw_for(target), 1.0 - exp(-10.0 * delta))
		rig.rotation.y = _yaw

	var telegraphing := sim.alive and sim.is_telegraphing()
	_telegraph.visible = telegraphing
	if telegraphing:
		var progress := sim.telegraph_progress()
		_telegraph.rotation.y = View3D.yaw_for(sim.attack_direction)
		_telegraph.set_param("progress", progress)
		_telegraph.set_param("intensity", 0.6 + 0.6 * progress)

	_update_dot_aura()
	_update_stun_fx()
	_update_root_fx()
	_bar_root.visible = sim.alive
	if sim.alive:
		var ratio := clampf(sim.health / maxf(sim.max_health, 1.0), 0.0, 1.0)
		# Billboard: escalar en X local encoge la barra hacia el centro; se
		# compensa desplazándola en el eje de pantalla de la cámara.
		_bar_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var right := cam.global_transform.basis.x
			_bar_fill.global_position = _bar_root.global_position - right * (1.0 - ratio) * BAR_WIDTH * 0.5
		_bar_mat.albedo_color = Color(0.55, 0.82, 0.38) if ratio > 0.35 else Color(0.90, 0.45, 0.25)

	if sim.hit_flash_ticks > 0 and sim.alive:
		rig.flash(Color(1.0, 0.95, 0.85), 0.08)


## Anillo de cadenas bajo los pies mientras está atado.
func _update_root_fx() -> void:
	var rooted: bool = sim.alive and sim.root_timer > 0.0
	if rooted and _root_fx == null:
		_root_fx = ArcaneFx.bind_ring()
		add_child(_root_fx)
	elif not rooted and _root_fx != null:
		_root_fx.queue_free()
		_root_fx = null


## Chispas amarillas girando sobre la cabeza mientras está aturdido.
func _update_stun_fx() -> void:
	if _stun_fx == null:
		_stun_fx = ArcaneFx.sparks(Color(1.0, 0.9, 0.3), 12, 0.7, 0.4, 0.12, false)
		_stun_fx.position = Vector3(0, 2.05, 0)
		_stun_fx.emission_sphere_radius = 0.3
		_stun_fx.gravity = Vector3.ZERO
		_stun_fx.emitting = false
		add_child(_stun_fx)
	_stun_fx.emitting = sim.alive and sim.stun_timer > 0.0


## Burbujas del color del daño en el tiempo (verde = veneno) mientras dure el DoT.
func _update_dot_aura() -> void:
	var type: int = sim.dots.dominant_type() if sim.alive else -1
	if type == _dot_aura_type:
		return
	_dot_aura_type = type
	if _dot_aura != null:
		_dot_aura.queue_free()
		_dot_aura = null
	if type >= 0:
		var color: Color = ArcaneFx.POISON if type == DamageSystem.Type.POISON else DamageSystem.color_of(type)
		_dot_aura = ArcaneFx.dot_aura(color)
		add_child(_dot_aura)


## Llamado por el actor del Warrior cuando un golpe conecta.
func on_struck(from: Vector2, hitstop: float, heavy: bool) -> void:
	if not sim.alive:
		return
	if sim.state != DummySim.State.TELEGRAPH:
		rig.play_clip(ANIM_HIT, 0.0, 1.0, 0.5, 0.09 if heavy else 0.07, 0.15, anim_idle, 0.03)
	rig.hitstop(hitstop)
	var away := (sim.position - from).normalized()
	if away.length_squared() > 0.0:
		# Pequeño retroceso visual (no afecta a la sim).
		var push := View3D.dir3(away) * (0.14 if heavy else 0.08)
		var tw := create_tween()
		tw.tween_property(rig, "position", push, 0.05).set_delay(hitstop)
		tw.tween_property(rig, "position", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Poise roto: reacciona con un golpe largo, destello y anillo.
func _on_staggered(seconds: float) -> void:
	if not sim.alive:
		return
	rig.play_clip(ANIM_HIT, 0.0, 1.0, 0.3, 0.1, maxf(seconds - 0.1, 0.3), anim_idle, 0.04)
	ArcaneFx.burst(arena, View3D.to3(sim.position, 1.9), Color(1.0, 0.95, 0.7), 36, 3.0, 0.13)
	arena.spawn_shockwave(sim.position, 60.0, Color(1.0, 0.9, 0.5, 0.9), 0.3, 0.75)
	arena.play_sfx(SFX_IMPACT, -4.0, 0.8)


func _on_telegraph_started(_direction: Vector2, radius: float, arc_degrees: float) -> void:
	# El telegraph se redimensiona por ataque: cono, línea estrecha o círculo.
	_telegraph.scale = Vector3.ONE * (View3D.meters(radius) / View3D.meters(DummySim.ATTACK_RANGE))
	_telegraph.set_param("arc", deg_to_rad(arc_degrees))
	var c := _telegraph_clip(sim.attack_name)
	rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]),
		sim.telegraph_seconds, sim.recover_seconds, anim_idle)
	arena.play_sfx(SFX_ALERT, -13.0, randf_range(0.96, 1.06))


## Animación de cada ataque con telegraph (EnemyActor3D la sustituye).
func _telegraph_clip(_attack_name: String) -> Dictionary:
	return attack_clip


func _on_attack_landed(damage: float) -> void:
	var forward := sim.attack_direction * minf(sim.attack_range, 100.0) * 0.55
	arena.spawn_impact(sim.position + forward, Color(0.95, 0.25, 0.18, 1.0), false)
	arena.spawn_damage_number(sim.position + forward, damage, false, 2.0, Color(1.0, 0.45, 0.4))
	arena.play_sfx(SFX_IMPACT, -6.0, randf_range(0.9, 1.0))
	arena.shake(4.0, 0.2)


func _on_attack_missed() -> void:
	arena.play_sfx(SFX_SWING, -12.0, randf_range(0.85, 0.95))


func _on_died() -> void:
	_telegraph.visible = false
	rig.play_clip(ANIM_DEATH, 0.0, 1.0, 0.4, 0.35, 0.8)
	arena.play_sfx(SFX_IMPACT, -9.0, 0.7)


func _on_revived() -> void:
	rig.position = Vector3.ZERO
	rig.play(anim_idle, 0.25, 1.0, true)
