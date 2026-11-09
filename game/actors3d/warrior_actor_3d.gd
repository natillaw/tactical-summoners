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

const SFX_SLASH := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Slash2.wav")
const SFX_SLASH_HEAVY := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Sword2.wav")
const SFX_HIT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Hit2.wav")
const SFX_HIT_HEAVY := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact3.wav")
const SFX_HURT := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact.wav")
const SFX_DEATH := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact5.wav")
const SFX_MAGIC := preload("res://assets/audio/sfx/ninja/Magic_Skill/Magic2.wav")
const SFX_BUFF := preload("res://assets/audio/sfx/ninja/Magic_Skill/Heal3.wav")
const SFX_PARRY := preload("res://assets/audio/sfx/ninja/Hit_Impact/Hit7.wav")
const SFX_ROLL := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Whoosh.wav")
const SFX_CHARGE := preload("res://assets/audio/sfx/ninja/Whoosh_Slash/Launch.wav")
const SFX_SLAM := preload("res://assets/audio/sfx/ninja/Hit_Impact/Impact3.wav")
const SFX_SPIN := preload("res://assets/audio/sfx/ninja/Magic_Skill/Magic2.wav")

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
]
const CLIP_THRUST := {"clip": "custom/thrust", "from": 0.30, "to": 0.62, "contact": 0.45}
const CLIP_SLAM := {"clip": "ual2/Sword_Heavy_Combo", "from": 0.52, "to": 0.80, "contact": 0.63}
const CLIP_PARRY := {"clip": "ual2/Sword_Block", "from": 0.0, "to": 0.45, "contact": 0.08}
const CLIP_ROLL := {"clip": "ual1/Roll", "from": 0.0, "to": 0.78, "contact": 0.55}
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


func setup(p_sim: WarriorSim, p_arena: Arena3D) -> void:
	sim = p_sim
	arena = p_arena

	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(model_path)

	sword = (load(sword_path) as PackedScene).instantiate()
	rig.attach_to_hand(sword)
	var blade_base := Node3D.new()
	blade_base.position = Vector3(0, 0.14, 0)
	sword.add_child(blade_base)
	var blade_tip := Node3D.new()
	blade_tip.position = Vector3(0, 0.92, 0)
	sword.add_child(blade_tip)
	trail = WeaponTrail.new()
	add_child(trail)
	trail.setup(blade_base, blade_tip)
	_analyze_clips(sword.transform * blade_tip.position)

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
	_connect_signals()
	position = View3D.to3(sim.position)


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
	sim.attack_started.connect(_on_attack_started)
	sim.attack_state_changed.connect(_on_attack_state_changed)
	sim.attack_hit.connect(_on_attack_hit)
	sim.attack_finished.connect(_on_attack_finished)
	sim.damage_taken.connect(_on_damage_taken)
	sim.stunned.connect(_on_stunned)
	sim.died.connect(_on_died)
	sim.cast_event.connect(_on_cast_event)
	sim.ultimate_changed.connect(_on_ultimate_changed)
	sim.last_stand_changed.connect(_on_last_stand_changed)


# --- Por frame ----------------------------------------------------------------


func _process(delta: float) -> void:
	if sim == null:
		return
	position = View3D.to3(sim.position, View3D.meters(sim.height))

	if not sim.alive:
		trail.emitting = false
		_aura.visible = false
		_guard.visible = false
		return
	if _dead_visual:
		_restore_visual()

	_update_facing(delta)
	_update_locomotion()
	_update_dash_fx(delta)
	_aura.visible = sim.is_last_stand_active()
	_guard.visible = sim.is_parrying()
	if _guard.visible:
		_guard.rotation.y = View3D.yaw_for(sim.attack_aim) - rig.rotation.y


func _update_facing(delta: float) -> void:
	var target_yaw := _yaw
	var rate := TURN_SPEED
	if sim.is_attacking():
		target_yaw = View3D.yaw_for(sim.attack_aim) - _align_yaw
		rate = TURN_SPEED_ATTACK
	elif sim.velocity.length_squared() > 64.0:
		target_yaw = View3D.yaw_for(sim.velocity)
	# Quieto: conserva su orientación (la cámara orbita libre y se ve en 360°).
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-rate * delta))

	if _spinning:
		_spin_yaw += SPIN_SPEED * delta
		rig.rotation.y = _yaw + _spin_yaw
	else:
		rig.rotation.y = _yaw


