class_name TownTables
extends RefCounted
## The town (D-030): every building, where it stands on the fixed town map, what it costs and what
## it opens. Levels live in Game.town_buildings (0 = not built yet). Costs are TUNING PLACEHOLDERS.

const MAP_W := 34
const MAP_H := 22

## plot = Rect2i(cell x, cell y, w, h) on the town map; the door is the bottom-centre cell.
## open = screen opened from the building ("" = info panel only). start = level in a new game.
## produces = HQ-turn output per assigned worker per building level (see Game.process_headquarters_turn).
## props = voxel props drawn next to the door (assets/packs/voxel-dungeon-pack-full/props/frames/<id>).
const BUILDINGS := {
    "town_hall": {"name": "Town Hall", "plot": Rect2i(14, 2, 6, 3), "start": 1, "max": 5, "cost": 60,
        "open": "hq", "roof": Color(0.95, 0.80, 0.45), "props": ["banner", "banner"],
        "desc": "Assign heroes to work in the town and run a work turn."},
    "summon_circle": {"name": "Summoning Circle", "plot": Rect2i(3, 3, 4, 3), "start": 1, "max": 1, "cost": 0,
        "open": "summon", "roof": Color(0.70, 0.55, 1.0), "props": ["altar"],
        "desc": "Call new heroes into the order."},
    "barracks": {"name": "Barracks", "plot": Rect2i(26, 3, 5, 3), "start": 1, "max": 1, "cost": 0,
        "open": "roster", "roof": Color(0.75, 0.75, 0.80), "props": ["weaponrack"],
        "desc": "Your heroes: stats, personality, training and promotion."},
    "war_room": {"name": "War Room", "plot": Rect2i(26, 8, 4, 2), "start": 1, "max": 1, "cost": 0,
        "open": "party", "roof": Color(0.80, 0.45, 0.40), "props": ["table"],
        "desc": "Choose the five heroes of the squad."},
    "tower_gate": {"name": "Tower Gate", "plot": Rect2i(15, 15, 4, 3), "start": 1, "max": 1, "cost": 0,
        "open": "tower", "roof": Color(0.45, 0.45, 0.55), "props": ["brazier", "brazier"],
        "desc": "Lead the squad into the tower (D-027)."},
    "memorial": {"name": "Memorial", "plot": Rect2i(3, 15, 3, 2), "start": 1, "max": 1, "cost": 0,
        "open": "memorial", "roof": Color(0.55, 0.55, 0.60), "props": ["torch_deco"],
        "desc": "The names of the fallen, kept forever."},
    "dorm_1": {"name": "Dormitory", "plot": Rect2i(3, 9, 4, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["barrel_deco"],
        "desc": "Beds for heroes: +5 roster capacity per level."},
    "dorm_2": {"name": "Dormitory", "plot": Rect2i(9, 9, 4, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.60, 0.75, 0.95), "props": ["barrel_deco"],
        "desc": "Beds for heroes: +5 roster capacity per level."},
    "kitchen": {"name": "Kitchen", "plot": Rect2i(21, 11, 3, 2), "start": 1, "max": 5, "cost": 30,
        "open": "", "roof": Color(0.95, 0.65, 0.35), "props": ["crate", "barrel_deco"], "produces": {"food": 5},
        "desc": "Workers cook provisions (food)."},
    "infirmary": {"name": "Hospital", "plot": Rect2i(26, 12, 4, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.92, 0.92, 0.95), "props": ["bucket_deco"], "produces": {"medicine": 3},
        "desc": "Workers tend the wounded and prepare medicine."},
    "blacksmith": {"name": "Blacksmith", "plot": Rect2i(9, 3, 4, 2), "start": 1, "max": 5, "cost": 50,
        "open": "", "roof": Color(0.55, 0.30, 0.25), "props": ["weaponrack", "shield_deco"],
        "desc": "Forge for weapons and armor. Crafting arrives with equipment (P-19, P-20)."},
    "workshop": {"name": "Workshop", "plot": Rect2i(21, 3, 3, 2), "start": 1, "max": 5, "cost": 40,
        "open": "", "roof": Color(0.70, 0.55, 0.35), "props": ["crate", "crate"], "produces": {"materials": 4},
        "desc": "Workers gather and shape building materials."},
    "alchemy": {"name": "Alchemy Lab", "plot": Rect2i(9, 15, 4, 2), "start": 0, "max": 5, "cost": 60,
        "open": "", "roof": Color(0.45, 0.85, 0.65), "props": ["crystal_deco", "bookshelf"],
        "desc": "Potions and reagents. Recipes arrive with crafting (P-20)."},
    "common": {"name": "Tavern", "plot": Rect2i(21, 15, 4, 2), "start": 1, "max": 5, "cost": 30,
        "open": "", "roof": Color(0.85, 0.55, 0.30), "props": ["table", "barrel_deco"],
        "desc": "Heroes who work here socialize and grow closer."},
}


static func ids() -> Array:
    return BUILDINGS.keys()


static func info(id: String) -> Dictionary:
    return BUILDINGS.get(id, {})


static func start_levels() -> Dictionary:
    var out := {}
    for id in BUILDINGS:
        out[id] = int(BUILDINGS[id]["start"])
    return out


## Materials needed to go from `level` to `level + 1` (building from 0 costs the base price).
static func upgrade_cost(id: String, level: int) -> int:
    return int(info(id).get("cost", 0)) * (level + 1)


static func door_cell(id: String) -> Vector2i:
    var p: Rect2i = info(id)["plot"]
    return Vector2i(p.position.x + p.size.x / 2, p.end.y)
