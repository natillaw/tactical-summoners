## WarriorSim — simulación determinista del Warrior de Combat Tower.
##
## Solo cambia dentro de step(), que llama CombatWorld una vez por tick fijo.
## La presentación lee sus campos y escucha sus señales; nunca escribe estado.
##
## El kit vive en WarriorKit. Esta clase interpreta los tipos de cast
## (`melee`, `line`, `aoe`, `dash`, `counter`) y mantiene Rage, carga de
## Ultimate, cooldowns por habilidad, combo de M1, parry y Last Stand.
class_name WarriorSim
extends RefCounted

signal health_changed(current: float, maximum: float)
signal rage_changed(current: float, maximum: float)
signal ultimate_changed(current: float, maximum: float)
signal attack_started(skill: Dictionary, direction: Vector2)
signal attack_state_changed(state: int)
signal attack_hit(skill: Dictionary, target: Object, damage: float, critical: bool, position: Vector2)
signal attack_finished(skill: Dictionary)
signal weapon_changed(item: Item)
signal jumped()
signal landed()
signal damage_taken(amount: float, source_position: Vector2, is_dot: bool)
signal died()
signal cast_event(event: String, skill: Dictionary, at: Vector2, direction: Vector2)
signal parry_success(skill: Dictionary, source_position: Vector2)
signal evaded(amount: float)
signal last_stand_changed(active: bool, seconds_left: float)
signal loadout_changed(loadout: Dictionary)
signal stunned(seconds: float)

enum AttackState { IDLE, WINDUP, ACTIVE, RECOVERY }

const RADIUS := 14.0
const MOVE_SPEED := 168.0
const ACCELERATION := 1500.0
const FRICTION := 2100.0
const MAX_HEALTH := 300.0

const BUFFER_SECONDS := 0.22
const BASE_CRIT := 0.05
## Velocidad normalizada (WoW Classic para golpes instantáneos): el ritmo de las
## skills no depende del arma, así que el daño por golpe se normaliza a esta
## velocidad. Así una daga no es peor que un hacha: difieren en dispersión y rasgo.
const NORMALIZED_SPEED := 2.6
## Salto (altura en píxeles de sim; 40 px = 1 m).
const JUMP_VELOCITY := 520.0
const GRAVITY := 2200.0

const RAGE_ON_HIT_TAKEN := 5.0
const ULTIMATE_ON_HIT := 8.0
const ULTIMATE_ON_DAMAGE_TAKEN := 5.0

var world: Object = null

var position: Vector2 = Vector2(480, 380)
var spawn_position: Vector2 = Vector2(480, 380)
var velocity: Vector2 = Vector2.ZERO
var move_input: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT

## Progresión y equipo: el daño sale del arma (min–max) + Fuerza/AP, como WoW Classic.
var progression := Progression.new()
var weapon: Item = ItemFactory.starter_sword()
var stats := CharacterStats.new()
var height: float = 0.0
var stun_timer: float = 0.0
## Resistencias por tipo de daño (DamageSystem.Type → fracción).
var resist: Dictionary = {}
var vertical_velocity: float = 0.0

var max_health: float = MAX_HEALTH
var health: float = MAX_HEALTH
var alive: bool = true

var state: int = AttackState.IDLE
var state_time: float = 0.0
var current_skill: Dictionary = {}
var current_slot: String = ""
var attack_aim: Vector2 = Vector2.RIGHT

var combo_index: int = 0
var combo_timer: float = 0.0
var buffered_slot: String = ""
var buffer_timer: float = 0.0

var cooldowns: Dictionary = {}
var resource: ClassResource
var ultimate_charge: float = 0.0

var parry_active: bool = false
var parry_window_end: float = 0.0

var last_stand_active: bool = false
var last_stand_timer: float = 0.0
var last_stand_cooldown: float = 0.0

var loadout: Dictionary = WarriorKit.default_loadout()

var tick: int = 0
var last_combat_tick: int = 0