func _update_locomotion() -> void:
	if sim.is_attacking():
		_hurt_time = 0.0
		return
	if _hurt_time > 0.0:
		_hurt_time -= get_process_delta_time()
		return
	if sim.is_airborne():
		rig.play(ANIM_JUMP, 0.1)
		return
	var speed_m := View3D.meters(sim.velocity.length())
	if speed_m > 0.4:
		var anim := ANIM_SPRINT if sim.current_move_speed_multiplier() > 1.15 else ANIM_RUN
		var ref := RUN_ANIM_SPEED * (1.6 if anim == ANIM_SPRINT else 1.0)
		rig.play(anim, 0.12, clampf(speed_m / ref, 0.6, 1.6))
	else:
		rig.play(ANIM_IDLE, 0.18)


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
		"seismic_break":
			_play_clip(CLIP_SLAM, windup, post)
		"parry":
			_play_clip(CLIP_PARRY, windup, float(skill.get("active", 0.45)))
		"bladestorm":
			_play_clip(M1_CLIPS[2], windup, 0.2)
		_:
			pass
	_yaw = View3D.yaw_for(direction) - _align_yaw
	rig.rotation.y = _yaw


func _play_clip(c: Dictionary, to_contact: float, after: float, then: String = "") -> void:
	var info: Dictionary = _clip_info.get(_clip_key(c), {})
	_align_yaw = float(info.get("yaw", 0.0))
	_swing_dir = float(info.get("sweep", 1.0))
	rig.play_clip(
		String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]),
		to_contact, after, then
	)


func _on_attack_state_changed(state: int) -> void:
	if _current_skill.is_empty():
		return
	var cast := String(_current_skill.get("cast", "melee"))
	if state == WarriorSim.AttackState.ACTIVE and (cast == "melee" or cast == "line"):
		trail.emitting = true
		trail.color = COLOR_FINISHER if _is_finisher() else COLOR_SLASH
		_spawn_cast_vfx(_current_skill)
		_play_cast_sfx(_current_skill)
		if _is_finisher():
			arena.shake(3.4, 0.18)
		elif _is_heavy(_current_skill):
			arena.shake(2.4, 0.14)
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
			if String(skill.get("id", "")) == "combat_roll":
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
			arena.shake(2.8, 0.16)
			rig.hitstop(0.07)
		"slam":
			var radius := float(skill.get("radius", 120.0))
			arena.spawn_shockwave(at, radius, COLOR_EARTH, 0.5, 0.7)
			arena.spawn_shockwave(at, radius * 0.55, Color(1.0, 0.85, 0.6, 0.45), 0.3, 0.75)
			arena.spawn_ground_flash(at, radius, Color(1.0, 0.45, 0.15, 0.5), 0.4)
			arena.spawn_dust(at, 22, View3D.meters(radius) * 0.9)
			arena.spawn_impact(at + direction * 26.0, COLOR_EARTH, true, 0.2, 1.4)
			arena.play_sfx(SFX_SLAM, -6.0, 1.0)
			arena.shake(5.0, 0.30)
			rig.hitstop(0.09)
		"parry_stance":
			arena.play_sfx(SFX_MAGIC, -12.0, 1.1)
			arena.shake(1.2, 0.08)
		"parry_success":
			_play_clip(CLIP_COUNTER, 0.05, recovery, ANIM_IDLE)
			arena.spawn_swipe(
				sim.position, direction, float(skill.get("counter_range", 90.0)),
				float(skill.get("counter_arc", 120.0)), COLOR_GUARD, 0.06, 0.2, 0.95, _swing_dir
			)
			arena.spawn_impact(at, COLOR_GUARD, true)
			arena.play_sfx(SFX_PARRY, -2.0, 1.15)
			arena.shake(2.6, 0.14)
			rig.hitstop(0.1)
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
			arena.shake(3.6, 0.22)
		"aoe_tick":
			arena.spawn_shockwave(at, float(skill.get("radius", 105.0)), COLOR_FINISHER, 0.25, 0.85)
			arena.shake(1.4, 0.08)
		"spin_end":
			_stop_spin()
		_:
			pass


func _stop_spin() -> void:
	if _spinning:
		_yaw = rig.rotation.y
	_spinning = false
	_spin_yaw = 0.0
	_spin_disc.visible = false
	trail.emitting = false


func _on_attack_hit(skill: Dictionary, target: Object, damage: float, critical: bool, hit_position: Vector2) -> void:
	var heavy := _is_heavy(skill) or critical
	arena.spawn_damage_number(hit_position, damage, critical)
	var color := Color(1.0, 0.86, 0.42) if critical else Color(1.0, 0.72, 0.35)
	arena.spawn_impact(hit_position, color, heavy)
	arena.play_sfx(SFX_HIT_HEAVY if heavy else SFX_HIT, -5.0, randf_range(0.92, 1.06))
	arena.shake(3.2 if heavy else 2.0, 0.14)
	# Hit-stop: congelar atacante y víctima unas centésimas da peso al golpe.
	var stop := 0.085 if heavy else 0.055
	rig.hitstop(stop)
	var dummy := arena.dummy_actor_for(target)
	if dummy != null:
		dummy.on_struck(sim.position, stop, heavy)


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
	arena.shake(3.2, 0.18)


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
	arena.shake(5.0, 0.35)


func _restore_visual() -> void:
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
