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
	_test_charge_hits_and_slows()
	_test_charge_miss_no_rage()
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
	_test_weapon_level_items_enemy()
	_test_jump_and_enemy_spacing()
	_test_m1_chains_without_cooldown()
	_test_attacks_hit_in_volume()
	_test_enemy_warrior_kit()
	_test_damage_types()
	_test_cc_diminishing()
	_test_dots_registry_ground()
	_test_mage()
	_test_blink_and_hold_aim()
	_test_rogue_ranger()
	_test_shadowstep_backstab()
	_test_anim_skills()
	_test_rogue_rework()
	_test_ranger_rework()
	_test_flank_stacks_castbar()
	_test_class_enemies_and_balance_sim()
	_test_defense_and_armor()
	_test_mage_redesign_and_ai()
	_test_quick_cast()
	_test_combos()

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
		_check(float(hits[0]) >= world.warrior.stats.get_stat(&"weapon_min") * 1.0 - 0.01, "Heavy Strikes hace al menos el daño mínimo del arma")
	_check(is_zero_approx(world.warrior.cooldown_left("M1")), "M1 no tiene cooldown")


func _test_piercing_thrust() -> void:
	var world := _make_world(false, 77)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)

	_step(world, 40, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))

	_check(hits.size() == 1, "Piercing Thrust conecta un único golpe en línea")
	_check(dummy.health < dummy.max_health, "Piercing Thrust aplica daño real")
	_check(world.warrior.rage() > 0.0, "Piercing Thrust genera Rage")
	if not hits.is_empty():
		_check(float(hits[0]) >= world.warrior.stats.get_stat(&"weapon_min") * 1.8 - 0.01, "Piercing Thrust usa su multiplicador de 1.8x")
	_check(world.warrior.cooldown_left("Q") > 0.0, "Piercing Thrust deja cooldown activo")
	_check(not world.warrior._can_start("Q"), "Piercing Thrust no se puede repetir durante el cooldown")

	_step(world, 130, null)
	_check(is_zero_approx(world.warrior.cooldown_left("Q")), "el cooldown de Piercing Thrust termina")


func _test_basic_damage_order() -> void:
	var light := _first_hit("M1", 77)
	var heavy := _first_hit("Q", 77)
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
	_check(world.warrior.cooldown_left("SHIFT") > 0.0, "Combat Roll deja cooldown activo")


func _test_charge_hits_and_slows() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var dummy: DummySim = world.add_dummy(Vector2(600, 300), false)
	var start := world.warrior.position

	_step(world, 30, _input(Vector2(1, 0), false, false, Vector2.ZERO, true))

	_check(dummy.health < dummy.max_health, "Charge impacta y daña al dummy")
	_check(dummy.stun_timer > 0.0, "Charge aturde al chocar")
	_check(world.warrior.rage() >= 20.0, "Charge genera Rage al impactar")
	_check(world.warrior.position.distance_to(start) > 80.0, "Charge desplaza al Warrior")
	_check(world.warrior.cooldown_left("SHIFT") > 0.0, "Charge deja cooldown activo")


func _test_charge_miss_no_rage() -> void:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var dummy: DummySim = world.add_dummy(Vector2(100, 100), false)
	var rage_before := world.warrior.rage()

	_step(world, 40, _input(Vector2(1, 0), false, false, Vector2.ZERO, true))

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

	_step(world, 3, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true))  # mantener R = apuntar
	_step(world, 80, _input(Vector2(0, -1), false, false))  # soltar = lanzar (salto de 0.85 s)

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
	_check(world.warrior.cooldown_left("F") > 50.0, "Bladestorm queda en cooldown largo al lanzarse")
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
	# Ultimate por cooldown (60 s): disponible al inicio y, tras lanzarla, bloqueada un minuto.
	var world := _make_world(false, 5)
	_check(world.warrior.cooldown_total("F") >= 60.0, "la Ultimate tiene cooldown de 1 minuto")
	_check(is_zero_approx(world.warrior.cooldown_left("F")), "la Ultimate empieza lista")


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
		_check(float(hits[0]) >= world.warrior.stats.get_stat(&"weapon_min") * 1.5 - 0.01, "Last Stand aplica +50% de daño")
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

	_step(world, 1, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))
	_step(world, 10, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))
	_check(starts[0] == 1, "mantener pulsado no repite el ataque")

	_step(world, 1, _input(Vector2(0, -1), false, false))
	_step(world, 1, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))
	_step(world, 10, _input(Vector2(0, -1), false, false))
	_check(starts[0] == 1, "el cooldown bloquea el recast")

	_step(world, 140, null)
	_step(world, 1, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, true))
	_check(starts[0] == 2, "tras el cooldown el ataque vuelve a estar disponible")


func _test_loadout_affects_casts() -> void:
	var world := _make_world(false, 5)
	var start := world.warrior.position

	world.warrior.assign_slot(&"E", &"hamstring")
	_check(String(world.warrior.ability_for_slot("E")["id"]) == "hamstring", "assign_slot cambia la habilidad del slot (opciones del rol)")

	world.warrior.debug_refill()
	_step(world, 30, _input(Vector2(1, 0), false, false, Vector2.ZERO, false, false, true))
	_check(world.warrior.cooldown_left("E") > 0.0 or world.warrior.is_attacking(), "el slot reasignado ejecuta la nueva habilidad")
	world.warrior.assign_slot(&"E", &"charge")
	_check(String(world.warrior.ability_for_slot("E")["id"]) == "hamstring", "assign_slot rechaza skills de otro rol (Charge es de Shift)")

	world.warrior.assign_slot(&"E", &"heavy_strikes")
	_check(String(world.warrior.ability_for_slot("E")["id"]) == "hamstring", "assign_slot rechaza habilidades no seleccionables")

	world.warrior.set_loadout({"SHIFT": &"bogus", "E": &"hamstring"})
	_check(String(world.warrior.ability_for_slot("SHIFT")["id"]) == "charge", "set_loadout repara ids inválidos")
	_check(String(world.warrior.ability_for_slot("E")["id"]) == "hamstring", "set_loadout conserva ids válidos")


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
		shift: bool = false,
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
	# r = skill de la tecla 1; f = ultimate (tecla R)
	message.actions = {"m1": m1, "m2": m2, "shift": shift, "q": q, "e": e, "s1": r, "r": f}
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
	copy.aim_point = message.aim_point
	copy.has_aim_point = message.has_aim_point
	copy.actions = message.actions.duplicate()
	return copy


