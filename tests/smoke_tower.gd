extends Control
## Tower floors on the real mission screen (F-002, F-003). Run:
##   godot --headless --path . res://tests/smoke_tower.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Tower floor tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_tower.json"
    Game.new_game()
    size = Vector2(1280, 720)

    # fixed sandbox map: relic and extraction are different places
    var fixed := SandboxMap.new()
    check(fixed.relic_cell != fixed.extract_cell, "fixed map: relic is not on the extraction cell")
    check(not fixed.is_blocked_cell(fixed.relic_cell) and not fixed.is_blocked_cell(fixed.extract_cell), "fixed map: relic and extraction are walkable")

    for floor_num in [1, 5, 10]:
        var sb := SandboxScreen.new(floor_num)
        add_child(sb)
        sb.size = Vector2(1280, 720)
        sb.set_physics_process(false)
        await get_tree().process_frame
        check(sb.map is ProceduralMap and sb.heroes.size() == 5, "floor %d: procedural map with a 5-hero squad" % floor_num)
        check(sb.map.relic_cell != sb.map.extract_cell, "floor %d: relic is not on the extraction cell" % floor_num)
        check(not sb.map.find_path(sb.map.center_of(sb.map.extract_cell), sb.map.center_of(sb.map.relic_cell)).is_empty(), "floor %d: relic reachable from extraction" % floor_num)
        for i in 300:
            sb.tick(1.0 / 60.0)
        check(sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: 5 s of simulation run and the mission is still active" % floor_num)
        sb.heroes[0].position = sb.relic.position
        sb.tick(1.0 / 60.0)
        check(sb.carrier == sb.heroes[0] and sb.mission_state == SandboxScreen.Mission.ACTIVE, "floor %d: picking up the relic does not end the mission" % floor_num)
        sb.heroes[0].position = sb.map.center_of(sb.map.extract_cell)
        sb.tick(1.0 / 60.0)
        check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "floor %d: carrying it to the extraction completes the mission" % floor_num)
        sb.queue_free()
        await get_tree().process_frame

    var hq := HQWorld.new()
    add_child(hq)
    await get_tree().process_frame
    check(hq.get_child_count() > 0, "HQWorld builds (F-001)")
    hq.queue_free()

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    for p in ["user://smoke_tower.json", "user://smoke_tower.json.bak", "user://smoke_tower.json.tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    get_tree().quit(1 if fails > 0 else 0)
