## EnemySim — "Soldado": enemigo cuerpo a cuerpo que juega como el Warrior.
##
## Usa las mismas habilidades que el jugador (datos de WarriorKit) y las decide
## como lo haría otro jugador, no con una rotación fija:
##  - M1 (Heavy Strikes): combo de 3 golpes SIN cooldown, mismos tiempos que el tuyo.
##  - Golpe pesado, Estocada y Ruptura sísmica: ataques con telegraph en el suelo
##    (cono / línea / círculo). El daño ocupa un volumen: saltar no los esquiva.
##  - Carga: se lanza hacia ti, daña y te aturde.
##  - Parry: si empiezas un ataque cerca, a veces lo desvía y contraataca.
##  - Voltereta: esquiva con invulnerabilidad.
##  - Bladestorm: giro de acero a vida baja (con aviso).
##  - Last Stand: a vida muy baja gana daño y velocidad.
##  - Guardia: una vez, bajo el 50 % de vida, reduce el daño recibido.
## Vida y daño escalan con el nivel (nivel 60: ~7.8k de vida).
class_name EnemySim
extends DummySim

signal charge_started(direction: Vector2)
signal charge_hit()
signal guard_started()
signal rolled(direction: Vector2)
signal m1_started(combo_index: int)
signal parry_started()
signal parried()
signal spin_started(radius: float)
signal spin_ended()
signal last_stand_started()

enum Act { NONE, M1, PARRY, SPIN }

const MOVE_SPEED := 130.0          # el Warrior corre a 168
const ENGAGE_DISTANCE := 64.0      # se acerca hasta aquí para golpear
const M1_DAMAGE_SCALE := 0.5       # un golpe de M1 vale la mitad del pesado
const ROLL_SPEED := 330.0
const ROLL_TIME := 0.32
const ROLL_COOLDOWN := 3.5
const ROLL_CHANCE := 0.45
const REACT_DISTANCE := 150.0
const PARRY_COOLDOWN := 6.0
const PARRY_CHANCE := 0.5
const PARRY_COUNTER_MULT := 1.8
const CHARGE_SPEED := 360.0
const CHARGE_MIN := 160.0
const CHARGE_MAX := 360.0
const CHARGE_COOLDOWN := 8.0
const CHARGE_REACH := 46.0
const CHARGE_MULT := 1.5
const CHARGE_STUN := 0.8           # al jugador (el Charge del jugador aturde 1 s)
const THRUST_COOLDOWN := 5.0
const HEAVY_COOLDOWN := 4.0
const SEISMIC_COOLDOWN := 11.0
const SPIN_COOLDOWN := 15.0
const SPIN_WINDUP := 0.55
const SPIN_SECONDS := 1.5
const SPIN_INTERVAL := 0.25
const SPIN_MULT := 0.3
const SPIN_RECOVER := 0.35
const GUARD_SECONDS := 2.5
const GUARD_REDUCTION := 0.6
const LAST_STAND_THRESHOLD := 0.3
const LAST_STAND_SECONDS := 5.0

## Ataques con telegraph (rangos y radios salen de WarriorKit).
const HEAVY := {"name": "heavy", "range": 92.0, "arc": 70.0, "mult": 1.0, "seconds": 0.72, "recover": 0.35}

## Tipo de daño de sus ataques (los enemigos de otros tipos solo cambian esto).
var damage_type: int = DamageSystem.Type.PHYSICAL
var level: int = 1
var xp_reward: int = 30
var act: int = Act.NONE
var act_phase: int = 0             # 0 preparación, 1 activo, 2 recuperación
var act_time: float = 0.0
var combo_index: int = 0
var charge_timer: float = 0.0
var charge_cooldown: float = 3.0
var charge_direction: Vector2 = Vector2.ZERO
var guard_timer: float = 0.0
var guard_used: bool = false
var last_stand_timer: float = 0.0
var last_stand_used: bool = false
var moving: bool = false
var roll_timer: float = 0.0
var roll_cooldown: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO

