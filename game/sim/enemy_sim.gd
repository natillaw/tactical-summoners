## EnemySim — "Soldado": enemigo cuerpo a cuerpo basado en el Warrior.
##
## Hereda el golpe con telegraph del muñeco (parry/interrupción funcionan) y
## añade IA: persigue, y tiene tres habilidades de guerrero:
##  - Golpe: cono con telegraph (heredado).
##  - Carga: se lanza hacia el jugador si está lejos y encadena un golpe.
##  - Guardia: una vez, por debajo del 50 % de vida, reduce el daño recibido.
## Vida y daño escalan con el nivel (a nivel 60 ~7.8k de vida y ~320 de golpe).
class_name EnemySim
extends DummySim

signal charge_started(direction: Vector2)
signal guard_started()

const MOVE_SPEED := 92.0
const CHARGE_SPEED := 520.0
const CHARGE_TIME := 0.34
const CHARGE_MIN := 190.0
const CHARGE_MAX := 420.0
const CHARGE_COOLDOWN := 7.0
const GUARD_SECONDS := 2.5
const GUARD_REDUCTION := 0.6

var level: int = 1
var xp_reward: int = 30
var charge_timer: float = 0.0
var charge_cooldown: float = 3.0
var charge_direction: Vector2 = Vector2.ZERO
var guard_timer: float = 0.0
var guard_used: bool = false


func _init(p_world: Object = null, p_position: Vector2 = Vector2.ZERO, p_level: int = 1) -> void:
	super._init(p_world, p_position, true)
	set_level(p_level)
	health = max_health


func set_level(lvl: int) -> void:
	level = clampi(lvl, 1, Progression.MAX_LEVEL)
	var ratio := health / maxf(max_health, 1.0) if max_health > 0.0 else 1.0
	max_health = 120.0 + 130.0 * (level - 1)
	attack_damage = 17.0 + 5.0 * level
	xp_reward = 30 + 10 * level
	health = max_health if not alive else clampf(ratio, 0.05, 1.0) * max_health
	health_changed.emit(health, max_health)


func step(tick_number: int, delta: float, warrior: Object) -> void:
	guard_timer = maxf(0.0, guard_timer - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	var before := position
	if alive and warrior != null and warrior.alive:
		_think(delta, warrior)
	super.step(tick_number, delta, warrior)
	_moved = position.distance_squared_to(before) > 0.01


func _think(delta: float, warrior: Object) -> void:
	var to_target: Vector2 = warrior.position - position
	var distance := to_target.length()
	var slow := slow_factor if slow_timer > 0.0 else 1.0

	if charge_timer > 0.0:
		charge_timer -= delta
		position = world.resolve_position(position + charge_direction * CHARGE_SPEED * delta, radius)
		if charge_timer <= 0.0:
			cooldown = 0.0  # nada más aterrizar, golpea
		return

	if state != State.IDLE or interrupted_timer > 0.0:
		return

	if charge_cooldown <= 0.0 and distance >= CHARGE_MIN and distance <= CHARGE_MAX:
		charge_cooldown = CHARGE_COOLDOWN
		charge_timer = CHARGE_TIME
		charge_direction = to_target.normalized()
		charge_started.emit(charge_direction)
		return

	if distance > ATTACK_RANGE * 0.75:
		position = world.resolve_position(position + to_target.normalized() * MOVE_SPEED * slow * delta, radius)


func is_charging() -> bool:
	return charge_timer > 0.0


func is_moving() -> bool:
	return alive and _moved


var _moved: bool = false


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
	super.revive()
