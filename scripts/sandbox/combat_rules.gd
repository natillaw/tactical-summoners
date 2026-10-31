class_name CombatRules
extends RefCounted
## The one place for combat numbers and formulas (D-012, D-035, D-036, D-037). Everything that
## deals damage goes through resolve(); every unit's stats come from derive() or an enemy table.
## All values are tuning placeholders.

const HERO_MELEE_RANGE := 52.0
const HERO_RANGED_RANGE := 190.0
const HERO_PERCEPTION := 260.0
const ARMOR_K := 5.0              # mitigation = 100 / (100 + ARMOR_K * armor)
const CRIT_MULT := 1.5
const AGONY_TIME := 20.0          # D-036
const AGONY_HIT_PENALTY := 5.0
const RESCUE_TIME := 2.5
const RESCUE_RANGE := 40.0
const RESCUE_HP := 0.25
const WOUNDED_MAX_HP := 0.8
const STATUS_TICK := 0.5

## Body size classes (game feel report). The hero is the reference unit. Measured opaque height of the
## art vs the hero (tools/measure_scale.gd): small < 0.8, standard 0.8-1.5, large 1.5-2.5, huge > 2.5.
## body = radius others keep away from (separation, debug hurtbox); mass = divides knock-back distance;
## reach = multiplies strike range and strike radius; windup = multiplies the telegraph time (heavier =
## longer, easier to read); accel = seconds to reach full speed; turn = radians/s the heading can turn.
const SIZE := {
    "small": {"body": 9.0, "mass": 0.7, "reach": 0.85, "windup": 0.85, "accel": 0.05, "turn": 30.0},
    "standard": {"body": 12.0, "mass": 1.0, "reach": 1.0, "windup": 1.0, "accel": 0.10, "turn": 16.0},
    "large": {"body": 17.0, "mass": 2.0, "reach": 1.2, "windup": 1.15, "accel": 0.22, "turn": 8.0},
    "huge": {"body": 28.0, "mass": 4.0, "reach": 1.5, "windup": 1.3, "accel": 0.35, "turn": 5.0},
}
## D-051: below this Obedience a hero ignores direct orders and cannot be taken under direct control.
const OBEY_MIN := 25
## D-052: chance that an AUTONOMOUS hero reacts to a telegraphed strike aimed at it and steps out, rolled
## once per strike. Zero at level 1, grows with AGI and level, capped. Moving the hero by hand is
## always possible and is the reliable way to dodge.
const DODGE_PER_AGI_LEVEL := 0.0015
const DODGE_MAX := 0.30
const DODGE_REACTION := 0.25      # seconds of wind-up that must be left to react at all
const KITE_COOLDOWN := 2.5        # a ranged hero backs off at most this often
const PROJECTILE_SPEED := 650.0   # basic shots (look and D-054 travel time)


static func auto_dodge_chance(agi: int, level: int) -> float:
    return clampf(DODGE_PER_AGI_LEVEL * float(agi) * float(maxi(0, level - 1)), 0.0, DODGE_MAX)


## Fog of war sight (D-056), in map cells. Scouts (ranger, rogue) see further; equipment can add
## "vision" later. A downed hero still lights its own surroundings a little.
const VISION_CELLS := 6
const SCOUT_VISION_BONUS := 2
const SCOUT_CLASSES := ["class.ranger", "class.rogue"]
const DOWNED_VISION := 2
const FOG_EVERY := 0.15          # seconds between sight updates

const HERO_BODY := 11.0
const HERO_MASS := 1.0
const BOSS_MASS_MULT := 2.5                     # a boss resists knock-back far more than its size alone
const CREATURE_SIZE := {
    "rat": "small", "bat": "small", "slime_green": "small", "slime_blue": "small", "orc_shaman": "standard",
    "orc_brute": "large", "orc_chieftain": "large", "golem": "huge", "golem_magma": "huge", "trex": "huge",
}


static func size_class_of(type_id: String) -> String:
    return String(CREATURE_SIZE.get(type_id, "standard"))


