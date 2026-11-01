class_name ItemLibrary
extends RefCounted
## D-077 item library (owner, 2026-10-31), every number in this one file:
##   - TIERS by material, 10 floors each (only tier 1 is reachable today).
##   - Crafted lines: the blacksmith (metal weapons and armour), the workshop's woodworker (bows,
##     staves, wands) and the jeweller (rings, amulets, trinkets). Clean names ("Copper Mail Shirt"),
##     predictable stats, one affix chosen from 3, at most rare, and a tier SET for armour.
##   - Drops: themed by the enemy that dropped them (THEMES), random affixes up to legendary. A drop
##     and a crafted piece never share a name: drops carry the theme ("Cutthroat's Dagger").
##   - Cursed affixes: 15% of non-common pieces carry one, always with a good affix made stronger.
##   - Requirements: hero level by tier and a light class rule (a mage never wields a greataxe).
##   - Uniques (red): secret objectives only, 1-2% per completion, one per account forever.
## Potions and other consumables are alchemy-only (EconomyDefs recipes), never dropped.

const TIERS := {
    1: {"name": "Copper & Iron", "floors": [1, 10], "metal": "copper", "metal2": "iron", "wood": "Pine", "gem": "Quartz", "min_level": 1, "ilvl": 5},
    2: {"name": "Steel", "floors": [11, 20], "metal": "steel", "wood": "Oak", "gem": "Amethyst", "min_level": 10, "ilvl": 15},
    3: {"name": "Silver & Mithril", "floors": [21, 30], "metal": "silver", "wood": "Yew", "gem": "Sapphire", "min_level": 20, "ilvl": 25},
    4: {"name": "Runic Gold", "floors": [31, 40], "metal": "gold", "wood": "Ironwood", "gem": "Ruby", "min_level": 30, "ilvl": 35},
    5: {"name": "Obsidian & Draconic", "floors": [41, 50], "metal": "gold", "wood": "Elderwood", "gem": "Dragonstone", "min_level": 40, "ilvl": 45},
}
const METAL_NAMES := {"copper": "Copper", "iron": "Iron", "steel": "Steel", "silver": "Mithril", "gold": "Runic"}

## Who makes what. cost = materials per tier step (x tier); time = work-hours.
const LINES := {
    "blacksmith": {"prof": "blacksmith", "bases": ["sword", "greataxe", "dagger", "mace", "shield", "helm", "mail", "gloves", "greaves", "boots"],
        "cost": {"ingot": 3, "materials": 4}, "cost_t1": {"ore": 5, "materials": 4}, "time": 6.0, "name": "metal"},
    "workshop": {"prof": "carpenter", "bases": ["bow", "staff", "wand"], "cost": {"wood": 6, "materials": 3}, "time": 5.0, "name": "wood"},
    "jeweler": {"prof": "jeweler", "bases": ["ring", "amulet", "charm"], "cost": {"ingot": 1, "materials": 2, "essence": 1}, "time": 6.0, "name": "gem"},
}
const CRAFT_MAX_RARITY := "rare"
const CRAFT_AFFIX_CHOICES := 3
## Smith sets (armour) per tier: pieces bonus at 2 / 3 / 5 pieces.
const SET_PIECES := ["helm", "mail", "gloves", "greaves", "boots"]
const SET_BONUS := {2: {"def": 2}, 3: {"hp_pct": 0.06}, 5: {"def": 4, "mres": 3, "hp_pct": 0.06}}
const SET_NAMES := {1: "Coppervein", 2: "Steelguard", 3: "Moonsilver", 4: "Runeforged", 5: "Dragonscale"}

## Drop themes: which bases an enemy family drops and how they are named.
const THEMES := {
    "bandit": {"bases": ["dagger", "sword", "bow", "hood", "gloves", "boots", "ring"], "names": ["Cutthroat's", "Brigand's", "Bandit's", "Highwayman's"]},
    "orc": {"bases": ["greataxe", "mace", "mail", "helm", "shield", "amulet"], "names": ["Tribal", "Orcish", "Warchief's", "Bonecrusher"]},
    "undead": {"bases": ["sword", "staff", "mail", "helm", "charm"], "names": ["Grave", "Bone", "Hollow", "Wight's"]},
    "beast": {"bases": ["boots", "gloves", "hood", "charm", "bow"], "names": ["Hide", "Fang", "Pelt", "Wild"]},
}
static func theme_of(enemy_id: String) -> String:
    if enemy_id.begins_with("bandido") or enemy_id.begins_with("capitan") or enemy_id.begins_with("jefe_baron"):
        return "bandit"
    if enemy_id.begins_with("orc") or enemy_id.contains("goblin") or enemy_id == "warlord":
        return "orc"
    if enemy_id.begins_with("skeleton") or enemy_id.contains("zombie"):
        return "undead"
    return "beast"