var _prev_actions: Dictionary = {}
var _m1_held: bool = false
var _dash_remaining: float = 0.0
var _dash_impact_done: bool = false
var _hit_targets: Dictionary = {}
var _parry_countered: bool = false
var _spin_tick: float = 0.0
var _rng: RandomNumberGenerator


func _init(p_world: Object = null) -> void:
	world = p_world
	resource = WarriorKit.create_rage_resource()
	_rng = RandomNumberGenerator.new()
	if world != null and world.get("rng") != null:
		_rng.seed = int(world.rng.seed)
	else:
		_rng.seed = 1337
	position = Vector2(480, 380)
	spawn_position = position
	progression.leveled_up.connect(func(_l: int) -> void: recompute_stats(true))
	recompute_stats(false)
	reset(position)


## Recalcula stats desde nivel + arma. Con `heal` rellena la vida (al subir de nivel).
func recompute_stats(heal: bool) -> void:
	var gear: Dictionary = weapon.stats if weapon != null else {}
	stats = CharacterStats.new()
	stats.set_base_stat(&"strength", Progression.strength_for(progression.level) + float(gear.get("strength", 0.0)))
	stats.set_base_stat(&"attack_power_bonus", float(gear.get("attack_power_bonus", 0.0)))
	var sword_bonus := 0.03 if weapon != null and weapon.weapon_type == "sword" else 0.0
	stats.set_base_stat(&"crit_chance", BASE_CRIT + float(gear.get("crit_chance", 0.0)) + sword_bonus)
	stats.set_base_stat(&"weapon_min", weapon.weapon_min if weapon != null else 1.0)
	stats.set_base_stat(&"weapon_max", weapon.weapon_max if weapon != null else 2.0)
	stats.set_base_stat(&"weapon_speed", weapon.weapon_speed if weapon != null else 2.0)
	var ratio := health / maxf(max_health, 1.0)
	max_health = Progression.health_for(progression.level) + float(gear.get("stamina", 0.0)) * 10.0
	health = max_health if heal else clampf(ratio, 0.0, 1.0) * max_health
	health_changed.emit(health, max_health)


## Daño base de un golpe: tirada del arma normalizada + AP/14 · velocidad normalizada.
func roll_hit() -> float:
	var speed := maxf(stats.get_stat(&"weapon_speed"), 0.1)
	var roll := _rng.randf_range(stats.get_stat(&"weapon_min"), stats.get_stat(&"weapon_max"))
	return roll * NORMALIZED_SPEED / speed + stats.get_attack_power() / 14.0 * NORMALIZED_SPEED


## Daño medio de un golpe (para UI y tests).
func average_hit() -> float:
	var speed := maxf(stats.get_stat(&"weapon_speed"), 0.1)
	var avg := (stats.get_stat(&"weapon_min") + stats.get_stat(&"weapon_max")) * 0.5
	return avg * NORMALIZED_SPEED / speed + stats.get_attack_power() / 14.0 * NORMALIZED_SPEED


func is_airborne() -> bool:
	return height > 0.0 or vertical_velocity > 0.0


func _update_jump(delta: float) -> void:
	if not is_airborne():
		return
	vertical_velocity -= GRAVITY * delta
	height += vertical_velocity * delta
	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		landed.emit()


func equip_weapon(item: Item) -> void:
	weapon = item
	recompute_stats(false)
	weapon_changed.emit(item)


func gain_xp(amount: int) -> void:
	progression.add_xp(amount)


# --- Tick -------------------------------------------------------------------


func step(tick_number: int, delta: float, input: Variant) -> void:
	tick = tick_number
	_read_input(input)
	_tick_timers(delta)

	if not alive:
		velocity = Vector2.ZERO
		return

	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		velocity = Vector2.ZERO
		_update_jump(delta)
		return

	_update_attack(delta)
	_update_movement(delta)
	_update_jump(delta)
	_update_last_stand()