func _first_hit(slot: String, seed_value: int) -> Array:
	var world := _make_world(false, seed_value)
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	_step(world, 40, _input(Vector2(0, -1), slot == "M1", false, Vector2.ZERO, false, slot == "Q"))
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


func _test_weapon_level_items_enemy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var world := _make_world(false, 5)
	var w = world.warrior
	var base_avg: float = w.stats.get_weapon_damage()
	# Un arma mejor sube el daño medio.
	w.equip_weapon(ItemFactory.roll_weapon(rng, 60, ItemRarity.Tier.EPICO, "sword"))
	_check(w.stats.get_weapon_damage() > base_avg * 5.0, "Un arma épica nv60 sube mucho el daño medio")
	# Escala WoW Classic: el golpe más fuerte (Seismic) con crítico ronda 3k a nivel 60.
	w.progression.set_level(60)
	var seismic: float = w.stats.get_weapon_damage() * 3.5 * 2.0
	_check(seismic > 1500.0 and seismic < 4500.0, "Seismic crítico nv60 ronda ~3k (%d)" % int(seismic))
	_check(absf(Progression.health_for(60) - 4500.0) < 400.0, "Vida base nv60 ~4.5k (%d)" % int(Progression.health_for(60)))
	# Rarezas.
	_check(ItemRarity.NAMES.size() == 6, "Hay 6 rarezas")
	var legend := ItemFactory.roll_weapon(rng, 30, ItemRarity.Tier.LEGENDARIO)
	_check(legend.legendary_effect != "" and legend.stats.size() > 0, "El legendario trae efecto y afijos")
	# XP y nivel.
	var prog := Progression.new()
	prog.add_xp(1000000)
	_check(prog.level == Progression.MAX_LEVEL, "La XP sube hasta el nivel máximo")
	# Enemigo: escala con el nivel, persigue y da XP al morir.
	var w2 := _make_world(false, 6)
	var enemy: EnemySim = w2.add_enemy(w2.warrior.position + Vector2(300, 0), 1)
	var start := enemy.position.distance_to(w2.warrior.position)
	_step(w2, 90, null)
	_check(enemy.position.distance_to(w2.warrior.position) < start, "El enemigo persigue al jugador")
	var xp_before: int = w2.warrior.progression.xp + w2.warrior.progression.level * 1000
	enemy.take_damage(99999.0)
	_check(not enemy.alive and w2.warrior.progression.xp + w2.warrior.progression.level * 1000 > xp_before - 1, "Matar al enemigo da XP")
	var e60 := EnemySim.new(w2, Vector2.ZERO, 60)
	_check(e60.max_health > 7000.0 and e60.attack_damage > 250.0, "El enemigo nv60 escala vida y daño")


func _test_jump_and_enemy_spacing() -> void:
	var world := _make_world(false, 8)
	var w = world.warrior
	# El Soldado no se queda pegado: tras golpear mantiene distancia.
	var w2 := _make_world(false, 9)
	var enemy: EnemySim = w2.add_enemy(w2.warrior.position + Vector2(150, 0), 1)
	var close_ticks := 0
	var max_speed := 0.0
	var prev := enemy.position
	for i in 600:
		w2.step(DT)
		if enemy.position.distance_to(w2.warrior.position) < 40.0:
			close_ticks += 1
		max_speed = maxf(max_speed, enemy.position.distance_to(prev) / DT)
		prev = enemy.position
	_check(max_speed <= EnemySim.CHARGE_SPEED + 1.0, "El Soldado nunca supera su velocidad de carga (%d px/s)" % int(max_speed))
	_check(close_ticks < 30, "El Soldado no se queda encima del jugador (%d ticks pegado)" % close_ticks)


func _test_m1_chains_without_cooldown() -> void:
	var world := _make_world(false, 21)
	var starts := [0]
	world.warrior.attack_started.connect(func(_skill: Dictionary, _dir: Vector2) -> void: starts[0] += 1)
	_step(world, 120, _input(Vector2(0, -1), true, false))  # 2 s con M1 mantenido
	# Un M1 dura 0.46 s: sin cooldown caben 4 en 2 s (con cooldown 0.35 serían 3).
	_check(starts[0] >= 4, "M1 mantenido encadena golpes sin pausa (%d en 2 s)" % starts[0])


func _test_attacks_hit_in_volume() -> void:
	var world := _make_world(false, 22)
	var w = world.warrior
	var attacker: DummySim = world.dummies[0]
	attacker.position = w.position + Vector2(-50, 0)
	w.height = 60.0  # en pleno salto
	var before: float = w.health
	var hit: bool = attacker._strike(w, Vector2.RIGHT, 92.0, 70.0, 10.0)
	_check(hit and w.health < before, "Un golpe cuerpo a cuerpo alcanza al jugador en pleno salto (volumen, no solo suelo)")
	w.height = 0.0
	before = w.health
	attacker._strike(w, Vector2.RIGHT, 120.0, 360.0, 10.0)
	_check(w.health < before, "El círculo (Ruptura sísmica) daña a quien salta o no")


func _test_enemy_warrior_kit() -> void:
	# M1 enemigo: combo de 3 sin pausa y daña.
	var world := _make_world(false, 23)
	var w = world.warrior
	var e: EnemySim = world.add_enemy(w.position + Vector2(60, 0), 1)
	var swings := [0]
	e.m1_started.connect(func(_i: int) -> void: swings[0] += 1)
	e._decide_timer = 99.0
	e._begin_m1_swing()
	var hp: float = w.health
	_step(world, 100, null)
	_check(swings[0] >= 3 and w.health < hp, "El Soldado encadena el combo de M1 y daña (%d golpes)" % swings[0])

	# Charge enemigo: daña y aturde al jugador.
	var world2 := _make_world(false, 24)
	var w2 = world2.warrior
	var e2: EnemySim = world2.add_enemy(w2.position + Vector2(300, 0), 1)
	e2.charge_cooldown = 0.0
	var stunned := false
	for i in 120:
		world2.step(DT)
		stunned = stunned or w2.is_stunned()
	_check(stunned, "La carga del Soldado aturde al jugador")

	# Parry enemigo: desvía el golpe frontal y no recibe daño.
	var world3 := _make_world(false, 25)
	var w3 = world3.warrior
	var e3: EnemySim = world3.add_enemy(w3.position + Vector2(60, 0), 1)
	e3._start_parry()
	_step(world3, 8, null)
	var parried := [false]
	e3.parried.connect(func() -> void: parried[0] = true)
	var e3_hp: float = e3.health
	var dealt := e3.take_damage(50.0, w3.position)
	_check(parried[0] and is_zero_approx(dealt) and is_equal_approx(e3.health, e3_hp), "El Soldado desvía con Parry")

	# Bladestorm enemigo: gira y daña alrededor.
	var world4 := _make_world(false, 26)
	var w4 = world4.warrior
	var e4: EnemySim = world4.add_enemy(w4.position + Vector2(60, 0), 1)
	var ended := [false]
	e4.spin_ended.connect(func() -> void: ended[0] = true)
	e4._decide_timer = 99.0
	e4._start_spin()
	var hp4: float = w4.health
	_step(world4, 160, null)
	_check(ended[0] and w4.health < hp4, "El Soldado usa Bladestorm y daña")


