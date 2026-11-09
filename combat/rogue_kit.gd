## RogueKit — datos del Rogue (Assassin / Skirmisher). Energy, ataques caros: 2 y a esperar.
##
## Mismo contrato que WarriorKit/MageKit (ver ClassRegistry.REQUIRED).
class_name RogueKit
extends RefCounted

const RageScript := preload("res://combat/rage.gd")

const CLASS_ID: StringName = &"rogue"
const CLASS_NAME: String = "Rogue"
const RESOURCE_NAME: String = "Energy"
const MAX_RAGE: float = 100.0
## Recurso que se regenera por segundo; DELAY = segundos sin gastar antes de regenerar;
## OOC_MULT = multiplicador fuera de combate.
const RESOURCE_REGEN: float = 25.0
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

## M1: tajo rápido con una daga (alterna de mano). Básico spameable, sin coste.
const M1: Dictionary = {
	"id": &"twin_fang", "name": "Twin Fang", "short": "FANG", "slot": "M1",
	"kind": "basic", "role": "Daño rápido", "description": "Tajo rápido con una daga. Sin coste: se puede spamear.",
	"implemented": true, "selectable": false, "cast": "melee", "anim": "slash",
	"melee_clips": [0, 1],
	"windup": 0.09, "active": 0.08, "recovery": 0.14, "cooldown": 0.0, "cost": 0.0,
	"range": 70.0, "arc": 100.0, "damage_mult": 1.0, "rage_gain": 0.0, "move_factor": 0.5,
	"combo_reset_window": 0.85,
}

## M2: cruce de dagas, más daño.
const M2: Dictionary = {
	"id": &"cross_cut", "name": "Cross Cut", "short": "CUT", "slot": "M2",
	"kind": "basic", "role": "Daño", "description": "Saltas hacia delante y cruzas ambas dagas al aterrizar.",
	"implemented": true, "selectable": false, "cast": "leap_slam", "anim": "slash",
	"full_clip": {"clip": "class/mutant_jump_attack", "from": 0.32, "to": 0.58, "contact": 0.44, "late": true},
	"lunge": 110.0, "leap_height": 45.0,
	"windup": 0.15, "active": 0.30, "recovery": 0.25, "cooldown": 0.0, "cost": 60.0,
	"range": 85.0, "arc": 140.0, "damage_mult": 1.7, "rage_gain": 0.0, "move_factor": 0.2,
}

const SHADOWSTEP: Dictionary = {
	"id": &"shadowstep", "name": "Shadowstep", "short": "STEP", "slot": "SHIFT",
	"kind": "mobility", "role": "Movilidad", "description": "Teletransporte al punto apuntado. Si apuntas a un enemigo, apareces a su espalda y lo apuñalas (mantén para apuntar, suelta para lanzar).",
	"backstab_mult": 2.2, "backstab_range": 60.0,
	"implemented": true, "selectable": true, "cast": "teleport", "anim": "slash", "target": "ground",
	"damage_type": 6,  # DamageSystem.Type.SHADOW
	"windup": 0.06, "active": 0.03, "recovery": 0.10, "cooldown": 5.0, "cost": 25.0,
	"range": 220.0, "radius": 20.0, "damage_mult": 0.0, "evade": true, "move_factor": 0.0,
	"color": [0.45, 0.3, 0.7],
}

const VANISH: Dictionary = {
	"id": &"vanish", "name": "Vanish", "short": "VANISH", "slot": "Q",
	"kind": "stealth", "role": "Sigilo / escape", "description": "Te vuelves invisible 5 s: los enemigos no te ven, salvo que ataques.",
	"implemented": true, "selectable": true, "cast": "buff", "anim": "slash",
	"damage_type": 6,  # DamageSystem.Type.SHADOW
	"windup": 0.12, "active": 0.05, "recovery": 0.20, "cooldown": 14.0, "cost": 30.0,
	"damage_mult": 0.0, "invisible": 5.0, "move_factor": 0.8,
	"color": [0.45, 0.3, 0.7],
}

const FAN_OF_KNIVES: Dictionary = {
	"id": &"fan_of_knives", "name": "Fan of Knives", "short": "FAN", "slot": "R",
	"kind": "control", "role": "Daño en área", "description": "Como en WotLK: das una vuelta de 360° lanzando cuchillos; golpean a todos los cercanos (poco daño) y los envenenan.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "slash", "spin": true,
	"windup": 0.28, "active": 0.06, "recovery": 0.22, "cooldown": 5.0, "cost": 35.0,
	"radius": 120.0, "damage_mult": 0.7, "rage_gain": 0.0, "move_factor": 0.3,
	"effects": {"dot": {"damage_type": 4, "dps_mult": 0.5, "duration": 5.0}},
	"knives": 14,
}

const BACKSTAB: Dictionary = {
	"id": &"backstab", "name": "Backstab", "short": "STAB", "slot": "E",
	"kind": "burst", "role": "Burst", "description": "Puñalada potenciada de gran daño.",
	"implemented": true, "selectable": true, "cast": "melee", "anim": "slash",
	"melee_clips": [2],
	"windup": 0.18, "active": 0.08, "recovery": 0.30, "cooldown": 6.0, "cost": 55.0,
	"range": 70.0, "arc": 90.0, "damage_mult": 3.4, "rage_gain": 0.0, "move_factor": 0.3,
}

const DEATH_SENTENCE: Dictionary = {
	"id": &"death_sentence", "name": "Death Sentence", "short": "DEATH", "slot": "F",
	"kind": "ultimate", "role": "Ultimate / stun", "description": "Ultimate: te lanzas sobre el objetivo y lo ejecutas con un golpe brutal que aturde 2 s.",
	"implemented": true, "selectable": true, "cast": "leap_slam", "anim": "slash",
	"full_clip": {"clip": "ual2/Sword_Heavy_Combo", "from": 0.52, "to": 0.80, "contact": 0.63, "late": true},
	"lunge": 130.0, "leap_height": 20.0,
	"windup": 0.20, "active": 0.25, "recovery": 0.40, "cooldown": 1.0, "cost": 0.0, "charge": 100.0,
	"range": 95.0, "arc": 110.0, "damage_mult": 5.0, "effects": {"stun": 2.0},
	"rage_gain": 0.0, "move_factor": 0.2,
}

## Pasiva: a vida baja, más daño y velocidad.
const PASSIVE: Dictionary = {
	"id": &"cornered", "name": "Cornered", "slot": "PASSIVE", "kind": "passive",
	"role": "Pasiva", "description": "Al bajar del 30% de vida, +25% de daño y +30% de velocidad durante 5 s.",
	"implemented": true, "threshold": 0.30, "damage_bonus": 1.25, "speed_bonus": 1.30,
	"duration": 5.0, "cooldown": 12.0,
}

const SPECIAL: Dictionary = SHADOWSTEP
const ULTIMATE: Dictionary = DEATH_SENTENCE

const DEFAULT_LOADOUT: Dictionary = {
	"SHIFT": &"shadowstep", "Q": &"vanish", "E": &"backstab", "R": &"fan_of_knives", "F": &"death_sentence",
}

const ALL_ABILITIES: Array = [M1, M2, SHADOWSTEP, VANISH, BACKSTAB, FAN_OF_KNIVES, DEATH_SENTENCE]
const POOL_ABILITIES: Array = [SHADOWSTEP, VANISH, BACKSTAB, FAN_OF_KNIVES, DEATH_SENTENCE]


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
