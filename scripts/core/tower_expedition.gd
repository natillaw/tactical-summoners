class_name TowerExpedition
extends RefCounted
## The first ten tower floors (D-027): all unlocked for now and all in the forest biome (D-031).
## Sizes are in map cells; "enemies" is the spawn budget; "foes" are the creature types that can
## appear (voxel-dungeon creatures, see EnemySprites; roles in EnemyDefs). Numbers are tuning placeholders.
## D-056: sized for a 10-30 minute expedition the first time (fog, unknown layout). Playtest 2026-10-31:
## at 92x80..108x92 a blind first run took 4-8 min, so floors 1-5 grew ~30% per side (~1.7x the area) with
## creatures and gathering spots scaled to keep the same density; a replay that goes straight to the goal
## stays short (that is fine). Older saved floors keep the size they were generated with (D-026).
## D-066: tower floors have no gathering spots (the Wilds hold the town's materials) and each needs a
## Summoner's Hall level ("hall", floor_block()).
## D-065: creature strength grows gently (+10% per floor, EnemyDefs.floor_scale); difficulty comes from
## mechanics that ask for thought: telegraphed blows (1), healers behind the line (2), a slow relic carrier
## everything hunts (3), lookouts that raise the alarm (4), a boss with shamans, wards and phases (5).
## A floor may still set "scale" to override the curve.

const THEME_NAME := "Whispering Forest"

const FLOORS := {
    1: {"name": "Floor 1: Forest Edge", "hall": 1, "difficulty": "Easy", "mission": "combat", "width": 120, "height": 104, "enemies": 27, "foes": ["slime_green", "rat", "mushroom_red"], "nodes": 0, "intro": "Your first steps in the tower: explore in the fog, beat the creatures of the edge, bring something home."},
    2: {"name": "Floor 2: Mossy Trail", "hall": 1, "difficulty": "Easy", "mission": "exploration", "width": 124, "height": 110, "enemies": 32, "foes": ["slime_green", "bat", "rat", "spider", "mushroom_red"], "nodes": 0, "intro": "A wide trail full of timber, ore and herbs. Find the three old markers; gather what the town needs."},
    3: {"name": "Floor 3: Mushroom Hollow", "hall": 2, "difficulty": "Normal", "mission": "retrieval", "width": 130, "height": 112, "enemies": 37, "foes": ["mushroom_red", "slime_green", "spider", "rat"], "nodes": 0, "intro": "A relic lies at the far end of the hollow. Find it, carry it back to the entrance and get out."},
    4: {"name": "Floor 4: Goblin Camp", "hall": 2, "difficulty": "Normal", "mission": "combat", "lookouts": true, "tactics": true, "width": 136, "height": 116, "enemies": 44, "foes": ["goblin", "spider", "bat", "mushroom_red"], "nodes": 0, "intro": "Goblins in groups, with archers and healers. Gear, potions and training will show here."},
    5: {"name": "Floor 5: Warlord's Grove", "hall": 3, "difficulty": "Hard", "mission": "boss", "boss_name": "Grove Warlord", "tactics": true, "width": 140, "height": 120, "enemies": 47, "foes": ["warlord", "hobgoblin", "goblin", "mushroom_purple", "slime_blue", "spider"], "nodes": 0, "intro": "The first great challenge: cross the grove and defeat the Goblin Warlord at its heart."},
    6: {"name": "Floor 6: Tangled Thicket", "hall": 3, "difficulty": "Hard", "mission": "exploration", "tactics": true, "width": 146, "height": 124, "enemies": 52, "foes": ["hobgoblin", "spider", "mushroom_blue"]},
    7: {"name": "Floor 7: Raider Woods", "hall": 4, "difficulty": "Hard", "mission": "combat", "tactics": true, "width": 150, "height": 130, "enemies": 58, "foes": ["orc_brute", "goblin", "bat", "mushroom_blue"]},
    8: {"name": "Floor 8: Stone Circle", "hall": 4, "difficulty": "Hard", "mission": "survival", "tactics": true, "width": 156, "height": 136, "enemies": 61, "foes": ["golem", "mushroom_purple", "hobgoblin"]},
    9: {"name": "Floor 9: Warband Clearing", "hall": 5, "difficulty": "Very Hard", "mission": "defense", "tactics": true, "width": 160, "height": 138, "enemies": 65, "foes": ["orc_brute", "hobgoblin", "golem", "spider"]},
    10: {"name": "Floor 10: Chieftain's Glade (Boss)", "hall": 5, "difficulty": "Very Hard", "mission": "boss", "tactics": true, "width": 118, "height": 104, "enemies": 24, "foes": ["orc_chieftain", "orc_brute", "mushroom_blue"]},
}


## D-066 (cambiado por Nathaniel 2026-10-31): the town no longer gates a floor. Every floor opened by
## tower progress (D-031: 1-10) can be entered; "hall" is only the suggested Summoner's Hall level. The
## difficulty is the content (enemies hit hard enough that crafted gear is the expected answer).
static func floor_block(_floor_num: int, _hall_level: int = 0) -> String:
    return ""


## Advisory text when the town is below a floor's suggested Hall level ("" if it is not).
static func floor_advice(floor_num: int, hall_level: int) -> String:
    if floor_num <= 0:
        return ""
    var need := int(get_floor_config(floor_num).get("hall", 1))
    return "" if hall_level >= need else "suggested: Summoner's Hall %d (now %d). Without town gear this floor is very hard" % [need, hall_level]


const RECOMMENDED_HEROES := 5          # D-017 squad; shown at the tower gate before entering
const SLICE_FLOORS := 5                # vertical slice: floors 1-5 are the polished, playable ones


static func get_floor_config(floor_num: int) -> Dictionary:
    if floor_num < 0:
        return DungeonDefs.config(-floor_num)     # D-066: negative = a tier of the repeatable Wilds
    var f := clampi(floor_num, 1, 10)
    return FLOORS[f]


## Creature type for the i-th spawn of a floor (the boss floor puts the chieftain first).
static func foe_for(floor_num: int, i: int) -> String:
    var foes: Array = get_floor_config(floor_num)["foes"]
    return String(foes[i % foes.size()])