func _read_input(input: Variant) -> void:
	if input == null:
		move_input = Vector2.ZERO
		_m1_held = false
		return

	move_input = _to_vec(_read_prop(input, "move_dir", Vector2.ZERO)).limit_length(1.0)
	var aim := _to_vec(_read_prop(input, "aim_dir", Vector2.RIGHT))
	if aim.length_squared() > 0.0001:
		aim_dir = aim.normalized()

	var actions: Dictionary = _read_prop(input, "actions", {})
	for slot: String in WarriorKit.SELECTABLE_SLOTS:
		var key := String(WarriorKit.ACTION_KEYS[slot])
		var pressed := bool(actions.get(key, false))
		var was := bool(_prev_actions.get(key, false))
		if pressed and not was:
			buffered_slot = slot
			buffer_timer = BUFFER_SECONDS
		_prev_actions[key] = pressed

	var jump_pressed := bool(actions.get("jump", false))
	if jump_pressed and not bool(_prev_actions.get("jump", false)) and alive and not is_airborne():
		vertical_velocity = JUMP_VELOCITY
		height = 0.001
		jumped.emit()
	_prev_actions["jump"] = jump_pressed

	var m1_pressed := bool(actions.get("m1", false))
	var m1_was := bool(_prev_actions.get("m1", false))
	if m1_pressed and not m1_was and state != AttackState.IDLE:
		buffered_slot = "M1"
		buffer_timer = BUFFER_SECONDS
	_m1_held = m1_pressed
	_prev_actions["m1"] = m1_pressed

	var m2_pressed := bool(actions.get("m2", false))
	var m2_was := bool(_prev_actions.get("m2", false))
	if m2_pressed and not m2_was:
		buffered_slot = "M2"
		buffer_timer = BUFFER_SECONDS
	_prev_actions["m2"] = m2_pressed


func _read_prop(source: Variant, key: String, fallback: Variant) -> Variant:
	if source == null:
		return fallback
	if source is Dictionary:
		var data: Dictionary = source
		return data.get(key, fallback)
	var value: Variant = source.get(key)
	return value if value != null else fallback


func _to_vec(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _tick_timers(delta: float) -> void:
	var keys: Array = cooldowns.keys().duplicate()
	for key: Variant in keys:
		var left := float(cooldowns[key]) - delta
		if left <= 0.0:
			cooldowns.erase(key)
		else:
			cooldowns[key] = left

	if buffer_timer > 0.0:
		buffer_timer = maxf(0.0, buffer_timer - delta)
		if buffer_timer <= 0.0:
			buffered_slot = ""

	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_index = 0

	last_stand_cooldown = maxf(0.0, last_stand_cooldown - delta)
	if last_stand_active:
		last_stand_timer = maxf(0.0, last_stand_timer - delta)
		if last_stand_timer <= 0.0:
			last_stand_active = false
			last_stand_changed.emit(false, 0.0)


# --- Ataques ----------------------------------------------------------------


func _update_attack(delta: float) -> void:
	if state == AttackState.IDLE:
		_try_start_attack()
		return

	state_time += delta

	match state:
		AttackState.WINDUP:
			if state_time >= float(current_skill.get("windup", 0.0)):
				_enter_active()
		AttackState.ACTIVE:
			_update_active(delta)
			if state_time >= float(current_skill.get("active", 0.1)):
				_enter_recovery()
		AttackState.RECOVERY:
			if state_time >= float(current_skill.get("recovery", 0.0)):
				_finish_attack()
		_:
			pass


func _try_start_attack() -> void:
	if not buffered_slot.is_empty():
		if _can_start(buffered_slot):
			var slot := buffered_slot
			buffered_slot = ""
			buffer_timer = 0.0
			_start_ability(slot)
			return
		if buffer_timer <= 0.0:
			buffered_slot = ""

	if _m1_held and _can_start("M1"):
		_start_ability("M1")


func _can_start(slot: String) -> bool:
	var ability := ability_for_slot(slot)
	if ability.is_empty():
		return false
	if cooldown_left(slot) > 0.0:
		return false
	return _can_afford(ability)


func _can_afford(ability: Dictionary) -> bool:
	var cost := float(ability.get("cost", 0.0))
	if rage() + 0.001 < cost:
		return false
	if String(ability.get("kind", "")) == "ultimate":
		return ultimate_charge + 0.001 >= float(ability.get("charge", WarriorKit.ULTIMATE_COST))
	return true


func _start_ability(slot: String) -> bool:
	if state != AttackState.IDLE or not alive:
		return false
	var ability := ability_for_slot(slot)
	if ability.is_empty() or not _can_afford(ability):
		return false

	if String(ability.get("kind", "")) == "ultimate":
		ultimate_charge = maxf(0.0, ultimate_charge - float(ability.get("charge", 100.0)))
		ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_COST)
	_spend_rage(float(ability.get("cost", 0.0)))

	current_skill = ability
	current_slot = slot
	attack_aim = aim_dir
	state = AttackState.WINDUP
	state_time = 0.0
	_hit_targets.clear()
	_dash_remaining = float(ability.get("distance", 0.0))
	_dash_impact_done = false
	_parry_countered = false
	parry_active = false
	parry_window_end = 0.0
	_spin_tick = 0.0

	if slot == "M1":
		if combo_timer > 0.0 and combo_index < 2:
			combo_index += 1
		else:
			combo_index = 0

	# M1 no tiene cooldown: solo lo limita su propia animación.
	if slot != "M1":
		cooldowns[String(ability["id"])] = cooldown_total(slot)

	attack_state_changed.emit(state)
	attack_started.emit(current_skill, attack_aim)
	cast_event.emit("cast_start", current_skill, position, attack_aim)
	return true


