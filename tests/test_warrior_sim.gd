## Test headless de la simulación del Warrior de Combat Tower (game/sim).
##
##   godot --headless --path . --script tests/test_warrior_sim.gd
##
## No abre ventana ni escena: crea CombatWorld, le inyecta InputMessage y
## avanza ticks fijos, exactamente como lo hará el servidor autoritativo.
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const WarriorKitScript: GDScript = preload("res://combat/warrior_kit.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior_sim (Combat Tower) ==")

	_test_heavy_strikes()
	_test_piercing_thrust()
	_test_basic_damage_order()
	_test_combat_roll()
	_test_charge_hits_and_slows()
	_test_charge_miss_no_rage()
	_test_parry_deflects_and_counters()
	_test_seismic_break()
	_test_bladestorm_ultimate()
	_test_bladestorm_requires_rage()
	_test_ultimate_requires_charge()
	_test_last_stand()
	_test_rage_persists()
	_test_death_and_reset()
	_test_cooldown_blocks_recast()
	_test_loadout_affects_casts()
	_test_debug_refill()
	_test_dummy_telegraph_and_respawn()
	_test_determinism()
	_test_snapshot()
	_test_collision()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Habilidades ------------------------------------------------------------


func _test_heavy_strikes() -> void:
	var world := _make_world(false, 11)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	var starts: Array = [0]
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	world.warrior.attack_started.connect(func(_skill: Dictionary, _dir: Vector2) -> void:
		starts[0] += 1
	)

	_step(world, 40, _input(Vector2(0, -1), true, false))

	_check(starts[0] >= 1, "Heavy Strikes inicia el ataque")
	_check(hits.size() >= 1, "Heavy Strikes conecta al menos un golpe")
	_check(dummy.health < dummy.max_health, "Heavy Strikes aplica daño real al dummy")
	_check(world.warrior.rage() > 0.0, "Heavy Strikes genera Rage al golpear")
	_check(world.warrior.rage() <= WarriorKitScript.MAX_RAGE, "Rage nunca supera el tope")
	if not hits.is_empty():
		_check(float(hits[0]) >= 22.0 - 0.01, "Heavy Strikes hace al menos el daño base")
	_check(world.warrior.cooldown_left("M1") > 0.0, "Heavy Strikes deja cooldown activo")


func _test_piercing_thrust() -> void:
	var world := _make_world(false, 77)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)

	_step(world, 40, _input(Vector2(0, -1), false, true))

	_check(hits.size() == 1, "Piercing Thrust conecta un único golpe en línea")
	_check(dummy.health < dummy.max_health, "Piercing Thrust aplica daño real")
	_check(world.warrior.rage() > 0.0, "Piercing Thrust genera Rage")
	if not hits.is_empty():
		_check(float(hits[0]) >= 33.0 - 0.01, "Piercing Thrust usa su multiplicador de 1.5x")
	_check(world.warrior.cooldown_left("M2") > 0.0, "Piercing Thrust deja cooldown activo")
	_check(not world.warrior._can_start("M2"), "Piercing Thrust no se puede repetir durante el cooldown")

	_step(world, 130, null)
	_check(is_zero_approx(world.warrior.cooldown_left("M2")), "el cooldown de Piercing Thrust termina")


func _test_basic_damage_order() -> void:
	var light := _first_hit("M1", 77)
	var heavy := _first_hit("M2", 77)
	_check(not light.is_empty() and not heavy.is_empty(), "ambas básicas conectan un golpe")
	if not light.is_empty() and not heavy.is_empty():
		_check(float(heavy[0]) > float(light[0]), "Piercing Thrust pega más fuerte que Heavy Strikes")