## Status effects (data). dot = damage per second (kind); move = movement multiplier;
## blocks = what the status prevents; out_dmg = outgoing damage multiplier; in_dmg = damage taken
## multiplier; hot = heals magnitude per second; debuff = removed by cleanse; stacks = max stacks.
const STATUS := {
    "poison": {"name": "Poisoned", "dot": "true", "stacks": 3, "debuff": true, "color": Color(0.5, 0.9, 0.3)},
    "burn": {"name": "Burning", "dot": "magical", "stacks": 1, "debuff": true, "color": Color(1.0, 0.5, 0.2)},
    "bleed": {"name": "Bleeding", "dot": "physical", "stacks": 3, "debuff": true, "color": Color(0.9, 0.2, 0.2)},
    "stun": {"name": "Stunned", "blocks": ["move", "act"], "debuff": true, "color": Color(1.0, 0.9, 0.3)},
    "root": {"name": "Rooted", "blocks": ["move"], "debuff": true, "color": Color(0.6, 0.45, 0.25)},
    "slow": {"name": "Slowed", "move": 0.6, "debuff": true, "color": Color(0.5, 0.7, 1.0)},
    "weaken": {"name": "Weakened", "out_dmg": 0.75, "debuff": true, "color": Color(0.7, 0.5, 0.8)},
    "marked": {"name": "Marked", "in_dmg": 1.25, "debuff": true, "color": Color(1.0, 0.4, 0.7)},
    "regen": {"name": "Regenerating", "hot": true, "no_resist": true, "color": Color(0.4, 1.0, 0.6)},
    "shield": {"name": "Shielded", "absorb": true, "no_resist": true, "color": Color(0.6, 0.85, 1.0)},
    "wounded": {"name": "Wounded", "max_hp": WOUNDED_MAX_HP, "no_resist": true, "color": Color(0.8, 0.3, 0.3)},
}


## D-035: derived combat stats from the five attributes + the class kit.
static func derive(attrs: Dictionary, class_id: String) -> Dictionary:
    var c: Dictionary = HeroTables.CLASS_COMBAT.get(class_id, HeroTables.CLASS_COMBAT["class.none"])
    var fue := int(attrs.get("fue", 1))
    var agi := int(attrs.get("agi", 1))
    var vit := int(attrs.get("vit", 1))
    var inte := int(attrs.get("int", 1))
    var tem := int(attrs.get("tem", 1))
    return {
        "hp": 40 + 10 * vit,
        "atk": 2 * fue + int(c["weapon"]),
        "mag": 2 * inte + int(c["focus"]),
        "def": vit / 2 + int(c["armor"]),
        "mres": tem / 2 + int(c["mres"]),
        "spd": agi,
        "move": 70.0 + float(agi) * 3.0,
        "interval": clampf(1.6 - float(agi) * 0.04, 0.6, 1.6),
        "crit": clampf(0.05 + float(agi) * 0.005, 0.0, 0.35),
        "energy": 3 + tem / 3,
        "status_resist": clampf(float(tem) * 0.01, 0.0, 0.5),
        "kind": String(c["kind"]),
    }


## Damage after armor / magic resistance. "true" damage ignores both. Never below 1.
static func mitigate(amount: float, kind: String, armor: int, mres: int) -> int:
    var def := 0.0
    match kind:
        "physical":
            def = float(armor)
        "magical":
            def = float(mres)
    return maxi(1, roundi(amount * 100.0 / (100.0 + ARMOR_K * maxf(0.0, def))))


## Legacy helper kept for callers that only know power and armor (physical damage).
static func damage(power: int, target_def: int) -> int:
    return mitigate(float(power), "physical", target_def, 0)


## Seconds between basic attacks; faster SPD attacks faster, clamped.
static func hero_interval(spd: int) -> float:
    return clampf(1.6 - float(spd) * 0.04, 0.6, 1.6)


static func skill_damage(power: int, mult: float, target_def: int) -> int:
    return mitigate(float(power) * mult, "physical", target_def, 0)


## Resolves one hit against a target: crit roll (D-037), attacker weaken, mitigation. Fills the
## info's result fields and returns the final damage.
static func resolve(info: DamageInfo, target: Combatant) -> int:
    var amount := info.amount
    if info.source != null and is_instance_valid(info.source) and info.source is Combatant:
        amount *= (info.source as Combatant).outgoing_mult()
    if info.can_crit and info.rng != null and info.rng.randf() < info.crit_chance:
        info.crit = true
        amount *= CRIT_MULT
    amount *= target.incoming_mult()
    info.final = mitigate(amount, info.kind, target.armor, target.mres)
    return info.final
