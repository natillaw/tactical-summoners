class_name TowerExpedition
extends RefCounted
## Defines the first ten tower floors, mission types, and procedural parameters (Mega Prompt Phase 2).

const THEME_NAME := "Stone Crypt & Ancient Depths"

const FLOORS := {
    1: {"name": "Floor 1: Outer Threshold", "difficulty": "Easy", "mission": "combat", "width": 80, "height": 80, "enemies": 4},
    2: {"name": "Floor 2: Guarded Hall", "difficulty": "Easy", "mission": "combat", "width": 90, "height": 90, "enemies": 6},
    3: {"name": "Floor 3: Forgotten Corridors", "difficulty": "Normal", "mission": "retrieval", "width": 100, "height": 100, "enemies": 8},
    4: {"name": "Floor 4: Patrolled Vaults", "difficulty": "Normal", "mission": "combat", "width": 110, "height": 110, "enemies": 10},
    5: {"name": "Floor 5: Ancient Crypt", "difficulty": "Normal", "mission": "rescue", "width": 120, "height": 120, "enemies": 12},
    6: {"name": "Floor 6: Catacomb Labyrinth", "difficulty": "Hard", "mission": "exploration", "width": 130, "height": 130, "enemies": 14},
    7: {"name": "Floor 7: Corrupted Depths", "difficulty": "Hard", "mission": "combat", "width": 140, "height": 140, "enemies": 16},
    8: {"name": "Floor 8: Deep Ritual Chamber", "difficulty": "Hard", "mission": "survival", "width": 150, "height": 150, "enemies": 18},
    9: {"name": "Floor 9: Guardian Sanctuary", "difficulty": "Very Hard", "mission": "defense", "width": 160, "height": 160, "enemies": 20},
    10: {"name": "Floor 10: Lord of the Depths (Boss)", "difficulty": "Very Hard", "mission": "boss", "width": 140, "height": 140, "enemies": 10},
}


static func get_floor_config(floor_num: int) -> Dictionary:
    var f := clampi(floor_num, 1, 10)
    return FLOORS[f]
