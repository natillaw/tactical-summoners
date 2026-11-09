## MageKit — datos canónicos del Mago.
##
## Esta clase es la única fuente de verdad de las 7 habilidades del kit y de la
## pasiva Last Stand. La simulación (game/sim/warrior_sim.gd) lee estos
## diccionarios; no tiene números de combate hardcodeados.
##
## Solo magia ARCANA (las subclases pyromancer, frostmage... añadirán su elemento).
## Slots: LMB Arcane Bolt, RMB Arcane Orb; SHIFT Blink, Q Arcane Pulse,
## E Arcane Rift, R Starfall, F Arcane Surge (ultimate). Skills de suelo (Smite): E, R, F.
class_name MageKit
extends RefCounted

const RageScript := preload("res://combat/rage.gd")

const CLASS_ID: StringName = &"mage"
const CLASS_NAME: String = "Mago"
const RESOURCE_NAME: String = "Mana"
const MAX_RAGE: float = 100.0
## Regeneración lenta: 1.5/s tras 2 s sin gastar maná; x4 fuera de combate (5 s sin golpes).
const RESOURCE_REGEN: float = 1.5
const RESOURCE_REGEN_DELAY: float = 2.0
const RESOURCE_OOC_MULT: float = 4.0
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

## M1: proyectil arcano sin cooldown.
const M1: Dictionary = {
	"id": &"arcane_bolt",
	"clips": [
		{"name": "standing_1h_magic_attack_01", "start": 0.5, "contact": 0.8, "end": 1.3},
		{"name": "standing_1h_magic_attack_02", "start": 0.3, "contact": 0.53, "end": 1.0},
		{"name": "standing_1h_magic_attack_03", "start": 0.5, "contact": 0.8, "end": 1.4},
	], "name": "Arcane Bolt", "short": "BOLT", "slot": "M1",
	"kind": "basic", "role": "Daño a distancia", "description": "Disparo arcano sin cooldown.",
	"implemented": true, "selectable": false, "cast": "projectile", "anim": "cast",
	"damage_type": 7,  # DamageSystem.Type.ARCANE
	"windup": 0.20, "active": 0.05, "recovery": 0.18, "cooldown": 0.0, "cost": 4.0,
	"speed": 520.0, "range": 480.0, "hit_radius": 10.0, "damage_mult": 0.9,
	"rage_gain": 0.0, "move_factor": 0.6, "color": [0.7, 0.5, 1.0],
}

## M2: bola de fuego con quemadura.
const M2: Dictionary = {
	"id": &"arcane_orb",
	"clip": {"name": "standing_2h_magic_attack_01", "start": 0.4, "contact": 1.13, "end": 1.7}, "name": "Arcane Orb", "short": "ORB", "slot": "M2",
	"kind": "basic", "role": "Daño / quemadura", "description": "Cast 0.9 s (quieto): orbe arcano lento que corroe al objetivo.",
	"implemented": true, "selectable": false, "cast": "projectile", "cast_bar": true, "anim": "cast",
	"damage_type": 7,  # DamageSystem.Type.ARCANE
	"windup": 0.9, "active": 0.05, "recovery": 0.25, "cooldown": 2.5, "cost": 10.0,
	"speed": 420.0, "range": 520.0, "hit_radius": 14.0, "damage_mult": 1.8,
	"effects": {"dot": {"damage_type": 7, "dps_mult": 0.35, "duration": 4.0}},
	"rage_gain": 0.0, "move_factor": 0.0, "color": [0.85, 0.55, 1.0],
}

const BLINK: Dictionary = {
	"id": &"blink",
	"clip": {"name": "standing_1h_cast_spell_01", "start": 0.3, "contact": 0.6, "end": 1.0},
	"name": "Blink", "short": "BLINK", "slot": "SHIFT",
	"kind": "mobility", "role": "Movilidad", "description": "Teletransporte: desapareces y apareces donde apuntes (mantén para apuntar, suelta para lanzar).",
	"implemented": true, "selectable": true, "cast": "teleport", "anim": "cast", "target": "ground",
	"damage_type": 7,  # DamageSystem.Type.ARCANE
	"windup": 0.14, "active": 0.04, "recovery": 0.12, "cooldown": 6.0, "cost": 15.0,
	"range": 280.0, "radius": 22.0, "damage_mult": 0.0, "evade": true, "move_factor": 0.0,
	"color": [0.75, 0.5, 1.0],
}

