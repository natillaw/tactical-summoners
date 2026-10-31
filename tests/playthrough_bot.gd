extends Control
## Automated playthrough (not a pass/fail suite): a scripted "player" starts a new account, builds the
## village, and plays floors 1-5 for real with player-level orders only (attack-move, W/E/R skills,
## rescue, gather, carry the relic, extract). No damage cheats. Prints a report for balance review.
##   godot --headless --path . res://tests/playthrough_bot.tscn
const DT := 1.0 / 30.0
const THINK := 0.5
const MAX_SIM := 30.0 * 60.0          # seconds of game time per attempt
var ATTEMPTS := int(OS.get_environment("PT_ATTEMPTS")) if OS.get_environment("PT_ATTEMPTS") != "" else 3

var log_lines: Array = []


func say(s: String) -> void:
    print(s)
    log_lines.append(s)


func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://playthrough.json"
    Game.new_game()
    var first: Array = Game.starter_summons()
    say("== NEW ACCOUNT: %d starter heroes, gems %d, capacity %d" % [first.size(), Game.gems, Game.max_hero_capacity()])
    for h in Game.heroes.values():
        say("  %s" % _hero_line(h))
    say("  stock: %s" % str(Game.hq_outputs))
    _town_turn("start")
    var from_floor := int(OS.get_environment("PT_FROM")) if OS.get_environment("PT_FROM") != "" else 1
    for f0 in range(1, from_floor):
        Game.tower_cleared[str(f0)] = 1
    for floor_num in range(from_floor, 6):
        var done := false
        for attempt in range(1, ATTEMPTS + 1):
            _pick_party()
            var r: Dictionary = await _play_floor(floor_num, attempt)
            _town_turn("after floor %d attempt %d" % [floor_num, attempt])
            if r["outcome"] == "SUCCESS":
                done = true
                break
            if floor_num > 1:
                say("  -> grinding floor %d for experience before retrying" % (floor_num - 1))
                _pick_party()
                await _play_floor(floor_num - 1, 0)
                _town_turn("after grinding")
            if Game.party_heroes().size() < Game.PARTY_SIZE and Game.heroes.size() < Game.PARTY_SIZE:
                say("!! fewer than 5 heroes left: cannot field a squad")
                break
        if not done:
            say("!! FLOOR %d NOT CLEARED after %d attempts — stopping" % [floor_num, ATTEMPTS])
            break
    say("== FINAL: heroes %d, memorial %d, gems %d, stash %d, cleared %s" % [Game.heroes.size(), Game.memorial.size(), Game.gems, Game.stash.size(), str(Game.tower_cleared)])
    say("  buildings: %s" % str(Game.town_buildings))
    say("  stock: %s" % str(Game.hq_outputs))
    for h in Game.heroes.values():
        say("  %s" % _hero_line(h))
    var f := FileAccess.open("user://playthrough_report.txt", FileAccess.WRITE)
    if f != null:
        f.store_string("\n".join(log_lines))
    get_tree().quit(0)


func _hero_line(h: HeroData) -> String:
    var p: Array = []
    for k in h.professions:
        p.append("%s%d" % [k, int(h.professions[k]["lvl"])])
    return "%s %d* Lv%d %s pow=%d hp=%d profs=%s job=%s hunger=%d fat=%d stress=%d dis=%s skills=%s eq=%d" % [h.display_name(), h.stars, h.level,
        h.hero_class.replace("class.", ""), h.power(), int(h.get_stats().get("hp", 0)), ",".join(p), h.hq_assignment, h.hunger, h.fatigue, h.stress,
        str(h.diseases.map(func(d): return d["id"])), str(h.loadout), h.equipment.size()]


# --- town ---------------------------------------------------------------------------------------

const BUILD_ORDER := ["workshop", "lumber_camp", "mine", "kitchen", "farm", "town_hall", "warehouse", "ascension", "dorm_3",
    "training_grounds", "infirmary", "blacksmith", "alchemy", "common", "library", "barracks", "war_room", "memorial"]
const WORK_ORDER := ["workshop", "workshop", "lumber_camp", "mine", "lumber_camp", "kitchen", "farm", "infirmary", "blacksmith", "alchemy", "mine", "farm"]


