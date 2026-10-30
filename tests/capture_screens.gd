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
    await _shot("01_menu", 0.5)
    for screen in ["summon", "roster", "party", "memorial", "hq"]:
        _main.call("show_screen", screen)
        await _shot("02_" + screen, 0.6)
    _main.call("show_screen", "sandbox")
    await _shot("03_sandbox_start", 1.5)
    await _shot("04_sandbox_after_5s", 5.0)
    var sb: Node = _find_sandbox()
    if sb != null:
        sb.call("select_slot", 0)
        await _shot("05_sandbox_focus_hero1", 1.5)
    _main.call("show_screen", "hq_world")
    await _shot("06_hq_world", 1.5)
    print("CAPTURE DONE -> ", _dir)
    get_tree().quit(0)


func _find_sandbox() -> Node:
    for n in _main.find_children("*", "Control", true, false):
        if n is SandboxScreen:
            return n
    return null


func _shot(shot_name: String, wait: float) -> void:
    await get_tree().create_timer(wait).timeout
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var path := _dir.path_join(shot_name + ".png")
    var err := img.save_png(path)
    # half-size copy so a reviewer without artifact access can read it from the job log
    DirAccess.make_dir_recursive_absolute(_dir.path_join("small"))
    var small := img.duplicate() as Image
    small.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
    small.save_png(_dir.path_join("small").path_join(shot_name + ".png"))
    print("shot ", shot_name, " -> ", path, " err=", err)
