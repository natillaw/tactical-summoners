## WarriorActor3D — presentación 3D del Warrior: modelo, animación, VFX y sonido.
##
## Igual que el actor 2D, es presentación pura: lee [WarriorSim] y escucha sus
## señales, nunca la modifica. La clave del "feel" está en sincronizar cada
## animación con la simulación: el impacto de cada clip (medido con
## tools/anim_contact_probe.gd: frame de máxima velocidad de la punta de la espada)
## se hace caer exactamente al final del windup, que es cuando la sim aplica el
## daño. Así el golpe visual y el golpe real son el mismo frame.
class_name WarriorActor3D
extends Node3D

const MODEL := "res://assets/models/characters/warrior.glb"
const SWORD := "res://assets/models/props/sword_bronze.glb"

const SFX_SLASH := &"slash"
const SFX_SLASH_HEAVY := &"slash_heavy"
const SFX_HIT := &"hit"
const SFX_HIT_HEAVY := &"hit_heavy"
const SFX_HURT := &"hurt"
const SFX_DEATH := &"death"
const SFX_MAGIC := &"magic"
const SFX_BUFF := &"buff"
const SFX_PARRY := &"parry"
const SFX_ROLL := &"roll"
const SFX_CHARGE := &"charge"
const SFX_SLAM := &"slam"
const SFX_SPIN := &"slash_heavy"

const ANIM_IDLE := "ual1/Sword_Idle"
const ANIM_RUN := "ual1/Jog_Fwd"
const ANIM_JUMP := "ual1/Jump"
const ANIM_SPRINT := "ual1/Sprint"
const ANIM_HIT := "ual1/Hit_Chest"
const ANIM_DEATH := "ual1/Death01"
## Velocidad (m/s) a la que Jog_Fwd no patina.
const RUN_ANIM_SPEED := 3.6

## Tramos de animación por skill: clip, [desde, hasta] y fracción de contacto.
## Los contactos salen de tools/anim_contact_probe.gd (pico de velocidad de la
## punta) corregidos a ojo con tools/pose_check.tscn.
const M1_CLIPS := [
	{"clip": "ual2/Sword_Regular_A", "from": 0.0, "to": 1.0, "contact": 0.55},
	{"clip": "ual2/Sword_Regular_B", "from": 0.0, "to": 1.0, "contact": 0.49},
	{"clip": "ual2/Sword_Regular_C", "from": 0.0, "to": 0.62, "contact": 0.34},
	{"clip": "ual1/Punch_Jab", "from": 0.0, "to": 0.6, "contact": 0.2, "no_align": true},  # mano izquierda
	{"clip": "class/stabbing", "from": 0.18, "to": 0.5, "contact": 0.27, "no_align": true},  # puñalada
]
## Estocada: el lance frontal de Sword_Dash (el clip custom/thrust era un tajo hacia arriba).
const CLIP_THRUST := {"clip": "ual2/Sword_Dash", "from": 0.08, "to": 0.40, "contact": 0.21}
const CLIP_SLAM := {"clip": "ual2/Sword_Heavy_Combo", "from": 0.52, "to": 0.80, "contact": 0.63}
const CLIP_PARRY := {"clip": "ual2/Sword_Block", "from": 0.0, "to": 0.45, "contact": 0.08}
const CLIP_ROLL := {"clip": "ual1/Roll", "from": 0.0, "to": 0.78, "contact": 0.55}
const CLIP_BLOCK_REACT := {"clip": "class/standing_block_react_large", "from": 0.08, "to": 0.6, "contact": 0.23}
const CLIP_COUNTER := {"clip": "ual2/Sword_Regular_B", "from": 0.25, "to": 1.0, "contact": 0.49}
const CLIP_CHARGE_HIT := {"clip": "ual2/Sword_Regular_C", "from": 0.2, "to": 0.62, "contact": 0.34}

const COLOR_SLASH := Color(1.0, 0.86, 0.6, 0.9)
const COLOR_FINISHER := Color(1.0, 0.62, 0.25, 1.0)
const COLOR_THRUST := Color(0.75, 0.9, 1.0, 0.9)
const COLOR_GUARD := Color(0.55, 0.8, 1.0, 0.9)
const COLOR_RAGE := Color(1.0, 0.42, 0.15, 1.0)
const COLOR_EARTH := Color(1.0, 0.7, 0.35, 1.0)

## Clips que se alinean con el apuntado: al cargar se mide hacia dónde apunta la
## punta de la espada en el contacto y el cuerpo se gira para que la hoja (no el
## pecho) caiga sobre el objetivo.
const ALIGNED_CLIPS := [CLIP_THRUST, CLIP_SLAM, CLIP_COUNTER, CLIP_CHARGE_HIT]
## Límite del giro de alineación: más allá el cuerpo quedaría de espaldas.
const MAX_ALIGN := 1.0

const TURN_SPEED := 16.0
const TURN_SPEED_ATTACK := 40.0
const SPIN_SPEED := 15.0

## Editables desde el editor (player_actor.tscn).
@export var model_path: String = MODEL
@export var sword_path: String = SWORD

var sim: WarriorSim
var arena: Arena3D
var rig: HumanoidRig
var sword: Node3D
var _hurt_time: float = 0.0
var trail: WeaponTrail

var _yaw: float = 0.0
var _current_skill: Dictionary = {}
var _dead_visual: bool = false
var _spinning: bool = false
var _spin_yaw: float = 0.0
var _dash_dust_timer: float = 0.0
var _shadow: FxShape
var _aura: FxShape
var _guard: FxShape
var _spin_disc: FxShape
var _clip_info: Dictionary = {}
var _align_yaw: float = 0.0
var _swing_dir: float = 1.0
var _orbs: Dictionary = {}
var _cast_index: int = 0
var _flurry_i: int = 0
var _shield_fx: MeshInstance3D
var _was_evading: bool = false
## Enemigo de clase: misma presentación que el jugador pero con IA, nombre y barra de vida.
var enemy_mode: bool = false
var _team_ring: FxShape
var _telegraph: FxShape
var _overhead: Node3D
var _bar_fill: MeshInstance3D
var _name_label: Label3D
var _mark_icon: MeshInstance3D
var _was_alert: bool = false
var _dot_type: int = -2
var _dot_fx: CPUParticles3D
## En el pueblo no se pelea: idle y caminata normales, armas guardadas.
var peaceful: bool = false
## Aliado (rescate): aspecto de aldeano, no usa el del jugador ni el tinte rojo de los enemigos.
var ally_mode: bool = false
var _offhand: Node3D
var _blade_tip: Node3D
var _aim_stance: float = 0.0
var _spin_rate: float = 15.0
var _spin_limit: float = 1e9


