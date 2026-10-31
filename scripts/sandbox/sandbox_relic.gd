class_name SandboxRelic
extends Node2D
## A mission marker on the map (T-011 + floor missions):
##   "relic"   gold relic to carry to EXIT          "captive" villager to escort to EXIT (rescue)
##   "clue"    point to discover (exploration)      "shrine"  point to hold (defense), shows progress
## Hidden while carried / once found.

var kind: String = "relic"
var progress: float = 0.0          # 0..1, drawn as an arc for the shrine
var _sprite: AnimatedSprite2D = null


func _init(p_kind: String = "relic") -> void:
    kind = p_kind


func _ready() -> void:
    if kind == "captive":
        var sf := CazArt.villager_frames(3)
        if sf != null:
            _sprite = AnimatedSprite2D.new()
            _sprite.sprite_frames = sf
            _sprite.offset = Vector2(0, -16)
            add_child(_sprite)
            _sprite.play("idle_down")


func _process(_delta: float) -> void:
    if kind == "shrine" or kind == "clue":
        queue_redraw()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    match kind:
        "captive":
            if _sprite == null:
                draw_circle(Vector2(0, -12), 9.0, Color(0.9, 0.85, 0.7))
            draw_string(font, Vector2(-24, -40), "HELP!", HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(1.0, 0.85, 0.4))
        "clue":
            var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
            draw_circle(Vector2(0, -10), 10.0 + pulse * 3.0, Color(0.5, 0.8, 1.0, 0.25))
            draw_arc(Vector2(0, -10), 12.0, 0.0, TAU, 24, Color(0.6, 0.9, 1.0), 2.0)
            draw_string(font, Vector2(-8, -4), "?", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color(0.85, 0.95, 1.0))
        "shrine":
            draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
            draw_circle(Vector2.ZERO, 120.0, Color(0.6, 0.5, 1.0, 0.08))
            draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 48, Color(0.7, 0.6, 1.0, 0.5), 2.0)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            draw_rect(Rect2(-8, -28, 16, 28), Color(0.55, 0.55, 0.65))
            draw_rect(Rect2(-5, -34, 10, 6), Color(0.75, 0.65, 1.0))
            draw_arc(Vector2(0, -16), 20.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Color(0.8, 0.7, 1.0), 4.0)
            draw_string(font, Vector2(-30, -44), "SHRINE %d%%" % int(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(0.85, 0.8, 1.0))
        _:
            var pts := PackedVector2Array([Vector2(0, -22), Vector2(10, -11), Vector2(0, 0), Vector2(-10, -11)])
            draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
            draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1.0, 0.95, 0.7), 2.0)
            draw_string(font, Vector2(-24, -30), "RELIC", HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(1.0, 0.82, 0.25))
