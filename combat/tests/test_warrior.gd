## Test de los datos canónicos del Warrior (WarriorKit) y de las fórmulas base.
##
##   godot --headless --path . --script combat/tests/test_warrior.gd
##
## Sale con código 0 si todo pasa, 1 si algo falla.
extends SceneTree

const SkillScript: GDScript = preload("res://combat/skill.gd")
const SkillRunnerScript: GDScript = preload("res://combat/skill_runner.gd")
const StatsScript: GDScript = preload("res://combat/stats.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior (Reflections - Warrior data) ==")

	_test_identity_and_resource()
	_test_basics()
	_test_passive()
	_test_special_and_ultimate()
	_test_skill_book()
	_test_stats_formulas()
	_test_skill_runner()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_identity_and_resource() -> void:
	_check(WarriorKit.CLASS_ID == "warrior", "class id is warrior")
	_check(WarriorKit.CLASS_NAME == "Warrior", "class display name is Warrior")
	_check(WarriorKit.RESOURCE_NAME == "Rage", "class resource is Rage")
	_check(is_equal_approx(WarriorKit.MAX_RAGE, 100.0), "Rage caps at 100")

	var rage = WarriorKit.create_rage_resource()
	_check(rage != null, "rage resource is created")
	_check(is_zero_approx(rage.get_current()), "Rage starts empty")
	_check(is_equal_approx(rage.max_amount, 100.0), "rage resource max is 100")
	_check(rage.resource_name == "Rage", "rage resource keeps its name")


func _test_basics() -> void:
	var basics := WarriorKit.get_basics()
	_check(basics.has("M1") and basics.has("M2"), "M1 and M2 exist")

	var m1: Dictionary = basics["M1"]
	var block: Dictionary = basics["M2"]
	var m2: Dictionary = WarriorKit.PIERCING_THRUST  # el M2 original (estocada) ahora es la skill Q
	_check(String(m1["slot"]) == "M1", "M1 is bound to slot M1")
	_check(String(block["slot"]) == "M2", "M2 is bound to slot M2")
	_check(String(m1["kind"]) == "basic" and String(block["kind"]) == "defense", "M1 is basic and M2 is the class defense")
	_check(bool(m1["implemented"]) and bool(block["implemented"]), "M1 and M2 are implemented")

	for skill: Dictionary in [m1, m2]:
		_check(float(skill["windup"]) > 0.0, "%s has windup" % skill["name"])
		_check(float(skill["active"]) > 0.0, "%s has active frames" % skill["name"])
		_check(float(skill["recovery"]) > 0.0, "%s has recovery" % skill["name"])
		_check(float(skill["range"]) > 0.0, "%s has range" % skill["name"])
		if String(skill["cast"]) == "melee":
			_check(float(skill["arc"]) > 0.0, "%s has an arc" % skill["name"])
		else:
			_check(float(skill["width"]) > 0.0, "%s has a line width" % skill["name"])
		_check(_first_mult(skill) > 0.0, "%s deals damage" % skill["name"])
		_check(float(skill["rage_gain"]) > 0.0, "%s generates Rage" % skill["name"])

	var m1_total := float(m1["windup"]) + float(m1["active"]) + float(m1["recovery"])
	var m2_total := float(m2["windup"]) + float(m2["active"]) + float(m2["recovery"])
	_check(m2_total > m1_total, "Piercing Thrust is slower than Heavy Strikes")
	_check(_first_mult(m2) > _first_mult(m1), "Piercing Thrust hits harder than Heavy Strikes")
	_check(float(m1["rage_gain"]) >= float(m2["rage_gain"]), "Heavy Strikes generates at least as much Rage")

	basics["M1"]["name"] = "mutated"
	_check(WarriorKit.M1["name"] == "Heavy Strikes", "get_basics returns a defensive copy")


func _test_passive() -> void:
	var passive := WarriorKit.get_passive()
	_check(bool(passive["implemented"]), "Last Stand is implemented")
	_check(String(passive["name"]) == "Last Stand", "passive keeps its design name")
	_check(is_equal_approx(float(passive["threshold"]), 0.30), "passive threshold is 30% health")
	_check(is_equal_approx(float(passive["damage_bonus"]), 1.50), "passive grants +50% damage")