func setup(p_sim: WarriorSim, p_arena: Arena3D) -> void:
	sim = p_sim
	arena = p_arena

	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	if enemy_mode:
		var look := RandomNumberGenerator.new()
		look.seed = hash(str(sim.class_id)) + int(sim.position.x * 31.0 + sim.position.y)
		var opts := CharacterBuilder.random_options(look)
		opts["outfit"] = ["ranger", "ranger_hood", "peasant"][look.randi() % 3]
		rig.setup_model(CharacterBuilder.build(opts))
		for mi: MeshInstance3D in rig.meshes:
			CharacterBuilder._tint(mi, Color(1.0, 0.66, 0.6))  # tinte rojizo: se distingue del jugador
	elif ally_mode:
		var villager := RandomNumberGenerator.new()
		villager.seed = 4242
		var vopts := CharacterBuilder.random_options(villager)
		vopts["outfit"] = "peasant"
		rig.setup_model(CharacterBuilder.build(vopts))
	elif CharacterProfile.chosen:
		var look_opts: Dictionary = CharacterProfile.appearance.duplicate()
		var worn := ArmorSets.gear_for(CharacterProfile.armor)  # piezas de set equipadas, una a una
		if not worn.is_empty():
			look_opts["gear"] = worn
		rig.setup_model(CharacterBuilder.build(look_opts))
	else:
		rig.setup(model_path)

	_build_weapon_visual()
	_analyze_clips(sword.transform * _blade_tip.position)

	_shadow = FxShape.new().setup(FxShape.Mode.DISC, 0.45, Color(0, 0, 0, 0))
	add_child(_shadow)
	_aura = FxShape.new().setup(FxShape.Mode.RING, 0.75, COLOR_RAGE)
	_aura.set_param("inner", 0.72)
	_aura.set_param("pulse", 1.0)
	_aura.position.y = 0.03
	_aura.visible = false
	add_child(_aura)
	_guard = FxShape.new().setup(FxShape.Mode.SECTOR, 0.95, COLOR_GUARD)
	_guard.set_param("arc", deg_to_rad(150.0))
	_guard.set_param("inner", 0.82)
	_guard.set_param("fill", 0.6)
	_guard.set_param("pulse", 1.0)
	_guard.position.y = 1.0
	_guard.visible = false
	add_child(_guard)
	_spin_disc = FxShape.new().setup(FxShape.Mode.RING, 1.0, COLOR_FINISHER)
	_spin_disc.set_param("inner", 0.86)
	_spin_disc.set_param("fill", 0.1)
	_spin_disc.set_param("pulse", 1.0)
	_spin_disc.position.y = 0.05
	_spin_disc.visible = false
	add_child(_spin_disc)

	_yaw = View3D.yaw_for(sim.aim_dir)
	rig.play(ANIM_IDLE, 0.0)
	_build_team_ring()
	if enemy_mode:
		_build_overhead()
	_connect_signals()
	position = View3D.to3(sim.position)


## Arma(s) en la mano según lo equipado (jugador) o el arquetipo (enemigo): ver WeaponCatalog.
## Se reconstruye cuando cambia el arma (weapon_changed), así se ve lo que llevas puesto.
func _build_weapon_visual() -> void:
	for node in [sword, _offhand]:
		if is_instance_valid(node):
			var holder: Node = node.get_parent()
			if holder is BoneAttachment3D:
				holder.queue_free()
			else:
				node.queue_free()
	if is_instance_valid(trail):
		trail.queue_free()
	var spec := WeaponCatalog.spec_for(sim, enemy_mode)
	var built: Dictionary = WeaponCatalog.build(spec)
	sword = built["node"]
	rig.attach_to_hand(sword, String(built["hand"]))
	if String(spec["type"]) == "bow":
		sword.rotate_object_local(Vector3.UP, deg_to_rad(-90.0))  # girar sobre el eje del puño deja el arco vertical (medido en 3 poses)
	_offhand = null
	if bool(spec["dual"]):
		var second := WeaponCatalog.build(spec)
		_offhand = second["node"]
		rig.attach_to_hand(_offhand, "l")
	var tip_len: float = built["tip"]
	var blade_base := Node3D.new()
	blade_base.position = Vector3(0, minf(0.14, tip_len * 0.3), 0)
	sword.add_child(blade_base)
	_blade_tip = Node3D.new()
	_blade_tip.position = Vector3(0, tip_len, 0)
	sword.add_child(_blade_tip)
	trail = WeaponTrail.new()
	add_child(trail)
	trail.setup(blade_base, _blade_tip)
	sword.visible = not peaceful
	if _offhand != null:
		_offhand.visible = not peaceful


func _on_weapon_swapped(_item: Item) -> void:
	if rig != null:
		_build_weapon_visual()


## Nombre + barra de vida sobre la cabeza (enemigos de clase).
## Anillo de equipo bajo los pies (top-down): dorado = tú, rojo = enemigo.
func _build_team_ring() -> void:
	var color := Color(1.0, 0.3, 0.25, 0.9) if enemy_mode else (Color(0.4, 1.0, 0.5, 0.9) if ally_mode else Color(1.0, 0.85, 0.4, 0.8))
	_team_ring = FxShape.new().setup(FxShape.Mode.RING, 0.8, color)
	_team_ring.set_param("inner", 0.82)
	_team_ring.set_param("fill", 0.08)
	_team_ring.position.y = 0.03
	_team_ring.visible = false
	add_child(_team_ring)


## Aviso en el suelo del ataque que prepara un enemigo de clase: cono, línea o círculo.
func _update_enemy_telegraph() -> void:
	if _telegraph == null:
		_telegraph = FxShape.new().setup(FxShape.Mode.SECTOR, 1.0, Color(1.0, 0.25, 0.15, 1.0))
		_telegraph.set_param("fill", 0.3)
		_telegraph.set_param("edge", 0.05)
		_telegraph.set_param("trail", 0.0)
		_telegraph.top_level = true
		_telegraph.visible = false
		add_child(_telegraph)
	var skill: Dictionary = sim.current_skill
	var show := sim.alive and sim.state == WarriorSim.AttackState.WINDUP and not skill.is_empty()
	var cast := String(skill.get("cast", ""))
	if show and cast in ["dash", "teleport", "buff", "guard", "mana_shield", "counter"]:
		show = false
	_telegraph.visible = show
	if not show:
		return
	var center := sim.position
	var radius_px := float(skill.get("range", 80.0))
	var arc := float(skill.get("arc", 100.0))
	match cast:
		"aoe":
			radius_px = float(skill.get("radius", 100.0))
			arc = 360.0
			if String(skill.get("target", "")) == "ground":
				center = sim._cast_point
		"line":
			arc = rad_to_deg(2.0 * atan2(float(skill.get("width", 30.0)) * 0.5, maxf(radius_px, 1.0)))
		"projectile":
			radius_px = minf(radius_px * 0.6, 280.0)
			arc = 8.0
		"leap_slam":
			radius_px += float(skill.get("lunge", 0.0))
	_telegraph.global_position = View3D.to3(center, 0.04)
	_telegraph.rotation.y = View3D.yaw_for(sim.attack_aim)
	_telegraph.scale = Vector3.ONE * View3D.meters(radius_px)
	_telegraph.set_param("arc", deg_to_rad(arc))
	var progress := clampf(sim.state_time / maxf(float(skill.get("windup", 0.3)), 0.05), 0.0, 1.0)
	_telegraph.set_param("progress", progress)
	_telegraph.set_param("intensity", 0.7 + 0.6 * progress)


func _build_overhead() -> void:
	# Las barras de vida las dibuja UnitBars (2D, estilo League); aquí solo el ancla del icono de marca.
	_overhead = Node3D.new()
	_overhead.position.y = 2.25
	add_child(_overhead)


## Icono flotante giratorio sobre los objetivos marcados (Mark for Death / Hunter's Mark).
## DoT visible en el enemigo: sangrado (gotas rojas) o veneno (burbujas verdes).
func _update_dot_visual() -> void:
	var type: int = sim.dots.dominant_type() if sim.alive else -1
	if type == _dot_type:
		return
	_dot_type = type
	if _dot_fx != null:
		_dot_fx.queue_free()
		_dot_fx = null
	if type >= 0:
		_dot_fx = ArcaneFx.dot_aura_for(type)
		add_child(_dot_fx)


