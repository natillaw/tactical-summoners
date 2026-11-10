## EnemyActor3D — "Soldado": el modelo del Warrior con armadura teñida y espada.
##
## Reutiliza DummyActor3D (telegraph, barra de vida, golpes, muerte) y añade
## locomoción (idle / correr / carga), etiqueta de nivel y el destello de Guardia.
class_name EnemyActor3D
extends DummyActor3D

const ENEMY_MODEL := "res://assets/models/characters/warrior.glb"
const ENEMY_SWORD := "res://assets/models/props/sword_bronze.glb"
const ANIM_SWORD_IDLE := "ual1/Sword_Idle"
const ANIM_RUN := "ual1/Jog_Fwd"
const ANIM_SPRINT := "ual1/Sprint"
const RUN_ANIM_SPEED := 3.6
const CLIP_SLASH := {"clip": "ual2/Sword_Regular_A", "from": 0.0, "to": 1.0, "contact": 0.55}
const TINT := Color(1.0, 0.55, 0.5)
const CLIP_ROLL := {"clip": "ual1/Roll", "from": 0.0, "to": 0.78, "contact": 0.55}
const ANIM_STUN := "ual1/Hit_Head"
## Los mismos clips que usa el jugador para M1 y sus habilidades.
const M1_CLIPS := [
	{"clip": "ual2/Sword_Regular_A", "from": 0.0, "to": 1.0, "contact": 0.55},
	{"clip": "ual2/Sword_Regular_B", "from": 0.0, "to": 1.0, "contact": 0.49},
	{"clip": "ual2/Sword_Regular_C", "from": 0.0, "to": 0.62, "contact": 0.34},
]
const CLIP_THRUST := {"clip": "ual2/Sword_Dash", "from": 0.08, "to": 0.40, "contact": 0.21}
const CLIP_SLAM := {"clip": "ual2/Sword_Heavy_Combo", "from": 0.52, "to": 0.80, "contact": 0.63}
const CLIP_PARRY := {"clip": "ual2/Sword_Block", "from": 0.0, "to": 0.45, "contact": 0.08}
const CLIP_COUNTER := {"clip": "ual2/Sword_Regular_B", "from": 0.25, "to": 1.0, "contact": 0.49}
const SPIN_SPEED := 15.0
const COLOR_GUARD := Color(0.55, 0.8, 1.0, 0.9)
const COLOR_RAGE := Color(1.0, 0.42, 0.15, 1.0)

## Editables desde el editor (soldier_actor.tscn).
@export var enemy_name: String = "Soldado"
@export var tint: Color = TINT
@export_file("*.glb") var enemy_model: String = ENEMY_MODEL
@export_file("*.glb") var enemy_sword: String = ENEMY_SWORD

var enemy: EnemySim
var _label: Label3D
var _spin_yaw: float = 0.0
var _was_spinning: bool = false


func setup(p_sim: DummySim, p_arena: Arena3D) -> void:
	enemy = p_sim as EnemySim
	model_path = enemy_model
	anim_idle = ANIM_SWORD_IDLE
	attack_clip = CLIP_SLASH
	super.setup(p_sim, p_arena)

	rig.attach_to_hand((load(enemy_sword) as PackedScene).instantiate())
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.003
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.7, 0.55)
	_label.position.y = BAR_HEIGHT + 0.25
	add_child(_label)
	enemy.rolled.connect(func(_d: Vector2) -> void:
		var c := CLIP_ROLL
		rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]), EnemySim.ROLL_TIME * 0.7, EnemySim.ROLL_TIME * 0.5, ANIM_SWORD_IDLE))
	enemy.effect_applied.connect(func(effect: String, _s: float) -> void:
		if effect == "stun" or effect == "stagger":
			rig.play_clip(ANIM_STUN, 0.0, 1.0, 0.3, 0.1, 0.8, ANIM_SWORD_IDLE))
	enemy.m1_started.connect(_on_m1_started)
	enemy.parry_started.connect(func() -> void:
		var c := CLIP_PARRY
		rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]), 0.06, 0.45, ANIM_SWORD_IDLE))
	enemy.parried.connect(_on_parried)
	enemy.charge_hit.connect(func() -> void:
		arena.spawn_impact(enemy.position + enemy.charge_direction * 20.0, COLOR_RAGE, true)
		arena.spawn_shockwave(enemy.position + enemy.charge_direction * 20.0, 60.0, COLOR_RAGE, 0.3)
		arena.shake(4.0, 0.2))
	enemy.spin_started.connect(_on_spin_started)
	enemy.last_stand_started.connect(func() -> void:
		arena.spawn_shockwave(enemy.position, 70.0, COLOR_RAGE, 0.5, 0.6))


