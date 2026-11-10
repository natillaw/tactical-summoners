## DummySim — simulación determinista de un muñeco de entrenamiento.
##
## Vive dentro de CombatWorld (RefCounted, sin nodos) para poder probarse en
## headless. La presentación (game/actors/dummy_actor.gd) solo lee su estado.
##
## Acepta efectos de las habilidades del Warrior: ralentización, vulnerabilidad
## e interrupción. No se mueve, así que la ralentización afecta a su telegráfico.
class_name DummySim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal telegraph_started(direction: Vector2, radius: float, arc_degrees: float)
signal attack_landed(damage: float)
signal attack_missed()
signal hit(amount: float, position: Vector2)
signal died()
signal revived()
signal interrupted()
signal effect_applied(effect_name: String, seconds: float)
signal dot_damage(amount: float, meta: Dictionary)
signal staggered(seconds: float)

enum State { IDLE, TELEGRAPH, RECOVER, DEAD }

const MAX_HEALTH := 300.0
const RADIUS := 16.0
const ATTACK_RANGE := 92.0
const ATTACK_ARC := 70.0
const ATTACK_DAMAGE := 22.0
const TELEGRAPH_SECONDS := 0.72
const RECOVER_SECONDS := 0.35
const COOLDOWN_SECONDS := 2.60
const RESPAWN_SECONDS := 3.0
## Los golpes ocupan un volumen (cilindro/cono), no solo el suelo: esta altura
## (px de sim, 40 px = 1 m) supera el pico del salto (~61 px), así que saltar no
## esquiva. Solo la voltereta (invulnerable) o el parry los evitan.
const HIT_HEIGHT := 90.0
## Radio del cuerpo del jugador (para el alcance de los golpes).
const TARGET_RADIUS := 14.0

var world: Object = null
var position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO
var auto_attack: bool = true
var max_health: float = MAX_HEALTH
var attack_damage: float = ATTACK_DAMAGE
var health: float = MAX_HEALTH
var alive: bool = true
var state: int = State.IDLE
var state_time: float = 0.0
var cooldown: float = 0.0
var facing: Vector2 = Vector2.LEFT
var hit_flash_ticks: int = 0
var radius: float = RADIUS
var attack_direction: Vector2 = Vector2.LEFT
## Ataque con telegraph en curso (el muñeco usa los valores por defecto).
var attack_name: String = "heavy"
var attack_range: float = ATTACK_RANGE
var attack_arc: float = ATTACK_ARC
var attack_mult: float = 1.0
var telegraph_seconds: float = TELEGRAPH_SECONDS
var recover_seconds: float = RECOVER_SECONDS
var attack_effects: Dictionary = {}

var slow_factor: float = 1.0
var slow_timer: float = 0.0
var vulnerable_amount: float = 0.0
var vulnerable_timer: float = 0.0
var interrupted_timer: float = 0.0
var stun_timer: float = 0.0
var cc := CCDiminish.new()
var knock_vel: Vector2 = Vector2.ZERO
var knock_timer: float = 0.0
var silence_timer: float = 0.0
var root_timer: float = 0.0
var poise: float = 60.0
var max_poise: float = 60.0
var stagger_immunity: float = 0.0
var _since_poise_hit: float = 99.0
var dots := DotTracker.new()
## Resistencias por tipo de daño (DamageSystem.Type → fracción).
var resist: Dictionary = {}


func _init(p_world: Object = null, p_position: Vector2 = Vector2.ZERO, p_auto_attack: bool = true) -> void:
	world = p_world
	position = p_position
	spawn_position = p_position
	auto_attack = p_auto_attack


func step(tick_number: int, delta: float, warrior: Object) -> void:
	_tick_effects(delta)

	if not alive:
		state_time += delta
		if state_time >= RESPAWN_SECONDS:
			revive()
		return

	if hit_flash_ticks > 0:
		hit_flash_ticks -= 1

	if knock_timer > 0.0:
		knock_timer -= delta
		position = world.resolve_position(position + knock_vel * delta, radius, self)

	if warrior != null and warrior.alive and not warrior.is_invisible():
		facing = (warrior.position - position).normalized()

	cooldown = maxf(0.0, cooldown - delta)

	if not auto_attack or stun_timer > 0.0:
		return

	var speed := slow_factor if slow_timer > 0.0 else 1.0

	match state:
		State.IDLE:
			_idle_decision(warrior)
		State.TELEGRAPH:
			state_time += delta * speed
			if state_time >= telegraph_seconds:
				_resolve_attack(warrior)
		State.RECOVER:
			state_time += delta * speed
			if state_time >= recover_seconds:
				state = State.IDLE
				state_time = 0.0
		_:
			pass


