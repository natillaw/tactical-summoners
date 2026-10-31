class_name TowerExpedition
extends RefCounted
## The first ten tower floors (D-027): all unlocked for now and all in the forest biome (D-031).
## Sizes are in map cells; "enemies" is the spawn budget; "foes" are the creature types that can
## appear (voxel-dungeon creatures, see EnemySprites). Numbers are tuning placeholders.

const THEME_NAME := "Whispering Forest"

const FLOORS := {
    1: {"name": "Floor 1: Forest Edge", "difficulty": "Easy", "mission": "combat", "width": 44, "height": 40, "enemies": 4, "foes": ["slime_green", "rat"]},
    2: {"name": "Floor 2: Mossy Trail", "difficulty": "Easy", "mission": "combat", "width": 46, "height": 42, "enemies": 6, "foes": ["slime_green", "bat", "rat"]},
    3: {"name": "Floor 3: Mushroom Hollow", "difficulty": "Normal", "mission": "retrieval", "width": 48, "height": 44, "enemies": 7, "foes": ["mushroom_red", "slime_green", "spider"]},
    4: {"name": "Floor 4: Goblin Camp", "difficulty": "Normal", "mission": "combat", "width": 50, "height": 46, "enemies": 8, "foes": ["goblin", "spider", "bat"]},
    5: {"name": "Floor 5: Old Grove", "difficulty": "Normal", "mission": "rescue", "width": 52, "height": 48, "enemies": 9, "foes": ["goblin", "mushroom_purple", "slime_blue"]},
    6: {"name": "Floor 6: Tangled Thicket", "difficulty": "Hard", "mission": "exploration", "width": 54, "height": 50, "enemies": 10, "foes": ["hobgoblin", "spider", "mushroom_blue"]},
    7: {"name": "Floor 7: Raider Woods", "difficulty": "Hard", "mission": "combat", "width": 56, "height": 52, "enemies": 11, "foes": ["orc_brute", "goblin", "bat"]},
    8: {"name": "Floor 8: Stone Circle", "difficulty": "Hard", "mission": "survival", "width": 58, "height": 54, "enemies": 12, "foes": ["golem", "mushroom_purple", "hobgoblin"]},
    9: {"name": "Floor 9: Warband Clearing", "difficulty": "Very Hard", "mission": "defense", "width": 60, "height": 56, "enemies": 13, "foes": ["orc_brute", "hobgoblin", "golem"]},
    10: {"name": "Floor 10: Chieftain's Glade (Boss)", "difficulty": "Very Hard", "mission": "boss", "width": 54, "height": 50, "enemies": 8, "foes": ["orc_chieftain", "orc_brute"]},
}


static func get_floor_config(floor_num: int) -> Dictionary:
    var f := clampi(floor_num, 1, 10)
    return FLOORS[f]


## Creature type for the i-th spawn of a floor (the boss floor puts the chieftain first).
static func foe_for(floor_num: int, i: int) -> String:
    var foes: Array = get_floor_config(floor_num)["foes"]
    return String(foes[i % foes.size()])
