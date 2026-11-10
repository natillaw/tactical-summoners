## Contrato de datos del Warrior contra los documentos de diseño.
##
##   godot --headless --path . --script tests/test_warrior_data.gd
##
## Verifica que WarriorKit siga siendo una traducción fiel del diseño del
## Warrior de Combat Tower: 7 habilidades, sin variantes/builds, costes y
## cooldowns válidos, y los números clave de la identidad Warrior.
extends SceneTree

const CLASES_DOC := "res://docs/design/CLASES_V2.md"
const EVOLUCIONES_DOC := "res://docs/design/EVOLUCIONES_V1.md"
const WARRIOR_DOC := "res://docs/design/WARRIOR.md"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior_data (design contract) ==")

	_test_design_documents()
	_test_skill_book_shape()
	_test_ability_schema()
	_test_pool_and_loadout()
	_test_no_variants()
	_test_identity_numbers()
	_test_roles()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_design_documents() -> void:
	var clases := _read(CLASES_DOC)
	_check(not clases.is_empty(), "CLASES_V2.md existe y es legible")
	_check(clases.contains("Warrior"), "el doc de diseño define al Warrior")

	var warrior_doc := _read(WARRIOR_DOC)
	_check(not warrior_doc.is_empty(), "WARRIOR.md existe y es legible")
	_check(warrior_doc.contains("Heavy Strikes") or warrior_doc.contains("Piercing Thrust"), "WARRIOR.md documenta habilidades del Warrior")


func _test_skill_book_shape() -> void:
	var book := WarriorKit.get_skill_book()
	_check(book.size() == 6, "exactamente 6 habilidades del kit de Combat Tower")

	var ids: Dictionary = {}
	for entry: Dictionary in book:
		var id := String(entry["id"])
		_check(not ids.has(id), "id duplicado: %s" % id)
		ids[id] = true
		_check(id == id.to_lower() and not id.contains(" "), "%s usa snake_case" % id)
		_check(not String(entry["name"]).is_empty(), "%s tiene nombre" % id)
		_check(not String(entry["role"]).is_empty(), "%s tiene rol" % id)
		_check(not String(entry["description"]).is_empty(), "%s tiene descripción" % id)
		_check(int(entry["cost"]) >= 0 and int(entry["cost"]) <= int(WarriorKit.MAX_RAGE), "%s cuesta Rage válido" % id)
		_check(float(entry["cooldown"]) >= 0.0, "%s tiene cooldown" % id)
		_check(bool(entry["implemented"]), "%s está implementado" % id)

	_check(WarriorKit.all_ids().size() == 6, "all_ids devuelve los 6 ids")


func _test_ability_schema() -> void:
	var abilities: Array = WarriorKit.get_pool()

	var seen: Dictionary = {}
	for entry: Dictionary in abilities:
		var id := String(entry["id"])
		_check(not seen.has(id), "pool id único: %s" % id)
		seen[id] = true
		for key: String in ["name", "role", "description", "cast", "vfx", "anim"]:
			_check(not String(entry.get(key, "")).is_empty(), "%s define %s" % [id, key])
		_check(float(entry["windup"]) >= 0.0, "%s tiene windup" % id)
		_check(float(entry["active"]) > 0.0, "%s tiene active frames" % id)
		_check(float(entry["recovery"]) >= 0.0, "%s tiene recovery" % id)
		_check(float(entry["move_factor"]) >= 0.0 and float(entry["move_factor"]) <= 1.0, "%s move factor sano" % id)
		var dm = entry.get("damage_mult", 0.0)
		var dm_ok := true
		if dm is Array:
			for v in dm:
				dm_ok = dm_ok and float(v) >= 0.0
		else:
			dm_ok = float(dm) >= 0.0
		_check(dm_ok, "%s damage multiplier no-negativo" % id)
		_check(WarriorKit.has_ability(StringName(id)), "%s alcanzable por id" % id)

		# Rol del pool: las habilidades del pool (M1/M2) no tienen range/width/radius
		# obligatorias salvo las que las usan.

	for entry: Dictionary in WarriorKit.get_pool():
		var id := String(entry["id"])
		var cast := String(entry.get("cast", ""))
		match cast:
			"melee":
				_check(float(entry["range"]) > 0.0 and float(entry["arc"]) > 0.0, "%s tiene rango y arco" % id)
			"line":
				_check(float(entry["range"]) > 0.0 and float(entry["width"]) > 0.0, "%s tiene largo y ancho" % id)
			"aoe", "leap_slam":
				_check(float(entry["radius"]) > 0.0, "%s tiene radio de área" % id)
			"dash":
				_check(float(entry["distance"]) > 0.0, "%s tiene distancia de dash" % id)
			"counter":
				_check(float(entry["counter_mult"]) > 0.0, "%s tiene multiplicador de contra" % id)
			"buff":
				_check(entry.has("buff") or entry.has("guard"), "%s aplica buff o guarda" % id)
			_:
				_check(false, "%s usa un tipo de cast conocido" % id)


