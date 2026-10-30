extends Node
## Visual capture (not a pass/fail suite): opens the real screens and saves PNG screenshots.
## Needs a real renderer (not --headless). In CI:
##   CAPTURE_DIR=$PWD/screenshots xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/capture_screens.tscn
## Uses its own save file; never touches the player's save.

var _dir: String = ""
var _main: Control = null


func _ready() -> void:
    _dir = OS.get_environment("CAPTURE_DIR")
    if _dir == "":
        _dir = ProjectSettings.globalize_path("user://captures")
    DirAccess.make_dir_recursive_absolute(_dir)
    Game.autosave = false
    Game.save_path = "user://capture_save.json"
    Game.new_game()
    Game.gems = 100000
    var pulled: Array = Game.pull(10)
    for i in mini(5, pulled.size()):
        Game.assign_party(i, (pulled[i] as HeroData).id)

    var scene: PackedScene = load("res://scenes/main.tscn")
    _main = scene.instantiate() as Control
    add_child(_main)
    await _shot("01_town", 1.5)
    var town: Node = _find("TownScreen")
    if town != null:
        town.call("select_building", "tower_gate")
        await _shot("01b_town_tower_gate", 0.5)
        town.call("select_building", "alchemy")
        await _shot("01c_town_build_alchemy", 0.5)
    for screen in ["menu", "summon", "roster", "party", "memorial", "hq"]:
        _main.call("show_screen", screen, 0)
        await _shot("02_" + screen, 0.6)
    _main.call("show_screen", "sandbox", 0)
    await _shot("03_sandbox_start", 1.5)
    await _shot("04_sandbox_after_5s", 5.0)
    var sb: Node = _find("SandboxScreen")
    if sb != null:
        sb.call("select_slot", 0)
        await _shot("05_sandbox_focus_hero1", 1.5)
    _main.call("show_screen", "sandbox", 1)
    await _shot("06_tower_floor1", 2.0)
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _find(cls: String) -> Node:
    for n in _main.find_children("*", "", true, false):
        var s: Script = n.get_script()
        if s != null and s.get_global_name() == cls:
            return n
    return null


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var path := _dir.path_join(shot_name + ".png")
    var err := img.save_png(path)
    print("shot ", shot_name, " -> ", path, " err=", err)
