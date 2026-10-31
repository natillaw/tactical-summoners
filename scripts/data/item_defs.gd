class_name ItemDefs
extends RefCounted
## Equipment as data (D-039 slots): rarities, base items, affixes, legendary/mythic uniques and sets.
## An item instance is a plain Dictionary made by ItemGen (saved inside the hero or the stash), so
## there is one inventory model and no dangling references. Numbers are tuning placeholders.

const SLOTS := ["main_hand", "off_hand", "head", "chest", "hands", "legs", "feet", "ring1", "ring2", "amulet", "special"]
const SLOT_NAMES := {"main_hand": "Main hand", "off_hand": "Off hand", "head": "Head", "chest": "Chest", "hands": "Hands",
    "legs": "Legs", "feet": "Feet", "ring1": "Ring", "ring2": "Ring", "amulet": "Amulet", "special": "Special"}

## affixes = random affixes; mult = base stat multiplier; unique = gets a unique power (legendary+).
const RARITIES := {
    "common": {"name": "Common", "affixes": 0, "mult": 1.0, "color": Color(0.85, 0.85, 0.85), "weight": 60.0},
    "uncommon": {"name": "Uncommon", "affixes": 1, "mult": 1.1, "color": Color(0.45, 0.9, 0.45), "weight": 28.0},
    "rare": {"name": "Rare", "affixes": 2, "mult": 1.2, "color": Color(0.4, 0.6, 1.0), "weight": 9.0},
    "epic": {"name": "Epic", "affixes": 3, "mult": 1.35, "color": Color(0.75, 0.4, 1.0), "weight": 2.5},
    "legendary": {"name": "Legendary", "affixes": 2, "mult": 1.5, "color": Color(1.0, 0.6, 0.15), "weight": 0.45, "unique": true},
    "mythic": {"name": "Mythic", "affixes": 3, "mult": 1.7, "color": Color(1.0, 0.25, 0.3), "weight": 0.05, "unique": true},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

## kind: "weapon" | "armor" | "jewel". slot: where it goes ("ring" fits ring1/ring2). two_handed fills
## both hands. classes = trained users (others get NOVICE_EFF of its stats). stats grow per item level.
const NOVICE_EFF := 0.75
const PER_ILVL := 0.12
const BASES := {
    "sword": {"name": "Sword", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 6}, "classes": ["class.warrior", "class.rogue", "class.commoner"]},
    "greataxe": {"name": "Greataxe", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 11}, "classes": ["class.warrior"]},
    "dagger": {"name": "Dagger", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 4, "crit": 0.04}, "classes": ["class.rogue"]},
    "mace": {"name": "Mace", "kind": "weapon", "slot": "main_hand", "stats": {"atk": 5, "mag": 2}, "classes": ["class.cleric", "class.warrior"]},
    "bow": {"name": "Longbow", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"atk": 8}, "classes": ["class.ranger"]},
    "staff": {"name": "Staff", "kind": "weapon", "slot": "main_hand", "two_handed": true, "stats": {"mag": 9}, "classes": ["class.mage", "class.cleric"]},
    "wand": {"name": "Wand", "kind": "weapon", "slot": "main_hand", "stats": {"mag": 5}, "classes": ["class.mage"]},
    "shield": {"name": "Shield", "kind": "armor", "slot": "off_hand", "stats": {"def": 4}, "classes": ["class.warrior", "class.cleric", "class.commoner"]},
    "helm": {"name": "Helm", "kind": "armor", "slot": "head", "stats": {"def": 2}, "classes": []},
    "hood": {"name": "Hood", "kind": "armor", "slot": "head", "stats": {"mres": 2}, "classes": []},
    "mail": {"name": "Mail shirt", "kind": "armor", "slot": "chest", "stats": {"def": 4, "hp": 10}, "classes": []},
    "robe": {"name": "Robe", "kind": "armor", "slot": "chest", "stats": {"mres": 4, "mag": 1}, "classes": []},
    "gloves": {"name": "Gloves", "kind": "armor", "slot": "hands", "stats": {"def": 1, "atk": 1}, "classes": []},
    "greaves": {"name": "Greaves", "kind": "armor", "slot": "legs", "stats": {"def": 2}, "classes": []},
    "boots": {"name": "Boots", "kind": "armor", "slot": "feet", "stats": {"def": 1, "move": 4.0}, "classes": []},
    "ring": {"name": "Ring", "kind": "jewel", "slot": "ring", "stats": {"crit": 0.02}, "classes": []},
    "amulet": {"name": "Amulet", "kind": "jewel", "slot": "amulet", "stats": {"mres": 2, "status_resist": 0.03}, "classes": []},
    "charm": {"name": "Charm", "kind": "jewel", "slot": "special", "stats": {"hp": 8}, "classes": []},
}
const CRAFTABLE := {"weapon": ["sword", "greataxe", "dagger", "mace", "bow", "staff", "wand"],
    "armor": ["shield", "helm", "hood", "mail", "robe", "gloves", "greaves", "boots"]}

