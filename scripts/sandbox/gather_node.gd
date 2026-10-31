class_name GatherNode
extends Node2D
## A gathering spot in a tower floor (EconomyDefs.NODES): ore vein, fallen timber or herb patch. A hero
## that stands next to it out of combat collects it in EconomyDefs.GATHER_TIME; what it yields goes to
## the expedition ledger (kept on success or escape). Drawn with simple shapes; hidden in unexplored fog.

const RANGE := 38.0

var kind: String = "herb"
var amounts: Dictionary = {}        # resource -> amount, rolled when the floor is entered
var progress: float = 0.0
var taken: bool = false


func _init(p_kind: String = "herb", p_amounts: Dictionary = {}) -> void:
    kind = p_kind
    amounts = p_amounts
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func label() -> String:
    return String(EconomyDefs.NODES.get(kind, {}).get("name", kind))


func _draw() -> void:
    var col: Color = EconomyDefs.NODES.get(kind, {}).get("color", Color.WHITE)
    draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    match kind:
        "ore":
            draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.38, 0.38, 0.42))
            draw_polyline(PackedVector2Array([Vector2(-13, 0), Vector2(-9, -14), Vector2(2, -19), Vector2(12, -10), Vector2(13, 0)]), Color(0.1, 0.07, 0.15), 1.5)
            for p in [Vector2(-5, -9), Vector2(4, -12), Vector2(6, -4)]:
                draw_circle(p, 2.2, col)
        "wood":
            for i in 3:
                var y := -4.0 - 6.0 * float(i)
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.48, 0.32, 0.18))
                draw_rect(Rect2(-14 + i * 3, y - 5, 26 - i * 6, 6), Color(0.15, 0.08, 0.05), false, 1.0)
                draw_circle(Vector2(12 - i * 3, y - 2), 2.5, Color(0.75, 0.6, 0.4))
        _:
            draw_circle(Vector2(0, -8), 10.0, Color(0.22, 0.5, 0.2))
            draw_circle(Vector2(-6, -12), 6.0, Color(0.28, 0.6, 0.24))
            draw_circle(Vector2(6, -11), 6.0, Color(0.25, 0.55, 0.22))
            for p in [Vector2(-5, -14), Vector2(3, -16), Vector2(6, -8)]:
                draw_circle(p, 2.0, Color(0.95, 0.85, 0.4))
    if progress > 0.0:
        var k := clampf(progress / EconomyDefs.GATHER_TIME, 0.0, 1.0)
        draw_arc(Vector2(0, -10), 18.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, col, 3.0)
