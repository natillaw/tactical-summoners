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
    "mushroom_red": {"hp": 45, "atk": 4, "armor": 1, "mres": 3, "speed": 40.0, "role": "support", "skills": ["mend"]},
    "mushroom_blue": {"hp": 50, "atk": 4, "armor": 1, "mres": 5, "speed": 40.0, "role": "support", "skills": ["mend", "ward"]},
    "mushroom_purple": {"hp": 45, "atk": 7, "armor": 1, "mres": 3, "speed": 42.0, "role": "ranged",
        "status": {"id": "poison", "dur": 4.0, "mag": 2.0}, "skills": ["spore_cloud"]},
    "spider": {"hp": 40, "atk": 8, "armor": 1, "mres": 1, "speed": 70.0, "role": "ranged",
        "status": {"id": "poison", "dur": 3.0, "mag": 2.0}, "skills": ["aimed_shot"]},
    "goblin": {"hp": 60, "atk": 10, "armor": 2, "mres": 1, "speed": 70.0, "role": "melee"},
    "hobgoblin": {"hp": 110, "atk": 13, "armor": 6, "mres": 2, "speed": 58.0, "role": "guard", "skills": ["rally"]},
    "orc_brute": {"hp": 170, "atk": 18, "armor": 5, "mres": 2, "speed": 56.0, "role": "brute", "skills": ["slam"]},
    "golem": {"hp": 320, "atk": 24, "armor": 10, "mres": 6, "speed": 40.0, "role": "brute", "skills": ["slam"]},
    "orc_chieftain": {"hp": 150, "atk": 14, "armor": 6, "mres": 3, "speed": 60.0, "role": "brute", "skills": ["slam", "rally"]},
    "warlord": {"hp": 120, "atk": 13, "armor": 5, "mres": 3, "speed": 58.0, "role": "brute", "skills": ["slam", "rally"]},   # floor 5 boss (make_boss scales it)
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
## D-066: in the tower creatures leave no parts (those are hunted in the Wilds) but sometimes a rare
## spirit essence, which the Wilds never give (higher ascensions, fine forging).
const TOWER_DROPS := {"essence": [0.06, 1, 1]}
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
const FLOOR_SCALE := 0.10         # +10% health and damage per floor above the first (D-065: difficulty comes from mechanics)

## --- creature classes and skills (D-065) -------------------------------------------------------------
## Roles work as classes: swarm (skirmisher), melee (fighter), brute, guard (defender), ranged (archer),
## support (healer / shaman), plus two jobs given by the floor: scout (lookout: flees to raise the alarm)
## and the boss's shamans. A creature casts a skill like a hero: a visible wind-up (a ring on the caster
## for help spells, the marked area for attacks) that a stun or an interrupt breaks; cooldown per skill.
## min_floor: the skill appears from that floor (floor 1 teaches the basics without enemy healers).
## Targets: ally_low = the most hurt creature in range (heals); ally_key = the boss if near, else the
## strongest creature (wards); allies = every creature around the caster; hero_area = an area at a hero
## (marked on the ground: step out of it).
const SKILLS := {
    "mend": {"name": "Mend", "cast": 1.5, "cd": 7.0, "range": 200.0, "target": "ally_low", "below": 0.75, "min_floor": 2,
        "heal_pct": 0.3, "desc": "Heals the most hurt creature. Kill or stun the healer."},
    "ward": {"name": "Ward", "cast": 1.1, "cd": 11.0, "range": 220.0, "target": "ally_key", "min_floor": 3,
        "shield_pct": 0.22, "desc": "Shields an ally (the boss first)."},
    "rally": {"name": "Rally", "cast": 1.2, "cd": 16.0, "range": 230.0, "target": "allies", "min_floor": 4,
        "status": {"id": "empowered", "dur": 8.0, "mag": 0.0}, "desc": "Nearby creatures hit 30% harder for a while."},
    "slam": {"name": "Slam", "cast": 1.4, "cd": 9.0, "range": 140.0, "target": "hero_area", "radius": 95.0, "min_floor": 1,
        "dmg_mult": 1.8, "status": {"id": "stun", "dur": 1.0, "mag": 0.0}, "desc": "A huge marked blow: get out of the circle."},
    "spore_cloud": {"name": "Spore Cloud", "cast": 1.0, "cd": 12.0, "range": 190.0, "target": "hero_area", "radius": 75.0, "min_floor": 3,
        "zone": {"status": "poison", "life": 6.0, "dur": 2.0, "mag": 3.0}, "desc": "Leaves a poison cloud: do not stand in it."},
    "aimed_shot": {"name": "Aimed Shot", "cast": 1.7, "cd": 8.0, "range": 230.0, "target": "hero_area", "radius": 28.0, "min_floor": 3,
        "dmg_mult": 2.4, "desc": "A long aim at one hero: move that hero, or stun the archer."},
}
const SCOUT_ALARM_RADIUS := 140.0  # a fleeing lookout raises the alarm on reaching this close to another group
const SCOUT_FLEE_SPEED := 1.25     # lookouts run faster than they walk
const BOSS_SHAMANS := 2            # floor bosses come with shamans that heal and ward them
const CARRIER_HUNT := 2.0          # creatures notice the relic carrier this many times further away

## #8 of the playtest: a boss used to be a big bag of health; a squad could run straight to it and win
## in a minute. Now it fights in phases: at each health threshold it calls its warband (every creature
## within CALL_RADIUS is alerted and `adds` new ones of the floor join next to it); the last phase also
## enrages it (faster wind-up and harder blows).
const BOSS_PHASES := [
    {"at": 0.6, "adds": 2, "call_radius": 650.0},
    {"at": 0.3, "adds": 3, "call_radius": 900.0, "enrage_atk": 1.25, "enrage_windup": 0.8},
]


## Health and damage multiplier of a floor's creatures: the floor's "scale" (TowerExpedition) or, when it
## has none, 1 + FLOOR_SCALE per floor above the first. D-065: kept gentle on purpose; the challenge of a
## floor is its mechanics (healers, lookouts, the relic carrier, the boss's shamans), not inflated numbers.
static func floor_scale(floor_num: int) -> float:
    if floor_num <= 0:
        return 1.0
    var cfg := TowerExpedition.get_floor_config(floor_num)
    return float(cfg.get("scale", 1.0 + FLOOR_SCALE * float(maxi(0, floor_num - 1))))


static func info(id: String) -> Dictionary:
    var d := DEFAULT.duplicate()
    d.merge(TYPES.get(id, {}), true)
    return d


static func role_of(id: String) -> String:
    return String(info(id)["role"])