## group = only one affix of a group per item; kinds = item kinds it can roll on.
const AFFIXES := {
    "mighty": {"name": "Mighty", "stat": "atk", "min": 2.0, "max": 4.0, "group": "atk", "kinds": ["weapon", "jewel", "armor"]},
    "arcane": {"name": "Arcane", "stat": "mag", "min": 2.0, "max": 4.0, "group": "mag", "kinds": ["weapon", "jewel", "armor"]},
    "keen": {"name": "Keen", "stat": "crit", "min": 0.02, "max": 0.05, "group": "crit", "kinds": ["weapon", "jewel"]},
    "swift": {"name": "Swift", "stat": "interval_pct", "min": 0.04, "max": 0.08, "group": "speed", "kinds": ["weapon", "jewel"]},
    "sturdy": {"name": "Sturdy", "stat": "def", "min": 1.0, "max": 3.0, "group": "def", "kinds": ["armor", "jewel"]},
    "warded": {"name": "Warded", "stat": "mres", "min": 1.0, "max": 3.0, "group": "mres", "kinds": ["armor", "jewel"]},
    "vital": {"name": "of Vitality", "stat": "hp", "min": 6.0, "max": 14.0, "group": "hp", "kinds": ["armor", "jewel"]},
    "resolute": {"name": "of Resolve", "stat": "status_resist", "min": 0.03, "max": 0.07, "group": "resist", "kinds": ["armor", "jewel"]},
    "fleet": {"name": "Fleet", "stat": "move", "min": 4.0, "max": 9.0, "group": "move", "kinds": ["armor", "jewel"]},
    "vampiric": {"name": "Vampiric", "stat": "lifesteal", "min": 0.03, "max": 0.06, "group": "leech", "kinds": ["weapon", "jewel"]},
    "thorned": {"name": "Thorned", "stat": "thorns", "min": 0.08, "max": 0.15, "group": "thorns", "kinds": ["armor"]},
}
## Grows with item level (flat stats only; percentages stay in range).
const SCALING_STATS := ["atk", "mag", "def", "mres", "hp"]

## Uniques: a fixed base with a power that changes how the hero fights. Mythic = the same power
## strengthened (power x MYTHIC_POWER) plus one more affix (RARITIES).
const MYTHIC_POWER := 1.5
const UNIQUES := {
    "emberbrand": {"name": "Emberbrand", "base": "sword", "power": {"on_hit_status": "burn", "chance": 0.35, "dur": 3.0, "mult": 0.12},
        "desc": "Hits may set the target on fire."},
    "gravewhisper": {"name": "Gravewhisper", "base": "dagger", "power": {"kill_heal": 0.15},
        "desc": "Each kill heals 15% of max HP."},
    "frostweave": {"name": "Frostweave", "base": "staff", "power": {"on_hit_status": "slow", "chance": 0.5, "dur": 2.0, "mult": 0.0},
        "desc": "Basic attacks may slow the target."},
    "bramblehide": {"name": "Bramblehide", "base": "mail", "power": {"thorns": 0.25},
        "desc": "Melee attackers take 25% of the damage back."},
    "wayfarer": {"name": "Wayfarer's Stride", "base": "boots", "power": {"slow_immune": 1.0, "move": 10.0},
        "desc": "Cannot be slowed; moves faster."},
}

## Sets: bonuses at 2 and 3 pieces that change play, not only numbers.
const SETS := {
    "warden": {"name": "Warden's Vigil", "pieces": {"helm": "Warden's Helm", "mail": "Warden's Hauberk", "shield": "Warden's Bulwark"},
        "bonus": {2: {"hp_pct": 0.1}, 3: {"shield_mult": 1.5}},
        "desc": "2: +10% max HP. 3: every shield the hero gives or gets is 50% stronger."},
    "nightstalker": {"name": "Nightstalker", "pieces": {"dagger": "Nightstalker Fang", "gloves": "Nightstalker Grips", "boots": "Nightstalker Treads"},
        "bonus": {2: {"crit": 0.05}, 3: {"busy_bonus": 0.3}},
        "desc": "2: +5% crit. 3: +30% damage to foes busy fighting someone else (basic attacks and skills)."},
}