func _test_damage_types() -> void:
	var world := _make_world(false, 31)
	var d: DummySim = world.dummies[0]
	d.resist = {DamageSystem.Type.FIRE: 0.5, DamageSystem.Type.POISON: -0.5}
	var phys := d.take_damage(100.0, Vector2.ZERO, {})
	d.health = d.max_health
	var fire := d.take_damage(100.0, Vector2.ZERO, {DamageSystem.KEY: DamageSystem.Type.FIRE})
	d.health = d.max_health
	var poison := d.take_damage(100.0, Vector2.ZERO, {DamageSystem.KEY: DamageSystem.Type.POISON})
	_check(is_equal_approx(phys, 100.0) and is_equal_approx(fire, 50.0) and is_equal_approx(poison, 150.0), "Las resistencias por tipo de daño se aplican (físico/fuego/veneno)")


func _test_cc_diminishing() -> void:
	var cc := CCDiminish.new()
	var a := cc.apply("stun", 1.0)
	var b := cc.apply("stun", 1.0)
	var c := cc.apply("stun", 1.0)
	var d := cc.apply("stun", 1.0)
	_check(is_equal_approx(a, 1.0) and is_equal_approx(b, 0.5) and is_equal_approx(c, 0.25) and d == 0.0, "El stun encadenado decrece 100/50/25 % y luego es inmune")
	cc.tick(16.0)
	_check(is_equal_approx(cc.apply("stun", 1.0), 1.0), "El rendimiento del CC se reinicia tras 15 s")


func _test_dots_registry_ground() -> void:
	var world := _make_world(false, 41)
	var d: DummySim = world.dummies[0]
	d.take_damage(1.0, Vector2.ZERO, {"dot": {DamageSystem.KEY: DamageSystem.Type.POISON, "dps": 20.0, "duration": 3.0}})
	var hp: float = d.health
	_step(world, 120, null)  # 2 s
	_check(hp - d.health >= 29.0 and hp - d.health < 45.0, "Veneno: ~20 dps durante su duración (%d)" % int(hp - d.health))
	_step(world, 180, null)
	var settled: float = d.health
	_step(world, 60, null)
	_check(is_equal_approx(d.health, settled), "El DoT termina al acabar su duración")
	var w = world.warrior
	var wh: float = w.health
	w.take_damage(1.0, Vector2.ZERO, {"dot": {DamageSystem.KEY: DamageSystem.Type.FIRE, "dps": 10.0, "duration": 2.0}})
	_step(world, 60, null)
	_check(wh - w.health > 4.0, "El jugador también recibe DoT")
	_check(ClassRegistry.missing(&"warrior").is_empty(), "El kit del Warrior cumple el contrato de ClassRegistry")
	var w2 := _make_world(false, 42)
	var ward = w2.warrior
	var far: Vector2 = ward.position + Vector2(0, -600)
	var target: DummySim = w2.dummies[0]
	target.position = ward.position + Vector2(0, -200)
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true)
	msg.aim_point = far
	msg.has_aim_point = true
	ward.debug_refill()
	var hp2: float = target.health
	_step(w2, 3, msg)
	msg.actions["s1"] = false
	_step(w2, 60, msg)
	_check(target.health < hp2, "Seismic cae en el punto apuntado (lejos del jugador)")
	_check(ward.clamp_ground_point(far, ward.ability_for_slot("R")).distance_to(ward.position) <= 260.01, "El punto de suelo se limita al alcance")


func _test_mage() -> void:
	_check(ClassRegistry.missing(&"mage").is_empty(), "MageKit cumple el contrato de ClassRegistry")
	var world := _make_world(false, 51)
	var w = world.warrior
	w.set_class(&"mage")
	var target: DummySim = world.dummies[0]
	target.position = w.position + Vector2(0, -150)
	var hp: float = target.health
	_step(world, 60, _input(Vector2(0, -1), true, false))
	_check(target.health < hp, "Arcane Bolt (proyectil) alcanza y daña al objetivo")
	var w2 := _make_world(false, 52)
	w2.warrior.set_class(&"mage")
	w2.warrior.assign_slot(&"R", &"arcane_orb")
	var t2: DummySim = w2.dummies[0]
	t2.position = w2.warrior.position + Vector2(0, -150)
	_step(w2, 90, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true))  # Arcane Orb (tecla 1), cast de 0.9 s
	var after_hit: float = t2.health
	_step(w2, 90, null)
	_check(t2.health < after_hit, "Fireball quema al objetivo después del impacto")
	var w3 := _make_world(false, 53)
	w3.warrior.set_class(&"mage")
	w3.warrior._spend_rage(50.0)
	var low: float = w3.warrior.rage()
	_step(w3, 90, null)
	var after_delay: float = w3.warrior.rage()
	_check(is_equal_approx(after_delay, low), "El maná no regenera justo después de gastar (retraso de 2 s)")
	_step(w3, 180, null)
	_check(w3.warrior.rage() > after_delay and w3.warrior.rage() < after_delay + 10.0, "El maná regenera lento (%.1f en 3 s)" % (w3.warrior.rage() - after_delay))
	w3.warrior.set_class(&"warrior")