func _test_combat_roll() -> void:
	var world := _make_world(false, 5)
	var dummy: DummySim = world.dummies[0]
	var start := world.warrior.position
	world.warrior.debug_refill()
	var rage_before := world.warrior.rage()

	_step(world, 6, _input(Vector2(1, 0), false, false, Vector2.ZERO, true))
	_check(world.warrior.state == WarriorSim.AttackState.ACTIVE, "Combat Roll entra en frames activos")
	_check(world.warrior.is_attacking(), "Combat Roll se registra como ataque")

	var health_before := world.warrior.health
	var dealt := world.warrior.take_damage(50.0, dummy.position, {})
	_check(is_zero_approx(dealt), "Combat Roll evade el daño durante los iframes")
	_check(is_equal_approx(world.warrior.health, health_before), "Combat Roll no pierde vida en iframes")

	_step(world, 30, null)
	_check(world.warrior.position.distance_to(start) > 100.0, "Combat Roll desplaza al Warrior")
	_check(world.warrior.rage() <= rage_before - 15.0 + 0.01, "Combat Roll consume 15 Rage")
	_check(world.warrior.cooldown_left("SPACE") > 0.0, "Combat Roll deja cooldown activo")


func _test_charge_hits_and_slows() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var dummy: DummySim = world.add_dummy(Vector2(600, 300), false)
	var start := world.warrior.position

	_step(world, 30, _input(Vector2(1, 0), false, false, Vector2.ZERO, false, false, true))

	_check(dummy.health < dummy.max_health, "Charge impacta y daña al dummy")
	_check(dummy.is_slowed(), "Charge aplica ralentización")
	_check(world.warrior.rage() >= 20.0, "Charge genera Rage al impactar")
	_check(world.warrior.position.distance_to(start) > 80.0, "Charge desplaza al Warrior")
	_check(world.warrior.cooldown_left("E") > 0.0, "Charge deja cooldown activo")


func _test_charge_miss_no_rage() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var dummy: DummySim = world.add_dummy(Vector2(100, 100), false)
	var rage_before := world.warrior.rage()

	_step(world, 40, _input(Vector2(1, 0), false, false, Vector2.ZERO, false, false, true))

	_check(dummy.health >= dummy.max_health, "Charge sin objetivo no daña")
	_check(is_equal_approx(world.warrior.rage(), rage_before), "Charge sin impacto no genera Rage")


func _test_parry_deflects_and_counters() -> void:
	var world := _make_world(false, 21)
	var dummy: DummySim = world.dummies[0]
	var parries: Array = [0]
	world.warrior.parry_success.connect(func(_skill: Dictionary, _pos: Vector2) -> void:
		parries[0] += 1
	)
	world.warrior.debug_refill()
	var rage_before := world.warrior.rage()

	_step(world, 8, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))
	_check(world.warrior.is_parrying(), "Parry entra en postura activa")

	var health_before := world.warrior.health
	var dealt := world.warrior.take_damage(22.0, dummy.position, {})
	_check(is_zero_approx(dealt), "Parry desvía un ataque frontal")
	_check(is_equal_approx(world.warrior.health, health_before), "Parry no recibe daño al desviar")
	_check(parries[0] >= 1, "Parry emite parry_success")
	_check(dummy.health < dummy.max_health, "Parry contraataca y daña al dummy")
	_check(world.warrior.rage() <= rage_before - 20.0 + 0.01, "Parry consume 20 Rage")
	_check(world.warrior.cooldown_left("Q") > 0.0, "Parry deja cooldown activo")


func _test_seismic_break() -> void:
	var world := _make_world(false, 5)
	var dummy: DummySim = world.dummies[0]
	world.warrior.debug_refill()
	dummy.state = DummySim.State.TELEGRAPH
	dummy.state_time = 0.0
	var rage_before := world.warrior.rage()

	_step(world, 25, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true))

	_check(world.warrior.rage() <= rage_before - 30.0 + 0.01, "Seismic Break consume 30 Rage")
	_check(dummy.health < dummy.max_health, "Seismic Break daña en área")
	_check(dummy.state == DummySim.State.IDLE, "Seismic Break interrumpe el telegráfico")
	_check(dummy.interrupted_timer > 0.0, "Seismic Break marca al dummy como interrumpido")
	_check(world.warrior.cooldown_left("R") > 0.0, "Seismic Break deja cooldown activo")


