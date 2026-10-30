extends Node
## Autoload "Game": player progress, summoning, training, party, save/load.
## UI scripts never touch the save file directly; they call these methods and listen to `changed`.

signal changed

const DEFAULT_SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5
const PARTY_SIZE := 5            # slots 0-2 = front row, slots 3-4 = back row
const XP_PER_BOOK := 100

var gems: int = 2000
var stones: int = 5              # promotion stones
var books: int = 5               # training books
var pity4: int = 0
var pity5: int = 0
var heroes: Dictionary = {}      # hero id -> HeroData (insertion order = order summoned)
var party: Array = ["", "", "", "", ""]
var rng := RandomNumberGenerator.new()
var autosave: bool = true
var save_path: String = DEFAULT_SAVE_PATH
var pull_count: int = 0          # total summons ever done (global pull number)
var summon_log: Array = []       # newest last, capped: lets any pull be reproduced from its seed
var memorial: Array = []         # fallen heroes, oldest first, NEVER capped or edited (D-011)
var _signatures: Dictionary = {} # appearance signatures already owned -> no duplicate looks
var hq_facilities: Dictionary = {"kitchen": 1, "workshop": 1, "infirmary": 1, "common": 1}
var hq_outputs: Dictionary = {"food": 50, "materials": 50, "medicine": 50}
var town_buildings: Dictionary = {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1}
var tower_maps: Dictionary = {} # floor_num (str) -> {"seed": int, "width": int, "height": int, "grid_rows": Array}


func _ready() -> void:
    rng.randomize()
    load_game()


# --- summoning ----------------------------------------------------------------

## Spends gems and returns the new heroes (empty array if the banner is invalid or gems are short).
## Nothing changes (no gems, no pity, no log) unless the whole summon can be paid for.
func pull(count: int, banner_id: String = SummonConfig.DEFAULT_BANNER) -> Array:
    var banner := SummonConfig.get_banner(banner_id)
    if banner.is_empty() or count <= 0:
        return []
    var problems := SummonConfig.validate(banner)
    if not problems.is_empty():
        push_error("Summon banner '%s' is invalid: %s" % [banner_id, ", ".join(problems)])
        return []
    var cost := SummonConfig.cost_for(banner, count)
    if gems < cost or not can_summon(count):
        return []
    gems -= cost
    var out: Array = []
    for i in count:
        var before4 := pity4
        var before5 := pity5
        var r := Gacha.roll_stars(rng, pity4, pity5, banner)
        pity4 = int(r["pity4"])
        pity5 = int(r["pity5"])
        var h := _generate_unique(int(r["stars"]))
        pull_count += 1
        h.summon_index = pull_count
        h.origin_banner = banner_id
        h.add_event("summoned", {"banner": banner_id, "banner_version": int(banner["version"]), "pull": pull_count})
        h.add_memory("summoned", "Summoned from the %s banner into the order." % banner_id, "", 2)
        heroes[h.id] = h
        _signatures[h.signature()] = true
        _log_pull(h, banner_id, int(banner["version"]), before4, before5)
        out.append(h)
    _commit()
    return out


func _log_pull(h: HeroData, banner_id: String, banner_version: int, before4: int, before5: int) -> void:
    summon_log.append({
        "n": pull_count,
        "banner": banner_id,
        "banner_version": banner_version,
        "seed": "%x" % h.hero_seed,
        "stars": h.stars,
        "gen": h.generator_version,
        "pity4_before": before4,
        "pity5_before": before5,
        "hero_id": h.id,
    })
    while summon_log.size() > SummonConfig.LOG_CAP:
        summon_log.pop_front()


func _generate_unique(stars: int) -> HeroData:
    var h: HeroData = null
    for attempt in 100:
        h = HeroGenerator.generate(_new_seed(), stars)
        if not _signatures.has(h.signature()) and not heroes.has(h.id):
            break
    _disambiguate_name(h)
    return h