func _update_mark_icon() -> void:
	_update_dot_visual()
	if sim.brain != null:  # al alertarse, el enemigo ruge (el sonido depende de la clase)
		var alert_now: bool = sim.brain.alerted
		if alert_now and not _was_alert and sim.alive:
			arena.play_sfx(&"alert", -10.0)
			var growl := &"beast"
			if not String(sim.archetype_id).begins_with("esbirro"):
				growl = &"ogre" if sim.class_id == &"warrior" else (&"shade" if sim.class_id in [&"mage", &"rogue"] else &"beast")
			arena.play_sfx(growl, -9.0, randf_range(0.9, 1.1))
		_was_alert = alert_now
	if sim.mark_timer <= 0.0 or not sim.alive:
		if _mark_icon != null:
			_mark_icon.visible = false
		return
	if _mark_icon == null:
		_mark_icon = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.2
		ring.outer_radius = 0.3
		_mark_icon.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.5, 0.12)
		mat.no_depth_test = true
		_mark_icon.material_override = mat
		var diamond := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.18, 0.22, 0.05)
		diamond.mesh = prism
		diamond.material_override = mat
		diamond.rotation.x = PI * 0.5
		_mark_icon.add_child(diamond)
		_mark_icon.position.y = 2.7
		add_child(_mark_icon)
	_mark_icon.visible = true
	var t := Time.get_ticks_msec() * 0.001
	_mark_icon.rotation = Vector3(PI * 0.5, 0.0, t * 3.0)
	_mark_icon.position.y = 2.7 + 0.08 * sin(t * 4.0)
	_mark_icon.scale = Vector3.ONE * (1.0 + 0.1 * sin(t * 8.0))


func _update_overhead() -> void:
	_overhead.visible = sim.alive
	_update_mark_icon()


func _shake(amount: float, seconds: float) -> void:
	if not enemy_mode:  # los golpes de los enemigos no sacuden la cámara del jugador
		arena.shake(amount, seconds)


func _analyze_clips(tip_in_hand: Vector3) -> void:
	var clips: Array = M1_CLIPS.duplicate()
	clips.append_array(ALIGNED_CLIPS)
	for c: Dictionary in clips:
		var key := _clip_key(c)
		var info := rig.analyze_clip(String(c["clip"]), float(c["contact"]), tip_in_hand)
		info["yaw"] = clampf(float(info["yaw"]), -MAX_ALIGN, MAX_ALIGN)
		_clip_info[key] = info
		print_verbose("WarriorActor3D: %s yaw=%.0f° sweep=%d" % [key, rad_to_deg(info["yaw"]), info["sweep"]])


func _clip_key(c: Dictionary) -> String:
	return "%s@%.3f" % [c["clip"], float(c["contact"])]


func _connect_signals() -> void:
	sim.weapon_changed.connect(_on_weapon_swapped)
	sim.attack_started.connect(_on_attack_started)
	sim.attack_state_changed.connect(_on_attack_state_changed)
	sim.attack_hit.connect(_on_attack_hit)
	sim.attack_finished.connect(_on_attack_finished)
	sim.damage_taken.connect(_on_damage_taken)
	sim.stunned.connect(_on_stunned)
	sim.guard_changed.connect(_on_guard_changed)
	sim.guard_result.connect(_on_guard_result)
	sim.perfect_evade.connect(_on_perfect_evade)
	sim.visibility_changed.connect(_set_invisible)
	sim.cast_cancelled.connect(func(_skill: Dictionary) -> void: rig.stop_overlay())
	sim.died.connect(_on_died)
	sim.cast_event.connect(_on_cast_event)
	sim.ultimate_changed.connect(_on_ultimate_changed)
	sim.last_stand_changed.connect(_on_last_stand_changed)


# --- Por frame ----------------------------------------------------------------


func _process(delta: float) -> void:
	if sim == null:
		return
	position = View3D.to3(sim.position, View3D.meters(sim.height))
	if enemy_mode and _overhead != null:
		_update_overhead()
	if _team_ring != null:
		_team_ring.visible = arena.topdown and sim.alive
	if enemy_mode:
		_update_enemy_telegraph()

	if not sim.alive:
		trail.emitting = false
		_aura.visible = false
		_guard.visible = false
		return
	if _dead_visual:
		_restore_visual()

	sword.visible = not peaceful
	if _offhand != null:
		_offhand.visible = not peaceful
	_update_orbs()
	_update_defense_fx()
	_update_facing(delta)
	_update_locomotion()
	_update_dash_fx(delta)
	_aura.visible = sim.is_last_stand_active()
	_guard.visible = sim.is_parrying()
	if _guard.visible:
		_guard.rotation.y = View3D.yaw_for(sim.attack_aim) - rig.rotation.y


func _update_facing(delta: float) -> void:
	# Cámara estilo Smite: el personaje siempre mira hacia donde mira la cámara (siempre se ve su
	# espalda). Al moverse en diagonal el cuerpo se inclina hasta 60° hacia el movimiento.
	var albion := arena.topdown and not enemy_mode  # top-down estilo Albion: mira hacia donde corre
	var cam_yaw := View3D.yaw_for(sim.aim_dir if enemy_mode else arena.cam_forward_sim())
	var target_yaw := _yaw if albion else cam_yaw
	var rate := TURN_SPEED_ATTACK if arena.topdown else TURN_SPEED
	if sim.is_attacking():
		target_yaw = View3D.yaw_for(sim.attack_aim) - _align_yaw
		if String(sim.current_skill.get("dash_dir", "")) == "move":
			target_yaw = View3D.yaw_for(sim._dash_dir)
		rate = TURN_SPEED_ATTACK
	elif albion and sim.velocity.length_squared() > 64.0:
		target_yaw = View3D.yaw_for(sim.velocity)
	elif sim.velocity.length_squared() > 64.0:
		var offset := wrapf(View3D.yaw_for(sim.velocity) - cam_yaw, -PI, PI)
		if absf(offset) <= deg_to_rad(100.0):
			target_yaw = cam_yaw + clampf(offset, deg_to_rad(-60.0), deg_to_rad(60.0))  # el cuerpo se inclina hacia el movimiento
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-rate * delta))

	if _spinning:
		_spin_yaw += _spin_rate * delta
		rig.rotation.y = _yaw + _spin_yaw
		if _spin_yaw >= _spin_limit:
			_stop_spin()
	else:
		rig.rotation.y = _yaw


func _aiming_stance() -> bool:
	return sim.class_id == &"ranger" and _aim_stance > 0.0


## Modo pueblo: guarda las armas y usa animaciones tranquilas.
func set_peaceful(value: bool) -> void:
	peaceful = value
	if sword != null:
		sword.visible = not value
	if _offhand != null:
		_offhand.visible = not value


func _update_locomotion() -> void:
	_aim_stance = maxf(0.0, _aim_stance - get_process_delta_time())
	if sim.guarding and sim.guard_kind == "block":
		return  # mantiene la pose de guardia
	if sim.is_attacking() and String(_current_skill.get("anim", "")) != "cast":
		_hurt_time = 0.0
		return
	if _hurt_time > 0.0:
		_hurt_time -= get_process_delta_time()
		return
	var speed_m := View3D.meters(sim.velocity.length())
	if speed_m > 0.4 and _is_lateral():
		# Paso lateral con las animaciones de strafe (el cuerpo mira hacia la cámara)
		var side := "right" if _move_angle() > 0.0 else "left"
		rig.play(_first_clip(["class/jog_strafe_" + side, "class/run_strafe_" + side]), 0.1, clampf(speed_m / 3.6, 0.7, 1.5))
	elif speed_m > 0.4 and _aiming_stance():
		rig.play(_strafe_anim(), 0.1, clampf(speed_m / 2.0, 0.6, 2.2))
	elif speed_m > 0.4 and _moving_back():
		var back_clip := _first_clip(["class/jog_backward", "class/run_backward"])
		if back_clip != "":
			rig.play(back_clip, 0.12, clampf(speed_m / 3.4, 0.7, 1.5))
		else:
			rig.play(ANIM_RUN, 0.12, -clampf(speed_m / RUN_ANIM_SPEED, 0.6, 1.6))  # sin clip de retroceso: carrera al revés
	elif speed_m > 0.4 and peaceful:
		rig.play("ual1/Walk", 0.15, clampf(speed_m / 1.5, 0.6, 1.6))
	elif speed_m > 0.4:
		var anim := ANIM_SPRINT if sim.current_move_speed_multiplier() > 1.15 else ANIM_RUN
		var ref := RUN_ANIM_SPEED * (1.6 if anim == ANIM_SPRINT else 1.0)
		rig.play(anim, 0.12, clampf(speed_m / ref, 0.6, 1.6))
	else:
		rig.play(_idle_anim(), 0.18)