func _test_special_and_ultimate() -> void:
	_check(String(WarriorKit.M2["id"]) == "block" and String(WarriorKit.M2["cast"]) == "guard", "M2 is Block (held guard)")
	_check(float(WarriorKit.M2["perfect_window"]) > 0.0 and float(WarriorKit.M2["cost"]) == 0.0, "Block has a perfect-parry window and costs no Rage")
	_check(bool(WarriorKit.SPECIAL["selectable"]), "Parry can join the loadout")
	_check(String(WarriorKit.ULTIMATE["id"]) == "bladestorm", "Ultimate is Bladestorm")
	_check(float(WarriorKit.ULTIMATE["cooldown"]) >= 60.0, "Ultimate has a 1 minute cooldown")
	_check(is_equal_approx(float(WarriorKit.ULTIMATE["cost"]), 40.0), "Bladestorm costs 40 Rage")
	_check(bool(WarriorKit.ULTIMATE["implemented"]), "Ultimate is playable")
	_check(bool(WarriorKit.ULTIMATE["selectable"]), "Ultimate can join the loadout")


func _test_skill_book() -> void:
	var book := WarriorKit.get_skill_book()
	_check(book.size() == 9, "Skill Book has 9 entries")

	var seen: Dictionary = {}
	for entry: Dictionary in book:
		var id := String(entry["id"])
		_check(not seen.has(id), "skill id is unique: %s" % id)
		seen[id] = true
		for key: String in ["name", "role", "description"]:
			_check(not String(entry[key]).is_empty(), "%s has %s" % [id, key])
		_check(int(entry["cost"]) >= 0, "%s cost is non-negative" % id)
		_check(float(entry["cooldown"]) >= 0.0, "%s has a cooldown" % id)
		_check(bool(entry["implemented"]), "%s is implemented" % id)

	_check(WarriorKit.all_ids().size() == 9, "all_ids returns the 9 ids")

	_check(WarriorKit.get_pool().size() == 7, "the pool is the 7 selectable abilities")
	_check(WarriorKit.SELECTABLE_SLOTS.size() == 6, "the loadout has six selectable slots (Shift, Q, E, 1, 2, R)")

	var loadout := WarriorKit.default_loadout()
	_check(loadout.size() == 6, "the default loadout is complete")
	for slot: String in WarriorKit.SELECTABLE_SLOTS:
		if String(loadout[slot]) != "":  # E y 2 quedan libres para skills futuras del Warrior
			_check(WarriorKit.has_ability(StringName(String(loadout[slot]))), "%s holds a real ability" % slot)
	_check(WarriorKit.sanitize_loadout({"SHIFT": &"bogus"})["SHIFT"] == WarriorKit.DEFAULT_LOADOUT["SHIFT"], "sanitize_loadout repairs bad ids")

	var roles := ""
	for entry: Dictionary in book:
		roles += String(entry["role"]) + " "
	for keyword: String in ["Daño", "Defensa", "Movilidad", "Control"]:
		_check(roles.contains(keyword), "Skill Book covers the %s role" % keyword)


func _test_stats_formulas() -> void:
	var stats: CharacterStats = StatsScript.new()
	stats.set_base_stat(&"strength", 20.0)
	stats.set_base_stat(&"attack_power_bonus", 10.0)
	stats.set_base_stat(&"weapon_min", 10.0)
	stats.set_base_stat(&"weapon_max", 20.0)
	stats.set_base_stat(&"weapon_speed", 2.0)
	stats.set_base_stat(&"crit_chance", 1.7)

	_check(is_equal_approx(stats.get_attack_power(), 50.0), "1 Strength = 2 Attack Power plus bonus")
	_check(is_equal_approx(stats.get_weapon_damage(), 15.0 + 50.0 / 14.0 * 2.0), "weapon damage formula")
	_check(is_equal_approx(stats.get_crit_chance(), 1.0), "crit chance is clamped to 1.0")


func _test_skill_runner() -> void:
	var skill: Skill = SkillScript.new()
	skill.id = &"warrior_test"
	skill.resource_generation = 8
	var rage = WarriorKit.create_rage_resource()
	var runner: SkillRunner = SkillRunnerScript.new()
	_check(runner.execute(skill, null, null, rage), "SkillRunner executes a data skill")
	_check(is_equal_approx(rage.get_current(), 8.0), "SkillRunner generates Rage")

	skill.resource_cost = 999
	_check(not runner.execute(skill, null, null, rage), "SkillRunner rejects unaffordable skills")


func _first_mult(skill: Dictionary) -> float:
	var raw: Variant = skill.get("damage_mult", 1.0)
	if raw is Array:
		var values: Array = raw
		return float(values[0]) if not values.is_empty() else 1.0
	return float(raw)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