## Two heroes never show the same name: the newer one gets a deterministic callsign.
func _disambiguate_name(h: HeroData) -> void:
    var taken := {}
    for id in heroes:
        taken[(heroes[id] as HeroData).display_name()] = true
    if not taken.has(h.display_name()):
        return
    h.callsign = SummonConfig.callsign_for(h.hero_seed, h.base_display_name(), taken)


func _new_seed() -> int:
    return ((int(rng.randi()) << 31) ^ int(rng.randi())) & 0x7FFFFFFFFFFFFFFF


# --- hero growth ----------------------------------------------------------------

func train(h: HeroData, use_books: int = 1) -> bool:
    if h == null or h.is_max_level() or books < use_books or use_books <= 0:
        return false
    books -= use_books
    h.add_xp(XP_PER_BOOK * use_books)
    _commit()
    return true


func promote(h: HeroData) -> bool:
    if h == null or not h.can_promote() or stones < h.promotion_cost():
        return false
    stones -= h.promotion_cost()
    h.promote()
    _commit()
    return true


# --- party ----------------------------------------------------------------------

func assign_party(slot: int, hero_id: String) -> void:
    if slot < 0 or slot >= PARTY_SIZE or not heroes.has(hero_id):
        return
    for i in PARTY_SIZE:
        if party[i] == hero_id:
            party[i] = ""
    party[slot] = hero_id
    _commit()


func clear_slot(slot: int) -> void:
    if slot < 0 or slot >= PARTY_SIZE:
        return
    party[slot] = ""
    _commit()


func clear_party() -> void:
    party = ["", "", "", "", ""]
    _commit()


func party_slot_of(hero_id: String) -> int:
    return party.find(hero_id)


func party_heroes() -> Array:
    var out: Array = []
    for id in party:
        if heroes.has(id):
            out.append(heroes[id])
    return out


# --- permanent death / memorial (D-011, T-013) -----------------------------------

## Permanent death: the hero leaves the roster and party for good and a full snapshot goes to the
## memorial. Returns false if the hero is not on the roster (e.g. a sandbox test hero).
## Survivors in the party lose a little Trust (deterministic, never a refused order: D-016).
func record_death(h: HeroData, cause: String = "", mission: String = "") -> bool:
    if h == null or not heroes.has(h.id):
        return false
    h.add_event("died", {"cause": cause, "mission": mission})
    memorial.append({
        "n": memorial.size() + 1,
        "hero_id": h.id,
        "name": h.display_name(),
        "stars": h.stars,
        "level": h.level,
        "class": h.hero_class,
        "traits": h.traits.duplicate(),
        "background": h.background_text,
        "summon_index": h.summon_index,
        "cause": cause,
        "mission": mission,
        "snapshot": h.to_dict(),
    })
    heroes.erase(h.id)            # the appearance signature stays taken: no look is ever reused
    for i in PARTY_SIZE:
        if party[i] == h.id:
            party[i] = ""
    for other in party_heroes():
        var oh := other as HeroData
        oh.add_event("ally_fell", {"name": h.display_name()}, -2, 0)
        oh.add_memory("witnessed_death", "Witnessed the fall of %s in combat." % h.display_name(), h.id, 3)
        oh.update_relationship(h.id, -5, "death")
    _commit()
    return true


# --- headquarters & simulation (Phase 2 & Mega Prompt Town & Persistent Maps) --------

func assign_hq(hero_id: String, facility: String) -> void:
    if not heroes.has(hero_id):
        return
    var h: HeroData = heroes[hero_id]
    h.hq_assignment = facility
    h.activity_state = "working" if facility != "" else "resting"
    h.add_memory("hq_assign", "Assigned to %s" % (facility if facility != "" else "Quarters"), "", 1)
    _commit()


func unassign_hq(hero_id: String) -> void:
    assign_hq(hero_id, "")


func max_hero_capacity() -> int:
    var cap := 5 # base town population
    for b_id in town_buildings:
        if b_id.begins_with("dorm"):
            cap += int(town_buildings[b_id]) * 5
    return cap


func can_summon(count: int) -> bool:
    return heroes.size() + count <= max_hero_capacity()