## Idle por clase: el rogue con la daga en guardia, el ranger apuntando.
## ¿Se mueve de espaldas respecto a donde mira la cámara? (animación de carrera al revés)
## Ángulo (grados) entre hacia dónde mira el personaje/cámara y su movimiento: 0 = adelante, + = derecha.
func _move_angle() -> float:
	if arena.topdown and not enemy_mode:
		return 0.0  # el cuerpo ya mira hacia donde corre: siempre carrera hacia delante
	var reference: Vector2 = sim.aim_dir if (enemy_mode or arena.topdown) else arena.cam_forward_sim()
	return rad_to_deg(reference.angle_to(sim.velocity))


func _first_clip(names: Array) -> String:
	for clip_name: String in names:
		if rig.player.has_animation(clip_name):
			return clip_name
	return ""


## Strafe lateral solo si hay clips de trote lateral (Mixamo "Jog Strafe Left/Right"); si no, se inclina.
func _is_lateral() -> bool:
	var a := absf(_move_angle())
	return a > 45.0 and a <= 135.0 and _first_clip(["class/jog_strafe_left", "class/run_strafe_left"]) != ""


func _moving_back() -> bool:
	return absf(_move_angle()) > 135.0


func _idle_anim() -> String:
	if peaceful:
		return "ual1/Idle"
	match sim.class_id:
		&"rogue":
			return "class/knife_idle"
		&"ranger":
			return "class/standing_aim_idle_01" if _aim_stance > 0.0 else ANIM_IDLE
		_:
			return ANIM_IDLE


## Caminata de apuntado del ranger según la dirección de movimiento respecto a la mira.
func _strafe_anim() -> String:
	var angle := rad_to_deg(sim.aim_dir.angle_to(sim.velocity))
	if absf(angle) <= 45.0:
		return "class/standing_aim_walk_forward"
	if absf(angle) >= 135.0:
		return "class/standing_aim_walk_back"
	return "class/standing_aim_walk_right" if angle > 0.0 else "class/standing_aim_walk_left"


func _update_dash_fx(delta: float) -> void:
	if sim.state != WarriorSim.AttackState.ACTIVE or String(_current_skill.get("cast", "")) != "dash":
		return
	_dash_dust_timer -= delta
	if _dash_dust_timer <= 0.0:
		_dash_dust_timer = 0.05
		arena.spawn_dust(sim.position, 3, 0.3)


# --- Señales de la simulación --------------------------------------------------


func _on_attack_started(skill: Dictionary, direction: Vector2) -> void:
	_current_skill = skill
	if String(skill.get("kind", "")) == "ultimate":  # el ultimate se nota: anillo, columna y temblor
		var tint := ArcaneFx.ARCANE if sim.class_id == &"mage" else (ArcaneFx.POISON if sim.class_id == &"rogue" else ArcaneFx.GOLD)
		arena.spawn_shockwave(sim.position, 150.0, Color(tint, 0.9), 0.7, 0.6)
		ArcaneFx.column(arena, View3D.to3(sim.position), tint, 3.5)
		_shake(4.0, 0.3)
	if bool(skill.get("spin", false)):
		# Vuelta de 360° durante la preparación, con la pose del brazo extendido.
		var turn_time := maxf(float(skill.get("windup", 0.3)), 0.1)
		_spinning = true
		_spin_yaw = 0.0
		_spin_rate = TAU / turn_time
		_spin_limit = TAU
		rig.play_clip(String(M1_CLIPS[0]["clip"]), 0.45, 0.6, 0.6, 0.06, 0.01)
		if String(skill.get("id", "")) == "fan_of_knives":
			ArcaneFx.knife_fan(arena, View3D.to3(sim.position), View3D.meters(float(skill.get("radius", 120.0))), int(skill.get("knives", 14)), ArcaneFx.POISON, turn_time)
	_align_yaw = 0.0
	_swing_dir = 1.0
	var windup := float(skill.get("windup", 0.1))
	var post := float(skill.get("active", 0.1)) + float(skill.get("recovery", 0.2))
	match String(skill.get("id", "")):
		"heavy_strikes":
			var c: Dictionary = M1_CLIPS[clampi(sim.combo_index, 0, 2)]
			_play_clip(c, windup, post)
		"piercing_thrust":
			_play_clip(CLIP_THRUST, windup, post)
		"parry":
			_play_clip(CLIP_PARRY, windup, float(skill.get("active", 0.45)))
		"bladestorm":
			_play_clip(M1_CLIPS[2], windup, 0.2)
		_:
			if bool(skill.get("spin", false)):
				pass
			elif String(skill.get("anim", "")) == "cast":
				_play_cast_overlay(skill, windup)
			elif skill.has("melee_clips"):
				var list: Array = skill["melee_clips"]
				_play_clip(M1_CLIPS[int(list[_cast_index % list.size()])], windup, post)
				_cast_index += 1
			elif skill.has("full_clip"):
				var full: Dictionary = skill["full_clip"]
				if bool(full.get("late", false)):  # el golpe cae al aterrizar
					_play_clip(full, windup + float(skill.get("active", 0.1)), float(skill.get("recovery", 0.2)))
				else:
					_play_clip(full, windup, post)
	_yaw = View3D.yaw_for(direction) - _align_yaw
	rig.rotation.y = _yaw


## Hechizo: animación de tren superior sobre la locomoción (castea y se mueve a la vez).
func _play_cast_overlay(skill: Dictionary, windup: float) -> void:
	var c: Dictionary = {}
	if skill.has("clips"):
		var list: Array = skill["clips"]
		c = list[_cast_index % list.size()]
		_cast_index += 1
	elif skill.has("clip"):
		c = skill["clip"]
	if c.is_empty():
		return
	var clip_name: String = ("spell/%s_upper" % String(c["name"])) if c.has("name") else rig.upper_variant(String(c["anim"]))
	rig.play_overlay(clip_name, float(c["start"]), float(c["contact"]), float(c["end"]), windup)


func _play_clip(c: Dictionary, to_contact: float, after: float, then: String = ANIM_IDLE) -> void:
	var info: Dictionary = _clip_info.get(_clip_key(c), {})
	_align_yaw = 0.0 if bool(c.get("no_align", false)) else float(info.get("yaw", 0.0))
	_swing_dir = float(info.get("sweep", 1.0))
	rig.play_clip(
		String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]),
		to_contact, after, then
	)


func _on_attack_state_changed(state: int) -> void:
	if _current_skill.is_empty():
		return
	if String(_current_skill.get("id", "")) in ["kick", "cheap_shot"]:
		# Golpes de pie/puño: sin estela ni sonido de espada, un impacto seco.
		if state == WarriorSim.AttackState.ACTIVE:
			arena.spawn_dust(sim.position + sim.attack_aim * 40.0, 7, 0.5)
			arena.play_sfx(SFX_HIT_HEAVY, -4.0, 0.7)
			_shake(2.0, 0.1)
		trail.emitting = false
		return
	var cast := String(_current_skill.get("cast", "melee"))
	if state == WarriorSim.AttackState.ACTIVE and (cast == "melee" or cast == "line"):
		trail.emitting = true
		trail.color = COLOR_FINISHER if _is_finisher() else COLOR_SLASH
		_spawn_cast_vfx(_current_skill)
		_play_cast_sfx(_current_skill)
		if _is_finisher():
			_shake(3.4, 0.18)
		elif _is_heavy(_current_skill):
			_shake(2.4, 0.14)
	elif state == WarriorSim.AttackState.RECOVERY:
		trail.emitting = false


