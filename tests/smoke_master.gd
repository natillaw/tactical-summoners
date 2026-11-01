extends Control
## D-080: the Master. Creation (character creator) -> save -> load keeps looks, class and trait; an old
## save without a Master asks for one and keeps the roster; the Master cannot be sacrificed, absorbed,
## sold, put to work or sent offline; always slot 1; the only driven hero in an expedition; never dies
## (lost -> the expedition fails and they come home wounded); every trait has a downside.
##   godot --headless --path . res://tests/smoke_master.tscn --quit-after 3000
var fails := 0
const PATH := "user://smoke_master.json"


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _ready() -> void:
    print("== Master tests ==")
    Game.autosave = false
    Game.save_path = PATH
    Game.new_game()
    check(Game.needs_master(), "a new account has no Master yet: the creator opens")

    # --- the creator -----------------------------------------------------------------------------
    var mc := MasterCreator.new()
    add_child(mc)
    await get_tree().process_frame
    mc.confirm()
    check(Game.master() == null and mc.block() != "", "the creator refuses an empty name and surname")
    mc._first.text = "Aldric"
    mc._last.text = "Vane"
    mc.step_look("race", 1)
    mc.step_look("body", 1)
    var body := String(mc.choices["look"]["body"])
    mc.step_look("hair_color", 1)
    mc.choose_class("class.mage")
    mc.choose_trait("trait.curious")
    var wanted: Dictionary = (mc.choices["look"] as Dictionary).duplicate()
    mc.confirm()
    var m := Game.master()
    check(m != null and m.is_master and m.hero_name == "Aldric Vane" and m.first_name == "Aldric" and m.surname == "Vane",
        "Confirm makes the Master with the chosen name and surname")
    check(m != null and m.hero_class == "class.mage" and m.traits == ["trait.curious"] and m.stars == MasterDefs.STARS,
        "class and trait are the chosen ones; mid rarity (%d stars)" % MasterDefs.STARS)
    var same_look := true
    for k in wanted:
        if m == null or str(m.look.get(k, "")) != str(wanted[k]):
            same_look = false
    check(same_look and m.look["body"] == body, "the look is exactly the one in the preview")
    check(m != null and m.equipment.is_empty() and LpcWardrobe.layers_for(m.look, m.hero_class).has(LpcWardrobe.STARTER_OUTFIT["chest"]),
        "the Master wears the plain starter outfit of every summon")
    check(m != null and Game.party[0] == m.id and m.innate.is_empty(), "the Master takes slot 1 and has no summon gifts")
    mc.queue_free()

    # --- save / load ---------------------------------------------------------------------------
    Game.save_game()
    var id := m.id
    var look_before: Dictionary = m.look.duplicate()
    Game.new_game()
    Game.load_game()
    var m2 := Game.master()
    check(m2 != null and m2.id == id and m2.is_master and m2.hero_name == "Aldric Vane" and m2.surname == "Vane",
        "save -> load keeps the Master and their name")
    check(m2 != null and m2.look == look_before and m2.hero_class == "class.mage" and m2.traits == ["trait.curious"],
        "save -> load keeps the same looks, class and trait")
    check(Game.party[0] == id and not Game.needs_master(), "after loading the Master is still in slot 1")

    # --- the first ten summons fill the slots after the Master ---------------------------------
    var ten: Array = Game.starter_summons()
    check(ten.size() == SummonConfig.STARTER_COUNT, "the ten free summons still come with a Master already made")
    check(Game.party[0] == id and Game.party.slice(1).all(func(x): return x != "" and x != id), "first squad: Master in slot 1 + 4 summons")
    check(Game.master().bed == Game.MASTER_BED and Game.max_hero_capacity() >= Game.heroes.size() - 1,
        "the Master sleeps in the Hall and does not take a dorm bed")

    # --- party rules ---------------------------------------------------------------------------
    var other: HeroData = Game.heroes[Game.party[1]]
    Game.assign_party(0, other.id)
    check(Game.party[0] == id, "nobody else can take slot 1")
    Game.assign_party(3, id)
    check(Game.party[0] == id and Game.party[3] != id, "the Master cannot be moved to another slot")
    Game.clear_slot(0)
    check(Game.party[0] == id, "slot 1 cannot be emptied")
    Game.clear_party()
    check(Game.party[0] == id and Game.party.slice(1).all(func(x): return x == ""), "Clear all keeps the Master")
    check(Game.party_heroes()[0] == Game.master(), "the party always starts with the Master")

    # --- what the Master can never be ----------------------------------------------------------
    var mm := Game.master()
    check(not bool(Game.sacrifice_preview(mm)["ok"]) and not bool(Game.sacrifice(mm).get("ok", false)) and Game.heroes.has(id),
        "sacrificing the Master is refused")
    var spare: HeroData = Game.heroes.values().filter(func(h): return not h.is_master)[0]
    check(not bool(Game.synthesis_preview(spare, [mm])["ok"]) and Game.heroes.has(id), "absorbing the Master in a synthesis is refused")
    check(Game.consumable_block(mm) != "", "the Master cannot be consumed or sold (%s)" % Game.consumable_block(mm))
    check(Game.assign_work(mm, "kitchen") != "" and mm.hq_assignment == "", "the Master cannot be put to work")
    check(OfflineExpeditions.block(Game, 1, [id], 0.0) != "", "the Master cannot go on an offline expedition")
    check(not Game.record_death(mm, "test") and Game.heroes.has(id) and Game.memorial.is_empty(), "the Master never goes to the memorial")

    # --- every trait has an upside and a downside -----------------------------------------------
    var free: Array = []
    for t in HeroTables.TRAITS:
        if MasterCreator.trait_pros(t).is_empty() or MasterCreator.trait_cons(t).is_empty():
            free.append(t)
    check(free.is_empty(), "no trait is free: every one shows an upside and a downside %s" % str(free))

    # --- an old save without a Master ----------------------------------------------------------
    Game.new_game()
    Game.gems = 100000
    var pulled: Array = Game.pull(6)
    for i in Game.PARTY_SIZE:
        Game.assign_party(i, (pulled[i] as HeroData).id)
    Game.onboarded = true
    Game.save_game()
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    raw["version"] = 16
    for hd in raw["heroes"]:
        (hd as Dictionary).erase("is_master")
    Game.apply_save(raw)
    var before := Game.heroes.size()
    var was_first := String(Game.party[0])
    check(Game.needs_master() and before == 6, "a v16 save loads with its 6 heroes and asks for a Master")
    var old_m := Game.create_master({"first": "Old", "last": "Hand", "class": "class.warrior", "trait": "trait.stoic"})
    check(Game.heroes.size() == before + 1 and pulled.all(func(h): return Game.heroes.has((h as HeroData).id)), "creating the Master keeps the whole roster")
    check(Game.party[0] == old_m.id and Game.heroes.has(was_first), "the Master takes slot 1; whoever had it stays on the roster")
    check(Game._migrate({"version": 16})["version"] == Game.SAVE_VERSION and Game.SAVE_VERSION == 17, "save v16 -> v17")

    # --- in the tower: the Master is the driven hero and never dies -----------------------------
    var floor_num := 3
    for i in range(1, Game.PARTY_SIZE):
        Game.party[i] = ""
    for i in range(1, TowerExpedition.party_max(floor_num)):
        Game.assign_party(i, (pulled[i] as HeroData).id)
    var sb := SandboxScreen.new(floor_num)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    check(sb.real_squad and sb.master_hero != null and sb.master_hero.hero == old_m, "the Master goes in as the first hero of the squad")
    check(sb.controlled() == sb.master_hero, "the Master is the driven hero from the start")
    sb.select_slot(1)
    check(sb.controlled() == sb.master_hero, "1-5 no longer switches the driven hero")
    sb.group_view()
    check(sb.controlled() == sb.master_hero, "the squad view keeps the Master driven")
    check(sb.heroes.filter(func(h): return h.is_controlled()).size() == 1, "the other heroes stay autonomous")
    sb.master_hero.go_down()
    sb.master_hero.agony = 0.01
    for i in 3:
        sb.tick(0.05)
    check(sb.master_hero.lost and not sb.master_hero.dead and sb.mission_state == SandboxScreen.Mission.FAILED,
        "the Master's agony runs out: no death, the expedition fails")
    check(Game.heroes.has(old_m.id) and Game.master() == old_m and Game.memorial.is_empty(), "the Master is still on the roster, not in the memorial")
    check(old_m.has_disease(MasterDefs.WOUND_DISEASE), "the Master comes home wounded (%s)" % MasterDefs.WOUND_DISEASE)
    sb.queue_free()

    for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)
