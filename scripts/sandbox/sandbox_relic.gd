class_name SandboxRelic
extends Node2D
## The mission objective item (T-011): a placeholder gold relic lying on the map.
## Hidden while a hero carries it; dropped where the carrier falls.


func _draw() -> void:
    var pts := PackedVector2Array([Vector2(0, -22), Vector2(10, -11), Vector2(0, 0), Vector2(-10, -11)])
    draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
    draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.95, 0.7), 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(-24, -30), "RELIC", HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(1.0, 0.82, 0.25))