func _spawn_cast_vfx(skill: Dictionary) -> void:
	var aim := sim.attack_aim
	match String(skill.get("cast", "melee")):
		"melee":
			var finisher := _is_finisher()
			arena.spawn_swipe(
				sim.position, aim, float(skill.get("range", 80.0)) * (1.1 if finisher else 1.0),
				float(skill.get("arc", 120.0)), COLOR_FINISHER if finisher else COLOR_SLASH,
				0.07, 0.18 if finisher else 0.14, 0.95, _swing_dir
			)
			if finisher:
				arena.spawn_ground_flash(sim.position + aim * 30.0, 50.0, Color(1.0, 0.5, 0.2, 0.6), 0.25)
		"line":
			arena.spawn_thrust(
				sim.position, aim, float(skill.get("range", 120.0)),
				float(skill.get("width", 32.0)), COLOR_THRUST
			)


func _on_cast_event(event: String, skill: Dictionary, at: Vector2, direction: Vector2) -> void:
	if skill.is_empty():
		return
	_current_skill = skill
	var active := float(skill.get("active", 0.2))
	var recovery := float(skill.get("recovery", 0.2))
	match event:
		"dash_start":
			_align_yaw = 0.0
			_yaw = View3D.yaw_for(direction)
			if skill.has("dash_clip"):
				_play_clip({"clip": String(skill["dash_clip"]), "from": 0.0, "to": 0.62, "contact": 0.3}, active * 0.5, active * 0.5 + recovery)
				arena.play_sfx(SFX_ROLL, -9.0, 1.2)
			elif skill.has("fall_clip"):
				# Evasive Leap: salto hacia atrás con la animación de caída en pleno vuelo
				rig.play(String(skill["fall_clip"]), 0.05, 1.0, true)
			elif String(skill.get("id", "")) == "combat_roll":
				_play_clip(CLIP_ROLL, active * 0.7, active * 0.3 + recovery)
				arena.play_sfx(SFX_ROLL, -9.0, 0.9)
			else:
				rig.play(ANIM_SPRINT, 0.05, 2.2, true)
				trail.emitting = true
				trail.color = COLOR_RAGE
				arena.play_sfx(SFX_CHARGE, -8.0, 0.9)
			arena.spawn_dust(at, 8, 0.5)
			_dash_dust_timer = 0.0
		"dash_impact":
			_play_clip(CLIP_CHARGE_HIT, 0.05, recovery + 0.1, ANIM_IDLE)
			arena.spawn_impact(at + direction * 18.0, COLOR_RAGE, true)
			arena.spawn_shockwave(at + direction * 18.0, float(skill.get("radius", 46.0)) * 1.4, COLOR_RAGE, 0.3)
			arena.play_sfx(SFX_HIT_HEAVY, -4.0, 0.9)
			_shake(2.8, 0.16)
			rig.hitstop(0.07)
		"slam":
			var radius := float(skill.get("radius", 120.0))
			if DamageSystem.type_of(skill) == DamageSystem.Type.ARCANE:
				_arcane_slam(at, radius, skill)
				return
			if _class_slam(at, radius, skill):
				return
			arena.spawn_shockwave(at, radius, COLOR_EARTH, 0.5, 0.7)
			arena.spawn_shockwave(at, radius * 0.55, Color(1.0, 0.85, 0.6, 0.45), 0.3, 0.75)
			arena.spawn_ground_flash(at, radius, Color(1.0, 0.45, 0.15, 0.5), 0.4)
			arena.spawn_dust(at, 22, View3D.meters(radius) * 0.9)
			arena.spawn_impact(at + direction * 26.0, COLOR_EARTH, true, 0.2, 1.4)
			arena.play_sfx(SFX_SLAM, -6.0, 1.0)
			_shake(5.0, 0.30)
			rig.hitstop(0.09)
		"parry_stance":
			arena.play_sfx(SFX_MAGIC, -12.0, 1.1)
			_shake(1.2, 0.08)
		"parry_success":
			_play_clip(CLIP_BLOCK_REACT, 0.08, recovery, ANIM_IDLE)
			arena.spawn_swipe(
				sim.position, direction, float(skill.get("counter_range", 90.0)),
				float(skill.get("counter_arc", 120.0)), COLOR_GUARD, 0.06, 0.2, 0.95, _swing_dir
			)
			arena.spawn_impact(at, COLOR_GUARD, true)
			arena.play_sfx(SFX_PARRY, -2.0, 1.15)
			_shake(2.6, 0.14)
			rig.hitstop(0.1)
		"projectile":
			if DamageSystem.type_of(skill) == DamageSystem.Type.ARCANE:
				arena.play_sfx(SFX_MAGIC, -9.0, randf_range(0.95, 1.1))
			else:
				arena.play_sfx(SFX_SLASH, -9.0, randf_range(1.2, 1.4))
				ArcaneFx.muzzle(arena, View3D.to3(at + direction * 22.0, 1.3), View3D.dir3(direction), ArcaneFx.GOLD)
			ArcaneFx.burst(arena, View3D.to3(at + direction * 18.0, 1.2), DamageSystem.color_of(DamageSystem.type_of(skill)), 14, 1.5, 0.1)
		"projectile_hit":
			match String(skill.get("id", "")):
				"arcane_bind":
					var bind_color := Color(0.8, 0.5, 1.0)
					ArcaneFx.ice_shards(arena, View3D.to3(at), 0.9, 10, bind_color)
					ArcaneFx.burst(arena, View3D.to3(at, 0.3), bind_color, 36, 3.0, 0.12)
					arena.spawn_shockwave(at, 55.0, bind_color, 0.4, 0.7)
					arena.play_sfx(SFX_SLAM, -6.0, 1.5)
					return
				"arcane_silence":
					ArcaneFx.swirl_zone(arena, View3D.to3(at), 0.7, Color(0.5, 0.4, 0.8), 0.8)
					ArcaneFx.burst(arena, View3D.to3(at, 1.8), Color(0.5, 0.4, 0.8), 36, 2.0, 0.12)
					arena.play_sfx(SFX_MAGIC, -3.0, 1.6)
					return
			if DamageSystem.type_of(skill) != DamageSystem.Type.ARCANE:
				return  # las flechas ya generan chispas en _on_attack_hit
			var hit_color := DamageSystem.color_of(DamageSystem.type_of(skill))
			ArcaneFx.burst(arena, View3D.to3(at, 1.1), hit_color, 36, 4.0, 0.13)
			arena.spawn_shockwave(at, 34.0, hit_color, 0.3, 0.7)
			arena.play_sfx(SFX_HIT, -6.0, 1.1)
		"vanish":
			ArcaneFx.burst(arena, View3D.to3(at, 1.0), Color(0.35, 0.28, 0.45), 60, 2.5, 0.28)
			ArcaneFx.column(arena, View3D.to3(at), Color(0.45, 0.35, 0.6), 2.0)
			arena.play_sfx(SFX_ROLL, -5.0, 0.7)
		"leap_start":
			arena.spawn_dust(at, 12, 0.6)
			arena.play_sfx(SFX_CHARGE, -8.0, 0.9)
		"explosion":
			var boom_color := Color(1.0, 0.6, 0.2)
			var boom_radius := float(skill.get("explode_radius", 100.0))
			ArcaneFx.burst(arena, View3D.to3(at, 0.8), boom_color, 70, 5.5, 0.16)
			ArcaneFx.debris(arena, View3D.to3(at), View3D.meters(boom_radius))
			arena.spawn_shockwave(at, boom_radius, boom_color, 0.45, 0.7)
			arena.spawn_ground_flash(at, boom_radius, Color(1.0, 0.5, 0.15, 0.55), 0.4)
			arena.play_sfx(SFX_SLAM, -3.0, 1.1)
			_shake(3.5, 0.2)
		"flurry_hit", "flurry_hit_last":
			var list: Array = skill.get("flurry_clips", [4])
			_flurry_i += 1
			_play_clip(M1_CLIPS[int(list[_flurry_i % list.size()])], 0.03, 0.12)
			var last := event == "flurry_hit_last"
			var hit_at := at + direction * 48.0
			ArcaneFx.hit_sparks(arena, View3D.to3(hit_at, 1.1), Color(0.9, 0.2, 0.25) if last else ArcaneFx.STEEL, View3D.dir3(direction), 34 if last else 14, last)
			arena.play_sfx(SFX_HIT_HEAVY if last else SFX_SLASH, -3.0 if last else -7.0, 0.8 if last else randf_range(1.1, 1.4))
			if last:
				arena.spawn_shockwave(hit_at, 80.0, Color(0.9, 0.2, 0.25), 0.4, 0.7)
				_shake(4.0, 0.2)
				rig.hitstop(0.09)
			else:
				_shake(1.2, 0.06)
		"team_buff":
			var buff_color := DamageSystem.color_of(DamageSystem.Type.ARCANE) if DamageSystem.type_of(skill) == DamageSystem.Type.ARCANE else Color(1.0, 0.8, 0.3)
			arena.spawn_shockwave(at, float(skill.get("radius", 200.0)), buff_color, 0.55, 0.8)
			arena.spawn_ground_flash(at, float(skill.get("radius", 200.0)) * 0.6, Color(buff_color.r, buff_color.g, buff_color.b, 0.45), 0.4)
			ArcaneFx.column(arena, View3D.to3(at), buff_color, 2.8)
			ArcaneFx.burst(arena, View3D.to3(at, 1.0), buff_color, 40, 3.0, 0.13)
			arena.play_sfx(SFX_MAGIC, -5.0, 0.9)
			_shake(1.6, 0.12)
		"blink_out":
			var blink_color := DamageSystem.color_of(DamageSystem.type_of(skill))
			ArcaneFx.column(arena, View3D.to3(at), blink_color, 2.2)
			ArcaneFx.burst(arena, View3D.to3(at, 1.0), blink_color, 40, 3.0, 0.12)
			arena.play_sfx(SFX_MAGIC, -6.0, 1.4)
			rig.visible = false
			trail.emitting = false
		"blink_in":
			var in_color := DamageSystem.color_of(DamageSystem.type_of(skill))
			ArcaneFx.column(arena, View3D.to3(at), in_color, 2.2)
			ArcaneFx.burst(arena, View3D.to3(at, 1.0), in_color, 40, 3.0, 0.12)
			arena.spawn_shockwave(at, 40.0, in_color, 0.35, 0.7)
			get_tree().create_timer(0.12).timeout.connect(func() -> void:
				rig.visible = true
				if skill.has("arrive_clip"):
					_play_clip(skill["arrive_clip"], 0.1, 0.25))
		"spin_start":
			_spinning = true
			_spin_yaw = 0.0
			trail.emitting = true
			trail.color = COLOR_FINISHER
			_spin_disc.visible = true
			_spin_disc.scale = Vector3.ONE * View3D.meters(float(skill.get("radius", 105.0)))
			# Pose de brazo extendido (contacto de Sword_Regular_A) congelada
			# mientras el modelo gira: lee como un tajo continuo.
			rig.play_clip(String(M1_CLIPS[0]["clip"]), 0.45, 0.6, 0.6, 0.06, 0.01)
			arena.play_sfx(SFX_SPIN, -6.0, 1.0)
			_shake(3.6, 0.22)
		"aoe_tick":
			if String(skill.get("id", "")) == "rain_of_arrows":
				ArcaneFx.arrow_rain(arena, View3D.to3(at), View3D.meters(float(skill.get("radius", 170.0))), 12)
				return
			arena.spawn_shockwave(at, float(skill.get("radius", 105.0)), COLOR_FINISHER, 0.25, 0.85)
			_shake(1.4, 0.08)
		"spin_end":
			_stop_spin()
		_:
			pass


