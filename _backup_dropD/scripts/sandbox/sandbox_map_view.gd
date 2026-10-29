class_name SandboxMapView
extends Node2D
## Draws the fixed test map (placeholder tiles: real tileset comes with the art pass).

var map: SandboxMap


func _init(m: SandboxMap = null) -> void:
    map = m


func _draw() -> void:
    if map == null:
        return
    for y in map.height:
        for x in map.width:
            var r := Rect2(x * SandboxMap.CELL, y * SandboxMap.CELL, SandboxMap.CELL, SandboxMap.CELL)
            if map.is_blocked_cell(Vector2i(x, y)):
                draw_rect(r, Color(0.20, 0.17, 0.30))
                draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), Color(0.32, 0.28, 0.46))
            else:
                var shade := 0.145 if (x + y) % 2 == 0 else 0.165
                draw_rect(r, Color(shade, shade * 0.95, shade * 1.35))
    # extraction/goal marker
    var g := map.center_of(SandboxMap.GOAL_CELL)
    draw_arc(g, 20.0, 0.0, TAU, 24, Color(0.45, 0.85, 0.50), 3.0)
    draw_string(ThemeDB.fallback_font, g + Vector2(-26, -28), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 52, 14, Color(0.45, 0.85, 0.50))