func _test_bladestorm_ultimate() -> void:
	var world := _make_world(false, 5)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	world.warrior.debug_refill()
	_check(world.warrior.ultimate_is_full(), "Ultimate empieza llena tras el refill")

	_step(world, 5, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, false, true))
	_check(world.warrior.ultimate() <= 0.01, "Bladestorm gasta la carga de Ultimate al iniciar")
	_check(world.warrior.rage() <= 60.01, "Bladestorm consume 40 Rage al iniciar")
	_step(world, 115, _input(Vector2(0, -1), false, false, Vector2.ZERO))

	_check(hits.size() >= 4, "Bladestorm golpea repetidamente en área")
	_check(dummy.health < dummy.max_health, "Bladestorm daña al dummy")
	_check(world.warrior.cooldown_left("F") > 0.0, "Bladestorm deja cooldown activo")


func _test_bladestorm_requires_rage() -> void:
	var world := _make_world(false, 5)
	var starts: Array = [0]
	world.warrior.attack_started.connect(func(_skill: Dictionary, _dir: Vector2) -> void:
		starts[0] += 1
	)
	world.warrior.ultimate_charge = WarriorKitScript.ULTIMATE_COST
	_check(is_zero_approx(world.warrior.rage()), "la Rage empieza vacía")

	_step(world, 30, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, false, true))

	_check(starts[0] == 0, "Bladestorm no se puede lanzar sin Rage aunque la Ultimate esté llena")
	_check(world.warrior.state == WarriorSim.AttackState.IDLE, "el intento sin Rage no deja al Warrior casteando")


func _test_ultimate_requires_charge() -> void:
	var world := _make_world(false, 5)
	var starts: Array = [0]
	world.warrior.attack_started.connect(func(_skill: Dictionary, _dir: Vector2) -> void:
		starts[0] += 1
	)
	_check(is_zero_approx(world.warrior.ultimate()), "la Ultimate empieza vacía")

	_step(world, 30, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, false, true))

	_check(starts[0] == 0, "Bladestorm no se puede lanzar sin carga")
	_check(world.warrior.state == WarriorSim.AttackState.IDLE, "el intento fallido no deja al Warrior casteando")


func _test_last_stand() -> void:
	var world := _make_world(false, 5)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	_check(not world.warrior.is_last_stand_active(), "Last Stand inactivo al inicio")

	world.warrior.health = 10.0
	_step(world, 1, null)
	_check(world.warrior.is_last_stand_active(), "Last Stand activa a vida baja")
	_check(world.warrior.current_move_speed_multiplier() >= 1.24, "Last Stand da el bonus de velocidad")

	_step(world, 20, _input(Vector2(0, -1), true, false))
	_check(hits.size() >= 1, "Last Stand permite seguir atacando")
	if not hits.is_empty():
		_check(float(hits[0]) >= 33.0 - 0.01, "Last Stand aplica +50% de daño")
	_check(dummy.health < dummy.max_health, "el golpe potenciado daña al dummy")


func _test_rage_persists() -> void:
	var world := _make_world(false, 9)
	_step(world, 40, _input(Vector2(0, -1), true, false))
	var peak := world.warrior.rage()
	_check(peak > 0.0, "Rage se almacena tras un golpe")

	_step(world, 300, null)
	_check(world.warrior.rage() >= peak - 0.001, "Rage no decae sin gasto")


