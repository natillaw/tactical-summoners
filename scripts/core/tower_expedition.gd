class_name TowerExpedition
extends RefCounted
## The first ten tower floors (D-027): all unlocked for now and all in the forest biome (D-031).
## Sizes are in map cells; "enemies" is the spawn budget; "foes" are the creature types that can
## appear (voxel-dungeon creatures, see EnemySprites; roles in EnemyDefs). Numbers are tuning placeholders.
## D-056: sized for a 10-30 minute expedition (floor 1: ~92x80 cells, a hero crosses it straight in ~50 s,
## the chained route through every room is several minutes, plus fights). Older saved floors keep the
## size they were generated with (D-026).

const THEME_NAME := "Whispering Forest"

const FLOORS := {
    1: {"name": "Floor 1: Forest Edge", "difficulty": "Easy", "mission": "combat", "width": 92, "height": 80, "enemies": 16, "foes": ["slime_green", "rat", "mushroom_red"], "nodes": 6, "node_mix": {"herb": 3, "wood": 2, "ore": 1}, "intro": "Your first steps in the tower: explore in the fog, beat the creatures of the edge, bring something home."},
    2: {"name": "Floor 2: Mossy Trail", "difficulty": "Easy", "mission": "exploration", "width": 96, "height": 84, "enemies": 19, "foes": ["slime_green", "bat", "rat", "spider"], "nodes": 12, "node_mix": {"herb": 2, "wood": 3, "ore": 2}, "intro": "A wide trail full of timber, ore and herbs. Find the three old markers; gather what the town needs."},
    3: {"name": "Floor 3: Mushroom Hollow", "difficulty": "Normal", "mission": "retrieval", "width": 100, "height": 86, "enemies": 22, "foes": ["mushroom_red", "slime_green", "spider", "rat"], "nodes": 9, "node_mix": {"herb": 3, "wood": 1, "ore": 1}, "intro": "A relic lies at the far end of the hollow. Find it, carry it back to the entrance and get out."},
    4: {"name": "Floor 4: Goblin Camp", "difficulty": "Normal", "mission": "combat", "width": 104, "height": 90, "enemies": 26, "foes": ["goblin", "spider", "bat", "mushroom_red"], "nodes": 9, "node_mix": {"herb": 1, "wood": 2, "ore": 2}, "intro": "Goblins in groups, with archers and healers. Gear, potions and training will show here."},
    5: {"name": "Floor 5: Warlord's Grove", "difficulty": "Hard", "mission": "boss", "boss_name": "Grove Warlord", "width": 108, "height": 92, "enemies": 28, "foes": ["warlord", "hobgoblin", "goblin", "mushroom_purple", "slime_blue", "spider"], "nodes": 10, "node_mix": {"herb": 2, "wood": 1, "ore": 2}, "intro": "The first great challenge: cross the grove and defeat the Goblin Warlord at its heart."},
    6: {"name": "Floor 6: Tangled Thicket", "difficulty": "Hard", "mission": "exploration", "width": 112, "height": 96, "enemies": 31, "foes": ["hobgoblin", "spider", "mushroom_blue"]},
    7: {"name": "Floor 7: Raider Woods", "difficulty": "Hard", "mission": "combat", "width": 116, "height": 100, "enemies": 34, "foes": ["orc_brute", "goblin", "bat", "mushroom_blue"]},
    8: {"name": "Floor 8: Stone Circle", "difficulty": "Hard", "mission": "survival", "width": 120, "height": 104, "enemies": 36, "foes": ["golem", "mushroom_purple", "hobgoblin"]},
    9: {"name": "Floor 9: Warband Clearing", "difficulty": "Very Hard", "mission": "defense", "width": 124, "height": 106, "enemies": 38, "foes": ["orc_brute", "hobgoblin", "golem", "spider"]},
    10: {"name": "Floor 10: Chieftain's Glade (Boss)", "difficulty": "Very Hard", "mission": "boss", "width": 90, "height": 80, "enemies": 14, "foes": ["orc_chieftain", "orc_brute", "mushroom_blue"]},
}


const RECOMMENDED_HEROES := 5          # D-017 squad; shown at the tower gate before entering
const SLICE_FLOORS := 5                # vertical slice: floors 1-5 are the polished, playable ones


static func get_floor_config(floor_num: int) -> Dictionary:
    var f := clampi(floor_num, 1, 10)
    return FLOORS[f]


## Creature type for the i-th spawn of a floor (the boss floor puts the chieftain first).
static func foe_for(floor_num: int, i: int) -> String:
    var foes: Array = get_floor_config(floor_num)["foes"]
    return String(foes[i % foes.size()])
