class_name CombatRules
extends RefCounted
## Provisional real-time combat numbers (D-012). Everything tunable lives here.

const HERO_MELEE_RANGE := 52.0
const HERO_RANGED_RANGE := 190.0
const HERO_PERCEPTION := 260.0


## Flat damage with half-DEF mitigation; never below 1.
static func damage(power: int, target_def: int) -> int:
    return maxi(1, roundi(float(power) - float(target_def) * 0.5))


## Seconds between basic attacks; faster SPD attacks faster, clamped.
static func hero_interval(spd: int) -> float:
    return clampf(1.6 - float(spd) * 0.04, 0.6, 1.6)


## Skill damage: power * multiplier, then the same half-DEF mitigation as basic attacks.
static func skill_damage(power: int, mult: float, target_def: int) -> int:
    return maxi(1, roundi(float(power) * mult - float(target_def) * 0.5))
