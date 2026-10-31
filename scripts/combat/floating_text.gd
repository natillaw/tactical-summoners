class_name FloatingText
extends Node2D
## Damage / heal / status numbers that rise and fade above a unit (combat feedback).

var text: String = ""
var color: Color = Color.WHITE
var big: bool = false
var life: float = LIFE
var _t: float = 0.0
var _drift: float = 0.0
const LIFE := 0.9
const POP_TIME := 0.12               # big numbers (crits) pop in from 1.5x, normal ones from 1.15x


static func spawn(unit: Node2D, p_text: String, p_color: Color, p_big: bool, p_life: float = LIFE) -> void:
    if unit == null or not unit.is_inside_tree() or unit.get_parent() == null or not unit.is_visible_in_tree():
        return                                    # nothing pops out of the fog of war
    var f := FloatingText.new()
    f.text = p_text
    f.color = p_color
    f.big = p_big
    f.life = p_life
    f._drift = randf_range(-10.0, 10.0)
    f.position = unit.position + Vector2(randf_range(-6, 6), -40)
    f.z_index = 50
    f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    unit.get_parent().add_child(f)


func _process(delta: float) -> void:
    _t += delta
    position.y -= (40.0 if _t < 0.25 else 16.0) * delta     # quick rise, then hangs to be read
    position.x += _drift * delta
    var pop := 1.0 + (0.5 if big else 0.15) * (1.0 - clampf(_t / POP_TIME, 0.0, 1.0))
    scale = Vector2.ONE * pop
    modulate.a = clampf((life - _t) / minf(0.35, life), 0.0, 1.0)   # readable, then a short fade
    if _t >= life:
        queue_free()
    queue_redraw()


func _draw() -> void:
    var font := UIKit.title_font() if big else UIKit.body_font()     # pixel fonts at native size (D-063)
    var size := UIKit.BODY
    var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    draw_string_outline(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, ArtPalette.OUTLINE)
    draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
