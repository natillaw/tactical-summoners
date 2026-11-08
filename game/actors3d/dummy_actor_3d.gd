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
const ANIM_RUN := "ual1/Jog_Fwd"
const ANIM_SPRINT := "ual1/Sprint"
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
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _label: Label3D
var _enemy: EnemySim


func setup(p_sim: DummySim, p_arena: Arena3D) -> void:
	sim = p_sim
	arena = p_arena

	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(MODEL)
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

	_telegraph = FxShape.new().setup(FxShape.Mode.SECTOR, View3D.meters(DummySim.ATTACK_RANGE), Color(1.0, 0.25, 0.15, 1.0))
	_telegraph.set_param("arc", deg_to_rad(DummySim.ATTACK_ARC))
	_telegraph.set_param("fill", 0.18)
	_telegraph.set_param("edge", 0.05)
	_telegraph.set_param("trail", 0.0)
	_telegraph.position.y = 0.035
	_telegraph.visible = false
	add_child(_telegraph)

	_build_health_bar()
	if sim is EnemySim:
		_enemy = sim as EnemySim
		_tint(Color(1.0, 0.55, 0.5))
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = false
		_label.pixel_size = 0.0045
		_label.font_size = 40
		_label.outline_size = 10
		_label.modulate = Color(1.0, 0.7, 0.55)
		_label.position.y = BAR_HEIGHT + 0.25
		add_child(_label)

	_yaw = View3D.yaw_for(sim.facing)
	rig.rotation.y = _yaw
	rig.play(ANIM_IDLE, 0.0)
	position = View3D.to3(sim.position)
	_was_alive = sim.alive

	sim.telegraph_started.connect(_on_telegraph_started)
	sim.attack_landed.connect(_on_attack_landed)
	sim.attack_missed.connect(_on_attack_missed)
	sim.died.connect(_on_died)
	sim.revived.connect(_on_revived)


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

	var target := sim.attack_direction if sim.state == DummySim.State.TELEGRAPH else sim.facing
	if sim.alive and target.length_squared() > 0.0001:
		_yaw = lerp_angle(_yaw, View3D.yaw_for(target), 1.0 - exp(-10.0 * delta))
		rig.rotation.y = _yaw

	if _enemy != null:
		_label.text = "Soldado  Nv.%d" % _enemy.level
		_label.visible = _enemy.alive
		if _enemy.alive and _enemy.state == DummySim.State.IDLE:
			var want := ANIM_SPRINT if _enemy.is_charging() else (ANIM_RUN if _enemy.is_moving() else ANIM_IDLE)
			if rig.current() in [ANIM_IDLE, ANIM_RUN, ANIM_SPRINT, ""] and rig.current() != want:
				rig.play(want, 0.12)
		if _enemy.guard_timer > 0.0 and _enemy.alive:
			rig.flash(Color(0.5, 0.7, 1.0), 0.05)

	var telegraphing := sim.alive and sim.state == DummySim.State.TELEGRAPH
	_telegraph.visible = telegraphing
	if telegraphing:
		var progress := sim.telegraph_progress()
		_telegraph.rotation.y = View3D.yaw_for(sim.attack_direction)
		_telegraph.set_param("progress", progress)
		_telegraph.set_param("intensity", 0.6 + 0.6 * progress)

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


## Llamado por el actor del Warrior cuando un golpe conecta.
func on_struck(from: Vector2, hitstop: float, heavy: bool) -> void:
	if not sim.alive:
		return
	if sim.state != DummySim.State.TELEGRAPH:
		rig.play_clip(ANIM_HIT, 0.0, 1.0, 0.5, 0.09 if heavy else 0.07, 0.15, ANIM_IDLE, 0.03)
	rig.hitstop(hitstop)
	var away := (sim.position - from).normalized()
	if away.length_squared() > 0.0:
		# Pequeño retroceso visual (no afecta a la sim).
		var push := View3D.dir3(away) * (0.14 if heavy else 0.08)
		var tw := create_tween()
		tw.tween_property(rig, "position", push, 0.05).set_delay(hitstop)
		tw.tween_property(rig, "position", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_telegraph_started(_direction: Vector2, _radius: float, _arc_degrees: float) -> void:
	var c := CLIP_PUNCH
	rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]),
		DummySim.TELEGRAPH_SECONDS, DummySim.RECOVER_SECONDS, ANIM_IDLE)
	arena.play_sfx(SFX_ALERT, -13.0, randf_range(0.96, 1.06))


func _on_attack_landed(damage: float) -> void:
	var forward := sim.attack_direction * DummySim.ATTACK_RANGE * 0.55
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
	rig.play(ANIM_IDLE, 0.25, 1.0, true)