func _enter_active() -> void:
	state = AttackState.ACTIVE
	state_time -= float(current_skill.get("windup", 0.0))
	attack_state_changed.emit(state)

	var cast := String(current_skill.get("cast", "melee"))
	match cast:
		"dash":
			cast_event.emit("dash_start", current_skill, position, attack_aim)
		"counter":
			parry_active = true
			parry_window_end = float(current_skill.get("active", 0.45))
			cast_event.emit("parry_stance", current_skill, position, attack_aim)
		"aoe":
			if String(current_skill.get("id", "")) == "bladestorm":
				cast_event.emit("spin_start", current_skill, position, attack_aim)
				_damage_area(
					position,
					float(current_skill.get("radius", 100.0)),
					_current_multiplier(),
					_effects(),
					1.0
				)
			else:
				cast_event.emit("slam", current_skill, position, attack_aim)
				_damage_area(
					position,
					float(current_skill.get("radius", 100.0)),
					_current_multiplier(),
					_effects(),
					1.0
				)
		"line":
			_damage_line(
				float(current_skill.get("range", 100.0)),
				float(current_skill.get("width", 30.0)),
				_current_multiplier(),
				_effects()
			)
		_:
			_damage_melee(
				float(current_skill.get("range", 80.0)),
				float(current_skill.get("arc", 110.0)),
				_current_multiplier(),
				_effects()
			)


func _update_active(delta: float) -> void:
	var cast := String(current_skill.get("cast", "melee"))
	if cast == "dash":
		_update_dash(delta)
	elif String(current_skill.get("id", "")) == "bladestorm":
		_spin_tick += delta
		var interval := maxf(float(current_skill.get("damage_interval", 0.2)), 0.05)
		while _spin_tick >= interval:
			_spin_tick -= interval
			_hit_targets.clear()
			_damage_area(
				position,
				float(current_skill.get("radius", 100.0)),
				_current_multiplier(),
				_effects(),
				1.0
			)
			cast_event.emit("aoe_tick", current_skill, position, attack_aim)


func _enter_recovery() -> void:
	state = AttackState.RECOVERY
	state_time -= float(current_skill.get("active", 0.1))
	parry_active = false
	parry_window_end = 0.0
	if String(current_skill.get("id", "")) == "bladestorm":
		cast_event.emit("spin_end", current_skill, position, attack_aim)
	attack_state_changed.emit(state)