const ARCANE_PULSE: Dictionary = {
	"id": &"arcane_pulse",
	"clip": {"name": "standing_2h_magic_area_attack_01", "start": 0.95, "contact": 1.27, "end": 1.8}, "name": "Arcane Pulse", "short": "PULSE", "slot": "Q",
	"kind": "control", "role": "Control", "description": "Pulso arcano a tu alrededor: daña y ralentiza.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "cast",
	"damage_type": 7,  # DamageSystem.Type.ARCANE
	"windup": 0.30, "active": 0.10, "recovery": 0.25, "cooldown": 9.0, "cost": 25.0,
	"radius": 130.0, "damage_mult": 1.2, "effects": {"slow": {"factor": 0.5, "duration": 3.0}},
	"rage_gain": 0.0, "move_factor": 0.0,
}

const ARCANE_RIFT: Dictionary = {
	"id": &"arcane_rift",
	"clip": {"name": "standing_2h_cast_spell_01", "start": 0.33, "contact": 0.63, "end": 1.3}, "name": "Arcane Rift", "short": "RIFT", "slot": "E",
	"kind": "control", "role": "Daño en el tiempo", "description": "Apunta al suelo: grieta arcana que corroe a quienes la pisan.",
	"implemented": true, "selectable": true, "cast": "aoe", "anim": "cast", "target": "ground",
	"damage_type": 7,  # DamageSystem.Type.ARCANE
	"windup": 0.30, "active": 0.10, "recovery": 0.25, "cooldown": 10.0, "cost": 25.0,
	"range": 300.0, "radius": 110.0, "damage_mult": 0.5,
	"effects": {"dot": {"damage_type": 7, "dps_mult": 0.6, "duration": 6.0}},
	"rage_gain": 0.0, "move_factor": 0.3,
}

const STARFALL: Dictionary = {
	"id": &"starfall",
	"clip": {"name": "standing_2h_magic_area_attack_02", "start": 0.5, "contact": 1.8, "end": 2.4}, "name": "Starfall", "short": "STARFALL", "slot": "R",
	"kind": "control", "role": "Daño en área", "description": "Apunta al suelo: un starfallo cae con gran daño de fuego.",
	"implemented": true, "selectable": true, "cast": "aoe", "cast_bar": true, "anim": "cast", "target": "ground",
	"damage_type": 7,
	"windup": 1.6, "active": 0.10, "recovery": 0.30, "cooldown": 14.0, "cost": 40.0,
	"range": 320.0, "radius": 100.0, "damage_mult": 4.0,
	"rage_gain": 0.0, "move_factor": 0.0,
}

const ARCANE_SURGE: Dictionary = {
	"id": &"arcane_surge",
	"clip": {"name": "standing_2h_magic_attack_05", "start": 0.4, "contact": 2.07, "end": 2.7}, "name": "Arcane Surge", "short": "SURGE", "slot": "F",
	"kind": "ultimate", "role": "Ultimate", "description": "Ultimate. Cast 2.2 s (quieto): explosión arcana enorme donde apuntes.",
	"implemented": true, "selectable": true, "cast": "aoe", "cast_bar": true, "anim": "cast", "target": "ground",
	"damage_type": 7,
	"windup": 2.2, "active": 0.10, "recovery": 0.40, "cooldown": 1.0, "cost": 0.0, "charge": 100.0,
	"range": 320.0, "radius": 160.0, "damage_mult": 6.0,
	"rage_gain": 0.0, "move_factor": 0.0,
}

## Pasiva (mismo contrato que el Warrior): a vida baja, más daño y velocidad.
const PASSIVE: Dictionary = {
	"id": &"desperate_focus", "name": "Desperate Focus", "slot": "PASSIVE", "kind": "passive",
	"role": "Pasiva", "description": "Al bajar del 30% de vida, +30% de daño y +25% de velocidad durante 5 s.",
	"implemented": true, "threshold": 0.30, "damage_bonus": 1.30, "speed_bonus": 1.25,
	"duration": 5.0, "cooldown": 12.0,
}

const SPECIAL: Dictionary = ARCANE_PULSE
const ULTIMATE: Dictionary = ARCANE_SURGE

const DEFAULT_LOADOUT: Dictionary = {
	"SHIFT": &"blink", "Q": &"arcane_pulse", "E": &"arcane_rift", "R": &"starfall", "F": &"arcane_surge",
}

const ALL_ABILITIES: Array = [M1, M2, BLINK, ARCANE_PULSE, ARCANE_RIFT, STARFALL, ARCANE_SURGE]
const POOL_ABILITIES: Array = [BLINK, ARCANE_PULSE, ARCANE_RIFT, STARFALL, ARCANE_SURGE]


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
			return "%dMP+ULT" % roundi(cost)
		return "ULT"
	if cost > 0.0:
		return "%d MP" % roundi(cost)
	return ""
