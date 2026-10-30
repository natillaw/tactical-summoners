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