func _tick_effects(delta: float) -> void:
	root_timer = maxf(0.0, root_timer - delta)
	silence_timer = maxf(0.0, silence_timer - delta)
	stagger_immunity = maxf(0.0, stagger_immunity - delta)
	_since_poise_hit += delta
	if _since_poise_hit > 3.0 and poise < max_poise:
		poise = minf(max_poise, poise + 20.0 * delta)
	cc.tick(delta)
	for hit: Dictionary in dots.tick(delta):
		take_damage(float(hit["amount"]), position, {DamageSystem.KEY: int(hit["type"]), "tick": true})
		dot_damage.emit(float(hit["amount"]), hit)
	if interrupted_timer > 0.0:
		interrupted_timer = maxf(0.0, interrupted_timer - delta)
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			slow_factor = 1.0
	if vulnerable_timer > 0.0:
		vulnerable_timer = maxf(0.0, vulnerable_timer - delta)
		if vulnerable_timer <= 0.0:
			vulnerable_amount = 0.0


## Qué hace el muñeco en reposo (EnemySim lo sustituye por su IA).
func _idle_decision(warrior: Object) -> void:
	if warrior != null and warrior.alive and not warrior.is_invisible() and cooldown <= 0.0:
		if position.distance_to(warrior.position) <= ATTACK_RANGE:
			_start_telegraph()


## Empieza un ataque con telegraph. `attack` puede traer: name, range, arc (360 =
## círculo), mult, seconds, recover y effects.
func _start_telegraph(attack: Dictionary = {}) -> void:
	state = State.TELEGRAPH
	state_time = 0.0
	attack_direction = facing
	attack_name = String(attack.get("name", "heavy"))
	attack_range = float(attack.get("range", ATTACK_RANGE))
	attack_arc = float(attack.get("arc", ATTACK_ARC))
	attack_mult = float(attack.get("mult", 1.0))
	telegraph_seconds = float(attack.get("seconds", TELEGRAPH_SECONDS))
	recover_seconds = float(attack.get("recover", RECOVER_SECONDS))
	attack_effects = attack.get("effects", {})
	telegraph_started.emit(attack_direction, attack_range, attack_arc)


func _resolve_attack(warrior: Object) -> void:
	state = State.RECOVER
	state_time = 0.0
	cooldown = COOLDOWN_SECONDS
	_strike(warrior, attack_direction, attack_range, attack_arc, attack_damage * attack_mult, attack_effects)


## Golpe en volumen: alcance horizontal + arco (360 = círculo) + altura. Devuelve
## true si hizo daño. Gestiona el parry del jugador y la voltereta (en take_damage).
func _strike(warrior: Object, direction: Vector2, reach: float, arc: float, damage: float, effects: Dictionary = {}) -> bool:
	if warrior == null or not warrior.alive or warrior.is_invisible():
		attack_missed.emit()
		return false

	var to_target: Vector2 = warrior.position - position
	if float(warrior.get("height")) > HIT_HEIGHT or to_target.length() > reach + TARGET_RADIUS:
		attack_missed.emit()
		return false

	if arc < 359.0:
		var angle_degrees := rad_to_deg(direction.angle_to(to_target))
		if absf(angle_degrees) > arc * 0.5:
			attack_missed.emit()
			return false

	# Parry del Warrior: desvía el ataque y contraataca.
	if warrior.is_parrying():
		var parry_time: float = float(warrior.state_time)
		var parry_window: float = float(warrior.parry_window_end_time())
		var in_window: bool = parry_time <= parry_window
		var facing_warrior: Vector2 = (position - warrior.position).normalized() as Vector2
		var facing_ok: bool = absf(direction.dot(facing_warrior)) > 0.5
		if in_window and facing_ok:
			warrior.parry_trigger(true)
			attack_missed.emit()
			return false

	var fx := effects.duplicate()
	if not fx.has("poise"):
		fx["poise"] = 20.0
	fx["attacker"] = self
	var dealt: float = warrior.take_damage(damage, position, fx)
	if dealt <= 0.0:
		attack_missed.emit()
		return false
	attack_landed.emit(dealt)
	return true


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, effects: Dictionary = {}) -> float:
	if not alive or amount <= 0.0:
		return 0.0

	var incoming := DamageSystem.mitigate(amount, DamageSystem.type_of(effects), resist)
	if vulnerable_timer > 0.0:
		incoming *= 1.0 + vulnerable_amount

	var dealt := minf(incoming, health)
	health -= dealt
	hit_flash_ticks = 6
	health_changed.emit(health, max_health)
	hit.emit(dealt, position)

	if not effects.is_empty():
		apply_effects(effects, source_position)
		var poise_hit := float(effects.get("poise", 0.0))
		if poise_hit > 0.0 and DamageSystem.type_of(effects) == DamageSystem.Type.PHYSICAL and health > 0.0:
			_lose_poise(poise_hit)

	if health <= 0.0:
		health = 0.0
		alive = false
		state = State.DEAD
		state_time = 0.0
		died.emit()
	return dealt


