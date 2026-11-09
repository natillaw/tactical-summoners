## WarriorKit — datos canónicos del Warrior de Combat Tower.
##
## Esta clase es la única fuente de verdad de las 7 habilidades del kit y de la
## pasiva Last Stand. La simulación (game/sim/warrior_sim.gd) lee estos
## diccionarios; no tiene números de combate hardcodeados.
##
## Slots fijos:
##   LMB   → Heavy Strikes   (combo de 3 golpes)
##   RMB   → Piercing Thrust (estocada lineal)
## Slots seleccionables (loadout por defecto):
##   SHIFT → Combat Roll
##   Q     → Parry
##   E     → Charge
##   R     → Seismic Break
##   F     → Bladestorm (ultimate)
##
## Sin variantes, sin builds: el jugador elige cuándo usar cada habilidad.
class_name WarriorKit
extends RefCounted

const RageScript := preload("res://combat/rage.gd")

const CLASS_ID: StringName = &"warrior"
const CLASS_NAME: String = "Warrior"
const RESOURCE_NAME: String = "Rage"
const MAX_RAGE: float = 100.0
const ULTIMATE_COST: float = 100.0
const SPECIAL_COST: float = 30.0

const SLOT_M1 := "M1"
const SLOT_M2 := "M2"
const SELECTABLE_SLOTS: Array = ["SHIFT", "Q", "E", "R", "F"]
const SLOT_ORDER: Array = ["M1", "M2", "SHIFT", "Q", "E", "R", "F"]

const ACTION_KEYS := {
	"M1": "m1",
	"M2": "m2",
	"SHIFT": "shift",
	"Q": "q",
	"E": "e",
	"R": "r",
	"F": "f",
}

const SLOT_LABELS := {
	"M1": "LMB",
	"M2": "RMB",
	"SHIFT": "SHIFT",
	"Q": "Q",
	"E": "E",
	"R": "R",
	"F": "F",
}

## M1: combo de tres golpes. El multiplicador se indexa con combo_index.
const M1: Dictionary = {
	"id": &"heavy_strikes",
	"name": "Heavy Strikes",
	"short": "STRIKE",
	"slot": "M1",
	"kind": "basic",
	"role": "Daño / presión",
	"description": "Combo de tres golpes pesados. El tercero golpea más fuerte.",
	"implemented": true,
	"selectable": false,
	"cast": "melee",
	"anim": "slash",
	"windup": 0.16,
	"active": 0.12,
	"recovery": 0.18,
	"cooldown": 0.0,
	"cost": 0.0,
	"range": 80.0,
	"arc": 120.0,
	"damage_mult": [1.0, 1.25, 1.6],
	"rage_gain": 12.0,
	"move_factor": 0.35,
	"combo_reset_window": 0.85,
	"vfx": "melee/sword-slash",
	"finisher_vfx": "melee/heavy-cleave",
	"impact_vfx": "impacts/hit-spark",
	"vfx_scale": 0.58,
	"vfx_speed": 1.35,
	"finisher_scale": 0.66,
	"finisher_speed": 1.55,
	"impact_scale": 0.55,
	"impact_speed": 1.30,
	"sfx": "slash",
}

## M2: estocada lineal, más alcance y daño que M1.
const M2: Dictionary = {
	"id": &"piercing_thrust",
	"name": "Piercing Thrust",
	"short": "THRUST",
	"slot": "M2",
	"kind": "basic",
	"role": "Daño / alcance",
	"description": "Estocada estrecha y precisa que atraviesa a los enemigos en línea.",
	"implemented": true,
	"selectable": false,
	"cast": "line",
	"anim": "thrust",
	"windup": 0.18,
	"active": 0.10,
	"recovery": 0.24,
	"cooldown": 1.5,
	"cost": 0.0,
	"range": 125.0,
	"width": 34.0,
	"damage_mult": 1.8,
	"rage_gain": 10.0,
	"move_factor": 0.15,
	"vfx": "melee/thrust",
	"impact_vfx": "impacts/hit-spark",
	"vfx_scale": 0.70,
	"vfx_speed": 1.40,
	"impact_scale": 0.50,
	"impact_speed": 1.35,
	"sfx": "thrust",
}

