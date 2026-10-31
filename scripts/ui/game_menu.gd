class_name GameMenu
extends Control
## Esc menu (D-062): opens over any screen and NEVER pauses the simulation (D-014). Resume, Options,
## Credits and a way out (back to the town or to the title). Options: music / SFX / UI volumes,
## screen shake, fullscreen, window size (x2 / x3 / x4 of the 640x360 base) and the controls list.
## Settings live in user://settings.cfg (per player, not in the save).

signal closed
signal leave_requested(to: String)

const SETTINGS := "user://settings.cfg"
const CONTROLS := [
    ["1-5 / Shift+1-5", "Drive a hero (focus + direct control)"], ["Tab", "Squad view, everyone autonomous"],
    ["G", "Select the whole squad"], ["Right click", "Move (attack / rescue in squad view)"],
    ["Q", "Basic attack at the mouse (hero you drive)"], ["W E R", "Skills (hold to aim, release to cast)"],
    ["A", "Attack-move"], ["H", "Hold"], ["F", "Follow"], ["C", "Regroup"], ["X", "Retreat"], ["S", "Stop"],
    ["M", "Whole map (the fog stays)"], ["I", "Details panel"], ["F3", "Debug overlay (debug builds)"], ["Esc", "This menu"],
]

var leave_label: String = "Back to the town"
var _box: VBoxContainer


static func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load(SETTINGS) != OK:
        return
    for bus in ["Music", "SFX", "UI"]:
        UIKit.set_volume(bus, float(cf.get_value("audio", bus, 0.8)))
    CombatFeel.shake_scale = float(cf.get_value("feel", "shake", 1.0))


static func save_settings() -> void:
    var cf := ConfigFile.new()
    for bus in ["Music", "SFX", "UI"]:
        cf.set_value("audio", bus, UIKit.get_volume(bus))
    cf.set_value("feel", "shake", CombatFeel.shake_scale)
    cf.save(SETTINGS)


func _ready() -> void:
    UIKit.fill(self)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(ArtPalette.INK, 0.55)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIKit.fill(dim)
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    var pc := PanelContainer.new()
    # the kit panel: the Dragon Regalia frames are bright blue, out of the palette (ArtPalette)
    center.add_child(pc)
    _box = VBoxContainer.new()
    _box.custom_minimum_size = Vector2(240, 0)
    pc.add_child(_box)
    UIKit.sound("open")
    show_main()


func _clear() -> void:
    for c in _box.get_children():
        c.queue_free()


func show_main() -> void:
    _clear()
    _box.add_child(UIKit.label("Menu", 28, UIKit.ACCENT))
    _box.add_child(UIKit.label("The game keeps running.", 12, UIKit.MUTED))
    _box.add_child(UIKit.button("Resume", close, Vector2(480, 40)))
    _box.add_child(UIKit.button("Options", show_options, Vector2(480, 40)))
    _box.add_child(UIKit.button("Controls", show_controls, Vector2(480, 40)))
    _box.add_child(UIKit.button("Credits", show_credits, Vector2(480, 40)))
    _box.add_child(UIKit.button(leave_label, func():
        close()
        leave_requested.emit("town"), Vector2(480, 40)))


func close() -> void:
    UIKit.sound("close")
    closed.emit()
    queue_free()


func _slider(text: String, value: float, on_change: Callable) -> void:
    var hb := HBoxContainer.new()
    var l := UIKit.label(text, 14, UIKit.TEXT)
    l.custom_minimum_size = Vector2(70, 0)
    hb.add_child(l)
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = value
    s.custom_minimum_size = Vector2(110, 12)
    s.value_changed.connect(func(v):
        on_change.call(v)
        save_settings())
    hb.add_child(s)
    _box.add_child(hb)


func show_options() -> void:
    _clear()
    _box.add_child(UIKit.label("Options", 28, UIKit.ACCENT))
    _slider("Music", UIKit.get_volume("Music"), func(v): UIKit.set_volume("Music", v))
    _slider("Effects", UIKit.get_volume("SFX"), func(v): UIKit.set_volume("SFX", v))
    _slider("Interface", UIKit.get_volume("UI"), func(v): UIKit.set_volume("UI", v))
    _slider("Shake", CombatFeel.shake_scale, func(v): CombatFeel.shake_scale = v)
    var hb := HBoxContainer.new()
    hb.add_child(UIKit.label("Window", 14, UIKit.TEXT))
    for k in [2, 3, 4]:
        var scale_k: int = k
        hb.add_child(UIKit.button("x%d" % k, func():
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_size(Vector2i(640, 360) * scale_k), Vector2(56, 32)))
    hb.add_child(UIKit.button("Full", func():
        var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN), Vector2(64, 32)))
    _box.add_child(hb)
    _box.add_child(UIKit.label("The picture always scales by whole numbers (crisp pixels).", 12, UIKit.MUTED))
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


func show_controls() -> void:
    _clear()
    _box.add_child(UIKit.label("Controls", 28, UIKit.ACCENT))
    var grid := GridContainer.new()
    grid.columns = 2
    _box.add_child(grid)
    for c in CONTROLS:
        grid.add_child(UIKit.label(String(c[0]), 12, UIKit.ACCENT))
        grid.add_child(UIKit.label(String(c[1]), 12, UIKit.TEXT))
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


## Credits generated from the asset registry (assets/CREDITS.md, made by the import tools).
func show_credits() -> void:
    _clear()
    _box.add_child(UIKit.label("Credits", 28, UIKit.ACCENT))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(300, 190)
    _box.add_child(scroll)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    scroll.add_child(vb)
    vb.add_child(UIKit.label("Tactical Summoners — heroes by Caz (Tiny Pixel Fantasy).", 12, UIKit.TEXT))
    for line in credit_lines():
        var l := UIKit.label(line, 12, UIKit.MUTED)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(290, 0)
        vb.add_child(l)
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


## "Name by Author - License" for every registered asset (markdown links stripped).
static func credit_lines() -> Array:
    var out: Array = []
    var path := "res://assets/CREDITS.md"
    if not FileAccess.file_exists(path):
        return out
    for raw in FileAccess.get_file_as_string(path).split("\n"):
        var line := String(raw).strip_edges()
        if not line.begins_with("- "):
            continue
        line = line.substr(2).replace("**", "")
        var re := RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
        line = re.sub(line, "$1", true)
        out.append(line)
    return out