func _finish_attack() -> void:
	var finished := current_skill
	# La ventana del combo corre desde que acaba el golpe (antes solo se armaba al
	# conectar, así que fallar reiniciaba siempre al primer golpe: un solo ataque).
	if String(finished.get("slot", "")) == "M1":
		combo_timer = float(finished.get("combo_reset_window", 0.85))
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	current_slot = ""
	parry_active = false
	parry_window_end = 0.0
	_dash_remaining = 0.0
	_dash_impact_done = false
	_hit_targets.clear()
	attack_state_changed.emit(state)
	attack_finished.emit(finished)


func _update_dash(delta: float) -> void:
	if _dash_remaining <= 0.0:
		return
	var active_time := maxf(float(current_skill.get("active", 0.2)), 0.001)
	var distance := float(current_skill.get("distance", 0.0))
	var step := minf(distance / active_time * delta, _dash_remaining)
	if step <= 0.0:
		return
	var desired := position + attack_aim * step
	position = world.resolve_position(desired, RADIUS) if world != null else desired
	_dash_remaining = maxf(0.0, _dash_remaining - step)

	if float(current_skill.get("damage_mult", 0.0)) > 0.0:
		var radius := float(current_skill.get("radius", 40.0))
		var hits := _damage_area(position, radius, _current_multiplier(), _effects(), 1.0, 1)
		if hits > 0 and not _dash_impact_done:
			_dash_impact_done = true
			cast_event.emit("dash_impact", current_skill, position, attack_aim)


func _current_multiplier() -> float:
	var raw: Variant = current_skill.get("damage_mult", 1.0)
	var mult := 1.0
	if raw is Array:
		var values: Array = raw
		if values.is_empty():
			mult = 1.0
		else:
			mult = float(values[clampi(combo_index, 0, values.size() - 1)])
	else:
		mult = float(raw)
	if last_stand_active:
		mult *= float(WarriorKit.PASSIVE.get("damage_bonus", 1.5))
	return mult


func _effects() -> Dictionary:
	var effects: Dictionary = current_skill.get("effects", {})
	return effects


# --- Daño -------------------------------------------------------------------


func _living_targets() -> Array:
	if world == null:
		return []
	return world.get_living_dummies()


func _damage_melee(range_value: float, arc: float, mult: float, effects: Dictionary) -> int:
	var count := 0
	for target: Object in _living_targets():
		if _hit_targets.has(target):
			continue
		var to_target: Vector2 = target.position - position
		var distance := to_target.length()
		if distance <= 0.001 or distance > range_value + float(target.radius):
			continue
		if absf(rad_to_deg(attack_aim.angle_to(to_target))) > arc * 0.5:
			continue
		_hit_target(target, mult, effects)
		count += 1
	return count


func _damage_line(range_value: float, width: float, mult: float, effects: Dictionary) -> int:
	var count := 0
	for target: Object in _living_targets():
		if _hit_targets.has(target):
			continue
		var to_target: Vector2 = target.position - position
		var forward := to_target.dot(attack_aim)
		if forward < 0.0 or forward > range_value + float(target.radius):
			continue
		var lateral := absf(to_target.cross(attack_aim))
		if lateral > width * 0.5 + float(target.radius):
			continue
		_hit_target(target, mult, effects)
		count += 1
	return count


func _damage_area(center: Vector2, radius: float, mult: float, effects: Dictionary, falloff: float = 1.0, max_targets: int = 0) -> int:
	if radius <= 0.0:
		return 0
	var count := 0
	for target: Object in _living_targets():
		if _hit_targets.has(target):
			continue
		var distance: float = center.distance_to(target.position)
		if distance > radius + float(target.radius):
			continue
		if max_targets > 0 and count >= max_targets:
			break
		var ratio := clampf(distance / maxf(radius, 0.001), 0.0, 1.0)
		_hit_target(target, mult * lerpf(1.0, falloff, ratio), effects)
		count += 1
	return count