func _town_turn(why: String) -> void:
    say("-- TOWN (%s) day %d %s" % [why, Game.town_day(), Game.town_time_text()])
    # pending skill choices: take the first option
    for h in Game.heroes.values():
        while not (h as HeroData).skill_choices.is_empty():
            var c: Dictionary = h.skill_choices[0]
            if not h.choose_skill(0, String(c["options"][0])):
                break
        for s in h.skills:
            if h.loadout.size() < SkillDefs.MAX_SLOTS and not h.loadout.has(s):
                h.equip_skill(h.loadout.size(), String(s))
    # build what we can afford, in order
    for bid in BUILD_ORDER:
        if not TownTables.BUILDINGS.has(bid):
            continue
        if Game.construction_block(bid) == "":
            var lvl := Game.building_level(bid)
            if Game.build_or_upgrade(bid):
                say("  build %s -> %d (materials left %d)" % [bid, lvl + 1, int(Game.hq_outputs.get("materials", 0))])
            else:
                say("  build %s refused: %s" % [bid, Game.last_reason])
    # jobs for everyone not in the party
    var party_ids: Array = Game.party.duplicate()
    for h in Game.heroes.values():
        if party_ids.has(h.id) or h.hq_assignment == "construction":
            continue
        if h.hq_assignment != "":
            continue
        var placed := false
        for k in h.professions:
            for bid in TownTables.ids():
                if Game.building_level(bid) > 0 and Game.workplace_prof(bid) == String(k) and Game.assign_work(h, bid) == "":
                    placed = true
                    break
            if placed:
                break
        if not placed:
            for bid in WORK_ORDER:
                if Game.building_level(bid) > 0 and Game.assign_work(h, bid) == "":
                    placed = true
                    break
        say("  job %s (%s) -> %s" % [h.display_name(), ",".join(h.professions.keys()), h.hq_assignment if h.hq_assignment != "" else "NONE: " + Game.last_reason])
    # set default jobs on producing buildings
    var want := {"workshop": "make_materials", "lumber_camp": "fell_wood", "mine": "dig_stone", "kitchen": "cook_meal", "farm": "grow_grain",
        "blacksmith": "smelt_iron", "alchemy": "brew_potion"}
    for bid in want:
        if Game.building_level(bid) > 0 and Game.job_of(bid) != want[bid]:
            if not Game.set_job(bid, String(want[bid])):
                say("  set_job %s %s refused: %s" % [bid, want[bid], Game.last_reason])
    if int(Game.hq_outputs.get("ingot", 0)) >= 4 and Game.building_level("blacksmith") > 0:
        Game.set_job("blacksmith", "forge_weapon")
    # training grounds: 2-star heroes learn a class skill
    for h in Game.heroes.values():
        if Game.training_block(h) == "":
            var opts := Game.training_options(h)
            if not opts.is_empty():
                say("  train %s: %s -> %s" % [h.display_name(), String(opts[0]), Game.train_skill(h, String(opts[0]))])
    # skill books
    for b in Game.skill_books.keys():
        for h in Game.heroes.values():
            if Game.use_skill_book(h, String(b)) == "":
                say("  %s read the book %s" % [h.display_name(), b])
                break
    # equip loot on the party
    for h in Game.party_heroes():
        for it in Game.stash.duplicate():
            var allowed := ItemDefs.slots_for(String(it["base"]))
            for s in allowed:
                if not h.equipment.has(s):
                    var why_eq := Game.equip(h, int(it["uid"]), String(s))
                    if why_eq == "":
                        say("  equip %s on %s" % [ItemDefs.item_label(it), h.display_name()])
                    break
        for res in ["potion", "antidote"]:
            if int(Game.hq_outputs.get(res, 0)) > 0:
                Game.pack_consumable(h, res)
    # ascension
    for h in Game.heroes.values():
        if h.is_max_level() and h.stars < 5:
            say("  %s at level cap %d: ascension blocked: %s" % [h.display_name(), h.level, Game.promotion_block(h)])
        if Game.promotion_block(h) == "":
            var r := Game.attempt_promotion(h)
            say("  ascension %s: %s" % [h.display_name(), str(r)])
    # summon if beds and gems
    var before := Game.heroes.size()
    if Game.can_summon(1) and Game.gems >= int(SummonConfig.BANNERS[SummonConfig.DEFAULT_BANNER].get("cost_single", 999999)):
        Game.pull(1)
    if Game.heroes.size() > before:
        say("  summoned %d hero(es)" % (Game.heroes.size() - before))
    var rep := Game.pass_time(12)
    say("  12h passed: produced %s events %s" % [str(rep.get("produced", {})), str((rep.get("events", []) as Array).slice(0, 6))])
    say("  stock: %s" % str(Game.hq_outputs))
    say("  problems: %s" % str(Game.town_problems))
    say("  construction: %s  builders %d" % [str(Game.construction), Game.builders().size()])


