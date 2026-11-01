class_name BuildingInterior
extends Control
## The inside of a town building (InteriorDefs): the baked scene at a whole-pixel scale, its assigned
## heroes (LPC) idling at their work spots, a title and a way out. The town's building panel stays on
## the right with jobs and workers; with nobody assigned it says so and nothing gets made.

signal closed

var building_id := ""
var _scene: Dictionary = {}


func _init(bid: String = "") -> void:
    building_id = bid
    _scene = InteriorDefs.scene_for(bid)


func has_scene() -> bool:
    return not _scene.is_empty()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0.06, 0.04, 0.03, 0.92)
    add_child(dim)
    dim.position = Vector2(-4000, -4000)               # covers the whole town whatever the layout
    dim.size = Vector2(8000, 8000)
    if _scene.is_empty():
        return
    var tex := load(InteriorDefs.ROOT + String(_scene["png"]) + ".png") as Texture2D
    var room := Node2D.new()
    room.name = "Room"
    add_child(room)
    var pic := Sprite2D.new()
    pic.texture = tex
    pic.centered = false
    room.add_child(pic)
    var workers: Array = Game.workers_at(building_id)
    var spots: Array = _scene["spots"]
    for i in workers.size():
        var h: HeroData = workers[i]
        var s := AnimatedSprite2D.new()
        s.sprite_frames = SpriteComposer.build_frames(h)
        s.offset = SpriteComposer.feet_offset(h)
        var sp: Array = spots[i % spots.size()]
        s.position = Vector2(float(sp[0]), float(sp[1])) + Vector2(float(i / spots.size()) * 18.0, 0)
        room.add_child(s)
        s.play("idle_down" if s.sprite_frames.has_animation("idle_down") else "idle")
        var tag := Label.new()
        tag.text = h.display_name().get_slice(" ", 0)
        tag.add_theme_font_size_override("font_size", 8)
        tag.position = s.position + Vector2(-16, 8)
        room.add_child(tag)
    var title := UIKit.label("%s  ·  %s" % [TownTables.info(building_id)["name"],
        ("%d working here" % workers.size()) if not workers.is_empty() else "nobody works here: assign a hero to make anything"], 15,
        UIKit.ACCENT if not workers.is_empty() else Color(1.0, 0.65, 0.5))
    title.position = Vector2(10, 6)
    add_child(title)
    var leave := UIKit.button("Leave", func(): closed.emit(), Vector2(60, 22))
    leave.position = Vector2(10, 30)
    add_child(leave)
    resized.connect(_fit)
    _fit.call_deferred()


## Whole-pixel scale that fits the space left of the building panel.
func _fit() -> void:
    var room := get_node_or_null("Room") as Node2D
    if room == null:
        return
    var pic := room.get_child(0) as Sprite2D
    var avail := size - Vector2(200, 60)
    var k := maxi(1, floori(minf(avail.x / pic.texture.get_width(), avail.y / pic.texture.get_height())))
    room.scale = Vector2.ONE * k
    room.position = Vector2(floorf((size.x - 190.0 - pic.texture.get_width() * k) * 0.5), floorf(30.0 + (size.y - 30.0 - pic.texture.get_height() * k) * 0.5))