func apply_effects(effects: Dictionary, source: Vector2 = Vector2.ZERO) -> void:
	var mark := float(effects.get("mark", 0.0))
	if mark > 0.0:
		vulnerable_amount = 0.25  # marcado: +25% de daño recibido
		vulnerable_timer = maxf(vulnerable_timer, mark)
		effect_applied.emit("vulnerable", mark)
	var root := float(effects.get("root", 0.0))
	if root > 0.0:
		var applied := cc.apply("root", root)
		if applied > 0.0:
			root_timer = maxf(root_timer, applied)
			effect_applied.emit("root", applied)
	var silence := float(effects.get("silence", 0.0))
	if silence > 0.0:
		silence_timer = maxf(silence_timer, silence)
		effect_applied.emit("silence", silence)
	var pull := float(effects.get("pull", 0.0))
	if pull > 0.0 and source != Vector2.ZERO:
		var to_source := source - position
		var travel := minf(pull, maxf(to_source.length() - 70.0, 0.0))
		knock_vel = to_source.normalized() * (travel / 0.18)
		knock_timer = 0.18
		interrupt()
	var knockback := float(effects.get("knockback", 0.0))
	if knockback > 0.0 and source != Vector2.ZERO:
		knock_vel = (position - source).normalized() * (knockback / 0.18)
		knock_timer = 0.18
		interrupt()
	var slow: Dictionary = effects.get("slow", {})
	if not slow.is_empty():
		slow_factor = clampf(float(slow.get("factor", 0.6)), 0.1, 1.0)
		slow_timer = float(slow.get("duration", 1.0))
		effect_applied.emit("slow", slow_timer)

	var vulnerable: Dictionary = effects.get("vulnerable", {})
	if not vulnerable.is_empty():
		vulnerable_amount = float(vulnerable.get("amount", 0.2))
		vulnerable_timer = float(vulnerable.get("duration", 5.0))
		effect_applied.emit("vulnerable", vulnerable_timer)

	if bool(effects.get("interrupt", false)):
		interrupt()

	var dot: Dictionary = effects.get("dot", {})
	if not dot.is_empty():
		dots.add(int(dot.get(DamageSystem.KEY, DamageSystem.Type.POISON)), float(dot.get("dps", 5.0)), float(dot.get("duration", 5.0)), int(dot.get("stacks", 1)), {"skill_id": dot.get("skill_id", ""), "src": dot.get("src", null)})

	var stun := cc.apply("stun", float(effects.get("stun", 0.0))) if effects.has("stun") else 0.0
	if stun > 0.0:
		stun_timer = maxf(stun_timer, stun)
		interrupt()
		effect_applied.emit("stun", stun)


func _lose_poise(amount: float) -> void:
	if amount <= 0.0 or stagger_immunity > 0.0 or not alive:
		return
	poise -= amount
	_since_poise_hit = 0.0
	if poise <= 0.0:
		_stagger(0.9)


func _stagger(seconds: float) -> void:
	poise = max_poise
	stagger_immunity = seconds + 3.0
	stun_timer = maxf(stun_timer, seconds)
	interrupt()
	staggered.emit(seconds)
	effect_applied.emit("stagger", seconds)


func break_poise() -> void:
	if alive:
		_stagger(1.3)


func interrupt() -> void:
	interrupted_timer = 0.5
	if state == State.TELEGRAPH:
		state = State.IDLE
		state_time = 0.0
		cooldown = maxf(cooldown, 1.2)
		interrupted.emit()


func revive() -> void:
	alive = true
	health = max_health
	state = State.IDLE
	state_time = 0.0
	cooldown = 1.0
	hit_flash_ticks = 0
	slow_factor = 1.0
	slow_timer = 0.0
	vulnerable_amount = 0.0
	vulnerable_timer = 0.0
	interrupted_timer = 0.0
	stun_timer = 0.0
	knock_timer = 0.0
	poise = max_poise
	stagger_immunity = 0.0
	cc.reset()
	dots.clear()
	health_changed.emit(health, max_health)
	revived.emit()


func telegraph_progress() -> float:
	if state != State.TELEGRAPH:
		return 0.0
	var speed := slow_factor if slow_timer > 0.0 else 1.0
	return clampf(state_time / maxf(telegraph_seconds / maxf(speed, 0.1), 0.001), 0.0, 1.0)


func is_telegraphing() -> bool:
	return state == State.TELEGRAPH


func is_slowed() -> bool:
	return slow_timer > 0.0


func is_vulnerable() -> bool:
	return vulnerable_timer > 0.0


func snapshot() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"health": health,
		"max_health": max_health,
		"alive": alive,
		"state": state,
		"telegraph": telegraph_progress(),
		"slow": slow_timer,
		"vulnerable": vulnerable_timer,
		"interrupted": interrupted_timer,
		"stun": stun_timer,
	}