func _hit_target(target: Object, mult: float, effects: Dictionary) -> void:
	_hit_targets[target] = true

	var type := DamageSystem.type_of(current_skill)
	var result := DamageSystem.roll(roll_hit(), mult, stats.get_crit_chance(), type, _rng)
	var damage: float = result["amount"]
	var critical: bool = result["critical"]
	var fx := effects.duplicate()
	fx[DamageSystem.KEY] = type

	var dealt: float = target.take_damage(damage, position, fx)
	if dealt <= 0.0:
		return

	_gain_rage(float(current_skill.get("rage_gain", 0.0)))
	_gain_ultimate(ULTIMATE_ON_HIT)
	combo_timer = float(current_skill.get("combo_reset_window", 0.85))
	last_combat_tick = tick
	attack_hit.emit(current_skill, target, dealt, critical, target.position)


func _resolve_parry_counter() -> void:
	if current_skill.is_empty():
		return
	var mult := float(current_skill.get("counter_mult", 1.8))
	if last_stand_active:
		mult *= float(WarriorKit.PASSIVE.get("damage_bonus", 1.5))
	var effects: Dictionary = current_skill.get("counter_effects", {})
	var radius := float(current_skill.get("counter_radius", 0.0))
	if radius > 0.0:
		_damage_area(position, radius, mult, effects, 1.0)
	else:
		_damage_melee(
			float(current_skill.get("counter_range", 90.0)),
			float(current_skill.get("counter_arc", 120.0)),
			mult,
			effects
		)
	cast_event.emit("parry_success", current_skill, position + attack_aim * 24.0, attack_aim)


func _resolve_pending_parry() -> void:
	if _parry_countered or current_skill.is_empty():
		return
	_parry_countered = true
	parry_active = false
	_resolve_parry_counter()


# --- Movimiento -------------------------------------------------------------


func _update_movement(delta: float) -> void:
	if state == AttackState.ACTIVE and String(current_skill.get("cast", "")) == "dash":
		velocity = Vector2.ZERO
		return

	var factor := 1.0
	if state != AttackState.IDLE:
		factor = float(current_skill.get("move_factor", 0.25))
		if state == AttackState.ACTIVE:
			factor *= 0.5
	if last_stand_active:
		factor *= float(WarriorKit.PASSIVE.get("speed_bonus", 1.25))

	var desired := move_input * MOVE_SPEED * factor
	var rate := ACCELERATION if move_input.length_squared() > 0.0001 else FRICTION
	velocity = velocity.move_toward(desired, rate * delta)
	if velocity.length_squared() < 0.01:
		velocity = Vector2.ZERO
	position += velocity * delta
	if world != null:
		position = world.resolve_position(position, RADIUS)


# --- Rage / Ultimate --------------------------------------------------------