func _on_m1_started(index: int) -> void:
	var c: Dictionary = M1_CLIPS[clampi(index, 0, 2)]
	var kit: Dictionary = WarriorKit.M1
	rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]),
		float(kit["windup"]), float(kit["active"]) + float(kit["recovery"]), ANIM_SWORD_IDLE)
	arena.play_sfx(SFX_SWING, -9.0, randf_range(0.95, 1.1))


func _on_parried() -> void:
	var c := CLIP_COUNTER
	rig.play_clip(String(c["clip"]), float(c["from"]), float(c["to"]), float(c["contact"]), 0.05, 0.4, ANIM_SWORD_IDLE)
	arena.spawn_impact(enemy.position + enemy.facing * 24.0, COLOR_GUARD, true)
	arena.play_sfx(SFX_IMPACT, -3.0, 1.2)
	arena.shake(2.6, 0.14)
	rig.hitstop(0.08)


func _on_spin_started(radius: float) -> void:
	# Aviso en el suelo (círculo que se llena) antes de empezar a girar.
	_telegraph.scale = Vector3.ONE * (View3D.meters(radius) / View3D.meters(DummySim.ATTACK_RANGE))
	_telegraph.set_param("arc", TAU)
	arena.play_sfx(SFX_ALERT, -10.0, 0.8)


## Cada ataque con telegraph usa su propia animación.
func _telegraph_clip(attack: String) -> Dictionary:
	match attack:
		"thrust":
			return CLIP_THRUST
		"seismic":
			return CLIP_SLAM
		_:
			return attack_clip


func _dress() -> void:
	# Sin peana: es un enemigo, no un muñeco. Armadura teñida de rojo.
	_tint(tint)


func _process(delta: float) -> void:
	super._process(delta)
	if enemy == null:
		return
	_label.visible = enemy.alive
	_label.text = ("¡ATURDIDO!  " if enemy.stun_timer > 0.0 else "") + enemy_name + "  Nv.%d" % enemy.level
	if not enemy.alive:
		return
	if enemy.stun_timer > 0.0:
		rig.flash(Color(1.0, 0.9, 0.3), 0.05)
	elif enemy.state == DummySim.State.IDLE and not enemy.is_rolling() and enemy.act == EnemySim.Act.NONE:
		var current := rig.current()
		if current in [ANIM_SWORD_IDLE, ANIM_RUN, ANIM_SPRINT, ""]:
			if enemy.is_charging():
				rig.play(ANIM_SPRINT, 0.08)
			elif enemy.moving:
				rig.play(ANIM_RUN, 0.12, clampf(View3D.meters(EnemySim.MOVE_SPEED) / RUN_ANIM_SPEED, 0.6, 1.3))
			else:
				rig.play(ANIM_SWORD_IDLE, 0.18)
	if enemy.guard_timer > 0.0:
		rig.flash(Color(0.5, 0.7, 1.0), 0.05)
	if enemy.last_stand_timer > 0.0:
		rig.flash(Color(1.0, 0.35, 0.1), 0.05)
	_update_spin(delta)


## Bladestorm: mientras dura, el modelo gira con la pose del tajo extendido.
func _update_spin(delta: float) -> void:
	var spinning := enemy.is_spinning()
	if spinning and not _was_spinning:
		_spin_yaw = 0.0
		rig.play_clip(String(M1_CLIPS[0]["clip"]), 0.45, 0.6, 0.6, 0.06, 0.01)
		arena.play_sfx(SFX_SWING, -6.0, 0.8)
		arena.shake(3.0, 0.2)
	_was_spinning = spinning
	if spinning:
		_spin_yaw += SPIN_SPEED * delta
		rig.rotation.y = _yaw + _spin_yaw
		if Engine.get_process_frames() % 12 == 0:
			arena.spawn_shockwave(enemy.position, enemy.attack_range, Color(1.0, 0.86, 0.55, 0.9), 0.25, 0.85)