static func rarity_color(r: String) -> Color:
    return RARITIES.get(r, RARITIES["common"])["color"]


## D-060: 8 slots are open now (they match the Dragon Regalia frames); hands, ring2 and special exist
## in the data and saves but stay locked until opened (nothing is generated or equipped for them).
const ACTIVE_SLOTS := ["main_hand", "off_hand", "head", "chest", "legs", "feet", "ring1", "amulet"]


static func slot_open(slot: String) -> bool:
    return ACTIVE_SLOTS.has(slot)


## True when a base goes into an open slot (loot and crafting only make these for now).
static func base_open(base_id: String) -> bool:
    return not slots_for(base_id).is_empty()


## Which open equipment slots a base can go in.
static func slots_for(base_id: String) -> Array:
    var s := String(BASES[base_id]["slot"])
    var all: Array = ["ring1", "ring2"] if s == "ring" else [s]
    return all.filter(func(x): return ACTIVE_SLOTS.has(x))


static func item_label(item: Dictionary) -> String:
    return "%s (%s, ilvl %d)" % [item.get("name", "?"), RARITIES.get(String(item.get("rarity", "common")), {}).get("name", ""), int(item.get("ilvl", 1))]


## Adds the equipment to derived stats (D-039). Weapons out of the class training give NOVICE_EFF.
## Also collects combat powers in stats["mods"]: "procs" (on-hit statuses), thorns, lifesteal,
## kill_heal, slow_immune and set bonuses (shield_mult, busy_bonus).
static func apply_equipment(stats: Dictionary, equipment: Dictionary, class_id: String) -> Dictionary:
    var out := stats.duplicate()
    var mods := {}
    var interval_pct := 0.0
    var hp_pct := 0.0
    var set_count := {}
    for slot in equipment:
        var it: Dictionary = equipment[slot]
        var base: Dictionary = BASES.get(String(it.get("base", "")), {})
        if base.is_empty():
            continue
        var classes: Array = base.get("classes", [])
        var eff := 1.0 if classes.is_empty() or classes.has(class_id) else NOVICE_EFF
        var all: Dictionary = (it.get("stats", {}) as Dictionary).duplicate()
        for a in it.get("affixes", []):
            all[String(a["stat"])] = float(all.get(String(a["stat"]), 0.0)) + float(a["value"])
        var power: Dictionary = it.get("power", {})
        if power.has("on_hit_status"):
            if not mods.has("procs"):
                mods["procs"] = []
            (mods["procs"] as Array).append(power)
        for k in power:
            match String(k):
                "move":
                    all["move"] = float(all.get("move", 0.0)) + float(power[k])
                "kill_heal", "thorns", "slow_immune":
                    mods[k] = float(mods.get(k, 0.0)) + float(power[k])
        for k in all:
            var v := float(all[k]) * eff
            match k:
                "atk", "mag", "def", "mres", "hp":
                    out[k] = int(out.get(k, 0)) + roundi(v)
                "crit", "status_resist":
                    out[k] = clampf(float(out.get(k, 0.0)) + v, 0.0, 0.6)
                "move":
                    out["move"] = float(out.get("move", 70.0)) + v
                "interval_pct":
                    interval_pct += v
                "lifesteal", "thorns":
                    mods[k] = float(mods.get(k, 0.0)) + v
        var st := String(it.get("set", ""))
        if st != "":
            set_count[st] = int(set_count.get(st, 0)) + 1
    for st in set_count:
        var bonus: Dictionary = SETS[st]["bonus"]
        for need in bonus:
            if int(set_count[st]) >= int(need):
                for k in bonus[need]:
                    match k:
                        "hp_pct":
                            hp_pct += float(bonus[need][k])
                        "crit":
                            out["crit"] = clampf(float(out.get("crit", 0.0)) + float(bonus[need][k]), 0.0, 0.6)
                        _:
                            mods[k] = bonus[need][k]
    out["hp"] = roundi(float(out.get("hp", 1)) * (1.0 + hp_pct))
    out["interval"] = clampf(float(out.get("interval", 1.0)) * (1.0 - interval_pct), 0.6, 1.6)
    out["mods"] = mods
    return out