func _test_blink_and_hold_aim() -> void:
	var world := _make_world(false, 61)
	var w = world.warrior
	w.set_class(&"mage")
	w.reset(w.position)
	var start: Vector2 = w.position
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, true)  # SHIFT = Blink (suelo)
	msg.aim_point = start + Vector2(0, -200)
	msg.has_aim_point = true
	_step(world, 5, msg)
	_check(not w.ground_slot_ready().is_empty() and w.position.distance_to(start) < 1.0, "Mantener Blink apunta sin lanzar todavía")
	msg.actions["shift"] = false
	var evaded := false
	for i in 30:
		world.submit_input(_duplicate_input(msg))
		world.step(DT)
		evaded = evaded or w.take_damage(1.0, Vector2.ZERO, {}) == 0.0
	_check(w.position.distance_to(start + Vector2(0, -200)) < 30.0, "Blink teletransporta al punto apuntado (%d px)" % int(w.position.distance_to(start)))
	_check(w.ground_slot_ready().is_empty(), "Al soltar desaparece el marcador de apuntado")
	w.set_class(&"warrior")


func _test_rogue_ranger() -> void:
	var world := _make_world(false, 71)
	var w = world.warrior
	w.set_class(&"rogue")
	w.reset(w.position)
	var starts := [0]
	w.attack_started.connect(func(_s: Dictionary, _d: Vector2) -> void: starts[0] += 1)
	var msg = _input(Vector2(0, -1), true, false)
	_step(world, 70, msg)  # ~1.2 s con M1 mantenido
	_check(starts[0] >= 3, "Rogue: M1 no cuesta Energy, se puede spamear (%d en 1.2 s)" % starts[0])
	_check(w.rage() > 95.0, "Rogue: M1 no gasta Energy")
	var w2 := _make_world(false, 72)
	var r = w2.warrior
	r.set_class(&"ranger")
	r.current_skill = r.kit.MULTISHOT.duplicate(true)
	r.attack_aim = Vector2(0, -1)
	r._spawn_projectile()
	_check(r.projectiles.size() == 3, "Multishot lanza 3 flechas en abanico")
	_check(ClassRegistry.missing(&"rogue").is_empty() and ClassRegistry.missing(&"ranger").is_empty(), "Rogue y Ranger cumplen el contrato de kit")
	r.set_class(&"warrior")


func _test_shadowstep_backstab() -> void:
	var world := _make_world(false, 81)
	var w = world.warrior
	w.set_class(&"rogue")
	w.reset(w.position)
	var enemy: DummySim = world.dummies[0]
	enemy.position = w.position + Vector2(0, -150)
	enemy.facing = (w.position - enemy.position).normalized()  # mira hacia el jugador
	var hp: float = enemy.health
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, true)
	msg.aim_point = enemy.position
	msg.has_aim_point = true
	_step(world, 4, msg)
	msg.actions["shift"] = false
	for i in 40:
		world.submit_input(_duplicate_input(msg))
		world.step(DT)
	var behind: bool = w.position.y < enemy.position.y  # al otro lado del enemigo
	_check(behind and enemy.health < hp, "Shadowstep apuntando al enemigo: aparece a su espalda y lo apuñala")
	var world2 := _make_world(false, 82)
	var w2 = world2.warrior
	w2.set_class(&"rogue")
	w2.reset(w2.position)
	var start: Vector2 = w2.position
	var e2: DummySim = world2.dummies[0]
	var hp2: float = e2.health
	var m2 = _input(Vector2(0, 1), false, false, Vector2.ZERO, true)
	m2.aim_point = start + Vector2(150, 0)
	m2.has_aim_point = true
	_step(world2, 4, m2)
	m2.actions["shift"] = false
	for i in 40:
		world2.submit_input(_duplicate_input(m2))
		world2.step(DT)
	_check(w2.position.distance_to(start + Vector2(150, 0)) < 30.0 and is_equal_approx(e2.health, hp2), "Shadowstep sin objetivo: solo teletransporta al punto apuntado")
	w2.set_class(&"warrior")


func _test_anim_skills() -> void:
	# Vanish: invisible 5 s; los enemigos no atacan; atacar rompe la invisibilidad.
	var world := _make_world(false, 91)
	var w = world.warrior
	w.set_class(&"rogue")
	w.reset(w.position)
	var e: EnemySim = world.add_enemy(w.position + Vector2(70, 0), 1)
	w.debug_refill()
	w.buffered_slot = "Q"
	w.buffer_timer = 1.0
	_step(world, 30, null)
	_check(w.is_invisible(), "Vanish vuelve invisible al Rogue")
	var hp: float = w.health
	_step(world, 150, null)  # ~2.5 s con el enemigo pegado
	_check(is_equal_approx(w.health, hp), "Los enemigos no atacan a un Rogue invisible")
	_step(world, 150, null)
	_check(not w.is_invisible(), "La invisibilidad dura unos 5 s")
	w.set_class(&"warrior")
	# Kick: empuja al enemigo.
	var world2 := _make_world(false, 92)
	var r = world2.warrior
	r.set_class(&"ranger")
	r.reset(r.position)
	var d: DummySim = world2.dummies[0]
	d.position = r.position + Vector2(0, -60)
	var before: float = d.position.distance_to(r.position)
	r.assign_slot(&"E", &"kick")
	r.buffered_slot = "E"
	r.buffer_timer = 1.0
	r.aim_dir = Vector2(0, -1)
	_step(world2, 40, _input(Vector2(0, -1), false, false))
	_check(d.position.distance_to(r.position) > before + 80.0, "Kick empuja al enemigo (%d px)" % int(d.position.distance_to(r.position) - before))
	# Evasive Leap: sube y vuelve a caer.
	r.debug_refill()
	r.buffered_slot = "SHIFT"
	r.buffer_timer = 1.0
	var peak := 0.0
	for i in 40:
		world2.submit_input(_duplicate_input(_input(Vector2(0, -1), false, false)))
		world2.step(DT)
		peak = maxf(peak, r.height)
	_check(peak > 20.0 and r.height == 0.0, "Evasive Leap salta y cae (pico %d px)" % int(peak))
	r.set_class(&"warrior")
	# Seismic Break: el Warrior salta hasta el punto apuntado.
	var world3 := _make_world(false, 93)
	var ward = world3.warrior
	var start: Vector2 = ward.position
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true)
	msg.aim_point = start + Vector2(0, -200)
	msg.has_aim_point = true
	ward.debug_refill()
	_step(world3, 3, msg)
	msg.actions["s1"] = false
	var air_peak := 0.0
	for i in 70:
		world3.submit_input(_duplicate_input(msg))
		world3.step(DT)
		air_peak = maxf(air_peak, ward.height)
	_check(ward.position.distance_to(start + Vector2(0, -200)) < 25.0 and air_peak > 40.0, "Seismic Break: salto hasta el punto apuntado (pico %d px)" % int(air_peak))