## Impacto de un hechizo de suelo arcano: anillos, columna de chispas y destello.
## Efectos propios de las skills de área de Rogue y Ranger. Devuelve true si los manejó.
func _class_slam(at: Vector2, radius: float, skill: Dictionary) -> bool:
	var meters_r := View3D.meters(radius)
	var ground := View3D.to3(at)
	match String(skill.get("id", "")):
		"fan_of_knives":
			arena.spawn_shockwave(at, radius, ArcaneFx.POISON, 0.35, 0.8)
			ArcaneFx.poison_cloud(arena, ground, meters_r * 0.6, 1.6)
			arena.play_sfx(SFX_SLASH, -4.0, 1.3)
			_shake(2.0, 0.12)
		"cross_cut":
			ArcaneFx.hit_sparks(arena, ground + Vector3(0, 0.3, 0), ArcaneFx.STEEL, View3D.dir3(sim.attack_aim), 22, true)
			arena.spawn_dust(at, 8, 0.5)
			_shake(2.4, 0.14)
		"death_sentence":
			var dark := Color(0.85, 0.15, 0.2)
			ArcaneFx.hit_sparks(arena, ground + Vector3(0, 1.0, 0) + View3D.dir3(sim.attack_aim) * 0.8, dark, View3D.dir3(sim.attack_aim), 40, true)
			ArcaneFx.burst(arena, ground + Vector3(0, 0.8, 0), dark, 50, 4.0, 0.14)
			arena.spawn_shockwave(at, 90.0, dark, 0.45, 0.7)
			arena.play_sfx(SFX_HIT_HEAVY, -2.0, 0.85)
			_shake(5.0, 0.25)
			rig.hitstop(0.1)
		"bear_trap":
			ArcaneFx.ice_shards(arena, ground, meters_r, 8, Color(0.78, 0.74, 0.66))
			arena.spawn_shockwave(at, radius, Color(0.9, 0.8, 0.6), 0.4, 0.75)
			arena.play_sfx(SFX_SLAM, -5.0, 1.3)
		"rain_of_arrows":
			ArcaneFx.arrow_rain(arena, ground, meters_r, 24)
			arena.spawn_shockwave(at, radius, Color(1.0, 0.85, 0.5, 0.8), 0.5, 0.85)
			arena.play_sfx(SFX_HIT, -5.0, 0.9)
		"frost_trap":
			ArcaneFx.ice_shards(arena, ground, meters_r)
			arena.spawn_shockwave(at, radius, ArcaneFx.FROST, 0.6, 0.7)
			arena.spawn_ground_flash(at, radius, Color(0.5, 0.8, 1.0, 0.45), 0.5)
			arena.play_sfx(SFX_MAGIC, -6.0, 1.4)
		"seismic_break":
			ArcaneFx.debris(arena, ground, meters_r)
			return false  # el resto del efecto de Seismic Break sigue su curso
		_:
			return false
	return true


