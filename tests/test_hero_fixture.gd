extends SceneTree
## Overhaul LPC phase 0: 200 seeds recorded BEFORE the LPC generator (v4). Everything but the look must
## stay identical forever (name, class, traits, passives, Trust/Obedience/Composure, stars).
##   godot --headless --path . --script res://tests/test_hero_fixture.gd              (check)
##   FIXTURE_WRITE=1 godot --headless --path . --script res://tests/test_hero_fixture.gd   (record, once)
const PATH := "res://tests/fixtures/hero_seeds_v3.json"


func _snap(seed_v: int) -> Dictionary:
    var h := HeroGenerator.generate(seed_v, 1 + seed_v % 5)
    return {"seed": seed_v, "name": h.hero_name, "class": h.hero_class, "stars": h.stars, "traits": h.traits,
        "passives": h.passives, "trust": h.trust, "obedience": h.obedience, "composure": h.composure, "look_v3": h.appearance}


func _init() -> void:
    print("== Hero seed fixture ==")
    var seeds: Array = range(1, 201).map(func(i): return i * 7919 + 13)
    if OS.get_environment("FIXTURE_WRITE") != "":
        var out: Array = seeds.map(func(s): return _snap(int(s)))
        var f := FileAccess.open(PATH, FileAccess.WRITE)
        f.store_string(JSON.stringify(out, " "))
        f.close()
        print("RESULT wrote %d seeds" % out.size())
        quit(0)
        return
    var data: Array = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    var bad := 0
    for rec in data:
        var now: Dictionary = JSON.parse_string(JSON.stringify(_snap(int(rec["seed"]))))   # same number types as the file
        for k in ["name", "class", "stars", "traits", "passives", "trust", "obedience", "composure"]:
            if str(now[k]) != str(rec[k]):
                bad += 1
                print("  FAIL  seed %d: %s %s -> %s" % [int(rec["seed"]), k, str(rec[k]), str(now[k])])
    print("  %s  %d seeds keep name, class, traits, passives and Trust/Obedience/Composure" % ["PASS" if bad == 0 else "FAIL", data.size()])
    print("== %s ==" % ("ALL PASSED" if bad == 0 else "%d FAILED" % bad))
    quit(1 if bad > 0 else 0)