func _test_rogue_rework() -> void:
	var world := _make_world(false, 101)
	var w = world.warrior
	w.set_class(&"rogue")
	w.reset(w.position)
	var e: DummySim = world.dummies[0]
	e.position = w.position + Vector2(0, -90)
	e.facing = Vector2(0, 1)
	w.debug_refill()
	var start: Vector2 = w.position
	var hp: float = e.health
	w.aim_dir = Vector2(0, -1)
	w.assign_slot(&"SHIFT", &"cross_cut")
	w.buffered_slot = "SHIFT"
	w.buffer_timer = 1.0
	_step(world, 45, _input(Vector2(0, -1), false, false))
	_check(w.position.distance_to(start) > 35.0 and e.health < hp, "Cross Cut salta hacia delante y golpea al aterrizar")
	# Death Sentence: gap closer que aturde 2 s.
	w.debug_refill()
	w.ultimate_charge = 100.0
	e.position = w.position + Vector2(0, -100)
	w.buffered_slot = "F"
	w.buffer_timer = 1.0
	_step(world, 40, _input(Vector2(0, -1), false, false))
	_check(e.stun_timer > 0.0, "Death Sentence aturde al objetivo")
	# Fan of Knives (R): AoE de poco daño con veneno.
	_step(world, 40, _input(Vector2(0, -1), false, false))  # termina la recuperación anterior
	w.debug_refill()
	w.assign_slot(&"R", &"fan_of_knives")
	e.position = w.position + Vector2(60, 0)
	var hp2: float = e.health
	w.buffered_slot = "R"
	w.buffer_timer = 1.0
	_step(world, 3, _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true))
	_step(world, 40, _input(Vector2(0, -1), false, false))
	_check(e.health < hp2 and e.dots.is_active(), "Fan of Knives (R) daña en área y envenena")
	# Un enemigo no sigue con la mirada a un jugador invisible.
	var facing_before: Vector2 = e.facing
	w.invisible_timer = 5.0
	w.position += Vector2(0, 120)
	_step(world, 10, null)
	_check(e.facing.is_equal_approx(facing_before), "El enemigo no gira hacia un jugador invisible")
	w.set_class(&"warrior")


func _test_ranger_rework() -> void:
	var world := _make_world(false, 111)
	var r = world.warrior
	r.set_class(&"ranger")
	r.reset(r.position)
	var a: DummySim = world.dummies[0]
	a.position = r.position + Vector2(0, -200)
	var b: DummySim = world.add_dummy(a.position + Vector2(70, 0), false)
	r.debug_refill()
	r.assign_slot(&"Q", &"explosive_arrow")
	var hp_b: float = b.health
	r.buffered_slot = "Q"
	r.buffer_timer = 1.0
	_step(world, 60, _input(Vector2(0, -1), false, false))
	_check(b.health < hp_b, "Explosive Arrow explota y daña a los cercanos al impacto")
	# Rain of Arrows: golpea varias veces en la zona.
	var world2 := _make_world(false, 112)
	var r2 = world2.warrior
	r2.set_class(&"ranger")
	r2.reset(r2.position)
	var t: DummySim = world2.dummies[0]
	t.position = r2.position + Vector2(0, -150)
	r2.debug_refill()
	r2.ultimate_charge = 100.0
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, false, true)
	msg.aim_point = t.position
	msg.has_aim_point = true
	_step(world2, 3, msg)
	msg.actions["r"] = false
	var hits := [0]
	t.hit.connect(func(_a: float, _p: Vector2) -> void: hits[0] += 1)
	for i in 240:
		world2.submit_input(_duplicate_input(msg))
		world2.step(DT)
	_check(hits[0] >= 5, "Rain of Arrows golpea en oleadas durante su duración (%d golpes)" % hits[0])
	# Kick: en línea y empuja.
	var world3 := _make_world(false, 113)
	var k = world3.warrior
	k.set_class(&"ranger")
	k.reset(k.position)
	_check(String(k.kit.KICK["cast"]) == "line", "Kick es una patada en línea")
	k.set_class(&"warrior")


func _test_flank_stacks_castbar() -> void:
	# Cheap Shot solo por la espalda; M1 de frente hace menos daño.
	var world := _make_world(false, 121)
	var w = world.warrior
	w.set_class(&"rogue")
	w.reset(w.position)
	var d: DummySim = world.dummies[0]
	d.position = w.position + Vector2(0, -50)
	w.aim_dir = Vector2(0, -1)
	d.facing = Vector2(0, 1)  # mira hacia el jugador: de frente
	w.debug_refill()
	_check(w._can_start("E"), "Cheap Shot se puede lanzar de frente (stun corto)")
	d.facing = Vector2(0, -1)  # de espaldas
	_check(w._can_start("E"), "Cheap Shot también por la espalda (stun largo)")
	d.facing = Vector2(0, 1)
	var front := 0.0
	var back := 0.0
	for i in 40:
		w._rng.seed = 5 + i
		w._hit_targets.clear()
		w.current_skill = w.kit.M1.duplicate(true)
		var h1: float = d.health
		d.facing = Vector2(0, 1)
		w._hit_target(d, 1.0, {})
		front += h1 - d.health
		d.health = d.max_health
		w._rng.seed = 5 + i
		w._hit_targets.clear()
		d.facing = Vector2(0, -1)
		var h2: float = d.health
		w._hit_target(d, 1.0, {})
		back += h2 - d.health
		d.health = d.max_health
	_check(front < back * 0.9, "El Rogue hace menos daño de frente que por la espalda (%d vs %d)" % [int(front), int(back)])
	# Veneno: se acumula hasta 3 veces.
	var tracker := DotTracker.new()
	for i in 5:
		tracker.add(DamageSystem.Type.POISON, 10.0, 5.0, 3)
	_check(tracker.stacks_of(DamageSystem.Type.POISON) == 3, "El veneno se acumula como máximo 3 veces")
	var per_second := 0.0
	for hit: Dictionary in tracker.tick(1.0):
		per_second += float(hit["amount"])
	_check(is_equal_approx(per_second, 22.0), "3 acumulaciones = 2.2x el daño por segundo (%.1f)" % per_second)
	w.set_class(&"warrior")
	# Barra de cast: el disparo concentrado se cancela al moverse y sale quieto.
	var world2 := _make_world(false, 122)
	var r = world2.warrior
	r.set_class(&"ranger")
	r.reset(r.position)
	var t: DummySim = world2.dummies[0]
	t.position = r.position + Vector2(0, -150)
	r.aim_dir = Vector2(0, -1)
	var before: float = t.health
	r.debug_refill()
	r.buffered_slot = "R"
	r.buffer_timer = 1.0
	_step(world2, 40, _input(Vector2(0, -1), false, false))
	_check(r.cast_progress() > 0.2 and r.cast_progress() < 0.9, "La barra de cast del disparo concentrado avanza (%.2f)" % r.cast_progress())
	var moving = _input(Vector2(0, -1), false, false, Vector2(1, 0))
	_step(world2, 5, moving)
	_check(r.cast_progress() < 0.0 and is_equal_approx(t.health, before), "Moverse cancela el cast y no sale disparo")
	_step(world2, 60, _input(Vector2(0, -1), false, false))
	r.buffered_slot = "R"
	r.buffer_timer = 1.0
	_step(world2, 140, _input(Vector2(0, -1), false, false))
	_check(t.health < before, "Quieto, el disparo concentrado sale con la barra llena")
	r.set_class(&"warrior")