## SHIFT: movilidad defensiva con iframes.
const COMBAT_ROLL: Dictionary = {
	"id": &"combat_roll",
	"name": "Combat Roll",
	"short": "ROLL",
	"slot": "SHIFT",
	"kind": "mobility",
	"role": "Movilidad / evasión",
	"description": "Rueda en la dirección de movimiento con una ventana breve de invulnerabilidad.",
	"implemented": true,
	"selectable": true,
	"cast": "dash",
	"anim": "run",
	"windup": 0.04,
	"active": 0.24,
	"recovery": 0.10,
	"cooldown": 4.0,
	"cost": 15.0,
	"distance": 190.0,
	"damage_mult": 0.0,
	"evade": true,
	"move_factor": 0.0,
	"vfx": "melee/spin-slash",
	"vfx_tint": [0.55, 0.78, 1.0, 0.85],
	"trail_vfx": "impacts/hit-spark",
	"impact_vfx": "",
	"vfx_scale": 0.55,
	"vfx_speed": 1.90,
	"trail_scale": 0.40,
	"trail_speed": 1.50,
	"trail_interval": 0.07,
	"sfx": "roll",
}

## Q: postura defensiva que desvía un ataque frontal y contraataca.
const PARRY: Dictionary = {
	"id": &"parry",
	"name": "Parry",
	"short": "PARRY",
	"slot": "Q",
	"kind": "counter",
	"role": "Defensa / contraataque",
	"description": "Desvía un ataque frontal durante una ventana breve y responde con un corte.",
	"implemented": true,
	"selectable": true,
	"cast": "counter",
	"anim": "slash",
	"windup": 0.06,
	"active": 0.45,
	"recovery": 0.22,
	"cooldown": 6.0,
	"cost": 20.0,
	"damage_mult": 0.0,
	"counter_mult": 1.8,
	"counter_range": 90.0,
	"counter_arc": 120.0,
	"counter_reduce": 1.0,
	"counter_effects": {},
	"move_factor": 0.0,
	"vfx": "impacts/parry",
	"vfx_scale": 0.62,
	"vfx_speed": 1.25,
	"guard_vfx": "holy/divine-shield",
	"guard_tint": [0.70, 0.86, 1.0, 0.90],
	"guard_scale": 0.65,
	"guard_speed": 1.15,
	"guard_lifetime": 0.60,
	"counter_vfx": "melee/sword-slash",
	"counter_scale": 0.62,
	"counter_speed": 1.40,
	"impact_vfx": "impacts/shield-block",
	"impact_scale": 0.50,
	"impact_speed": 1.35,
	"sfx": "parry",
}

## E: engage con daño y aturdimiento (1 s) al impactar.
const CHARGE: Dictionary = {
	"id": &"charge",
	"name": "Charge",
	"short": "CHARGE",
	"slot": "E",
	"kind": "mobility",
	"role": "Movilidad / iniciación",
	"description": "Carga hacia delante; el primer enemigo alcanzado recibe daño y queda aturdido 1 s.",
	"implemented": true,
	"selectable": true,
	"cast": "dash",
	"anim": "run",
	"windup": 0.10,
	"active": 0.22,
	"recovery": 0.20,
	"cooldown": 7.0,
	"cost": 0.0,
	"distance": 210.0,
	"radius": 46.0,
	"damage_mult": 1.5,
	"rage_gain": 20.0,
	"effects": {"stun": 1.0},
	"move_factor": 0.0,
	"vfx": "melee/thrust",
	"impact_vfx": "impacts/ground-slam",
	"vfx_scale": 0.66,
	"vfx_speed": 1.50,
	"trail_vfx": "impacts/hit-spark",
	"trail_scale": 0.45,
	"trail_speed": 1.50,
	"trail_interval": 0.05,
	"impact_scale": 0.52,
	"impact_speed": 1.90,
	"sfx": "charge",
}

