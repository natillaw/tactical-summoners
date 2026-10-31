class_name ItemGen
extends RefCounted
## Procedural equipment (Diablo-like principles, own data): base + rarity + affixes within ranges,
## uniques and set pieces. Deterministic for a given RNG state. `uid` must be unique per save.

## Rarity roll: deeper floors and better sources shift weight to the rare end. floor_bonus: boss = 3.
static func roll_rarity(rng: RandomNumberGenerator, ilvl: int, source_bonus: float = 0.0, min_rarity: String = "common") -> String:
    var total := 0.0
    var weights := {}
    var start := ItemDefs.RARITY_ORDER.find(min_rarity)
    for i in ItemDefs.RARITY_ORDER.size():
        if i < start:
            continue
        var r: String = ItemDefs.RARITY_ORDER[i]
        var w := float(ItemDefs.RARITIES[r]["weight"])
        if i >= 2:
            w *= 1.0 + 0.12 * float(ilvl) + source_bonus
        weights[r] = w
        total += w
    var roll := rng.randf() * total
    for r in weights:
        roll -= float(weights[r])
        if roll <= 0.0:
            return r
    return ItemDefs.RARITY_ORDER[start]


## Makes one item. base_id "" = random base (of kind when given). Set pieces: SET_CHANCE on rare/epic.
const SET_CHANCE := 0.15
static func generate(rng: RandomNumberGenerator, uid: int, ilvl: int, rarity: String, base_id: String = "", kind: String = "") -> Dictionary:
    ilvl = maxi(1, ilvl)
    var rd: Dictionary = ItemDefs.RARITIES[rarity]
    var unique_id := ""
    if rd.get("unique", false) and base_id == "":
        var uk: Array = ItemDefs.UNIQUES.keys()
        uk.sort()
        unique_id = String(uk[rng.randi() % uk.size()])
        base_id = String(ItemDefs.UNIQUES[unique_id]["base"])
    if base_id == "":
        var pool: Array = []
        for b in ItemDefs.BASES:
            if (kind == "" or String(ItemDefs.BASES[b]["kind"]) == kind) and ItemDefs.base_open(String(b)):
                pool.append(b)
        pool.sort()
        base_id = String(pool[rng.randi() % pool.size()])
    var base: Dictionary = ItemDefs.BASES[base_id]
    var scale := (1.0 + ItemDefs.PER_ILVL * float(ilvl - 1)) * float(rd["mult"])
    var stats := {}
    for k in base["stats"]:
        var v := float(base["stats"][k])
        stats[k] = roundi(v * scale) if ItemDefs.SCALING_STATS.has(k) else snappedf(v * float(rd["mult"]), 0.01)
    var item := {"uid": uid, "base": base_id, "name": String(base["name"]), "rarity": rarity, "ilvl": ilvl,
        "stats": stats, "affixes": [], "power": {}, "unique": "", "set": ""}
    if unique_id != "":
        var u: Dictionary = ItemDefs.UNIQUES[unique_id]
        item["unique"] = unique_id
        item["name"] = String(u["name"])
        var pw: Dictionary = (u["power"] as Dictionary).duplicate()
        if rarity == "mythic":
            for k in pw:
                if typeof(pw[k]) == TYPE_FLOAT and k != "chance" and k != "dur":
                    pw[k] = snappedf(float(pw[k]) * ItemDefs.MYTHIC_POWER, 0.01)
            item["name"] = "Mythic " + String(u["name"])
        item["power"] = pw
    elif (rarity == "rare" or rarity == "epic") and rng.randf() < SET_CHANCE:
        for st in ItemDefs.SETS:
            if (ItemDefs.SETS[st]["pieces"] as Dictionary).has(base_id):
                item["set"] = st
                item["name"] = String(ItemDefs.SETS[st]["pieces"][base_id])
    _roll_affixes(rng, item, int(rd["affixes"]), String(base["kind"]), ilvl)
    if item["unique"] == "" and item["set"] == "" and not (item["affixes"] as Array).is_empty():
        var an := String(ItemDefs.AFFIXES[String(item["affixes"][0]["id"])]["name"])
        item["name"] = ("%s %s" % [item["name"], an]) if an.begins_with("of ") else ("%s %s" % [an, item["name"]])
    return item


static func _roll_affixes(rng: RandomNumberGenerator, item: Dictionary, count: int, kind: String, ilvl: int) -> void:
    var pool: Array = []
    for a in ItemDefs.AFFIXES:
        if (ItemDefs.AFFIXES[a]["kinds"] as Array).has(kind):
            pool.append(a)
    pool.sort()
    var groups := {}
    var scale := 1.0 + ItemDefs.PER_ILVL * float(ilvl - 1)
    while count > 0 and not pool.is_empty():
        var id := String(pool.pop_at(rng.randi() % pool.size()))
        var a: Dictionary = ItemDefs.AFFIXES[id]
        if groups.has(a["group"]):
            continue
        groups[a["group"]] = true
        var v := rng.randf_range(float(a["min"]), float(a["max"]))
        if ItemDefs.SCALING_STATS.has(String(a["stat"])):
            v = float(roundi(v * scale))
        else:
            v = snappedf(v, 0.01)
        (item["affixes"] as Array).append({"id": id, "stat": String(a["stat"]), "value": v})
        count -= 1


## Crafted item (blacksmith): rarity comes from the smith's level and the forge level, with a small
## controlled luck. A high forge with an apprentice cannot make masterpieces (and the reverse).
static func craft_rarity(rng: RandomNumberGenerator, prof_level: int, building_level: int) -> String:
    var score := minf(float(prof_level) * 1.5, float(building_level) * 3.0) + float(rng.randi_range(-1, 1))
    if score >= 12.0:
        return "epic"
    if score >= 7.0:
        return "rare"
    if score >= 3.0:
        return "uncommon"
    return "common"


## One-line description of the item's numbers for the UI.
static func describe(item: Dictionary) -> String:
    var parts: Array = []
    for k in item.get("stats", {}):
        parts.append("%s %s" % [_fmt(String(k), float(item["stats"][k])), k])
    for a in item.get("affixes", []):
        parts.append("%s %s" % [_fmt(String(a["stat"]), float(a["value"])), a["stat"]])
    if String(item.get("unique", "")) != "":
        parts.append(String(ItemDefs.UNIQUES[String(item["unique"])]["desc"]))
    if String(item.get("set", "")) != "":
        parts.append("Set: " + String(ItemDefs.SETS[String(item["set"])]["name"]))
    return ", ".join(parts)


static func _fmt(stat: String, v: float) -> String:
    if stat in ["crit", "status_resist", "interval_pct", "lifesteal", "thorns"]:
        return "+%d%%" % roundi(v * 100.0)
    return "+%d" % roundi(v)