func _arcane_slam(at: Vector2, radius: float, skill: Dictionary) -> void:
	var color := DamageSystem.color_of(DamageSystem.Type.ARCANE)
	match String(skill.get("id", "")):
		"time_rift":
			ArcaneFx.swirl_zone(arena, View3D.to3(at), View3D.meters(radius), Color(0.6, 0.55, 1.0), float(skill.get("lingering", 4.0)))
			arena.spawn_shockwave(at, radius, Color(0.6, 0.55, 1.0), 0.6, 0.8)
			arena.play_sfx(SFX_MAGIC, -5.0, 0.6)
			return
		"arcane_pulse":
			# Onda de repulsión: anillos que se expanden y chispas hacia fuera
			arena.spawn_shockwave(at, radius, color, 0.4, 0.55)
			arena.spawn_shockwave(at, radius * 1.4, color.lightened(0.4), 0.55, 0.8)
			ArcaneFx.burst(arena, View3D.to3(at, 0.9), color, 60, 6.0, 0.14)
			arena.play_sfx(SFX_SLAM, -4.0, 1.3)
			_shake(2.6, 0.16)
			return
	arena.spawn_shockwave(at, radius, color, 0.6, 0.7)
	arena.spawn_shockwave(at, radius * 0.6, color.lightened(0.4), 0.4, 0.75)
	arena.spawn_ground_flash(at, radius, Color(color.r, color.g, color.b, 0.55), 0.5)
	ArcaneFx.column(arena, View3D.to3(at), color, 3.0)
	ArcaneFx.burst(arena, View3D.to3(at, 0.8), color, 70, 5.0, 0.16)
	arena.play_sfx(SFX_MAGIC, -3.0, 0.8)
	_shake(3.0 + radius * 0.012, 0.25)


func _stop_spin() -> void:
	_spin_rate = SPIN_SPEED
	_spin_limit = 1e9
	if _spinning:
		_yaw = rig.rotation.y
	_spinning = false
	_spin_yaw = 0.0
	_spin_disc.visible = false
	trail.emitting = false


func _on_attack_hit(skill: Dictionary, target: Object, damage: float, critical: bool, hit_position: Vector2) -> void:
	var heavy := _is_heavy(skill) or critical
	_spawn_hit_fx(skill, hit_position, heavy)
	arena.spawn_damage_number(hit_position, damage, critical)
	var color := Color(1.0, 0.86, 0.42) if critical else Color(1.0, 0.72, 0.35)
	arena.spawn_impact(hit_position, color, heavy)
	arena.play_sfx(SFX_HIT_HEAVY if heavy else SFX_HIT, -5.0, randf_range(0.92, 1.06))
	_shake(3.2 if heavy else 2.0, 0.14)
	# Hit-stop: congelar atacante y víctima unas centésimas da peso al golpe.
	var stop := 0.085 if heavy else 0.055
	rig.hitstop(stop)
	var dummy := arena.dummy_actor_for(target)
	if dummy != null:
		dummy.on_struck(sim.position, stop, heavy)


## Chispas de impacto según clase/skill: acero y oro; verde si deja veneno.
func _spawn_hit_fx(skill: Dictionary, hit_position: Vector2, heavy: bool) -> void:
	var type := DamageSystem.type_of(skill)
	if type == DamageSystem.Type.ARCANE:
		return
	var color := ArcaneFx.GOLD if sim.class_id != &"rogue" else ArcaneFx.STEEL
	var dot: Dictionary = (skill.get("effects", {}) as Dictionary).get("dot", {})
	if not dot.is_empty() and int(dot.get("damage_type", -1)) == DamageSystem.Type.POISON:
		color = ArcaneFx.POISON
		ArcaneFx.burst(arena, View3D.to3(hit_position, 1.0), ArcaneFx.POISON, 30, 2.5, 0.12)
	ArcaneFx.hit_sparks(arena, View3D.to3(hit_position, 1.1), color, View3D.dir3(sim.attack_aim), 18, heavy)
	# Corte con textura: el trazo (slash_0N) y un fogonazo de impacto.
	var cut_names := ["slash_01", "slash_02", "slash_03", "slash_04"]
	ArcaneFx.flash_sprite(arena, View3D.to3(hit_position, 1.1), cut_names[randi() % cut_names.size()], color.lightened(0.3), 2.0 if heavy else 1.3, 0.22, randf_range(-0.8, 0.8))
	ArcaneFx.flash_sprite(arena, View3D.to3(hit_position, 1.1), "star_06" if heavy else "spark_04", Color(1.0, 0.95, 0.8), 1.1 if heavy else 0.6, 0.14)
	if (skill.get("effects", {}) as Dictionary).has("mark"):
		ArcaneFx.burst(arena, View3D.to3(hit_position, 1.2), Color(1.0, 0.55, 0.15), 30, 2.5, 0.12)
		arena.spawn_shockwave(hit_position, 50.0, Color(1.0, 0.55, 0.15, 0.9), 0.4, 0.7)
	if (skill.get("effects", {}) as Dictionary).has("stun"):
		ArcaneFx.burst(arena, View3D.to3(hit_position, 1.6), Color(1.0, 0.9, 0.3), 24, 2.0, 0.13)
	match String(skill.get("id", "")):
		"eviscerate":  # remate: corte grande y salpicadura roja
			ArcaneFx.flash_sprite(arena, View3D.to3(hit_position, 1.2), "slash_04", Color(1.0, 0.35, 0.3), 3.2, 0.3, randf_range(-0.5, 0.5))
			ArcaneFx.burst(arena, View3D.to3(hit_position, 1.2), Color(0.85, 0.05, 0.08), 36, 3.2, 0.13)
		"death_sentence":
			ArcaneFx.flash_sprite(arena, View3D.to3(hit_position, 1.2), "star_06", Color(0.9, 0.2, 0.9), 2.4, 0.3)
		"hamstring":
			ArcaneFx.burst(arena, View3D.to3(hit_position, 0.6), Color(0.8, 0.05, 0.05), 20, 2.0, 0.11)


func _on_attack_finished(_skill: Dictionary) -> void:
	_current_skill = {}
	_align_yaw = 0.0
	trail.emitting = false
	_stop_spin()


func _on_damage_taken(_amount: float, _source_position: Vector2, is_dot: bool) -> void:
	if is_dot:
		return
	rig.flash(Color(1.0, 0.25, 0.2), 0.14)
	if not sim.is_attacking() and sim.alive:
		_hurt_time = 0.32
		rig.play_clip(ANIM_HIT, 0.0, 0.8, 0.25, 0.06, 0.26, ANIM_IDLE, 0.04)
	arena.play_sfx(SFX_HURT, -6.0, randf_range(0.92, 1.05))
	_shake(3.2, 0.18)


## Vanish: el personaje se ve semitransparente mientras es invisible.
func _set_invisible(on: bool) -> void:
	for mi: Node in rig.model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = 0.65 if on else 0.0
	if not on:
		ArcaneFx.burst(arena, View3D.to3(sim.position, 1.0), Color(0.45, 0.35, 0.6), 30, 2.0, 0.2)


## Defensa mantenida: pose de guardia (Warrior) o escudo de maná (Mago).
func _on_guard_changed(active: bool, kind: String) -> void:
	if kind == "block":
		if active:
			_play_clip(CLIP_PARRY, 0.08, 0.4, "")  # se queda en la pose de bloqueo
			arena.play_sfx(SFX_PARRY, -14.0, 0.7)
		return
	_ensure_shield()
	_shield_fx.visible = active
	if active:
		var m2 := sim.ability_for_slot("M2")
		_play_cast_overlay(m2, 0.2)
		ArcaneFx.burst(arena, View3D.to3(sim.position, 1.0), DamageSystem.color_of(DamageSystem.Type.ARCANE), 26, 2.2, 0.1)
		arena.play_sfx(SFX_MAGIC, -10.0, 1.3)


func _ensure_shield() -> void:
	if _shield_fx != null:
		return
	_shield_fx = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.15
	mesh.height = 2.3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.7, 0.5, 1.0, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	_shield_fx.mesh = mesh
	_shield_fx.position.y = 1.0
	_shield_fx.visible = false
	add_child(_shield_fx)