func _pick_party() -> void:
    Game.clear_party()
    var pool: Array = Game.heroes.values().filter(func(h): return h.hq_assignment != "construction")
    pool.sort_custom(func(a, b): return (1 if Game.is_fighter(a) else 0) * 100000 + a.power() > (1 if Game.is_fighter(b) else 0) * 100000 + b.power())
    if pool.size() < Game.PARTY_SIZE:
        pool = Game.heroes.values()
    for i in mini(Game.PARTY_SIZE, pool.size()):
        var h: HeroData = pool[i]
        if h.hq_assignment != "" and h.hq_assignment != "construction":
            Game.assign_work(h, "")
        Game.assign_party(i, h.id)


# --- expedition ---------------------------------------------------------------------------------

func _centre(list: Array) -> Vector2:
    var c := Vector2.ZERO
    for h in list:
        c += h.position
    return c / float(maxi(1, list.size()))


func _play_floor(floor_num: int, attempt: int) -> Dictionary:
    var cfg := TowerExpedition.get_floor_config(floor_num)
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    sb.set_physics_process(false)
    say("== FLOOR %d (%s, %s) attempt %d: map %dx%d, enemies %d, nodes %d" % [floor_num, cfg["mission"], cfg["difficulty"], attempt,
        sb.map.width, sb.map.height, sb.enemies.size(), sb.nodes.size()])
    for h in sb.heroes:
        say("  squad %s hp=%d range=%.0f res=%s slots=%s" % [h.hero.display_name(), h.max_hp, h.attack_range(), h.res_kind, str(h.slots)])
    var t := 0.0
    var think := 0.0
    var order_t := 0.0
    var last_goal := Vector2.INF
    var stuck_ref := Vector2.ZERO
    var stuck_t := 0.0
    var skills_used := 0
    var skill_refusals := {}
    var retreating := false
    var downs := 0
    var seen_down := {}
    var min_hp_frac := 1.0
    var skip_targets: Array = []
    var first_contact := -1.0
    var hp_seen := {}
    var hurt_by := {}
    while sb.mission_state == SandboxScreen.Mission.ACTIVE and t < MAX_SIM:
        sb.tick(DT)
        t += DT
        think -= DT
        order_t -= DT
        if think > 0.0:
            continue
        think = THINK
        # who hurts the squad: hits from creatures the heroes cannot see (fog) are counted apart
        for h in sb.heroes:
            var prev := int(hp_seen.get(h, h.max_hp))
            if h.alive and h.hp < prev:
                var src = null
                for e in sb.living_enemies():
                    if src == null or e.position.distance_to(h.position) < src.position.distance_to(h.position):
                        src = e
                if src != null:
                    var key := "%s %s" % [src.type_id, "VISIBLE" if src.visible else "HIDDEN"]
                    hurt_by[key] = int(hurt_by.get(key, 0)) + (prev - h.hp)
            hp_seen[h] = h.hp
        if OS.get_environment("PT_TRACE") != "" and fmod(t, 30.0) < THINK:
            var st: Array = sb.heroes.filter(func(h): return h.alive)
            say("    trace t=%.0f c=%s goal=%s orders=%s paths=%s targets=%s" % [t, str(sb.map.cell_of(_centre(st))), str(sb.map.cell_of(last_goal)) if last_goal != Vector2.INF else "-",
                str(st.map(func(h): return h.order)), str(st.map(func(h): return h.path.size())), str(st.map(func(h): return h.target.type_id if h.target != null else "-"))])
        var alive: Array = sb.heroes.filter(func(h): return h.alive)
        var standing: Array = alive.filter(func(h): return not h.downed)
        for h in sb.heroes:
            if h.downed and not seen_down.has(h):
                seen_down[h] = true
                downs += 1
            elif not h.downed:
                seen_down.erase(h)
            if h.alive:
                min_hp_frac = minf(min_hp_frac, float(h.hp) / float(h.max_hp))
        if standing.is_empty():
            continue
        var c := _centre(standing)
        var foes: Array = sb.visible_enemies()
        var near_foes: Array = foes.filter(func(e): return e.position.distance_to(c) < 380.0)
        if not near_foes.is_empty() and first_contact < 0.0:
            first_contact = t
        # skills: every hero tries W/E/R when a foe is close
        if not near_foes.is_empty():
            for h in standing:
                for i in 3:
                    if h.use_skill_slot(i, foes, sb.heroes):
                        skills_used += 1
                    elif h.last_refusal != "" and not h.last_refusal.begins_with("cooldown"):
                        skill_refusals[h.last_refusal] = int(skill_refusals.get(h.last_refusal, 0)) + 1
        # rescue downed allies
        for d in sb.heroes:
            if d.downed and d.alive:
                var busy: bool = sb.heroes.any(func(x): return x.rescue_target == d)
                if not busy:
                    var best = null
                    for h in standing:
                        if best == null or h.position.distance_to(d.position) < best.position.distance_to(d.position):
                            best = h
                    if best != null:
                        best.order_rescue(d)
        # retreat when the squad is broken
        if not retreating and standing.size() <= 2 and sb.heroes.size() >= 4:
            retreating = true
            sb.select_only(standing)
            sb.retreat_selected()
            say("  t=%.0fs squad broken (%d standing): retreat" % [t, standing.size()])
        if retreating:
            if sb.extract_block() == "":
                sb.extract()
            elif order_t <= 0.0:
                order_t = 4.0
                sb.select_only(standing)
                sb.retreat_selected()
            continue
        if not near_foes.is_empty():
            if order_t <= 0.0:
                order_t = 1.5
                var tgt = near_foes[0]
                for e in near_foes:
                    if e.position.distance_to(c) < tgt.position.distance_to(c):
                        tgt = e
                sb.select_only(standing.filter(func(h): return h.rescue_target == null))
                sb.attack_move_selected(tgt.position)
            continue
        # objective
        var goal := Vector2.INF
        match sb.mission_type:
            "combat":
                var best_d := INF
                for e in sb.living_enemies():
                    if skip_targets.has(e):
                        continue
                    var d: float = e.position.distance_to(c)
                    if d < best_d:
                        best_d = d
                        goal = e.position
            "exploration":
                var best_d := INF
                for cl in sb.clues:
                    if cl.visible and cl.position.distance_to(c) < best_d:
                        best_d = cl.position.distance_to(c)
                        goal = cl.position
            "retrieval", "rescue":
                goal = sb.relic.position if sb.carrier == null else sb.map.center_of(sb.map.extract_cell)
            "boss":
                if sb.boss != null:
                    goal = sb.boss.position
        # a gathering spot close by first
        for g in sb.nodes:
            if not g.taken and is_instance_valid(g) and g.position.distance_to(c) < 260.0 and (sb.carrier == null or sb.mission_type == "combat"):
                goal = g.position
                break
        if t > 90.0 and t < 90.0 + THINK and sb.defeated == 0:
            say("  !! no kill after 90 s: centre %s goal %s path %d boss %s at %s blocked=%s heroes %s" % [str(sb.map.cell_of(c)),
                str(sb.map.cell_of(goal)) if goal != Vector2.INF else "INF", sb.map.find_path(c, goal).size() if goal != Vector2.INF else -1,
                sb.boss.type_id if sb.boss != null else "null", str(sb.map.cell_of(sb.boss.position)) if sb.boss != null else "-",
                str(sb.map.is_blocked_cell(sb.map.cell_of(sb.boss.position))) if sb.boss != null else "-",
                str(sb.heroes.map(func(h): return "%s:%s:%d" % [str(sb.map.cell_of(h.position)), h.order, h.path.size()]))])
        if goal == Vector2.INF:
            continue
        if c.distance_to(stuck_ref) < 24.0:
            stuck_t += THINK
        else:
            stuck_t = 0.0
            stuck_ref = c
        if stuck_t > 25.0:
            say("  t=%.0fs squad stuck near %s heading to %s (mission %s)" % [t, str(sb.map.cell_of(c)), str(sb.map.cell_of(goal)), sb.mission_type])
            stuck_t = 0.0
            for e in sb.living_enemies():
                if e.position.distance_to(goal) < 10.0:
                    skip_targets.append(e)
        if order_t <= 0.0 or goal.distance_to(last_goal) > 80.0:
            order_t = 3.0
            last_goal = goal
            sb.select_only(standing)
            if sb.carrier != null and sb.mission_type in ["retrieval", "rescue"]:
                sb.order_move_selected(goal)
            else:
                sb.attack_move_selected(goal)
    var outcome: String = SandboxScreen.Mission.keys()[sb.mission_state]
    if sb.mission_state == SandboxScreen.Mission.ACTIVE:
        outcome = "TIMEOUT"
        say("  TIMEOUT after %.0f s: enemies left %d/%d, clues left %d, carrier %s" % [t, sb.living_enemies().size(), sb.enemies.size(),
            sb.clues.filter(func(x): return x.visible).size(), str(sb.carrier != null)])
        var cc := _centre(sb.heroes.filter(func(h): return h.alive))
        say("    squad centre %s" % str(sb.map.cell_of(cc)))
        Game.save_game()
        DirAccess.copy_absolute(ProjectSettings.globalize_path(Game.save_path), ProjectSettings.globalize_path("user://stuck_floor%d.json" % floor_num))
        for e in sb.living_enemies():
            var p := sb.map.find_path(cc, e.position)
            say("    stuck foe %s at %s home %s path_len %d last_pt %s blocked=%s state=%s" % [e.type_id, str(sb.map.cell_of(e.position)),
                str(sb.map.cell_of(e.home)) if e.home != Vector2.INF else "-", p.size(), str(sb.map.cell_of(p[p.size() - 1])) if not p.is_empty() else "-",
                str(sb.map.is_blocked_cell(sb.map.cell_of(e.position))), str(e.get("state"))])
        for e in sb.living_enemies().slice(0, 6):
            say("    left: %s at %s dormant=%s visible=%s" % [e.type_id, str(sb.map.cell_of(e.position)), str(e.dormant), str(e.visible)])
    say("  RESULT %s in %d:%02d (first contact %.0fs), killed %d/%d, downs %d, fallen %s, min hp %.0f%%, skills used %d" % [outcome,
        int(t) / 60, int(t) % 60, first_contact, sb.defeated, sb.enemies.size(), downs, str(sb.fallen), min_hp_frac * 100.0, skills_used])
    say("  damage taken by nearest source: %s" % str(hurt_by))
    for h in sb.heroes:
        if h.dead:
            say("    DEATH %s killed_by=%s" % [h.hero.display_name(), h.killed_by])
    if not skill_refusals.is_empty():
        say("  skill refusals: %s" % str(skill_refusals))
    for h in sb.heroes:
        say("    %s alive=%s hp=%d/%d contrib=%s" % [h.hero.display_name(), str(not h.dead), h.hp, h.max_hp, str(h.contrib)])
    say("  ledger %s  reward %s  mvp %s" % [str(sb.ledger), str(sb.results.get("reward", {})), str(sb.results.get("mvp", ""))])
    say("  xp %s" % str((sb.results.get("xp", []) as Array).map(func(x): return "%s +%d Lv%d->%d%s" % [x["name"], x["xp"], x["from"], x["to"], " CAP" if x["capped"] else ""])))
    if not sb.town_report.is_empty():
        say("  town while away: %s" % str((sb.town_report.get("events", []) as Array).slice(0, 8)))
    sb.queue_free()
    await get_tree().process_frame
    return {"outcome": outcome, "time": t}
