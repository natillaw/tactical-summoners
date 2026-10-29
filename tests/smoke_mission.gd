extends Control
## Mission flow, skills and panel checks (T-008, T-009, T-011, T-013 integration). Run:
##   godot --headless --path . res://tests/smoke_mission.tscn --quit-after 3000
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _make_screen() -> SandboxScreen:
    var sb := SandboxScreen.new()
    add_child(sb)
    sb.size = Vector2(1280, 720)
    sb.set_physics_process(false)
    return sb


func _clear_enemies(sb: SandboxScreen) -> void:
    for e in sb.enemies:
        e.alive = false
        e.visible = false


func _ready() -> void:
    print("== Mission tests ==")
    Game.autosave = false
    Game.save_path = "user://smoke_mission.json"
    Game.new_game()
    size = Vector2(1280, 720)

    # --- real party: relic, carrier death, memorial, extraction, reward --------------------
    Game.gems = 100000
    var pulled: Array = Game.pull(5)
    for i in 5:
        Game.assign_party(i, pulled[i].id)
    var sb := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(sb.real_squad and sb.heroes.size() == 5, "saved party is deployed as the squad")
    check(sb.mission_state == SandboxScreen.Mission.ACTIVE and sb.relic.visible, "mission starts active with the relic on the map")
    _clear_enemies(sb)

    var id0: String = sb.heroes[0].hero.id
    sb.heroes[0].position = sb.relic.position
    sb.tick(1.0 / 60.0)
    check(sb.carrier == sb.heroes[0] and sb.heroes[0].carrying and not sb.relic.visible, "walking onto the relic picks it up")

    var drop_at: Vector2 = sb.heroes[0].position
    sb.heroes[0].take_damage(99999, sb.enemies[0])
    sb.tick(1.0 / 60.0)
    check(not sb.heroes[0].alive and sb.carrier == null and sb.relic.visible and sb.relic.position.distance_to(drop_at) < 1.0, "carrier dies: relic drops where they fell")
    check(not Game.heroes.has(id0) and Game.memorial.size() == 1, "death is permanent: removed from roster, written to memorial")
    check(Game.memorial[0]["cause"] == "Slain by Grunt" and Game.memorial[0]["mission"] == SandboxScreen.MISSION_NAME, "memorial records cause and mission")
    check(Game.party[0] == "" and sb.fallen.size() == 1, "party slot cleared, fallen list updated")

    sb.heroes[1].position = sb.relic.position
    sb.tick(1.0 / 60.0)
    check(sb.carrier == sb.heroes[1], "another hero can recover the dropped relic")

    sb.select_slot(0)
    check(not sb.selected.has(sb.heroes[0]) and sb.follow_slot != 0, "a fallen hero cannot be selected with its key")
    sb.select_slot(1)
    sb._refresh_info()
    check(sb._info.text.contains("Skill:") and sb._squad_label.text.contains("FALLEN") and sb._squad_label.text.contains("[RELIC]"), "panel shows skill, fallen hero and relic carrier")

    var gems_before := Game.gems
    var stones_before := Game.stones
    sb.heroes[1].position = sb.map.center_of(SandboxMap.GOAL_CELL)
    sb.tick(1.0 / 60.0)
    check(sb.mission_state == SandboxScreen.Mission.SUCCESS, "carrier reaching the exit completes the mission")
    check(Game.gems == gems_before + SandboxScreen.REWARD_GEMS and Game.stones == stones_before + SandboxScreen.REWARD_STONES, "placeholder reward granted once")
    var t_end := sb.elapsed
    sb.tick(1.0)
    check(is_equal_approx(sb.elapsed, t_end) and sb.reward_given, "simulation stops after the result; no second reward")
    var txt := sb.result_text()
    check(txt.contains("MISSION COMPLETE") and txt.contains("Fallen") and sb._overlay != null, "result screen lists the outcome and the fallen")
    sb.queue_free()

    # memorial screen lists the fallen hero
    var ms := MemorialScreen.new()
    add_child(ms)
    await get_tree().process_frame
    var entry := MemorialScreen.entry_text(Game.memorial[0])
    check(entry.contains(Game.memorial[0]["name"]) and entry.contains("Slain by Grunt"), "memorial entry text shows name and cause")
    check(ms.find_children("*", "Label", true, false).any(func(x): return x.text.contains("Slain by Grunt")), "memorial screen renders the entry")
    ms.queue_free()

    # --- test squad: failure when everyone dies, nothing recorded --------------------------
    Game.new_game()
    var sb2 := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(not sb2.real_squad, "no full party -> test squad")
    for dead in sb2.heroes:
        dead.take_damage(99999)
    sb2.tick(1.0 / 60.0)
    check(sb2.mission_state == SandboxScreen.Mission.FAILED and sb2.result_text().contains("MISSION FAILED"), "all heroes dead -> mission failed")
    check(Game.memorial.is_empty() and Game.gems == 2000, "test heroes write no memorial and earn no reward")
    sb2.queue_free()

    # --- skills ----------------------------------------------------------------------------
    var sb3 := _make_screen()
    await get_tree().process_frame
    await get_tree().process_frame
    check(sb3.heroes.all(func(x): return not x.skill.is_empty() and float(x.skill["cooldown"]) > 0.0), "every hero has exactly one active skill")
    for cls in HeroTables.CLASSES:
        check(SkillTables.SKILLS.has(cls), "skill defined for %s" % cls)
    _clear_enemies(sb3)
    var h: SandboxHero = sb3.heroes[0]
    var e1: SandboxEnemy = sb3.enemies[0]
    var e2: SandboxEnemy = sb3.enemies[1]
    var e3: SandboxEnemy = sb3.enemies[2]
    for e in [e1, e2, e3]:
        e.alive = true
        e.visible = true
        e.hp = e.max_hp
    h.position = sb3.map.center_of(Vector2i(20, 17))
    h.hp = h.max_hp
    var foes: Array = [e1, e2, e3]

    h.skill = SkillTables.for_class("class.warrior")
    e1.position = h.position + Vector2(50, 0)
    e2.position = h.position + Vector2(-50, 0)
    e3.position = h.position + Vector2(300, 0)
    check(h.use_skill(foes), "warrior Cleave fires")
    check(e1.hp < e1.max_hp and e2.hp < e2.max_hp and e3.hp == e3.max_hp, "Cleave hits enemies around the hero, not far ones")
    check(not h.skill_ready() and not h.use_skill(foes), "skill is refused only because of its cooldown")
    h.tick(float(h.skill["cooldown"]) + 0.1)
    check(h.skill_ready(), "skill is ready again after the cooldown")

    e1.position = h.position + Vector2(900, 0)
    e2.position = h.position + Vector2(900, 50)
    check(not h.use_skill(foes) and h.skill_ready(), "no target in reach: refused and cooldown not spent")

    h.skill = SkillTables.for_class("class.mage")
    h.skill_cd = 0.0
    e1.hp = e1.max_hp
    e2.hp = e2.max_hp
    e1.position = h.position + Vector2(150, 0)
    e2.position = e1.position + Vector2(40, 0)
    e3.position = e1.position + Vector2(200, 0)
    check(h.use_skill(foes) and e1.hp < e1.max_hp and e2.hp < e2.max_hp and e3.hp == e3.max_hp, "mage Fire Burst damages the target and its neighbours only")

    h.skill = SkillTables.for_class("class.none")
    h.skill_cd = 0.0
    check(not h.use_skill(foes), "heal is refused at full HP (cooldown kept)")
    h.hp = h.max_hp - 10
    var hp_before := h.hp
    check(h.use_skill(foes) and h.hp > hp_before and h.hp <= h.max_hp, "Second Breath heals")

    # key / button path through the screen
    h.skill = SkillTables.for_class("class.rogue")
    h.skill_cd = 0.0
    e1.hp = e1.max_hp
    e1.position = h.position + Vector2(40, 0)
    sb3.select_slot(0)
    check(sb3.use_skill_selected() == 1 and e1.hp < e1.max_hp, "use_skill_selected fires for the selected hero")
    h.path.append(h.position + Vector2(100, 0))
    sb3.stop_selected()
    check(not h.is_moving(), "stop order clears the path")

    check(not get_tree().paused and is_equal_approx(Engine.time_scale, 1.0), "no pause and no time-slow")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_mission.json"))
    get_tree().quit(1 if fails > 0 else 0)