## R: control de área con interrupción. Cuesta 30 Rage.
const SEISMIC_BREAK: Dictionary = {
	"id": &"seismic_break",
	"name": "Seismic Break",
	"short": "SEISMIC",
	"slot": "R",
	"kind": "control",
	"role": "Control / AoE",
	"description": "Apunta al suelo con la mira: saltas hasta ahí y golpeas con una onda que daña e interrumpe a los enemigos cercanos.",
	"implemented": true,
	"selectable": true,
	"cast": "leap_slam",
	"anim": "thrust",
	"full_clip": {"clip": "class/standing_melee_run_jump_attack", "from": 0.27, "to": 0.62, "contact": 0.46, "late": true},
	"leap_height": 75.0,
	"windup": 0.30,
	"active": 0.55,
	"recovery": 0.35,
	"cooldown": 9.0,
	"cost": 30.0,
	"target": "ground",
	"range": 260.0,
	"radius": 120.0,
	"damage_mult": 3.5,
	"rage_gain": 0.0,
	"effects": {"interrupt": true},
	"move_factor": 0.0,
	"vfx": "impacts/ground-slam",
	"impact_vfx": "nature/quake",
	"vfx_scale": 0.66,
	"vfx_speed": 1.70,
	"impact_scale": 0.80,
	"impact_speed": 1.50,
	"burst_vfx": "nature/earth-spike",
	"burst_scale": 0.50,
	"burst_speed": 1.30,
	"burst_count": 3,
	"burst_radius": 52.0,
	"sfx": "slam",
}

## F: ultimate. Gira con la espada y golpea repetidamente alrededor.
const BLADESTORM: Dictionary = {
	"id": &"bladestorm",
	"name": "Bladestorm",
	"short": "STORM",
	"slot": "F",
	"kind": "ultimate",
	"role": "Daño / AoE",
	"description": "Ultimate: giro de acero continuo que daña a todos los enemigos alrededor.",
	"implemented": true,
	"selectable": true,
	"cast": "aoe",
	"anim": "slash",
	"windup": 0.20,
	"active": 1.6,
	"recovery": 0.35,
	"cooldown": 1.0,
	"cost": 40.0,
	"charge": 100.0,
	"radius": 105.0,
	"damage_mult": 0.75,
	"damage_interval": 0.20,
	"rage_gain": 6.0,
	"move_factor": 0.55,
	"vfx": "melee/spin-slash",
	"vfx_tint": [1.0, 0.86, 0.55, 0.90],
	"impact_vfx": "impacts/hit-spark",
	"vfx_scale": 0.82,
	"vfx_speed": 1.55,
	"tick_vfx_scale": 0.68,
	"tick_vfx_speed": 1.80,
	"impact_scale": 0.45,
	"impact_speed": 1.40,
	"sfx": "bladestorm",
}

## Pasiva: Last Stand. A vida baja gana daño y velocidad temporalmente.
const PASSIVE: Dictionary = {
	"id": &"last_stand",
	"name": "Last Stand",
	"slot": "PASSIVE",
	"kind": "passive",
	"role": "Pasiva",
	"description": "Al bajar del 30% de vida, gana +50% de daño y +25% de velocidad durante 5 s.",
	"implemented": true,
	"threshold": 0.30,
	"damage_bonus": 1.50,
	"speed_bonus": 1.25,
	"duration": 5.0,
	"cooldown": 10.0,
}

## Alias de compatibilidad: la Special del kit actual es Parry y la Ultimate
## es Bladestorm. El loadout sólo expone las cinco habilidades seleccionables.
const SPECIAL: Dictionary = PARRY
const ULTIMATE: Dictionary = BLADESTORM

