extends Control
## Tower floors on the real mission screen: forest floors, creatures, and every mission type
## (combat, retrieval, rescue, exploration, survival, defense, boss) plus the town. Run:
##   godot --headless --path . res://tests/smoke_tower.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _kill_all(sb: SandboxScreen) -> void:
    for e in sb.enemies:
        if e.alive:
            e.take_damage(999999)


func _make(floor_num: int) -> SandboxScreen:
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


func _ready() -> void:
    print("== Tower floor tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_tower.json"
    Game.new_game()
    size = Vector2(1280, 720)

    var fixed := SandboxMap.new()
    check(fixed.relic_cell != fixed.extract_cell, "fixed map: relic is not on the extraction cell")

    for floor_num in [1, 3, 5, 6, 8, 9, 10]:
        var sb := _make(floor_num)
        await get_tree().process_frame
        var cfg: Dictionary = TowerExpedition.get_floor_config(floor_num)
        check(sb.map is ProceduralMap and sb.heroes.size() == 5 and sb.mission_type == String(cfg["mission"]), "floor %d: procedural forest, 5 heroes, mission '%s'" % [floor_num, sb.mission_type])
        check(not sb.enemies.is_empty() and sb.enemies.all(func(e): return (cfg["foes"] as Array).has(e.type_id)), "floor %d: forest creatures from the floor table" % floor_num)
        var extract: Vector2 = sb.map.center_of(sb.map.extract_cell)
        match sb.mission_type:
            "combat":
                sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: combat is active while enemies live" % floor_num)
                _kill_all(sb)
                sb.tick(0.1)
            "boss":
                check(sb.boss != null and sb.boss.enemy_name == "Orc Chieftain" and sb.boss.max_hp > sb.enemies[1].max_hp * 4, "floor %d: the chieftain is a real boss" % floor_num)
                for e in sb.enemies:
                    if e != sb.boss:
                        e.take_damage(999999)
                sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: boss fight continues while the chieftain lives" % floor_num)
                sb.boss.take_damage(999999)
                sb.tick(0.1)
            "retrieval", "rescue":
                _kill_all(sb)
                sb.heroes[0].position = sb.relic.position
                sb.tick(0.1)
                check(sb.carrier == sb.heroes[0] and sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: picking up does not end the mission" % floor_num)
                sb.heroes[0].position = extract
                sb.tick(0.1)
            "exploration":
                _kill_all(sb)
                check(sb.clues.size() == 3, "floor %d: three clues to discover" % floor_num)
                for k in sb.clues.size() - 1:
                    sb.heroes[0].position = sb.clues[k].position
                    sb.tick(0.1)
                check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: not done until every clue is found" % floor_num)
                sb.heroes[0].position = sb.clues[sb.clues.size() - 1].position
                sb.tick(0.1)
            "survival", "defense":
                for i in 40:
                    _kill_all(sb)
                    if sb.shrine != null:
                        for h in sb.heroes:
                            h.position = sb.shrine.position
                    sb.tick(2.0)
                    if sb.mission_state != SandboxScreen.Mission.ACTIVE:
                        break
                check(sb.enemies.size() > cfg["enemies"], "floor %d: waves spawned more enemies" % floor_num)
        check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "floor %d: '%s' can be completed" % [floor_num, sb.mission_title()])
        sb.queue_free()
        await get_tree().process_frame

    Game.gems = 100000
    Game.pull(3)
    var town := TownScreen.new()
    add_child(town)
    town.size = Vector2(1280, 720)
    await get_tree().process_frame
    check(town.heroes.size() == Game.heroes.size() and town.view != null, "town shows every hero")
    town.click_at(town.map.center_of((TownTables.info("barracks")["plot"] as Rect2i).position))
    check(town.selected == "barracks", "clicking a building selects it")
    Game.hq_outputs["materials"] = 1000
    var lvl_before := Game.building_level("alchemy")
    Game.build_or_upgrade("alchemy")
    await get_tree().process_frame
    check(Game.building_level("alchemy") == lvl_before + 1 and town.map.is_blocked_cell((TownTables.info("alchemy")["plot"] as Rect2i).position), "building from the town updates the map")
    var th: TownHero = town.heroes[0]
    town.click_at(th.position + Vector2(0, -14))
    check(town.hero_panel != null and town.hero_panel.hero == th.hero, "clicking a hero opens its panel")
    for i in 10:
        for x in town.heroes:
            x._process(0.5)
    check(town.heroes.any(func(x): return x.activity != "idle"), "town heroes choose activities on their own")
    town.queue_free()

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    for p in ["user://smoke_tower.json", "user://smoke_tower.json.bak", "user://smoke_tower.json.tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    get_tree().quit(1 if fails > 0 else 0)