## Cursed (bad) affixes: rolled on 15% of non-common pieces, always with a good one x CURSE_BOOST.
const CURSE_CHANCE := 0.15
const CURSE_BOOST := 1.5
const CURSES := {
    "brittle": {"name": "Brittle", "stat": "def", "min": -3.0, "max": -1.0},
    "frail": {"name": "of Frailty", "stat": "hp", "min": -12.0, "max": -6.0},
    "sluggish": {"name": "Sluggish", "stat": "move", "min": -8.0, "max": -4.0},
    "clumsy": {"name": "Clumsy", "stat": "crit", "min": -0.04, "max": -0.02},
    "dull": {"name": "Dull", "stat": "atk", "min": -3.0, "max": -1.0},
    "unwarded": {"name": "Unwarded", "stat": "mres", "min": -3.0, "max": -1.0},
}

## Light class rules: these classes cannot equip these bases at all (everything else may, at
## NOVICE_EFF if the class is not trained with it).
const FORBIDDEN := {"greataxe": ["class.mage", "class.cleric"], "staff": ["class.warrior"], "wand": ["class.warrior"],
    "bow": [], "shield": ["class.mage", "class.ranger"]}

## Uniques (secret objectives): chance per completed secret; once per account.
const UNIQUE_CHANCE := 0.02


static func tier_of_ilvl(ilvl: int) -> int:
    for t in TIERS:
        if ilvl <= int(TIERS[t]["floors"][1]):
            return int(t)
    return 5


static func tier_of_floor(floor_num: int) -> int:
    return clampi(1 + (maxi(1, floor_num) - 1) / 10, 1, 5)


## Level needed to equip an item.
static func min_level(item: Dictionary) -> int:
    return int(TIERS[tier_of_ilvl(int(item.get("ilvl", 1)))]["min_level"])


## "" if the hero may equip the item, else why not.
static func equip_block(h: HeroData, item: Dictionary) -> String:
    if (FORBIDDEN.get(String(item.get("base", "")), []) as Array).has(h.hero_class):
        return "%s cannot use a %s" % [HeroTables.CLASSES[h.hero_class]["name"], String(ItemDefs.BASES[String(item["base"])]["name"]).to_lower()]
    if h.level < min_level(item):
        return "needs level %d" % min_level(item)
    return ""


## The crafted recipe id for a base at a tier.
static func recipe_id(line: String, base: String, tier: int) -> String:
    return "craft_%s_%s_t%d" % [line, base, tier]


## Display name of a crafted piece ("Copper Mail Shirt", "Pine Longbow", "Quartz Ring").
static func crafted_name(line: String, base: String, tier: int) -> String:
    var t: Dictionary = TIERS[tier]
    var word := ""
    match String(LINES[line]["name"]):
        "metal":
            word = String(METAL_NAMES.get(String(t["metal"]), "Iron"))
        "wood":
            word = String(t["wood"])
        _:
            word = String(t["gem"])
    return "%s %s" % [word, ItemDefs.BASES[base]["name"]]


## Every crafted recipe of the library, EconomyDefs.RECIPES format plus "base", "tier", "line".
static var _recipes: Dictionary = {}
static func recipes() -> Dictionary:
    if not _recipes.is_empty():
        return _recipes
    for line in LINES:
        var l: Dictionary = LINES[line]
        for tier in TIERS:
            for base in l["bases"]:
                var cost: Dictionary = (l.get("cost_t1", l["cost"]) if int(tier) == 1 else l["cost"]).duplicate()
                for k in cost:
                    cost[k] = int(cost[k]) * int(tier)
                if int(tier) >= 2:
                    cost["mat_iron_ore"] = 2 * (int(tier) - 1)
                var kind := String(ItemDefs.BASES[base]["kind"])
                _recipes[recipe_id(line, base, int(tier))] = {"name": crafted_name(line, base, int(tier)), "building": line,
                    "prof": String(l["prof"]), "min": (int(tier) - 1) * 4 + (0 if kind == "jewel" else 1), "work": float(l["time"]) + float(tier),
                    "in": cost, "out": {}, "craft": base, "tier": int(tier), "line": line,
                    "category": "Weapons" if kind == "weapon" else ("Jewellery" if kind == "jewel" else "Armour")}
    return _recipes