## Resultado de un golpe contra la defensa: perfect parry / block / deflection / absorción.
func _on_guard_result(kind: String, _source: Vector2, _physical: bool) -> void:
	var front := sim.position + sim.aim_dir * 34.0
	var arcane := DamageSystem.color_of(DamageSystem.Type.ARCANE)
	match kind:
		"perfect":
			var flash := Color(0.75, 0.9, 1.0)
			ArcaneFx.hit_sparks(arena, View3D.to3(front, 1.2), flash, View3D.dir3(sim.aim_dir), 40, true)
			ArcaneFx.burst(arena, View3D.to3(front, 1.2), Color(1.0, 1.0, 1.0), 30, 4.0, 0.12)
			arena.spawn_shockwave(front, 70.0, flash, 0.35, 0.7)
			_play_clip(CLIP_BLOCK_REACT, 0.08, 0.35)
			arena.play_sfx(SFX_PARRY, -1.0, 1.25)
			_shake(3.0, 0.16)
			rig.hitstop(0.1)
		"block":
			ArcaneFx.hit_sparks(arena, View3D.to3(front, 1.2), ArcaneFx.GOLD, View3D.dir3(sim.aim_dir), 14, false)
			arena.play_sfx(SFX_HIT, -4.0, 0.7)
			_shake(1.6, 0.1)
		"deflect":
			ArcaneFx.burst(arena, View3D.to3(sim.position, 1.1), arcane.lightened(0.3), 50, 4.5, 0.14)
			arena.spawn_shockwave(sim.position, 100.0, arcane, 0.45, 0.7)
			arena.spawn_ground_flash(sim.position, 80.0, Color(arcane.r, arcane.g, arcane.b, 0.5), 0.3)
			arena.play_sfx(SFX_MAGIC, -2.0, 1.5)
			_shake(2.6, 0.15)
			rig.hitstop(0.08)
		"absorb":
			ArcaneFx.burst(arena, View3D.to3(sim.position, 1.1), arcane, 16, 2.0, 0.09)
			arena.play_sfx(SFX_HIT, -9.0, 1.6)
			if _shield_fx != null:
				_shield_fx.scale = Vector3.ONE * 1.12
				create_tween().tween_property(_shield_fx, "scale", Vector3.ONE, 0.18)
		"shield_break":
			ArcaneFx.burst(arena, View3D.to3(sim.position, 1.1), arcane, 60, 5.0, 0.16)
			arena.spawn_shockwave(sim.position, 80.0, arcane, 0.4, 0.6)
			arena.play_sfx(SFX_SLAM, -6.0, 1.4)
			if _shield_fx != null:
				_shield_fx.visible = false


## Esquiva perfecta del Ranger: destello dorado y siguiente ráfaga potenciada.
func _on_perfect_evade() -> void:
	ArcaneFx.burst(arena, View3D.to3(sim.position, 1.0), Color(1.0, 0.9, 0.4), 40, 3.5, 0.12)
	arena.spawn_shockwave(sim.position, 70.0, Color(1.0, 0.85, 0.3, 0.9), 0.35, 0.7)
	arena.play_sfx(SFX_PARRY, -4.0, 1.5)
	rig.hitstop(0.06)


## Escudo de maná pulsando y efecto fantasma durante los iframes (voltereta / paso evasivo).
func _update_defense_fx() -> void:
	if sim.absorb_amount > 0.0:
		_ensure_shield()
	if _shield_fx != null:
		_shield_fx.visible = (sim.guarding and sim.guard_kind == "mana_shield") or sim.absorb_amount > 0.0
		if _shield_fx.visible:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			(_shield_fx.mesh.material as StandardMaterial3D).albedo_color.a = 0.16 + 0.12 * pulse
	var evading := sim.is_evading()
	if evading != _was_evading:
		_was_evading = evading
		if not sim.is_invisible():
			for mi: Node in rig.model.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).transparency = 0.55 if evading else 0.0


func _on_stunned(seconds: float) -> void:
	_hurt_time = seconds
	trail.emitting = false
	_stop_spin()
	rig.play_clip("ual1/Hit_Head", 0.0, 1.0, 0.3, 0.1, maxf(seconds - 0.1, 0.2), ANIM_IDLE)
	rig.flash(Color(1.0, 0.9, 0.3), 0.3)


func _on_died() -> void:
	_dead_visual = true
	_stop_spin()
	trail.emitting = false
	rig.play_clip(ANIM_DEATH, 0.0, 1.0, 0.4, 0.4, 0.9)
	arena.play_sfx(SFX_DEATH, -4.0, 0.9)
	_shake(5.0, 0.35)


func _restore_visual() -> void:
	_set_invisible(false)
	rig.visible = true
	_dead_visual = false
	rig.play(ANIM_IDLE, 0.2, 1.0, true)


func _on_ultimate_changed(current: float, maximum: float) -> void:
	if current >= maximum and maximum > 0.0:
		arena.play_sfx(SFX_BUFF, -14.0, 0.7)


func _on_last_stand_changed(active: bool, _seconds_left: float) -> void:
	if not active:
		return
	arena.play_sfx(SFX_BUFF, -9.0, 0.85)
	arena.spawn_shockwave(sim.position, 70.0, COLOR_RAGE, 0.5, 0.6)


# --- Proyectiles (orbes) --------------------------------------------------------------


func _update_orbs() -> void:
	var seen: Dictionary = {}
	for p: Dictionary in sim.projectiles:
		var id: int = int(p["id"])
		seen[id] = true
		if not _orbs.has(id):
			var rgb: Array = (p["skill"] as Dictionary).get("color", [1.0, 0.8, 0.4])
			var big := 1.5 if float((p["skill"] as Dictionary).get("hit_radius", 10.0)) > 12.0 else 1.0
			var skill_data: Dictionary = p["skill"]
			var orb: Node3D
			if String(skill_data.get("id", "")) == "mark_for_death":
				orb = ArcaneFx.make_spinning_knife(Color(rgb[0], rgb[1], rgb[2]))
			else:
				orb = ArcaneFx.make_orb(Color(rgb[0], rgb[1], rgb[2]), big) if DamageSystem.type_of(skill_data) == DamageSystem.Type.ARCANE else ArcaneFx.make_arrow(Color(rgb[0], rgb[1], rgb[2]))
			arena.add_child(orb)
			_orbs[id] = orb
		var spinner := (_orbs[id] as Node3D).get_node_or_null("Spinner") as Node3D
		if spinner != null:
			spinner.rotation.z = Time.get_ticks_msec() * 0.03  # el cuchillo gira mientras vuela
		(_orbs[id] as Node3D).position = View3D.to3(p["pos"], 1.15)
		(_orbs[id] as Node3D).rotation.y = View3D.yaw_for(p["dir"])
	for id: int in _orbs.keys():
		if not seen.has(id):
			(_orbs[id] as Node3D).queue_free()
			_orbs.erase(id)


# --- Utilidades -----------------------------------------------------------------


func _play_cast_sfx(skill: Dictionary) -> void:
	match String(skill.get("sfx", "slash")):
		"slash":
			arena.play_sfx(SFX_SLASH_HEAVY if _is_heavy(skill) else SFX_SLASH, -7.0, randf_range(0.92, 1.06))
		"thrust":
			arena.play_sfx(SFX_SLASH_HEAVY, -7.0, 1.02)
		_:
			arena.play_sfx(SFX_SLASH, -8.0, 1.0)


func _damage_mult_scalar(skill: Dictionary) -> float:
	var raw: Variant = skill.get("damage_mult", 1.0)
	if raw is Array:
		var values: Array = raw
		var idx := clampi(sim.combo_index, 0, values.size() - 1) if String(skill.get("id", "")) == "heavy_strikes" else values.size() - 1
		return float(values[idx]) if not values.is_empty() else 1.0
	return float(raw)


func _is_heavy(skill: Dictionary) -> bool:
	return _damage_mult_scalar(skill) >= 1.5


func _is_finisher() -> bool:
	return String(_current_skill.get("id", "")) == "heavy_strikes" and sim.combo_index >= 2
