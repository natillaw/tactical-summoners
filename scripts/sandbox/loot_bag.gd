class_name LootBag
extends Node2D
## D-120/D-121 (pista D): loot left on the floor of a tower floor: a body that carried something, or the
## backpack a fallen hero dropped (D-124). It glows in the colour of its best item (gold when it holds only
## materials) until someone loots it; while the Master holds F next to it a ring fills (LootDefs.LOOT_HOLD).
## Hidden in unexplored fog like the gathering spots. Pure data + drawing: SandboxScreen does the looting.

var items: Array = []                 # item dicts (ItemGen)
var res: Dictionary = {}              # resource id -> amount (materials, keys, books)
var source: String = "body"           # "body" | "pack" (a fallen hero's backpack)
var owner_name: String = ""           # whose pack it was
var hold: float = 0.0                 # 0..1: the Master's F progress
var prompt: bool = false              # the Master is next to it
var visible_to_bot: bool = true       # MasterBot gave up on it (could not reach it)
var _t: float = 0.0


func is_empty() -> bool:
    return items.is_empty() and res.is_empty()


func glow_color() -> Color:
    var best := LootService.best_rarity(items)
    if best == "":
        return Color(0.95, 0.82, 0.4)                # materials only
    return ItemDefs.rarity_color(best)


func _ready() -> void:
    z_index = 1                                      # over the ground art (the units draw on top by order)
    if SimMode.on:
        visible = false
        set_process(false)


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    if is_empty():
        return
    var c := glow_color()
    var pulse := 0.5 + 0.5 * sin(_t * 3.2)
    draw_circle(Vector2.ZERO, 14.0 + 4.0 * pulse, Color(c, 0.22 + 0.14 * pulse))
    draw_circle(Vector2.ZERO, 7.0, Color(c, 0.7))
    draw_arc(Vector2.ZERO, 14.0 + 4.0 * pulse, 0.0, TAU, 28, Color(c, 0.85), 1.0)
    for i in 3:                                      # small rising sparks
        var a := _t * 1.7 + float(i) * TAU / 3.0
        var p := Vector2(cos(a) * 8.0, -fmod(_t * 14.0 + float(i) * 7.0, 18.0))
        draw_rect(Rect2(p, Vector2(2, 2)), Color(c, 0.9))
    if source == "pack":
        draw_rect(Rect2(-5, -4, 10, 8), Color(0.45, 0.3, 0.18))   # a dropped backpack
        draw_rect(Rect2(-5, -4, 10, 8), c, false, 1.0)
    if hold > 0.0:
        draw_arc(Vector2.ZERO, 16.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold, 0.0, 1.0), 24, Color(1, 1, 1, 0.9), 2.0)
    if prompt:
        var f := ThemeDB.fallback_font
        var txt := tr("Hold F: loot")
        draw_string(f, Vector2(-f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2.0, -20), txt,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.95))