func _gain_rage(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := resource.get_current()
	resource.generate(amount)
	if not is_equal_approx(before, resource.get_current()):
		rage_changed.emit(resource.get_current(), resource.max_amount)


func _spend_rage(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := resource.get_current()
	resource.current_amount = maxf(0.0, before - amount)
	if not is_equal_approx(before, resource.get_current()):
		rage_changed.emit(resource.get_current(), resource.max_amount)


func _gain_ultimate(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := ultimate_charge
	ultimate_charge = minf(WarriorKit.ULTIMATE_COST, ultimate_charge + amount)
	if not is_equal_approx(before, ultimate_charge):
		ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_COST)


# --- Pasiva -----------------------------------------------------------------


func _update_last_stand() -> void:
	if not alive:
		return
	if last_stand_active or last_stand_cooldown > 0.0:
		return
	var ratio := health / maxf(max_health, 1.0)
	if ratio <= float(WarriorKit.PASSIVE.get("threshold", 0.3)):
		last_stand_active = true
		last_stand_timer = float(WarriorKit.PASSIVE.get("duration", 5.0))
		last_stand_cooldown = float(WarriorKit.PASSIVE.get("cooldown", 10.0))
		last_stand_changed.emit(true, last_stand_timer)


func is_last_stand_active() -> bool:
	return last_stand_active


func last_stand_seconds_left() -> float:
	return last_stand_timer


# --- Daño recibido ----------------------------------------------------------


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, effects: Dictionary = {}) -> float:
	if not alive or amount <= 0.0:
		return 0.0

	if parry_active and not _parry_countered and _is_frontal(source_position):
		_resolve_pending_parry()
		parry_success.emit(current_skill, source_position)
		return 0.0

	if _is_evading():
		evaded.emit(amount)
		return 0.0

	amount = DamageSystem.mitigate(amount, DamageSystem.type_of(effects), resist)
	var dealt := minf(amount, health)
	health -= dealt
	_gain_rage(RAGE_ON_HIT_TAKEN)
	_gain_ultimate(ULTIMATE_ON_DAMAGE_TAKEN)
	last_combat_tick = tick

	health_changed.emit(health, max_health)
	damage_taken.emit(dealt, source_position, false)

	var stun := float(effects.get("stun", 0.0))
	if stun > 0.0 and health > 0.0:
		_apply_stun(stun)

	if health <= 0.0:
		health = 0.0
		alive = false
		state = AttackState.IDLE
		current_skill = {}
		current_slot = ""
		parry_active = false
		velocity = Vector2.ZERO
		died.emit()

	return dealt


## Aturdimiento (Charge enemigo): cancela el ataque en curso y bloquea el control.
func _apply_stun(seconds: float) -> void:
	stun_timer = maxf(stun_timer, seconds)
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	current_slot = ""
	parry_active = false
	parry_window_end = 0.0
	_dash_remaining = 0.0
	buffered_slot = ""
	buffer_timer = 0.0
	velocity = Vector2.ZERO
	attack_state_changed.emit(state)
	stunned.emit(seconds)


func is_stunned() -> bool:
	return stun_timer > 0.0


func _is_evading() -> bool:
	if state != AttackState.ACTIVE:
		return false
	if String(current_skill.get("cast", "")) != "dash":
		return false
	return bool(current_skill.get("evade", false))


func _is_frontal(source_position: Vector2) -> bool:
	if source_position == Vector2.ZERO:
		return true
	var to_source := source_position - position
	if to_source.length_squared() < 0.0001:
		return true
	return absf(rad_to_deg(attack_aim.angle_to(to_source))) <= 90.0


func is_parrying() -> bool:
	return parry_active


func parry_window_end_time() -> float:
	return parry_window_end


## Llamado por el atacante cuando su golpe es desviado.
func parry_trigger(success: bool) -> void:
	if not success or _parry_countered:
		return
	_resolve_pending_parry()
	parry_success.emit(current_skill, position)


# --- Loadout ----------------------------------------------------------------


func ability_for_slot(slot: String) -> Dictionary:
	if slot == "M1":
		return WarriorKit.M1.duplicate(true)
	if slot == "M2":
		return WarriorKit.M2.duplicate(true)
	var id := StringName(String(loadout.get(slot, "")))
	if id == &"":
		return {}
	return WarriorKit.ability_by_id(id)


func ability_name_for_slot(slot: String) -> String:
	var ability := ability_for_slot(slot)
	return String(ability.get("name", ""))


func ability_short_for_slot(slot: String) -> String:
	var ability := ability_for_slot(slot)
	return String(ability.get("short", ability.get("name", "")))


func set_loadout(new_loadout: Dictionary) -> void:
	loadout = WarriorKit.sanitize_loadout(new_loadout)
	buffered_slot = ""
	buffer_timer = 0.0
	loadout_changed.emit(loadout_to_strings())


func assign_slot(slot: StringName, ability_id: StringName) -> void:
	var slot_name := String(slot)
	if not WarriorKit.SELECTABLE_SLOTS.has(slot_name):
		return
	if not WarriorKit.pool_ids().has(ability_id):
		return
	loadout[slot_name] = ability_id
	loadout_changed.emit(loadout_to_strings())


func loadout_to_strings() -> Dictionary:
	return WarriorKit.loadout_to_strings(loadout)


# --- Consultas --------------------------------------------------------------


func cooldown_left(slot: String) -> float:
	var ability := ability_for_slot(slot)
	if ability.is_empty():
		return 0.0
	return float(cooldowns.get(String(ability["id"]), 0.0))


func cooldown_total(slot: String) -> float:
	var ability := ability_for_slot(slot)
	if ability.is_empty():
		return 0.0
	return float(ability.get("windup", 0.0)) + float(ability.get("active", 0.0)) + float(ability.get("recovery", 0.0)) + float(ability.get("cooldown", 0.0))


func is_attacking() -> bool:
	return state != AttackState.IDLE


func rage() -> float:
	return resource.get_current()


func rage_max() -> float:
	return resource.max_amount


func ultimate() -> float:
	return ultimate_charge


func ultimate_is_full() -> bool:
	return ultimate_charge >= WarriorKit.ULTIMATE_COST


func current_move_speed_multiplier() -> float:
	var mult := 1.0
	if last_stand_active:
		mult *= float(WarriorKit.PASSIVE.get("speed_bonus", 1.25))
	return mult


func debug_refill() -> void:
	resource.current_amount = WarriorKit.MAX_RAGE
	ultimate_charge = WarriorKit.ULTIMATE_COST
	cooldowns.clear()
	rage_changed.emit(resource.get_current(), resource.max_amount)
	ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_COST)


