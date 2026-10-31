class_name StarRow
extends Control
## Draws N five-point stars (no font needed, so it works with any default font).

var count: int = 1
var star_color: Color = Color.WHITE
var star_size: float = 14.0


func _init(c: int = 1, s: float = 14.0, col: Color = Color.WHITE) -> void:
    count = c
    star_size = s
    star_color = col
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2((s + 2.0) * float(c), s)


func _draw() -> void:
    for i in count:
        var cx := star_size * 0.5 + float(i) * (star_size + 2.0)
        var cy := star_size * 0.5
        var pts := PackedVector2Array()
        for k in 10:
            var r := star_size * 0.5 if k % 2 == 0 else star_size * 0.22
            var ang := -PI / 2.0 + float(k) * PI / 5.0
            pts.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r))
        draw_colored_polygon(pts, star_color)
