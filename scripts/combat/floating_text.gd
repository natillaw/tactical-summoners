class_name FloatingText
extends Node2D
## Damage / heal / status numbers that rise and fade above a unit (combat feedback).

var text: String = ""
var color: Color = Color.WHITE
var big: bool = false
var _t: float = 0.0
const LIFE := 0.9


static func spawn(unit: Node2D, p_text: String, p_color: Color, p_big: bool) -> void:
    if unit == null or not unit.is_inside_tree() or unit.get_parent() == null:
        return
    var f := FloatingText.new()
    f.text = p_text
    f.color = p_color
    f.big = p_big
    f.position = unit.position + Vector2(randf_range(-6, 6), -40)
    f.z_index = 50
    unit.get_parent().add_child(f)


func _process(delta: float) -> void:
    _t += delta
    position.y -= 28.0 * delta
    modulate.a = clampf(1.0 - _t / LIFE, 0.0, 1.0)
    if _t >= LIFE:
        queue_free()
    queue_redraw()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var size := 18 if big else 13
    var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    draw_string_outline(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
    draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
