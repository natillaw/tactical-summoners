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

var enemy: EnemySim
var _label: Label3D


func setup(p_sim: DummySim, p_arena: Arena3D) -> void:
	enemy = p_sim as EnemySim
	model_path = ENEMY_MODEL
	anim_idle = ANIM_SWORD_IDLE
	attack_clip = CLIP_SLASH
	super.setup(p_sim, p_arena)

	rig.attach_to_hand((load(ENEMY_SWORD) as PackedScene).instantiate())
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
		if effect == "stun":
			rig.play_clip(ANIM_STUN, 0.0, 1.0, 0.3, 0.1, 0.8, ANIM_SWORD_IDLE))


func _dress() -> void:
	# Sin peana: es un enemigo, no un muñeco. Armadura teñida de rojo.
	_tint(TINT)


func _process(delta: float) -> void:
	super._process(delta)
	if enemy == null:
		return
	_label.visible = enemy.alive
	_label.text = ("¡ATURDIDO!  " if enemy.stun_timer > 0.0 else "") + "Soldado  Nv.%d" % enemy.level
	if not enemy.alive:
		return
	if enemy.stun_timer > 0.0:
		rig.flash(Color(1.0, 0.9, 0.3), 0.05)
	elif enemy.state == DummySim.State.IDLE and not enemy.is_rolling():
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