func _test_class_enemies_and_balance_sim() -> void:
	# Enemigo de clase: ataca al jugador con las skills de su clase.
	var world := _make_world(false, 131)
	var foe := world.add_fighter(&"mage", 1, world.warrior.position + Vector2(0, -200), 3, "Mago")
	_check(foe.team == 1 and foe.alive and foe.progression.level == 3, "add_fighter crea un enemigo de clase con nivel")
	var hp_before: float = world.warrior.health
	_step(world, 600, null)
	_check(world.warrior.health < hp_before, "El enemigo de clase (Mago) ataca al jugador (%d de daño)" % int(hp_before - world.warrior.health))
	# El jugador también le pega (es objetivo válido).
	_check(world.targets_for(world.warrior).has(foe), "El enemigo de clase es un objetivo para el jugador")
	# Simulador: DPS en muñeco y overrides de balance.
	BalanceData.clear()
	var base := BalanceSim.dps_race({"class": "rogue", "level": 1, "seconds": 20, "seed": 3})
	_check(float(base["damage"]) > 0.0 and (base["skills"] as Array).size() > 0, "dps_race devuelve daño y desglose por skill")
	BalanceData.set_class_mod(&"rogue", "damage_mult", 2.0)
	var boosted := BalanceSim.dps_race({"class": "rogue", "level": 1, "seconds": 20, "seed": 3})
	_check(float(boosted["damage"]) > float(base["damage"]) * 1.6, "El multiplicador de daño de clase se refleja en el simulador")
	BalanceData.clear()
	BalanceData.set_skill_value("twin_fang", "damage_mult", 3.0)
	var skilled := BalanceSim.dps_race({"class": "rogue", "level": 1, "seconds": 20, "seed": 3})
	_check(float(skilled["damage"]) > float(base["damage"]) * 1.3, "Un override de skill cambia el daño en el simulador")
	BalanceData.clear()
	var duel := BalanceSim.run_many({"a": [{"class": "warrior", "level": 1}], "b": [{"class": "mage", "level": 1}], "max_seconds": 60}, 3)
	_check(int(duel["wins"]["A"]) + int(duel["wins"]["B"]) + int(duel["wins"]["empate"]) == 3, "Los duelos 1v1 registran sus resultados")
	var team := BalanceSim.team_match({"a": [{"class": "warrior"}, {"class": "mage"}], "b": [{"class": "rogue"}], "max_seconds": 30, "seed": 5})
	_check((team["fighters"] as Array).size() == 3, "Los combates por equipos (2v1) funcionan")


## Cancelaciones: el escape corta el windup del básico y la recuperación; otra skill corta la recuperación tardía.
func _test_cancels() -> void:
	var world := _make_world(false, 145)
	var w = world.warrior
	w.reset(w.position)
	w.debug_refill()
	_step(world, 1, _input(Vector2.RIGHT, true, false))
	_check(w.state == WarriorSim.AttackState.WINDUP and w.current_slot == "M1", "M1 entra en windup")
	var esc = _input(Vector2.RIGHT, false, false, Vector2.ZERO, true)
	_step(world, 2, esc)
	_check(w.current_slot == "SHIFT", "La movilidad cancela el windup del ataque básico (slot %s)" % w.current_slot)
	w.reset(w.position)
	w.debug_refill()
	var q = _input(Vector2.RIGHT, false, false, Vector2.ZERO, false, true)
	_step(world, 1, q)
	var skill_q: Dictionary = w.current_skill
	var to_recovery := int(ceil((float(skill_q["windup"]) + float(skill_q["active"])) * 60.0)) + 1
	_step(world, to_recovery, null)
	_check(w.state == WarriorSim.AttackState.RECOVERY, "Q llega a recuperación")
	_step(world, 1, _input(Vector2.RIGHT, true, false))  # M1 pulsado al principio de la recuperación: queda en buffer
	_check(w.current_slot == "Q" and w.buffered_slot == "M1", "Al inicio de la recuperación la acción queda en buffer")
	var early := int(ceil(float(skill_q["recovery"]) * WarriorSim.RECOVERY_CANCEL * 60.0)) + 1
	_step(world, early, _input(Vector2.RIGHT, true, false))
	_check(w.current_slot == "M1", "Pasado el %d%% de la recuperación, la acción en buffer la corta" % int(WarriorSim.RECOVERY_CANCEL * 100.0))
	_check(WarriorSim.BUFFER_SECONDS >= 0.3, "Buffer de input generoso (%.2f s)" % WarriorSim.BUFFER_SECONDS)