# --- Reset / snapshot -------------------------------------------------------


func reset(spawn: Vector2 = Vector2(480, 380)) -> void:
	position = spawn
	spawn_position = spawn
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	aim_dir = Vector2.RIGHT
	health = max_health
	alive = true
	height = 0.0
	vertical_velocity = 0.0
	stun_timer = 0.0
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	current_slot = ""
	attack_aim = Vector2.RIGHT
	combo_index = 0
	combo_timer = 0.0
	buffered_slot = ""
	buffer_timer = 0.0
	cooldowns.clear()
	ultimate_charge = 0.0
	parry_active = false
	parry_window_end = 0.0
	last_stand_active = false
	last_stand_timer = 0.0
	last_stand_cooldown = 0.0
	_dash_remaining = 0.0
	_dash_impact_done = false
	_hit_targets.clear()
	_parry_countered = false
	_spin_tick = 0.0
	_prev_actions.clear()
	_m1_held = false
	last_combat_tick = 0
	resource.current_amount = 0.0

	health_changed.emit(health, max_health)
	rage_changed.emit(resource.get_current(), resource.max_amount)
	ultimate_changed.emit(ultimate_charge, WarriorKit.ULTIMATE_COST)
	attack_state_changed.emit(state)
	loadout_changed.emit(loadout_to_strings())


func revive() -> void:
	health = max_health
	alive = true
	state = AttackState.IDLE
	state_time = 0.0
	current_skill = {}
	current_slot = ""
	parry_active = false
	velocity = Vector2.ZERO
	health_changed.emit(health, max_health)


func snapshot() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"aim": [aim_dir.x, aim_dir.y],
		"height": height,
		"health": health,
		"max_health": max_health,
		"rage": resource.get_current(),
		"max_rage": resource.max_amount,
		"ultimate": ultimate_charge,
		"ultimate_max": WarriorKit.ULTIMATE_COST,
		"state": state,
		"attack_state": state,
		"alive": alive,
		"vengeful": last_stand_active,
		"combo_index": combo_index,
		"combo_timer": combo_timer,
		"last_stand": last_stand_active,
		"last_stand_timer": last_stand_timer,
		"last_stand_cooldown": last_stand_cooldown,
		"cooldowns": cooldowns.duplicate(),
		"loadout": loadout_to_strings(),
		"casting": {
			"slot": current_slot,
			"id": String(current_skill.get("id", "")),
			"cast": String(current_skill.get("cast", "")),
		},
	}
