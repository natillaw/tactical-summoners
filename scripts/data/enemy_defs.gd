class_name EnemyDefs
extends RefCounted
## Creature stats and combat roles (D-056: difficulty from composition, not from inflated health).
## Numbers are tuning placeholders for early floors (heroes of 1-2 stars, level 1-5: ~100-130 HP and
## ~12 damage per second each). Body size (reach, wind-up, mass) comes from CombatRules.SIZE on top.
##
## Roles: swarm = fast and frail, comes in numbers; melee = standard fighter; brute = slow heavy hitter;
## guard = holds a spot (leash) with armour; ranged = strikes from afar and backs off; support = heals
## hurt allies and stays behind them. status = applied to heroes its strike hits ({id, dur, mag}).

const ROLES := ["swarm", "melee", "brute", "guard", "ranged", "support"]
const DEFAULT := {"hp": 60, "atk": 12, "armor": 3, "mres": 2, "speed": 62.0, "role": "melee"}

const TYPES := {
    # tower floors (Voxel Dungeon creatures, D-031 forest)
    "rat": {"hp": 28, "atk": 5, "armor": 0, "mres": 0, "speed": 88.0, "role": "swarm", "windup": 0.55, "recover": 0.5},
    "bat": {"hp": 22, "atk": 5, "armor": 0, "mres": 1, "speed": 100.0, "role": "swarm", "windup": 0.5, "recover": 0.5},
    "slime_green": {"hp": 55, "atk": 8, "armor": 2, "mres": 1, "speed": 48.0, "role": "melee", "windup": 0.8},
    "slime_blue": {"hp": 65, "atk": 9, "armor": 3, "mres": 4, "speed": 48.0, "role": "melee", "windup": 0.8,
        "status": {"id": "slow", "dur": 2.0, "mag": 0.0}},
    "mushroom_red": {"hp": 45, "atk": 4, "armor": 1, "mres": 3, "speed": 40.0, "role": "support"},
    "mushroom_blue": {"hp": 50, "atk": 4, "armor": 1, "mres": 5, "speed": 40.0, "role": "support"},
    "mushroom_purple": {"hp": 45, "atk": 7, "armor": 1, "mres": 3, "speed": 42.0, "role": "ranged",
        "status": {"id": "poison", "dur": 4.0, "mag": 2.0}},
    "spider": {"hp": 40, "atk": 8, "armor": 1, "mres": 1, "speed": 70.0, "role": "ranged",
        "status": {"id": "poison", "dur": 3.0, "mag": 2.0}},
    "goblin": {"hp": 60, "atk": 10, "armor": 2, "mres": 1, "speed": 70.0, "role": "melee"},
    "hobgoblin": {"hp": 110, "atk": 13, "armor": 6, "mres": 2, "speed": 58.0, "role": "guard"},
    "orc_brute": {"hp": 170, "atk": 18, "armor": 5, "mres": 2, "speed": 56.0, "role": "brute"},
    "golem": {"hp": 320, "atk": 24, "armor": 10, "mres": 6, "speed": 40.0, "role": "brute"},
    "orc_chieftain": {"hp": 150, "atk": 14, "armor": 6, "mres": 3, "speed": 60.0, "role": "brute"},
    "warlord": {"hp": 120, "atk": 13, "armor": 5, "mres": 3, "speed": 58.0, "role": "brute"},   # floor 5 boss (make_boss scales it)
    # training ground (Pixel Crawler mobs): the old shared numbers, with roles
    "orc": {"role": "melee"},
    "orc_rogue": {"role": "melee", "speed": 72.0},
    "orc_warrior": {"role": "guard", "armor": 5},
    "orc_shaman": {"role": "support"},
    "skeleton_base": {"role": "melee"},
    "skeleton_rogue": {"role": "melee", "speed": 72.0},
    "skeleton_warrior": {"role": "guard", "armor": 5},
    "skeleton_mage": {"role": "ranged"},
}

## Drops: resource -> [chance, min, max], rolled when the creature dies (kept by the expedition ledger).
const DROPS := {
    "rat": {"hide": [0.6, 1, 1], "fang": [0.4, 1, 1]},
    "bat": {"hide": [0.5, 1, 1], "fang": [0.3, 1, 1]},
    "slime_green": {"gel": [0.8, 1, 2]},
    "slime_blue": {"gel": [0.9, 1, 2]},
    "mushroom_red": {"spore": [0.8, 1, 2], "herb": [0.5, 1, 1]},
    "mushroom_blue": {"spore": [0.8, 1, 2], "herb": [0.5, 1, 1]},
    "mushroom_purple": {"spore": [0.9, 1, 2], "venom": [0.3, 1, 1]},
    "spider": {"silk": [0.8, 1, 2], "venom": [0.5, 1, 1]},
    "goblin": {"fang": [0.4, 1, 1], "bone": [0.5, 1, 1], "ore": [0.3, 1, 2]},
    "hobgoblin": {"bone": [0.8, 1, 2], "hide": [0.5, 1, 2], "ingot": [0.2, 1, 1]},
    "orc_brute": {"bone": [0.9, 1, 2], "hide": [0.7, 1, 2]},
    "golem": {"core": [0.6, 1, 1], "stone": [1.0, 2, 4], "ore": [0.8, 1, 3]},
    "orc_chieftain": {"core": [1.0, 1, 1], "bone": [1.0, 2, 3]},
    "warlord": {"hide": [1.0, 3, 5], "bone": [1.0, 2, 3], "core": [0.5, 1, 1]},
}
const XP_PER_HP := 0.2            # experience a creature is worth (its max HP x this)


const RANGED_RANGE := 150.0       # ranged strike distance (the marked circle is at the hero's feet)
const RANGED_RADIUS := 30.0       # a ranged strike hits a small circle: one hero, dodgeable by moving
const BACK_OFF := 70.0            # ranged and support creatures step back when a hero is this close
const SUPPORT_HEAL := 0.2         # fraction of the patient's max HP
const SUPPORT_EVERY := 5.0        # seconds between heals
const SUPPORT_REACH := 170.0
const GUARD_LEASH := 160.0        # a guard never follows further than this from its post
const AMBUSH_WAKE := 90.0         # an ambusher stays hidden and still until a hero is this close
const ALERT_PERCEPTION := 1.6     # an alerted group sees further (one of them was attacked or spotted you)
const FLOOR_SCALE := 0.08         # +8% health and damage per floor above the first


static func info(id: String) -> Dictionary:
    var d := DEFAULT.duplicate()
    d.merge(TYPES.get(id, {}), true)
    return d


static func role_of(id: String) -> String:
    return String(info(id)["role"])