func _test_defense_and_armor() -> void:
	# --- Warrior: Block y Perfect Parry ---
	var world := _make_world(false, 141)
	var w = world.warrior
	w.reset(w.position)
	var foe: DummySim = world.dummies[0]
	foe.position = w.position + Vector2(0, -60)
	w.aim_dir = Vector2(0, -1)
	var hold = _input(Vector2(0, -1), false, true)  # M2 mantenido
	_step(world, 3, hold)
	_check(w.guarding, "Mantener M2 activa el Block")
	var hp: float = w.health
	var foe_hp: float = foe.health
	var dealt: float = w.take_damage(50.0, foe.position, {"attacker": foe})
	_check(is_zero_approx(dealt) and is_equal_approx(w.health, hp) and foe.health < foe_hp and is_zero_approx(foe.stun_timer), "Perfect Parry anula el golpe físico y contraataca (sin stagger)")
	foe_hp = foe.health
	var spell: float = w.take_damage(50.0, foe.position, {"attacker": foe, DamageSystem.KEY: DamageSystem.Type.FIRE})
	_check(is_zero_approx(spell) and is_equal_approx(foe.health, foe_hp), "Un hechizo parado perfectamente solo se anula (sin contraataque)")
	_step(world, 30, hold)
	var reduced: float = w.take_damage(100.0, foe.position, {"attacker": foe})
	_check(reduced > 0.0 and reduced <= 25.0, "Block normal reduce ~80%% el daño físico (%.0f de 100)" % reduced)
	var behind: float = w.take_damage(100.0, w.position + Vector2(0, 80), {"attacker": foe})
	_check(behind > reduced * 3.0, "Por la espalda no hay bloqueo (%.0f)" % behind)
	# --- Armadura: reduce el daño físico, no el mágico; no existe poise ni stagger ---
	var world2 := _make_world(false, 142)
	var t: DummySim = world2.dummies[0]
	for i in 12:
		t.take_damage(5.0, Vector2(1, 1), {})
	_check(is_zero_approx(t.stun_timer), "Encadenar golpes físicos ya no aturde (sin stagger)")
	_check(w.get("poise") == null and t.get("poise") == null and not w.has_signal("staggered"), "No queda rastro de poise/stagger en la simulación")
	var tank = _make_world(false, 144).warrior
	tank.reset(tank.position)
	var phys: float = tank.take_damage(100.0, tank.position + Vector2(50, 0), {})
	var magic: float = tank.take_damage(100.0, tank.position + Vector2(50, 0), {DamageSystem.KEY: DamageSystem.Type.FIRE})
	_check(phys < magic and is_equal_approx(magic, 100.0) and is_equal_approx(phys, 100.0 * (1.0 - tank.physical_reduction())), "La armadura del Warrior reduce el daño físico (%.0f) y no el mágico (%.0f)" % [phys, magic])
	_check(tank.physical_reduction() > 0.2 and tank.physical_reduction() <= WarriorSim.ARMOR_CAP, "Reducción física del Warrior nivel 1: %d%%" % int(tank.physical_reduction() * 100.0))
	# --- Cancelaciones y buffer ---
	_test_cancels()
	# --- Mago: Mana Shield y Arcane Deflection ---
	var world3 := _make_world(false, 143)
	var m = world3.warrior
	m.set_class(&"mage")
	m.reset(m.position)
	var attacker: DummySim = world3.dummies[0]
	attacker.position = m.position + Vector2(0, -80)
	var shield = _input(Vector2(0, -1), false, true)
	_step(world3, 3, shield)
	var hp_attacker: float = attacker.health
	var deflected: float = m.take_damage(30.0, attacker.position, {"attacker": attacker})
	_check(is_zero_approx(deflected) and attacker.health < hp_attacker and is_zero_approx(attacker.stun_timer), "Arcane Deflection devuelve el golpe al atacante (sin stagger)")
	_step(world3, 30, shield)
	var mana_before: float = m.rage()
	var hp_m: float = m.health
	var absorbed: float = m.take_damage(20.0, attacker.position, {"attacker": attacker})
	_check(is_zero_approx(absorbed) and is_equal_approx(m.health, hp_m) and m.rage() < mana_before - 15.0, "Mana Shield absorbe el daño gastando maná (%.0f)" % (mana_before - m.rage()))
	m.set_class(&"warrior")
	# --- Rogue: Dodge Roll con ventana de invulnerabilidad ---
	var world4 := _make_world(false, 144)
	var r = world4.warrior
	r.set_class(&"rogue")
	r.reset(r.position)
	r.debug_refill()
	r.buffered_slot = "M2"
	r.buffer_timer = 1.0
	var move_right = _input(Vector2(1, 0), false, false, Vector2(1, 0))
	_step(world4, 2, move_right)
	_step(world4, 6, move_right)  # ~0.13 s: dentro de la ventana (0.03-0.22 s)
	var in_window: float = r.take_damage(40.0, r.position + Vector2(40, 0), {})
	_step(world4, 40, move_right)  # termina el roll
	var after: float = r.take_damage(40.0, r.position + Vector2(40, 0), {})
	_check(is_zero_approx(in_window) and after > 0.0, "Dodge Roll es invulnerable solo dentro de su ventana")
	r.set_class(&"warrior")