func upgrade_building(bid: String, cost: int) -> bool:
    if hq_outputs.get("materials", 0) < cost:
        return false
    hq_outputs["materials"] -= cost
    if not town_buildings.has(bid):
        town_buildings[bid] = 1
    else:
        town_buildings[bid] = int(town_buildings[bid]) + 1
    _commit()
    return true


func get_or_create_tower_floor_map(floor_num: int) -> ProceduralMap:
    var f_key := str(floor_num)
    if tower_maps.has(f_key):
        var m_data: Dictionary = tower_maps[f_key]
        var pmap := ProceduralMap.new(int(m_data["width"]), int(m_data["height"]), int(m_data["seed"]), floor_num)
        return pmap
    else:
        var cfg := TowerExpedition.get_floor_config(floor_num)
        var f_seed := rng.randi()
        var pmap := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), f_seed, floor_num)
        tower_maps[f_key] = {
            "seed": f_seed,
            "width": pmap.width,
            "height": pmap.height,
            "grid_rows": pmap.grid_rows.duplicate()
        }
        _commit()
        return pmap


func process_headquarters_turn() -> Dictionary:
    var summary := {"food_produced": 0, "materials_produced": 0, "medicine_produced": 0, "events": 0}
    var facility_workers := {}
    for id in heroes:
        var h: HeroData = heroes[id]
        if h.hq_assignment != "":
            if not facility_workers.has(h.hq_assignment):
                facility_workers[h.hq_assignment] = []
            (facility_workers[h.hq_assignment] as Array).append(h)
    
    for fac in facility_workers:
        var workers: Array = facility_workers[fac]
        for w in workers:
            var worker := w as HeroData
            match fac:
                "kitchen":
                    hq_outputs["food"] += 5
                    summary["food_produced"] += 5
                    worker.add_memory("work_kitchen", "Prepared provisions in the kitchen.", "", 1)
                "workshop":
                    hq_outputs["materials"] += 4
                    summary["materials_produced"] += 4
                    worker.add_memory("work_workshop", "Crafted tools and maintained gear in the workshop.", "", 1)
                "infirmary":
                    hq_outputs["medicine"] += 3
                    summary["medicine_produced"] += 3
                    worker.add_memory("work_infirmary", "Tended to the wounded in the infirmary.", "", 1)
                "common", "training":
                    worker.add_memory("work_common", "Spent time socializing and training in headquarters.", "", 1)
            summary["events"] += 1
            
            for other in workers:
                var o := other as HeroData
                if o.id != worker.id:
                    worker.update_relationship(o.id, 1, "hq_work")
    _commit()
    return summary


# --- debug / reset ----------------------------------------------------------------

func grant(add_gems: int, add_stones: int, add_books: int) -> void:
    gems += add_gems
    stones += add_stones
    books += add_books
    _commit()


func new_game() -> void:
    gems = 2000
    stones = 5
    books = 5
    pity4 = 0
    pity5 = 0
    pull_count = 0
    summon_log.clear()
    memorial.clear()
    heroes.clear()
    _signatures.clear()
    party = ["", "", "", "", ""]
    hq_facilities = {"kitchen": 1, "workshop": 1, "infirmary": 1, "common": 1}
    hq_outputs = {"food": 50, "materials": 50, "medicine": 50}
    town_buildings = {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1}
    tower_maps.clear()
    SpriteComposer.clear_cache()
    _commit()


# --- save / load ------------------------------------------------------------------

func _commit() -> void:
    if autosave:
        save_game()
    changed.emit()


func save_game() -> bool:
    var hero_list: Array = []
    for id in heroes:
        hero_list.append((heroes[id] as HeroData).to_dict())
    var data := {
        "version": SAVE_VERSION,
        "gems": gems,
        "stones": stones,
        "books": books,
        "pity4": pity4,
        "pity5": pity5,
        "pull_count": pull_count,
        "summon_log": summon_log,
        "memorial": memorial,
        "party": party,
        "heroes": hero_list,
        "hq_facilities": hq_facilities,
        "hq_outputs": hq_outputs,
        "town_buildings": town_buildings,
        "tower_maps": tower_maps,
    }
    return _write_atomic(JSON.stringify(data))