const DEFAULT_LOADOUT: Dictionary = {
	"SHIFT": &"combat_roll",
	"Q": &"parry",
	"E": &"charge",
	"R": &"seismic_break",
	"F": &"bladestorm",
}

const ALL_ABILITIES: Array = [M1, M2, COMBAT_ROLL, PARRY, CHARGE, SEISMIC_BREAK, BLADESTORM]
const POOL_ABILITIES: Array = [COMBAT_ROLL, PARRY, CHARGE, SEISMIC_BREAK, BLADESTORM]


static func create_rage_resource() -> Rage:
	var resource: Rage = RageScript.new()
	resource.resource_name = RESOURCE_NAME
	resource.current_amount = 0.0
	resource.max_amount = MAX_RAGE
	resource.min_amount = 0.0
	return resource


static func get_basics() -> Dictionary:
	return {"M1": M1.duplicate(true), "M2": M2.duplicate(true)}


static func get_passive() -> Dictionary:
	return PASSIVE.duplicate(true)


static func get_special() -> Dictionary:
	return SPECIAL.duplicate(true)


static func get_ultimate() -> Dictionary:
	return ULTIMATE.duplicate(true)


## Las 7 habilidades del kit (básicas incluidas), para datos y tests.
static func get_skill_book() -> Array:
	var book: Array = []
	for entry: Dictionary in ALL_ABILITIES:
		book.append(entry.duplicate(true))
	return book


## Las 5 cartas que el loadout puede asignar a SHIFT/Q/E/R/F.
static func get_pool() -> Array:
	var pool: Array = []
	for entry: Dictionary in POOL_ABILITIES:
		pool.append(entry.duplicate(true))
	return pool


static func all_ids() -> Array:
	var ids: Array = []
	for entry: Dictionary in ALL_ABILITIES:
		ids.append(entry["id"])
	return ids


static func pool_ids() -> Array:
	var ids: Array = []
	for entry: Dictionary in POOL_ABILITIES:
		ids.append(entry["id"])
	return ids


static func ability_by_id(id: StringName) -> Dictionary:
	for entry: Dictionary in ALL_ABILITIES:
		if entry["id"] == id:
			return entry.duplicate(true)
	return {}


static func has_ability(id: StringName) -> bool:
	return not ability_by_id(id).is_empty()


## Habilidad por defecto de un slot. La simulación usa su loadout real.
static func ability_for_slot(slot: String) -> Dictionary:
	if slot == "M1":
		return M1.duplicate(true)
	if slot == "M2":
		return M2.duplicate(true)
	var id: StringName = DEFAULT_LOADOUT.get(slot, &"")
	if id == &"":
		return {}
	return ability_by_id(id)


static func default_loadout() -> Dictionary:
	return DEFAULT_LOADOUT.duplicate(true)


static func loadout_to_strings(loadout: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot: String in SELECTABLE_SLOTS:
		out[slot] = String(loadout.get(slot, DEFAULT_LOADOUT[slot]))
	return out


## Valida y completa un loadout leído de disco. Sólo admite cartas del pool.
static func sanitize_loadout(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot: String in SELECTABLE_SLOTS:
		var id := StringName(String(raw.get(slot, String(DEFAULT_LOADOUT[slot]))))
		if not POOL_ABILITIES.any(func(entry: Dictionary) -> bool: return entry["id"] == id):
			id = DEFAULT_LOADOUT[slot]
		out[slot] = id
	return out


static func slot_label(slot: String) -> String:
	return String(SLOT_LABELS.get(slot, slot))


static func cost_label(ability: Dictionary) -> String:
	var cost := float(ability.get("cost", 0.0))
	if String(ability.get("kind", "")) == "ultimate":
		if cost > 0.0:
			return "%dR+ULT" % roundi(cost)
		return "ULT"
	if cost > 0.0:
		return "%d R" % roundi(cost)
	return ""
