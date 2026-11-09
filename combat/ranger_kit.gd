## RangerKit — datos del Ranger (arquero). Energy, proyectiles físicos y trampas.
##
## Mismo contrato que WarriorKit/MageKit (ver ClassRegistry.REQUIRED).
class_name RangerKit
extends RefCounted

const RageScript := preload("res://combat/rage.gd")

const CLASS_ID: StringName = &"ranger"
const CLASS_NAME: String = "Ranger"
const RESOURCE_NAME: String = "Energy"
const MAX_RAGE: float = 100.0
## Recurso que se regenera por segundo; DELAY = segundos sin gastar antes de regenerar;
## OOC_MULT = multiplicador fuera de combate.
const RESOURCE_REGEN: float = 14.0
const RESOURCE_REGEN_DELAY: float = 0.0
const RESOURCE_OOC_MULT: float = 1.0
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

## M1: disparo único de cadencia estable (no cuesta Energy).
const M1: Dictionary = {
	"id": &"quick_shot", "name": "Quick Shot", "short": "SHOT", "slot": "M1",
	"kind": "basic", "role": "Daño a distancia", "description": "Disparo único de cadencia estable.",
	"implemented": true, "selectable": false, "cast": "projectile", "anim": "cast",
	"clip": {"anim": "class/standing_aim_recoil", "start": 0.0, "contact": 0.2, "end": 0.65},
	"windup": 0.22, "active": 0.05, "recovery": 0.20, "cooldown": 0.0, "cost": 0.0,
	"speed": 600.0, "range": 560.0, "hit_radius": 8.0, "damage_mult": 0.9,
	"rage_gain": 0.0, "move_factor": 0.6, "color": [1.0, 0.92, 0.65],
}

## M2: disparo cargado, más potente, más alcance y atraviesa. La carga frena el movimiento.
const M2: Dictionary = {
	"id": &"charged_shot", "name": "Charged Shot", "short": "CHARGE", "slot": "M2",
	"kind": "basic", "role": "Daño / penetración", "description": "Carga el arco: flecha potente que atraviesa enemigos.",
	"implemented": true, "selectable": false, "cast": "projectile", "anim": "cast",
	"clip": {"anim": "class/standing_aim_overdraw", "start": 0.7, "contact": 1.33, "end": 1.8},
	"windup": 0.65, "active": 0.05, "recovery": 0.30, "cooldown": 1.0, "cost": 20.0,
	"speed": 800.0, "range": 760.0, "hit_radius": 10.0, "damage_mult": 2.4, "pierce": true,
	"rage_gain": 0.0, "move_factor": 0.15, "color": [1.0, 0.85, 0.4],
}

const EVASIVE_LEAP: Dictionary = {
	"id": &"evasive_leap", "name": "Evasive Leap", "short": "LEAP", "slot": "SHIFT",
	"kind": "mobility", "role": "Movilidad", "description": "Salto hacia atrás con invulnerabilidad breve.",
	"implemented": true, "selectable": true, "cast": "dash", "anim": "run", "dir": -1.0, "hop": 45.0, "fall_clip": "class/fall_a_loop",
	"windup": 0.03, "active": 0.20, "recovery": 0.12, "cooldown": 5.0, "cost": 20.0,
	"distance": 190.0, "damage_mult": 0.0, "evade": true, "move_factor": 0.0,
	"vfx_tint": [0.8, 0.9, 0.6, 0.8],
}

const MULTISHOT: Dictionary = {
	"id": &"multishot", "name": "Multishot", "short": "MULTI", "slot": "Q",
	"kind": "control", "role": "Daño en abanico", "description": "Tres flechas en abanico.",
	"implemented": true, "selectable": true, "cast": "projectile", "anim": "cast",
	"clip": {"anim": "class/standing_aim_recoil", "start": 0.0, "contact": 0.2, "end": 0.65},
	"windup": 0.30, "active": 0.05, "recovery": 0.25, "cooldown": 5.0, "cost": 25.0,
	"speed": 560.0, "range": 420.0, "hit_radius": 8.0, "damage_mult": 0.8, "count": 3, "spread": 14.0,
	"rage_gain": 0.0, "move_factor": 0.4, "color": [1.0, 0.92, 0.65],
}

const KICK: Dictionary = {
	"id": &"kick", "name": "Kick", "short": "KICK", "slot": "E",
	"kind": "control", "role": "Control / empuje", "description": "Patada que daña y empuja al enemigo lejos de ti.",
	"implemented": true, "selectable": true, "cast": "melee", "anim": "slash",
	"full_clip": {"clip": "class/standing_melee_kick", "from": 0.21, "to": 0.55, "contact": 0.35},
	"windup": 0.15, "active": 0.08, "recovery": 0.30, "cooldown": 7.0, "cost": 15.0,
	"range": 75.0, "arc": 110.0, "damage_mult": 0.8, "effects": {"knockback": 160.0},
	"rage_gain": 0.0, "move_factor": 0.2,
}

const VOLLEY: Dictionary = {
	"id": &"volley", "name": "Volley", "short": "VOLLEY", "slot": "R",
	"kind": "control", "role": "Daño en área", "description": "Apunta al suelo: lluvia de flechas.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "cast", "target": "ground",
	"clip": {"anim": "class/standing_draw_arrow", "start": 0.1, "contact": 0.33, "end": 0.7},
	"windup": 0.50, "active": 0.10, "recovery": 0.25, "cooldown": 12.0, "cost": 40.0,
	"range": 320.0, "radius": 120.0, "damage_mult": 3.0, "rage_gain": 0.0, "move_factor": 0.3,
}

const RAIN_OF_ARROWS: Dictionary = {
	"id": &"rain_of_arrows", "name": "Rain of Arrows", "short": "RAIN", "slot": "F",
	"kind": "ultimate", "role": "Ultimate", "description": "Ultimate: lluvia de flechas sobre un área enorme.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "cast", "target": "ground",
	"clip": {"anim": "class/standing_draw_arrow", "start": 0.1, "contact": 0.33, "end": 0.7},
	"windup": 0.80, "active": 0.10, "recovery": 0.35, "cooldown": 1.0, "cost": 0.0, "charge": 100.0,
	"range": 340.0, "radius": 170.0, "damage_mult": 5.5, "rage_gain": 0.0, "move_factor": 0.2,
}

## Pasiva: a vida baja, más daño y velocidad.
const PASSIVE: Dictionary = {
	"id": &"predators_instinct", "name": "Predator's Instinct", "slot": "PASSIVE", "kind": "passive",
	"role": "Pasiva", "description": "Al bajar del 30% de vida, +30% de daño y +25% de velocidad durante 5 s.",
	"implemented": true, "threshold": 0.30, "damage_bonus": 1.30, "speed_bonus": 1.25,
	"duration": 5.0, "cooldown": 12.0,
}

const SPECIAL: Dictionary = MULTISHOT
const ULTIMATE: Dictionary = RAIN_OF_ARROWS

const DEFAULT_LOADOUT: Dictionary = {
	"SHIFT": &"evasive_leap", "Q": &"multishot", "E": &"kick", "R": &"volley", "F": &"rain_of_arrows",
}

const ALL_ABILITIES: Array = [M1, M2, EVASIVE_LEAP, MULTISHOT, KICK, VOLLEY, RAIN_OF_ARROWS]
const POOL_ABILITIES: Array = [EVASIVE_LEAP, MULTISHOT, KICK, VOLLEY, RAIN_OF_ARROWS]


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
			return "%d+ULT" % roundi(cost)
		return "ULT"
	if cost > 0.0:
		return "%d" % roundi(cost)
	return ""
