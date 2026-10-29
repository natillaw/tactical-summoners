class_name HeroData
extends RefCounted
## One summoned hero. Everything needed to rebuild it lives in to_dict(), so saves
## never depend on the generator staying identical between versions.

var id: String = ""
var hero_seed: int = 0
var hero_name: String = ""
var epithet: String = ""
var stars: int = 1
var level: int = 1
var xp: int = 0
var hero_class: String = "class.none"
var appearance: Dictionary = {}   # layer key -> "Folder/style_color" ("" = layer not used)
var traits: Array = []            # trait ids
var passives: Array = []          # passive ids
var background_id: String = ""
var background_text: String = ""
var profession: String = ""        # past life profession/job for base building lobby bonuses
var variance: Dictionary = {}     # stat key -> small seeded multiplier
var callsign: String = ""         # only set when another hero would share the same display name
var generator_version: int = 1    # 1 = Drop A heroes, 2 = summon system v2
var origin_banner: String = ""
var summon_index: int = 0         # global pull number when summoned (0 = unknown/legacy)
# Social state (spec sec 7). Three SEPARATE values; none of them ever blocks a direct order.
var trust: int = 50               # long-term, 0-100: belief that the commander protects/keeps promises
var obedience: int = 50           # long-term, 0-100: command discipline
var composure: int = 100          # short-term mission steadiness, 0-100 (resets between missions)
# Structured event ledger: [{seq, type, trust, obedience, info}], newest last, capped.
var events: Array = []
var event_seq: int = 0

const EVENT_CAP := 100


func base_display_name() -> String:
    if epithet == "":
        return hero_name
    return "%s %s" % [hero_name, epithet]


func display_name() -> String:
    if callsign == "":
        return base_display_name()
    return "%s \"%s\"" % [base_display_name(), callsign]


## Records a structured event and applies its deterministic Trust/Obedience deltas.
func add_event(type: String, info: Dictionary = {}, trust_delta: int = 0, obedience_delta: int = 0) -> void:
    trust = clampi(trust + trust_delta, 0, 100)
    obedience = clampi(obedience + obedience_delta, 0, 100)
    event_seq += 1
    events.append({"seq": event_seq, "type": type, "trust": trust_delta, "obedience": obedience_delta, "info": info.duplicate()})
    while events.size() > EVENT_CAP:
        events.pop_front()


## JSON turns every number into a float. Whole floats go back to ints so a reloaded
## ledger/log is identical to what was saved.
static func intify(v: Variant) -> Variant:
    match typeof(v):
        TYPE_FLOAT:
            return int(v) if is_equal_approx(v, roundf(v)) else v
        TYPE_DICTIONARY:
            var out := {}
            for k in v:
                out[k] = intify(v[k])
            return out
        TYPE_ARRAY:
            return v.map(func(x): return intify(x))
    return v


func set_composure(v: int) -> void:
    composure = clampi(v, 0, 100)


## Old (v1) saves only had one "loyalty" number. It becomes Trust; Obedience is derived from traits.
static func legacy_obedience(trait_ids: Array) -> int:
    var v := 50
    for t in trait_ids:
        v += int(HeroTables.OBEDIENCE_MODS.get(t, 0))
    return clampi(v, 0, 100)


func class_title() -> String:
    return String(HeroTables.CLASSES[hero_class]["name"])


func star_color() -> Color:
    return HeroTables.STAR_COLORS[stars]


func signature() -> String:
    var parts: Array = []
    for key in SpriteComposer.LAYER_ORDER:
        parts.append(String(appearance.get(key, "")))
    return "|".join(parts)


func level_cap() -> int:
    return int(HeroTables.STAR_DATA[stars]["level_cap"])


func is_max_level() -> bool:
    return level >= level_cap()


func xp_to_next() -> int:
    return 40 + level * level * 6


## Adds experience and returns how many levels were gained.
func add_xp(amount: int) -> int:
    var gained := 0
    if is_max_level():
        return 0
    xp += amount
    while level < level_cap() and xp >= xp_to_next():
        xp -= xp_to_next()
        level += 1
        gained += 1
    if level >= level_cap():
        xp = 0
    return gained