func _test_pool_and_loadout() -> void:
	var pool := WarriorKit.get_pool()
	_check(pool.size() == 4, "el pool son las 4 habilidades seleccionables")

	var seen: Dictionary = {}
	for entry: Dictionary in pool:
		var id := String(entry["id"])
		_check(not seen.has(id), "pool id único: %s" % id)
		seen[id] = true
		_check(bool(entry["implemented"]), "%s implementado" % id)

	_check(WarriorKit.pool_ids().size() == 4, "pool_ids devuelve los 4 ids")
	_check(WarriorKit.SELECTABLE_SLOTS.size() == 6, "hay seis slots seleccionables")
	_check(WarriorKit.SLOT_ORDER.size() == 8, "el orden del HUD es M1, M2 y los seis slots")

	var default := WarriorKit.default_loadout()
	_check(default.size() == 6, "el loadout por defecto cubre los seis slots")
	for slot: String in WarriorKit.SELECTABLE_SLOTS:
		_check(default.has(slot), "loadout por defecto tiene %s" % slot)
		if String(default[slot]) != "":  # E y 2 quedan libres para skills futuras
			_check(WarriorKit.has_ability(StringName(String(default[slot]))), "%s contiene una habilidad real" % slot)

	_check(StringName(String(default["SHIFT"])) == &"charge", "SHIFT por defecto es Charge")
	_check(StringName(String(default["Q"])) == &"piercing_thrust", "Q por defecto es Piercing Thrust")
	_check(String(default["E"]) == "", "E está libre para una skill futura")
	_check(StringName(String(default["R"])) == &"seismic_break", "R por defecto es Seismic Break")
	_check(StringName(String(default["F"])) == &"bladestorm", "F por defecto es Bladestorm")

	var dirty := {"SHIFT": &"does_not_exist", "Q": &"seismic_break"}
	var clean := WarriorKit.sanitize_loadout(dirty)
	_check(clean.size() == 6, "sanitize_loadout rellena todos los slots")
	_check(clean["SHIFT"] == WarriorKit.DEFAULT_LOADOUT["SHIFT"], "ids inválidas caen al default")
	_check(clean["Q"] == &"seismic_break", "ids válidas se preservan")
	_check(clean["F"] == WarriorKit.DEFAULT_LOADOUT["F"], "slots faltantes caen al default")

	var strings := WarriorKit.loadout_to_strings(default)
	_check(String(strings["F"]) == "bladestorm", "loadout_to_strings serializa ids")
	_check(WarriorKit.slot_label("SHIFT") == "SHIFT", "etiquetas de slot legibles")
	_check(WarriorKit.ability_by_id(&"not_real").is_empty(), "habilidades desconocidas resuelven a vacío")

	var copy := WarriorKit.ability_by_id(&"charge")
	copy["name"] = "mutated"
	_check(String(WarriorKit.ability_by_id(&"charge")["name"]) == "Charge", "ability_by_id devuelve una copia")


func _test_no_variants() -> void:
	var entries: Array = WarriorKit.get_pool()

	var implemented: int = 0
	for entry: Dictionary in entries:
		implemented += 1 if bool(entry["implemented"]) else 0
	_check(implemented == 4, "las 4 habilidades del pool están implementadas")
	_check(bool(WarriorKit.PASSIVE["implemented"]), "Last Stand está implementado")
	_check(bool(WarriorKit.SPECIAL["implemented"]), "la Special es jugable")
	_check(bool(WarriorKit.ULTIMATE["implemented"]), "el Ultimate es jugable")

	for entry: Dictionary in entries:
		_check(not entry.has("variant") and not entry.has("variants"), "%s no tiene campo variant" % entry["id"])
		_check(not entry.has("build") and not entry.has("builds"), "%s no tiene campo build" % entry["id"])


func _test_identity_numbers() -> void:
	_check(WarriorKit.CLASS_ID == "warrior", "class id es warrior")
	_check(WarriorKit.CLASS_NAME == "Warrior", "nombre de clase es Warrior")
	_check(WarriorKit.RESOURCE_NAME == "Rage", "recurso de clase es Rage")
	_check(is_equal_approx(WarriorKit.MAX_RAGE, 100.0), "Rage se topa en 100")
	_check(is_equal_approx(float(WarriorKit.SEISMIC_BREAK["cost"]), 30.0), "Seismic Break cuesta 30 Rage")
	_check(is_equal_approx(float(WarriorKit.COMBAT_ROLL["cost"]), 15.0), "Combat Roll cuesta 15 Rage")
	_check(is_equal_approx(float(WarriorKit.PARRY["cost"]), 20.0), "Parry cuesta 20 Rage")
	_check(is_zero_approx(float(WarriorKit.CHARGE["cost"])), "Charge es gratis")
	_check(is_zero_approx(float(WarriorKit.M1["cost"])), "Heavy Strikes es gratis")
	_check(is_zero_approx(float(WarriorKit.M2["cost"])), "Piercing Thrust es gratis")
	_check(is_equal_approx(float(WarriorKit.BLADESTORM["cost"]), 40.0), "Bladestorm cuesta 40 Rage además de la Ultimate")


func _test_roles() -> void:
	var book := WarriorKit.get_skill_book()
	var roles := ""
	for entry: Dictionary in book:
		roles += String(entry["role"]) + " "
	for keyword: String in ["Daño", "Defensa", "Movilidad", "Control"]:
		_check(roles.contains(keyword), "Skill Book cubre el rol %s" % keyword)


func _read(path: String) -> String:
	var f := FileAccess.get_file_as_string(path)
	return f if f != null else ""


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