var _parry_cooldown: float = 0.0
var _parry_done: bool = false
var _thrust_cooldown: float = 2.0
var _heavy_cooldown: float = 1.0
var _seismic_cooldown: float = 4.0
var _spin_cooldown: float = 6.0
var _spin_tick: float = 0.0
var _charge_hit_done: bool = false
var _breath: float = 0.0
var _decide_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_time: float = 0.0
var _warrior_was_attacking: bool = false


func _init(p_world: Object = null, p_position: Vector2 = Vector2.ZERO, p_level: int = 1) -> void:
	super._init(p_world, p_position, true)
	set_level(p_level)
	health = max_health


func set_level(lvl: int) -> void:
	level = clampi(lvl, 1, Progression.MAX_LEVEL)
	var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	max_health = 120.0 + 130.0 * (level - 1)
	attack_damage = 17.0 + 5.0 * level
	xp_reward = 30 + 10 * level
	health = ratio * max_health if alive else 0.0
	max_poise = 60.0 + 3.0 * level
	poise = max_poise
	health_changed.emit(health, max_health)


func step(tick_number: int, delta: float, warrior: Object) -> void:
	guard_timer = maxf(0.0, guard_timer - delta)
	last_stand_timer = maxf(0.0, last_stand_timer - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	_thrust_cooldown = maxf(0.0, _thrust_cooldown - delta)
	_heavy_cooldown = maxf(0.0, _heavy_cooldown - delta)
	_seismic_cooldown = maxf(0.0, _seismic_cooldown - delta)
	_spin_cooldown = maxf(0.0, _spin_cooldown - delta)
	var before := position
	if alive and warrior != null and warrior.alive and not warrior.is_invisible():
		_think(delta, warrior)
	super.step(tick_number, delta, warrior)
	moving = position.distance_squared_to(before) > 0.01


## La IA decide aquí; DummySim solo avanza el telegraph que ella inicie.
func _idle_decision(_warrior: Object) -> void:
	pass


func _speed() -> float:
	var s := MOVE_SPEED * (slow_factor if slow_timer > 0.0 else 1.0)
	return s * (1.25 if last_stand_timer > 0.0 else 1.0)


func _move(direction: Vector2, speed: float, delta: float) -> void:
	position = world.resolve_position(position + direction * speed * delta, radius, self)


func _think(delta: float, warrior: Object) -> void:
	var to_target: Vector2 = warrior.position - position
	var distance := to_target.length()
	var dir := to_target / maxf(distance, 0.001)

	# Lee al jugador como lo haría otro jugador: ¿acaba de empezar un ataque?
	var warrior_attacking: bool = warrior.is_attacking()
	var attack_began := warrior_attacking and not _warrior_was_attacking
	_warrior_was_attacking = warrior_attacking
	_breath = maxf(0.0, _breath - delta)

	if stun_timer > 0.0 or knock_timer > 0.0:
		_cancel_actions()
		return

	if roll_timer > 0.0:
		roll_timer -= delta
		_move(roll_direction, ROLL_SPEED, delta)
		return

	if charge_timer > 0.0:
		_update_charge(delta, warrior)
		return

	if act != Act.NONE:
		_update_act(delta, warrior, dir, distance)
		return

	if state != State.IDLE or interrupted_timer > 0.0:
		return  # plantado mientras prepara un ataque con telegraph

	# 1) Defensa reactiva: parry o voltereta ante tu ataque.
	if attack_began and distance < REACT_DISTANCE and silence_timer <= 0.0:
		if _parry_cooldown <= 0.0 and world.rng.randf() < PARRY_CHANCE:
			_start_parry()
			return
		if roll_cooldown <= 0.0 and world.rng.randf() < ROLL_CHANCE:
			roll_cooldown = ROLL_COOLDOWN
			roll_timer = ROLL_TIME
			roll_direction = (dir.orthogonal() * _strafe_sign - dir * 0.6).normalized()
			rolled.emit(roll_direction)
			return

	# 2) Ofensiva (cada pocas décimas, como quien piensa su siguiente jugada).
	_decide_timer -= delta
	if _decide_timer <= 0.0:
		_decide_timer = world.rng.randf_range(0.12, 0.35)
		if _decide_attack(warrior, dir, distance):
			return

	# 3) Movimiento: rodea cambiando de lado y se acerca para golpear.
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = world.rng.randf_range(0.5, 1.4)
		_strafe_sign = -_strafe_sign
	var step_dir := Vector2.ZERO
	if _breath > 0.0:
		step_dir = -dir * 0.3 + dir.orthogonal() * _strafe_sign * 0.7  # respira tras el combo
	elif distance > ENGAGE_DISTANCE:
		step_dir = dir + dir.orthogonal() * _strafe_sign * 0.25
	else:
		step_dir = dir.orthogonal() * _strafe_sign * 0.5
	_move(step_dir.limit_length(1.0), _speed(), delta)


func _decide_attack(warrior: Object, dir: Vector2, distance: float) -> bool:
	var hp := health / maxf(max_health, 1.0)
	if silence_timer > 0.0:  # silenciado: solo puede dar su combo básico
		if distance <= float(WarriorKit.M1["range"]) + TARGET_RADIUS and _breath <= 0.0:
			combo_index = 0
			_begin_m1_swing()
			return true
		return false

	if charge_cooldown <= 0.0 and distance >= CHARGE_MIN and distance <= CHARGE_MAX:
		charge_cooldown = CHARGE_COOLDOWN
		charge_timer = clampf((distance + 40.0) / CHARGE_SPEED, 0.3, 1.2)  # llega y se pasa un poco
		charge_direction = dir
		_charge_hit_done = false
		charge_started.emit(charge_direction)
		return true

	var options: Array = []
	var seismic_r := float(WarriorKit.SEISMIC_BREAK["radius"])
	if _seismic_cooldown <= 0.0 and hp <= 0.8 and distance <= seismic_r - 10.0:
		options.append("seismic")
	if _spin_cooldown <= 0.0 and hp <= 0.5 and distance <= float(WarriorKit.BLADESTORM["radius"]) - 5.0:
		options.append("spin")
	var thrust_r := float(WarriorKit.PIERCING_THRUST["range"])
	if _thrust_cooldown <= 0.0 and distance >= 80.0 and distance <= thrust_r:
		options.append("thrust")
	var m1_reach := float(WarriorKit.M1["range"]) + TARGET_RADIUS
	if distance <= m1_reach:
		if _heavy_cooldown <= 0.0:
			options.append("heavy")
		if _breath <= 0.0:
			for i in 4:
				options.append("m1")
	if options.is_empty():
		return false

	match String(options[world.rng.randi() % options.size()]):
		"m1":
			combo_index = 0
			_begin_m1_swing()
		"heavy":
			_heavy_cooldown = HEAVY_COOLDOWN
			_start_telegraph(HEAVY)
		"thrust":
			_thrust_cooldown = THRUST_COOLDOWN
			_start_telegraph({
				"name": "thrust", "range": thrust_r, "arc": 24.0, "mult": 1.6,
				"seconds": 0.5, "recover": 0.4,
			})
		"seismic":
			_seismic_cooldown = SEISMIC_COOLDOWN
			_start_telegraph({
				"name": "seismic", "range": seismic_r, "arc": 360.0, "mult": 2.2,
				"seconds": 0.9, "recover": 0.5,
			})
		"spin":
			_spin_cooldown = SPIN_COOLDOWN
			_start_spin()
	return true


# --- Acciones con fases (M1, Parry, Bladestorm) -----------------------------------


func _set_act(kind: int) -> void:
	act = kind
	act_phase = 0
	act_time = 0.0


func _update_act(delta: float, warrior: Object, dir: Vector2, distance: float) -> void:
	act_time += delta
	match act:
		Act.M1:
			_update_m1(delta, warrior, dir, distance)
		Act.PARRY:
			var parry: Dictionary = WarriorKit.PARRY
			if act_phase == 0 and act_time >= float(parry["windup"]):
				act_phase = 1
				act_time -= float(parry["windup"])
			elif act_phase == 1 and act_time >= float(parry["active"]):
				act_phase = 2
				act_time -= float(parry["active"])
			elif act_phase == 2 and act_time >= float(parry["recovery"]):
				_end_act()
		Act.SPIN:
			_update_spin(delta, warrior, dir)


func _begin_m1_swing() -> void:
	_set_act(Act.M1)
	attack_direction = facing
	attack_name = "m1"
	attack_range = float(WarriorKit.M1["range"])
	attack_arc = float(WarriorKit.M1["arc"])
	m1_started.emit(combo_index)


func _update_m1(delta: float, warrior: Object, dir: Vector2, distance: float) -> void:
	var kit: Dictionary = WarriorKit.M1
	# Se desplaza despacio hacia ti mientras golpea (como tu move_factor de M1).
	if distance > ENGAGE_DISTANCE:
		_move(dir, _speed() * float(kit["move_factor"]), delta)
	match act_phase:
		0:
			if act_time >= float(kit["windup"]):
				act_phase = 1
				act_time -= float(kit["windup"])
				var mults: Array = kit["damage_mult"]
				var mult := float(mults[clampi(combo_index, 0, mults.size() - 1)])
				_strike(warrior, facing, float(kit["range"]), float(kit["arc"]), attack_damage * M1_DAMAGE_SCALE * mult, {"poise": 8.0})
		1:
			if act_time >= float(kit["active"]):
				act_phase = 2
				act_time -= float(kit["active"])
		2:
			if act_time >= float(kit["recovery"]):
				# Sin cooldown: encadena mientras sigas a su alcance.
				var reach := float(kit["range"]) + TARGET_RADIUS
				if combo_index < 2 and distance <= reach + 10.0:
					combo_index += 1
					_begin_m1_swing()
				else:
					combo_index = 0
					_end_act(world.rng.randf_range(0.15, 0.5))


func _start_parry() -> void:
	_parry_cooldown = PARRY_COOLDOWN
	_parry_done = false
	_set_act(Act.PARRY)
	parry_started.emit()


func _start_spin() -> void:
	_set_act(Act.SPIN)
	_spin_tick = 0.0
	attack_name = "spin"
	attack_direction = facing
	attack_range = float(WarriorKit.BLADESTORM["radius"])
	attack_arc = 360.0
	spin_started.emit(attack_range)


func _update_spin(delta: float, warrior: Object, dir: Vector2) -> void:
	match act_phase:
		0:
			if act_time >= SPIN_WINDUP:
				act_phase = 1
				act_time -= SPIN_WINDUP
				_spin_tick = 0.0
		1:
			_move(dir, _speed() * 0.55, delta)
			_spin_tick += delta
			while _spin_tick >= SPIN_INTERVAL:
				_spin_tick -= SPIN_INTERVAL
				_strike(warrior, facing, attack_range, 360.0, attack_damage * SPIN_MULT, {"poise": 5.0})
			if act_time >= SPIN_SECONDS:
				act_phase = 2
				act_time -= SPIN_SECONDS
				spin_ended.emit()
		2:
			if act_time >= SPIN_RECOVER:
				_end_act(0.5)


func _end_act(breath: float = 0.0) -> void:
	if act == Act.SPIN and act_phase == 1:
		spin_ended.emit()
	act = Act.NONE
	act_phase = 0
	act_time = 0.0
	_breath = maxf(_breath, breath)


func _cancel_actions() -> void:
	charge_timer = 0.0
	roll_timer = 0.0
	if act != Act.NONE:
		_end_act(0.4)


func _update_charge(delta: float, warrior: Object) -> void:
	charge_timer -= delta
	_move(charge_direction, CHARGE_SPEED, delta)
	if not _charge_hit_done and position.distance_to(warrior.position) <= CHARGE_REACH + TARGET_RADIUS:
		_charge_hit_done = true
		charge_timer = 0.0
		attack_direction = charge_direction
		attack_range = CHARGE_REACH
		if _strike(warrior, charge_direction, CHARGE_REACH, 360.0, attack_damage * CHARGE_MULT, {"stun": CHARGE_STUN, "poise": 35.0}):
			charge_hit.emit()
	if charge_timer <= 0.0:
		charge_timer = 0.0
		_breath = 0.0  # al llegar, encadena un golpe


# --- Efectos recibidos ----------------------------------------------------------


func interrupt() -> void:
	super.interrupt()
	if (act == Act.M1 and act_phase == 0) or act == Act.SPIN:
		_end_act(0.4)


## Pierde el golpe cuando está en fase de preparación (los telegraph los gestiona DummySim).
func apply_effects(effects: Dictionary, source: Vector2 = Vector2.ZERO) -> void:
	super.apply_effects(effects, source)
	if stun_timer > 0.0 or knock_timer > 0.0:
		_cancel_actions()


func _strike(warrior: Object, direction: Vector2, reach: float, arc: float, damage: float, effects: Dictionary = {}) -> bool:
	if last_stand_timer > 0.0:
		damage *= float(WarriorKit.PASSIVE["damage_bonus"])
	var fx := effects.duplicate()
	fx[DamageSystem.KEY] = damage_type
	return super._strike(warrior, direction, reach, arc, damage, fx)


func is_rolling() -> bool:
	return roll_timer > 0.0


func is_charging() -> bool:
	return charge_timer > 0.0


func is_spinning() -> bool:
	return act == Act.SPIN and act_phase == 1


func is_parrying() -> bool:
	return act == Act.PARRY and act_phase == 1


func is_swinging() -> bool:
	return act == Act.M1


## El aviso del giro cuenta como telegraph (círculo en el suelo).
func is_telegraphing() -> bool:
	return state == State.TELEGRAPH or (act == Act.SPIN and act_phase == 0)


func telegraph_progress() -> float:
	if act == Act.SPIN and act_phase == 0:
		return clampf(act_time / SPIN_WINDUP, 0.0, 1.0)
	return super.telegraph_progress()


func _is_frontal(source_position: Vector2) -> bool:
	if source_position == Vector2.ZERO:
		return true
	var to_source := source_position - position
	return absf(rad_to_deg(facing.angle_to(to_source))) <= 90.0


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, effects: Dictionary = {}) -> float:
	# Parry: desvía el golpe frontal y contraataca.
	if alive and not bool(effects.get("tick", false)) and is_parrying() and not _parry_done and _is_frontal(source_position):
		_parry_done = true
		parried.emit()
		var warrior: Object = world.warrior
		if warrior != null and warrior.alive:
			attack_direction = facing
			attack_range = float(WarriorKit.PARRY["counter_range"])
			_strike(warrior, facing, attack_range, float(WarriorKit.PARRY["counter_arc"]), attack_damage * PARRY_COUNTER_MULT)
		act_phase = 2
		act_time = 0.0
		return 0.0

	if alive and guard_timer > 0.0:
		amount *= 1.0 - GUARD_REDUCTION
	var dealt := super.take_damage(amount, source_position, effects)
	if alive and not guard_used and health < max_health * 0.5:
		guard_used = true
		guard_timer = GUARD_SECONDS
		guard_started.emit()
	if alive and not last_stand_used and health < max_health * LAST_STAND_THRESHOLD:
		last_stand_used = true
		last_stand_timer = LAST_STAND_SECONDS
		last_stand_started.emit()
	return dealt


func revive() -> void:
	position = spawn_position
	guard_used = false
	guard_timer = 0.0
	last_stand_used = false
	last_stand_timer = 0.0
	charge_timer = 0.0
	charge_cooldown = 3.0
	roll_timer = 0.0
	roll_cooldown = 0.0
	_parry_cooldown = 0.0
	_thrust_cooldown = 2.0
	_heavy_cooldown = 1.0
	_seismic_cooldown = 4.0
	_spin_cooldown = 6.0
	act = Act.NONE
	act_phase = 0
	act_time = 0.0
	combo_index = 0
	_breath = 0.0
	super.revive()