func promotion_cost() -> int:
    return stars * 3


func can_promote() -> bool:
    return stars < HeroTables.MAX_STARS and is_max_level()


func promote() -> void:
    if not can_promote():
        return
    stars += 1
    HeroGenerator.apply_promotion(self)
    add_event("promoted", {"stars": stars})


func get_stats() -> Dictionary:
    var base: Dictionary = HeroTables.CLASSES[hero_class]["base"]
    var mult: float = float(HeroTables.STAR_DATA[stars]["mult"])
    var growth: float = 1.0 + 0.12 * float(level - 1)
    var out := {}
    for k in HeroTables.STAT_KEYS:
        var v: float = float(base[k]) * mult * growth * float(variance.get(k, 1.0))
        for t in traits:
            var mods: Dictionary = HeroTables.TRAITS[t].get("mods", {})
            v *= float(mods.get(k, 1.0))
        out[k] = maxi(1, roundi(v))
    return out


func power() -> int:
    var s := get_stats()
    return roundi(float(s["hp"]) * 0.1 + float(s["atk"]) * 1.5 + float(s["mag"]) * 1.5 + float(s["def"]) + float(s["spd"]))


func to_dict() -> Dictionary:
    return {
        "id": id,
        "seed": "%x" % hero_seed,   # stored as hex text: JSON numbers would lose 64-bit precision
        "name": hero_name,
        "epithet": epithet,
        "stars": stars,
        "level": level,
        "xp": xp,
        "class": hero_class,
        "appearance": appearance.duplicate(),
        "traits": traits.duplicate(),
        "passives": passives.duplicate(),
        "background_id": background_id,
        "background_text": background_text,
        "profession": profession,
        "variance": variance.duplicate(),
        "callsign": callsign,
        "generator_version": generator_version,
        "origin_banner": origin_banner,
        "summon_index": summon_index,
        "trust": trust,
        "obedience": obedience,
        "composure": composure,
        "event_seq": event_seq,
        "events": events.duplicate(true),
    }


static func from_dict(d: Dictionary) -> HeroData:
    var h := HeroData.new()
    h.id = str(d.get("id", ""))
    h.hero_seed = String(d.get("seed", "0")).hex_to_int()
    h.hero_name = str(d.get("name", "Unknown"))
    h.epithet = str(d.get("epithet", ""))
    h.stars = clampi(int(d.get("stars", 1)), 1, HeroTables.MAX_STARS)
    h.level = maxi(1, int(d.get("level", 1)))
    h.xp = int(d.get("xp", 0))
    h.hero_class = str(d.get("class", "class.none"))
    if not HeroTables.CLASSES.has(h.hero_class):
        h.hero_class = "class.none"
    h.appearance = (d.get("appearance", {}) as Dictionary).duplicate()
    h.traits = (d.get("traits", []) as Array).duplicate()
    h.passives = (d.get("passives", []) as Array).duplicate()
    h.background_id = str(d.get("background_id", ""))
    h.background_text = str(d.get("background_text", ""))
    h.profession = str(d.get("profession", ""))
    h.variance = (d.get("variance", {}) as Dictionary).duplicate()
    h.callsign = str(d.get("callsign", ""))
    h.generator_version = int(d.get("generator_version", 1))
    h.origin_banner = str(d.get("origin_banner", ""))
    h.summon_index = int(d.get("summon_index", 0))
    if d.has("trust"):
        h.trust = clampi(int(d["trust"]), 0, 100)
        h.obedience = clampi(int(d.get("obedience", 50)), 0, 100)
        h.composure = clampi(int(d.get("composure", 100)), 0, 100)
    else:
        # v1 save: single loyalty value -> Trust, Obedience derived from traits
        h.trust = clampi(int(d.get("loyalty", 50)), 0, 100)
        h.obedience = legacy_obedience(h.traits)
        h.composure = 100
    h.events = intify(d.get("events", []) as Array)
    h.event_seq = int(d.get("event_seq", h.events.size()))
    return h
