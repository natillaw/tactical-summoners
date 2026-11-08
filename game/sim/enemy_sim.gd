## EnemySim — "Soldado": enemigo cuerpo a cuerpo basado en el Warrior.
##
## Hereda el golpe con telegraph del muñeco (parry/interrupción/salto funcionan)
## y añade IA y tres habilidades de guerrero:
##  - Golpe: cono con telegraph (heredado de DummySim).
##  - Carga: si el jugador está lejos, se lanza hacia él y encadena un golpe.
##  - Guardia: una vez, por debajo del 50 % de vida, reduce el daño recibido.
## Se mueve como un jugador: rodea cambiando de lado, entra cuando su golpe está
## listo, encadena combos, rueda para esquivar tus ataques y queda aturdido por Charge.
## Vida y daño escalan con el nivel (nivel 60: ~7.8k de vida, ~320 por golpe).
class_name EnemySim
extends DummySim

signal charge_started(direction: Vector2)
signal guard_started()
signal rolled(direction: Vector2)

const MOVE_SPEED := 120.0          # el Warrior corre a 168
const ATTACK_COOLDOWN := 1.7
const FOLLOWUP_COOLDOWN := 0.25
const COMBO_CHANCE := 0.45
const ROLL_SPEED := 330.0
const ROLL_TIME := 0.32
const ROLL_COOLDOWN := 3.5
const ROLL_CHANCE := 0.55
const ROLL_REACT_DISTANCE := 150.0
const CHARGE_SPEED := 360.0
const CHARGE_TIME := 0.34
const CHARGE_MIN := 200.0
const CHARGE_MAX := 420.0
const CHARGE_COOLDOWN := 8.0
const GUARD_SECONDS := 2.5
const GUARD_REDUCTION := 0.6
const ENGAGE_DISTANCE := ATTACK_RANGE * 0.8   # se acerca hasta aquí para golpear
const SPACING_MIN := 120.0                     # tras golpear: distancia de respeto
const SPACING_MAX := 170.0

var level: int = 1
var xp_reward: int = 30
var charge_timer: float = 0.0
var charge_cooldown: float = 3.0
var charge_direction: Vector2 = Vector2.ZERO
var guard_timer: float = 0.0
var guard_used: bool = false
var moving: bool = false
var _strafe_sign: float = 1.0
var _strafe_time: float = 0.0
var _combo_left: int = 0
var _warrior_was_attacking: bool = false
var roll_timer: float = 0.0
var roll_cooldown: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO


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
	health_changed.emit(health, max_health)


func step(tick_number: int, delta: float, warrior: Object) -> void:
	guard_timer = maxf(0.0, guard_timer - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	var before := position
	if alive and warrior != null and warrior.alive:
		_think(delta, warrior)
	super.step(tick_number, delta, warrior)
	moving = position.distance_squared_to(before) > 0.01


func _think(delta: float, warrior: Object) -> void:
	var to_target: Vector2 = warrior.position - position
	var distance := to_target.length()
	var dir := to_target / maxf(distance, 0.001)
	var speed := MOVE_SPEED * (slow_factor if slow_timer > 0.0 else 1.0)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)

	# Lee al jugador como lo haría otro jugador: si empieza un ataque cerca, rueda.
	var warrior_attacking: bool = warrior.is_attacking()
	var attack_began := warrior_attacking and not _warrior_was_attacking
	_warrior_was_attacking = warrior_attacking

	if stun_timer > 0.0:
		charge_timer = 0.0
		roll_timer = 0.0
		return

	if roll_timer > 0.0:
		roll_timer -= delta
		position = world.resolve_position(position + roll_direction * ROLL_SPEED * delta, radius, self)
		return

	if charge_timer > 0.0:
		charge_timer -= delta
		position = world.resolve_position(position + charge_direction * CHARGE_SPEED * delta, radius, self)
		if charge_timer <= 0.0 or distance <= ENGAGE_DISTANCE:
			charge_timer = 0.0
			cooldown = 0.0  # al llegar, golpea
		return

	if attack_began and state != State.TELEGRAPH and roll_cooldown <= 0.0 			and distance < ROLL_REACT_DISTANCE and world.rng.randf() < ROLL_CHANCE:
		roll_cooldown = ROLL_COOLDOWN
		roll_timer = ROLL_TIME
		roll_direction = (dir.orthogonal() * _strafe_sign - dir * 0.6).normalized()
		rolled.emit(roll_direction)
		return

	if state != State.IDLE or interrupted_timer > 0.0:
		return

	if charge_cooldown <= 0.0 and distance >= CHARGE_MIN and distance <= CHARGE_MAX:
		charge_cooldown = CHARGE_COOLDOWN
		charge_timer = CHARGE_TIME
		charge_direction = dir
		charge_started.emit(charge_direction)
		return

	# Cambia de lado de forma irregular, como un jugador que "baila" el combate.
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = world.rng.randf_range(0.5, 1.4)
		_strafe_sign = -_strafe_sign

	var step_dir := Vector2.ZERO
	if cooldown <= 0.25:
		if distance > ENGAGE_DISTANCE:
			step_dir = dir + dir.orthogonal() * _strafe_sign * 0.25
	elif distance < SPACING_MIN:
		step_dir = -dir * 0.8 + dir.orthogonal() * _strafe_sign * 0.5
	elif distance > SPACING_MAX:
		step_dir = dir + dir.orthogonal() * _strafe_sign * 0.4
	else:
		step_dir = dir.orthogonal() * _strafe_sign
	position = world.resolve_position(position + step_dir.limit_length(1.0) * speed * delta, radius, self)


func _resolve_attack(warrior: Object) -> void:
	super._resolve_attack(warrior)
	# Combo: a veces encadena un segundo golpe casi inmediato.
	if _combo_left > 0:
		_combo_left -= 1
	elif world.rng.randf() < COMBO_CHANCE:
		_combo_left = 1
	cooldown = FOLLOWUP_COOLDOWN if _combo_left > 0 else ATTACK_COOLDOWN


func is_rolling() -> bool:
	return roll_timer > 0.0


func is_charging() -> bool:
	return charge_timer > 0.0


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, effects: Dictionary = {}) -> float:
	if alive and guard_timer > 0.0:
		amount *= 1.0 - GUARD_REDUCTION
	var dealt := super.take_damage(amount, source_position, effects)
	if alive and not guard_used and health < max_health * 0.5:
		guard_used = true
		guard_timer = GUARD_SECONDS
		guard_started.emit()
	return dealt


func revive() -> void:
	position = spawn_position
	guard_used = false
	guard_timer = 0.0
	charge_timer = 0.0
	charge_cooldown = 3.0
	roll_timer = 0.0
	_combo_left = 0
	super.revive()