func _test_death_and_reset() -> void:
	var world := _make_world(false, 3)
	var died: Array = [false]
	world.warrior.died.connect(func() -> void:
		died[0] = true
	)

	world.warrior.take_damage(99999.0, Vector2.ZERO, {})
	_check(not world.warrior.alive, "daño letal mata al Warrior")
	_check(is_zero_approx(world.warrior.health), "la vida queda clampeada a cero")
	_check(died[0], "died se dispara")

	world.reset()
	_check(world.warrior.alive, "reset revive al Warrior")
	_check(is_equal_approx(world.warrior.health, world.warrior.max_health), "reset restaura vida plena")
	_check(is_zero_approx(world.warrior.rage()), "reset limpia Rage")
	_check(is_zero_approx(world.warrior.ultimate()), "reset limpia la Ultimate")
	_check(world.warrior.position.distance_to(world.bounds.get_center()) < 0.01, "reset vuelve al centro")


func _test_cooldown_blocks_recast() -> void:
	var world := _make_world(false, 5)
	var starts: Array = [0]
	world.warrior.attack_started.connect(func(_skill: Dictionary, _dir: Vector2) -> void:
		starts[0] += 1
	)

	_step(world, 1, _input(Vector2(0, -1), false, true))
	_step(world, 10, _input(Vector2(0, -1), false, true))
	_check(starts[0] == 1, "mantener pulsado no repite el ataque")

	_step(world, 1, _input(Vector2(0, -1), false, false))
	_step(world, 1, _input(Vector2(0, -1), false, true))
	_step(world, 10, _input(Vector2(0, -1), false, false))
	_check(starts[0] == 1, "el cooldown bloquea el recast")

	_step(world, 140, null)
	_step(world, 1, _input(Vector2(0, -1), false, true))
	_check(starts[0] == 2, "tras el cooldown el ataque vuelve a estar disponible")


func _test_loadout_affects_casts() -> void:
	var world := _make_world(false, 5)
	var start := world.warrior.position

	world.warrior.assign_slot(&"Q", &"combat_roll")
	_check(String(world.warrior.ability_for_slot("Q")["id"]) == "combat_roll", "assign_slot cambia la habilidad del slot")

	world.warrior.debug_refill()
	_step(world, 30, _input(Vector2(1, 0), false, false, Vector2.ZERO, false, true))
	_check(world.warrior.position.distance_to(start) > 100.0, "el slot reasignado ejecuta la nueva habilidad")

	world.warrior.assign_slot(&"Q", &"heavy_strikes")
	_check(String(world.warrior.ability_for_slot("Q")["id"]) == "combat_roll", "assign_slot rechaza habilidades no seleccionables")

	world.warrior.set_loadout({"SPACE": &"bogus", "Q": &"parry"})
	_check(String(world.warrior.ability_for_slot("SPACE")["id"]) == "combat_roll", "set_loadout repara ids inválidos")
	_check(String(world.warrior.ability_for_slot("Q")["id"]) == "parry", "set_loadout conserva ids válidos")


func _test_debug_refill() -> void:
	var world := _make_world(false, 5)
	_step(world, 40, _input(Vector2(0, -1), true, false))
	_check(world.warrior.cooldown_left("M1") >= 0.0, "hay un cooldown que limpiar")

	world.warrior.debug_refill()
	_check(is_equal_approx(world.warrior.rage(), WarriorKitScript.MAX_RAGE), "debug_refill llena Rage")
	_check(world.warrior.ultimate_is_full(), "debug_refill llena la Ultimate")
	_check(is_zero_approx(world.warrior.cooldown_left("M1")), "debug_refill limpia cooldowns")


# --- Mundo / determinismo ---------------------------------------------------


func _test_dummy_telegraph_and_respawn() -> void:
	var world := _make_world(true, 21)
	var dummy: DummySim = world.dummies[0]
	var telegraphs: Array = [0]
	dummy.telegraph_started.connect(func(_dir: Vector2, _radius: float, _arc: float) -> void:
		telegraphs[0] += 1
	)

	_step(world, 70, null)
	_check(telegraphs[0] >= 1, "el dummy telegrafía su ataque")
	_check(world.warrior.health < world.warrior.max_health, "el dummy lastima al Warrior")

	dummy.take_damage(99999.0)
	_check(not dummy.alive, "un dummy puede ser destruido")
	_step(world, 195, null)
	_check(dummy.alive, "el dummy resucita tras 3 s")


