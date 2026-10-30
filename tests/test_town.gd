extends SceneTree
## Town buildings (D-030): build/upgrade costs, capacity, production by level, save v5 -> v6.
##   godot --headless --path . --script res://tests/test_town.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _init() -> void:
    print("== Town tests ==")
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = "user://test_town.json"
    g.new_game()

    # every building has a plot inside the map, no two plots overlap, doors are free cells
    var plots: Array = []
    var ok_plots := true
    for id in TownTables.ids():
        var p: Rect2i = TownTables.info(id)["plot"]
        if p.position.x < 1 or p.position.y < 1 or p.end.x > TownTables.MAP_W - 1 or p.end.y > TownTables.MAP_H - 1:
            ok_plots = false
        for q in plots:
            if (q as Rect2i).intersects(p):
                ok_plots = false
        plots.append(p)
    check(ok_plots, "building plots are inside the town and never overlap")
    var town := TownMap.new(g.town_buildings)
    var doors_ok := true
    for id in TownTables.ids():
        if town.is_blocked_cell(TownTables.door_cell(id)):
            doors_ok = false
        elif town.find_path(town.center_of(town.goal_cell), town.center_of(TownTables.door_cell(id))).is_empty():
            doors_ok = false
    check(doors_ok, "every building door is reachable from the plaza")

    # build an unbuilt building
    check(g.building_level("alchemy") == 0, "alchemy lab starts unbuilt")
    var cost: int = g.next_building_cost("alchemy")
    g.hq_outputs["materials"] = cost - 1
    check(not g.build_or_upgrade("alchemy") and g.building_level("alchemy") == 0, "cannot build without enough materials (nothing changes)")
    g.hq_outputs["materials"] = cost + 5
    check(g.build_or_upgrade("alchemy") and g.building_level("alchemy") == 1 and int(g.hq_outputs["materials"]) == 5, "building spends exactly its cost")
    check(TownMap.new(g.town_buildings).is_blocked_cell((TownTables.info("alchemy")["plot"] as Rect2i).position), "a built building becomes solid on the town map")

    # upgrade: dorms raise capacity, max level is respected
    var cap_before: int = g.max_hero_capacity()
    g.hq_outputs["materials"] = 100000
    check(g.build_or_upgrade("dorm_1") and g.max_hero_capacity() == cap_before + 5, "dormitory upgrade adds 5 roster capacity")
    check(g.next_building_cost("summon_circle") == -1 and not g.build_or_upgrade("summon_circle"), "a max-level building cannot be upgraded")

    # production scales with level; unbuilt buildings produce nothing
    g.gems = 100000
    var pulled: Array = g.pull(2)
    var a: HeroData = pulled[0]
    var b: HeroData = pulled[1]
    a.profession = "occupation.scholar"          # not a kitchen expert
    b.profession = "occupation.scholar"
    g.assign_hq(a.id, "kitchen")
    var food0: int = int(g.hq_outputs["food"])
    g.process_headquarters_turn()
    var gain1: int = int(g.hq_outputs["food"]) - food0
    g.build_or_upgrade("kitchen")
    food0 = int(g.hq_outputs["food"])
    g.process_headquarters_turn()
    var gain2: int = int(g.hq_outputs["food"]) - food0
    check(gain1 == 5 and gain2 == 10, "kitchen food doubles at level 2 (%d -> %d)" % [gain1, gain2])
    g.town_buildings["workshop"] = 0
    g.assign_hq(b.id, "workshop")
    var mat0: int = int(g.hq_outputs["materials"])
    g.process_headquarters_turn()
    check(int(g.hq_outputs["materials"]) == mat0, "a worker in an unbuilt building produces nothing")

    # profession experts produce double (owner "sí", 2026-10-30)
    g.town_buildings["workshop"] = 1
    b.profession = "occupation.miner"
    mat0 = int(g.hq_outputs["materials"])
    g.process_headquarters_turn()
    check(int(g.hq_outputs["materials"]) - mat0 == 4 * TownTables.EXPERT_MULT, "a miner in the workshop produces double materials")
    check(TownTables.best_workplaces("occupation.chef").has("kitchen"), "a chef is an expert at the kitchen")

    # floor rewards and tower progress
    var gems0: int = g.gems
    var r: Dictionary = g.complete_floor(4)
    check(int(r["materials"]) == 60 and g.gems == gems0 + 200 and int(g.tower_cleared["4"]) == 1, "completing floor 4 pays and is recorded")

    # save v5 -> v6 migration keeps old facility levels and adds the new buildings
    var v5 := {"version": 5, "gems": 1, "stones": 1, "books": 1, "pity4": 0, "pity5": 0, "pull_count": 0,
        "summon_log": [], "memorial": [], "party": ["", "", "", "", ""], "heroes": [],
        "hq_facilities": {"kitchen": 3, "workshop": 2, "infirmary": 1, "common": 1},
        "hq_outputs": {"food": 1, "materials": 2, "medicine": 3},
        "town_buildings": {"town_hall": 1, "dorm_1": 2, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1},
        "tower_maps": {}}
    var g2: Node = load("res://scripts/autoload/game.gd").new()
    g2.autosave = false
    g2.apply_save(JSON.parse_string(JSON.stringify(v5)))
    check(g2.building_level("dorm_1") == 2 and g2.building_level("workshop") == 2 and g2.building_level("alchemy") == 0 and g2.building_level("tower_gate") == 1, "v5 save migrates: levels kept, new buildings added")
    check(g2.building_level("kitchen") == 1, "existing town_buildings level wins over the old facility level")
    g.free()
    g2.free()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