## Write to a temp file, check it parses, keep the previous save as .bak, then swap it in.
func _write_atomic(text: String) -> bool:
    var tmp := save_path + ".tmp"
    var bak := save_path + ".bak"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_warning("Could not write save file: %s" % tmp)
        return false
    f.store_string(text)
    f.close()
    if typeof(JSON.parse_string(FileAccess.get_file_as_string(tmp))) != TYPE_DICTIONARY:
        push_warning("Save verification failed; previous save kept.")
        return false
    var dir := DirAccess.open(save_path.get_base_dir())
    if dir == null:
        return false
    if FileAccess.file_exists(save_path):
        dir.copy(save_path, bak)
        dir.remove(save_path)
    if dir.rename(tmp, save_path) != OK:
        if FileAccess.file_exists(bak):
            dir.copy(bak, save_path)
        push_warning("Could not finalize save; restored backup.")
        return false
    return true


func load_game() -> void:
    var parsed: Variant = _read_save(save_path)
    if typeof(parsed) != TYPE_DICTIONARY:
        parsed = _read_save(save_path + ".bak")
        if typeof(parsed) == TYPE_DICTIONARY:
            push_warning("Main save unreadable, loaded the backup.")
    if typeof(parsed) != TYPE_DICTIONARY:
        if FileAccess.file_exists(save_path):
            push_warning("Save file unreadable, starting a new game.")
        new_game()
        return
    apply_save(parsed)
    changed.emit()


func _read_save(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func apply_save(data: Dictionary) -> void:
    data = _migrate(data)
    gems = int(data.get("gems", 0))
    stones = int(data.get("stones", 0))
    books = int(data.get("books", 0))
    pity4 = int(data.get("pity4", 0))
    pity5 = int(data.get("pity5", 0))
    heroes.clear()
    _signatures.clear()
    for d in data.get("heroes", []):
        var h := HeroData.from_dict(d)
        if h.id == "":
            continue
        heroes[h.id] = h
        _signatures[h.signature()] = true
    pull_count = maxi(int(data.get("pull_count", heroes.size())), heroes.size())
    summon_log = HeroData.intify(data.get("summon_log", []) as Array)
    memorial = HeroData.intify(data.get("memorial", []) as Array)
    party = ["", "", "", "", ""]
    var saved_party: Array = data.get("party", [])
    for i in mini(saved_party.size(), PARTY_SIZE):
        var id := str(saved_party[i])
        if heroes.has(id):
            party[i] = id
    hq_facilities = HeroData.intify(data.get("hq_facilities", {"kitchen": 1, "workshop": 1, "infirmary": 1, "common": 1}) as Dictionary)
    hq_outputs = HeroData.intify(data.get("hq_outputs", {"food": 50, "materials": 50, "medicine": 50}) as Dictionary)
    town_buildings = HeroData.intify(data.get("town_buildings", {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1}) as Dictionary)
    tower_maps = HeroData.intify(data.get("tower_maps", {}) as Dictionary)


## Old save versions get upgraded here when the format changes.
func _migrate(data: Dictionary) -> Dictionary:
    var v := int(data.get("version", 1))
    if v < 2:
        # v1 -> v2: summon log + pull counter appear; hero Trust/Obedience/Composure are
        # filled per hero inside HeroData.from_dict (old "loyalty" becomes Trust).
        data["pull_count"] = (data.get("heroes", []) as Array).size()
        data["summon_log"] = []
    if v < 3:
        data["memorial"] = []         # v2 -> v3: memorial of fallen heroes appears
    if v < 4:
        data["hq_facilities"] = {"kitchen": 1, "workshop": 1, "infirmary": 1, "common": 1}
        data["hq_outputs"] = {"food": 50, "materials": 50, "medicine": 50}
    if v < 5:
        data["town_buildings"] = {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1}
        data["tower_maps"] = {}
    data["version"] = SAVE_VERSION
    return data
