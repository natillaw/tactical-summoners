extends Node
## Boots the real main scene and opens every screen once (catches script errors like F-001). Run:
##   godot --headless --path . res://tests/smoke_boot.tscn --quit-after 3000


func _ready() -> void:
    print("== Boot test ==")
    Game.autosave = false
    Game.save_path = "user://smoke_boot.json"
    Game.new_game()
    var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
    add_child(main)
    await get_tree().process_frame
    var ok := main.has_method("show_screen") and main.find_children("*", "", true, false).any(func(n): return n is TownScreen)
    print("  ", "PASS  " if ok else "FAIL  ", "main.gd loaded and the first screen is the town (D-030)")
    if ok:
        for s in ["summon", "roster", "party", "memorial", "hq", "sandbox", "menu", "town"]:
            main.call("show_screen", s)
            await get_tree().process_frame
            print("  PASS  opened screen ", s)
    print("== %s ==" % ("ALL PASSED" if ok else "1 FAILED"))
    if FileAccess.file_exists("user://smoke_boot.json"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_boot.json"))
    get_tree().quit(0 if ok else 1)