func _test_determinism() -> void:
	var first := _run_sequence(42)
	var second := _run_sequence(42)
	_check(JSON.stringify(first) == JSON.stringify(second), "misma seed + mismos inputs = mismo snapshot")


func _test_snapshot() -> void:
	var world := _make_world(false, 1)
	var snap: Dictionary = world.snapshot()
	_check(snap.has("tick") and snap.has("warrior") and snap.has("dummies"), "snapshot tiene secciones de red")
	var warrior: Dictionary = snap["warrior"]
	for key: String in ["position", "velocity", "aim", "health", "max_health", "rage", "max_rage", "ultimate", "ultimate_max", "state", "attack_state", "alive", "last_stand", "cooldowns", "loadout", "casting"]:
		_check(warrior.has(key), "warrior snapshot tiene %s" % key)

	var dummy: Dictionary = snap["dummies"][0]
	for key: String in ["position", "health", "max_health", "alive", "state", "telegraph"]:
		_check(dummy.has(key), "dummy snapshot tiene %s" % key)


func _test_collision() -> void:
	var world: CombatWorld = CombatWorldScript.new(1)
	world.setup_arena(Rect2(0, 0, 200, 200), [{"position": Vector2(100, 100), "radius": 30}])

	var clamped: Vector2 = world.resolve_position(Vector2(-50, -50), 14.0)
	_check(clamped.x >= 14.0 and clamped.y >= 14.0, "posiciones se clampean dentro de la arena")

	var pushed: Vector2 = world.resolve_position(Vector2(105, 100), 14.0)
	_check(pushed.distance_to(Vector2(100, 100)) >= 43.9, "pilares empujan a los actores")

	world.add_dummy(Vector2(60, 60), false)
	var around_dummy: Vector2 = world.resolve_position(Vector2(62, 60), 14.0)
	_check(around_dummy.distance_to(Vector2(60, 60)) >= 29.9, "dummies vivos bloquean el movimiento")


# --- Helpers ----------------------------------------------------------------


func _make_world(auto_attack: bool, seed_value: int) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(seed_value)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.add_dummy(Vector2(450, 230), auto_attack)
	return world


func _input(
		aim: Vector2,
		m1: bool,
		m2: bool,
		move: Vector2 = Vector2.ZERO,
		space: bool = false,
		q: bool = false,
		e: bool = false,
		r: bool = false,
		f: bool = false
) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = move
	message.aim_dir = aim.normalized()
	message.actions = {"m1": m1, "m2": m2, "space": space, "q": q, "e": e, "r": r, "f": f}
	return message


func _step(world: CombatWorld, ticks: int, message: InputMessage) -> void:
	for i: int in range(ticks):
		if message != null:
			world.submit_input(_duplicate_input(message))
		world.step(DT)


func _duplicate_input(message: InputMessage) -> InputMessage:
	var copy: InputMessage = InputMessageScript.new()
	copy.tick = message.tick
	copy.peer_id = message.peer_id
	copy.move_dir = message.move_dir
	copy.aim_dir = message.aim_dir
	copy.actions = message.actions.duplicate()
	return copy


func _first_hit(slot: String, seed_value: int) -> Array:
	var world := _make_world(false, seed_value)
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	_step(world, 40, _input(Vector2(0, -1), slot == "M1", slot == "M2"))
	return hits


func _run_sequence(seed_value: int) -> Dictionary:
	var world := _make_world(true, seed_value)
	for i: int in range(120):
		var message := _input(
			Vector2(0, -1),
			i % 7 < 4,
			(i + 3) % 11 == 0,
			Vector2(0.25, 0.0) if i > 40 else Vector2.ZERO,
			(i % 13 == 0),
			(i % 17 == 0),
			(i % 19 == 0),
			(i % 23 == 0),
			(i % 29 == 0)
		)
		world.submit_input(message)
		world.step(DT)
	return world.snapshot()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