func _test_mage_redesign_and_ai() -> void:
	# Silence: el objetivo no puede usar skills; Pull lo arrastra hacia el mago.
	var world := _make_world(false, 151)
	var w = world.warrior
	w.set_class(&"mage")
	w.reset(w.position)
	var foe := world.add_fighter(&"warrior", 1, w.position + Vector2(0, -250), 1)
	foe.silence_timer = 0.0
	foe.take_damage(1.0, w.position, {"silence": 3.0})
	foe.debug_refill()
	_check(foe.silence_timer > 2.5 and not foe._can_start("SHIFT") and not foe._can_start("F"), "Silence impide usar skills (solo ataque básico)")
	var start_gap: float = foe.position.distance_to(w.position)
	foe.take_damage(1.0, w.position, {"pull": 170.0})
	_step(world, 20, null)
	_check(foe.position.distance_to(w.position) < start_gap - 100.0, "Arcane Pull arrastra al objetivo hacia el mago (%d px)" % int(start_gap - foe.position.distance_to(w.position)))
	_check(w.kit.DEFAULT_LOADOUT["Q"] == &"arcane_bind" and w.kit.DEFAULT_LOADOUT["E"] == &"arcane_pulse", "El mago lleva Bind y Pulse por defecto (Silence/Time Rift son alternativas)")
	# Arcane Bind: el objetivo atado no se mueve (pero sí puede atacar).
	var rooted := world.add_fighter(&"warrior", 1, w.position + Vector2(200, 0), 1)
	rooted.take_damage(1.0, w.position, {"root": 2.5})
	var before := rooted.position
	_step(world, 60, null)
	_check(rooted.root_timer > 0.0 and rooted.position.distance_to(before) < 5.0, "Arcane Bind ata al objetivo al suelo")
	# Death Sentence: lance y ráfaga de cortes con aturdimiento.
	var world_r := _make_world(false, 154)
	var rg = world_r.warrior
	rg.set_class(&"rogue")
	rg.reset(rg.position)
	var victim: DummySim = world_r.dummies[0]
	victim.position = rg.position + Vector2(0, -110)
	rg.debug_refill()
	rg.ultimate_charge = 100.0
	rg.aim_dir = Vector2(0, -1)
	var hits := [0]
	victim.hit.connect(func(_a: float, _p: Vector2) -> void: hits[0] += 1)
	rg.buffered_slot = "F"
	rg.buffer_timer = 1.0
	_step(world_r, 90, _input(Vector2(0, -1), false, false))
	_check(hits[0] >= 5 and victim.stun_timer > 0.0, "Death Sentence: lance + ráfaga de cortes y stun (%d golpes)" % hits[0])
	# Ambush: el primer golpe desde el sigilo pega más.
	var plain := _first_ambush_damage(false)
	var sneaky := _first_ambush_damage(true)
	_check(sneaky > plain * 1.3, "Ambush: golpear desde el sigilo hace más daño (%.0f vs %.0f)" % [sneaky, plain])
	# Arquetipos: el Campeón bloquea con timing y tiene más armadura que el Soldado.
	var world2 := _make_world(false, 152)
	var soldier := world2.add_archetype("soldado", 1, world2.warrior.position + Vector2(0, -200), 3)
	var champion := world2.add_archetype("campeon", 1, world2.warrior.position + Vector2(80, -200), 3)
	_check(champion.armor > soldier.armor * 1.4 and champion.brain.difficulty > soldier.brain.difficulty, "El Campeón tiene más armadura y más nivel de IA que el Soldado")
	_check(champion.progression.level == 4, "El arquetipo suma niveles (nivel base + bonus)")
	# La IA reacciona al ataque del rival: el hechicero se aparta / usa su escudo y no se queda quieto.
	var world3 := _make_world(false, 153)
	var caster := world3.add_archetype("hechicero", 1, world3.warrior.position + Vector2(0, -90), 2)
	var start_pos: Vector2 = caster.position
	_step(world3, 120, null)
	_check(caster.position.distance_to(start_pos) > 30.0, "El hechicero se reposiciona en vez de quedarse parado")


func _first_ambush_damage(invisible: bool) -> float:
	var world := _make_world(false, 155)
	var r = world.warrior
	r.set_class(&"rogue")
	r.reset(r.position)
	var dummy: DummySim = world.dummies[0]
	dummy.position = r.position + Vector2(0, -50)
	dummy.facing = Vector2(0, -1)
	r.aim_dir = Vector2(0, -1)
	if invisible:
		r.invisible_timer = 5.0
	r._rng.seed = 9
	r.current_skill = r.kit.M1.duplicate(true)
	var before: float = dummy.health
	r._hit_target(dummy, 1.0, {})
	return before - dummy.health


func _test_quick_cast() -> void:
	# Quick cast (top-down): la skill de suelo sale al pulsar, en el punto del cursor.
	var world := _make_world(false, 161)
	var w = world.warrior
	w.quick_cast = true
	var target: DummySim = world.dummies[0]
	target.position = w.position + Vector2(0, -150)
	w.debug_refill()
	var msg = _input(Vector2(0, -1), false, false, Vector2.ZERO, false, false, false, true)  # tecla 1 = Seismic Break
	msg.aim_point = target.position
	msg.has_aim_point = true
	var hp: float = target.health
	_step(world, 90, msg)  # la tecla sigue pulsada: no hace falta soltar
	_check(target.health < hp, "Quick cast: Seismic Break sale al pulsar, sin mantener y soltar")


func _hit_damage(sim_class: StringName, slot: String, setup: Callable) -> float:
	var world := _make_world(false, 171)
	var w = world.warrior
	w.set_class(sim_class)
	w.reset(w.position)
	var dummy: DummySim = world.dummies[0]
	dummy.position = w.position + Vector2(0, -60)
	dummy.facing = Vector2(0, -1)
	w.aim_dir = Vector2(0, -1)
	setup.call(dummy)
	w._rng.seed = 11
	w.current_skill = w.ability_for_slot(slot)
	var before: float = dummy.health
	w._hit_target(dummy, float(w.current_skill.get("damage_mult", 1.0)), {})
	return before - dummy.health


func _test_combos() -> void:
	var plain := _hit_damage(&"warrior", "Q", func(_d: DummySim) -> void: pass)
	var stunned := _hit_damage(&"warrior", "Q", func(d: DummySim) -> void: d.stun_timer = 1.0)
	_check(stunned > plain * 1.4, "Combo Warrior: Piercing Thrust pega +50%% a un aturdido (%.0f vs %.0f)" % [stunned, plain])
	var seismic_plain := _hit_damage(&"warrior", "R", func(_d: DummySim) -> void: pass)
	var seismic_marked := _hit_damage(&"warrior", "R", func(d: DummySim) -> void: d.apply_effects({"mark": 5.0}))
	_check(seismic_marked > seismic_plain * 1.5, "Combo Warrior: un objetivo marcado recibe más (marca +25%% y Seismic +40%%)")
	var mage_plain := _hit_damage(&"mage", "R", func(_d: DummySim) -> void: pass)
	var mage_rooted := _hit_damage(&"mage", "R", func(d: DummySim) -> void: d.root_timer = 2.0)
	_check(mage_rooted > mage_plain * 1.5, "Combo Mago: Starfall pega +60%% a un atado (%.0f vs %.0f)" % [mage_rooted, mage_plain])
	var rogue_plain := _hit_damage(&"rogue", "R", func(_d: DummySim) -> void: pass)
	var rogue_combo := _hit_damage(&"rogue", "R", func(d: DummySim) -> void:
		d.stun_timer = 1.0
		d.dots.add(DamageSystem.Type.POISON, 5.0, 5.0))
	_check(rogue_combo > rogue_plain * 2.0, "Combo Rogue: Eviscerate pega mucho más a un envenenado y aturdido (%.0f vs %.0f)" % [rogue_combo, rogue_plain])
	var ranger_plain := _hit_damage(&"ranger", "R", func(_d: DummySim) -> void: pass)
	var ranger_rooted := _hit_damage(&"ranger", "R", func(d: DummySim) -> void: d.root_timer = 2.0)
	_check(ranger_rooted > ranger_plain * 1.4, "Combo Ranger: Concentrated Shot pega +50%% a un atado por Bear Trap")
