class_name TownHero
extends Node2D
## A hero living in the town. What it does comes from the simulation (HeroData.activity_state, set
## by TownSim): it walks (A* on the town map) to its workplace, bed, kitchen, tavern or hospital and
## acts it out. Only when the simulation says "idle" does it pick a free-time pastime of its own
## (wander, visit, train, rest, chat), weighted by personality. Never changes hero data.

const SPEED := 55.0
const ACTIVITIES := ["wander", "visit", "train", "work", "rest", "chat"]
const SYNC_EVERY := 0.5
## Jobs done indoors (the hero goes inside) vs. outdoors (swings a tool at the door).
const INDOOR := ["alchemy", "library", "infirmary", "kitchen", "common", "warehouse", "town_hall"]
var sim_state: String = ""          # last HeroData.activity_state acted out
var _inside_goal: bool = false
var _sync_t: float = 0.0

var hero: HeroData
var map: TownMap
var town_heroes: Array = []       # other TownHero nodes (for chatting), set by TownScreen
var hovered: bool = false
var activity: String = "idle"
var activity_target: String = ""   # building id or hero name, for the info panel
var _sprite: AnimatedSprite2D
var _path: Array[Vector2] = []
var _timer: float = 0.0
var _doing: bool = false          # arrived and performing the activity
var _rng := RandomNumberGenerator.new()
var _facing := "down"
var _bubble: String = ""
var _bubble_t: float = 0.0
var _swing: float = 0.0


func _init(h: HeroData = null, m: TownMap = null) -> void:
    hero = h
    map = m


func _ready() -> void:
    if hero == null:
        return
    _rng.seed = hero.hero_seed
    _sprite = AnimatedSprite2D.new()
    _sprite.sprite_frames = SpriteComposer.build_frames(hero)
    _sprite.offset = Vector2(0, -16)
    add_child(_sprite)
    _sprite.play("idle_down")
    _timer = _rng.randf_range(0.2, 2.0)


## Human-readable current activity (shown in the hero panel).
func activity_text() -> String:
    match activity:
        "sim_work":
            return "Working at the %s" % TownTables.info(activity_target).get("name", "construction site")
        "sim_build":
            return "Building the %s" % TownTables.info(activity_target).get("name", "town")
        "sim_sleep":
            return "Sleeping" + ("" if hero.bed != "" else " rough (no bed)")
        "sim_eat":
            return "Eating a meal"
        "sim_social":
            return "Unwinding at the tavern"
        "sim_treat":
            return "Being treated at the hospital"
        "visit":
            return "Visiting the %s" % TownTables.info(activity_target).get("name", "town")
        "train":
            return "Training at the barracks yard"
        "work":
            return "Working at the %s" % TownTables.info(activity_target).get("name", "town")
        "rest":
            return "Resting at the plaza"
        "chat":
            return "Chatting with %s" % activity_target
        "wander":
            return "Strolling around town"
    return "Thinking about what to do"


## Weighted by personality and job: workers work more, brave/hot-headed train more, cheerful chat more.
func _choose() -> String:
    var w := {"wander": 3.0, "visit": 2.0, "train": 1.0, "work": 0.0, "rest": 1.5, "chat": 1.5}
    for t in hero.traits:
        match String(t):
            "trait.brave", "trait.hot_headed", "trait.reckless":
                w["train"] += 2.0
            "trait.cheerful", "trait.kind":
                w["chat"] += 2.0
            "trait.lazy", "trait.gloomy":
                w["rest"] += 2.0
            "trait.curious", "trait.greedy":
                w["visit"] += 2.0
    var total := 0.0
    for k in w:
        total += float(w[k])
    var roll := _rng.randf() * total
    for k in ACTIVITIES:
        roll -= float(w[k])
        if roll <= 0.0:
            return k
    return "wander"


func _built_buildings() -> Array:
    return TownTables.ids().filter(func(id): return Game.building_level(id) > 0)


## Acts out the simulation state; returns false when the hero is free (idle) to pick a pastime.
func _start_sim() -> bool:
    sim_state = hero.activity_state
    var target := ""
    var inside := true
    match sim_state:
        "working":
            if hero.hq_assignment == "construction":
                activity = "sim_build"
                target = String(Game.construction[0]["bid"]) if not Game.construction.is_empty() else "town_hall"
                inside = false
            else:
                activity = "sim_work"
                target = hero.hq_assignment
                inside = INDOOR.has(target)
        "sleeping":
            activity = "sim_sleep"
            target = hero.bed
            inside = hero.bed != ""
        "eating":
            activity = "sim_eat"
            target = "common" if Game.building_level("common") > 0 else "kitchen"
        "socializing":
            activity = "sim_social"
            target = "common"
            inside = false
        "in_treatment":
            activity = "sim_treat"
            target = "infirmary"
        "deployed":
            activity = "away"
            visible = false
            _path.clear()
            _doing = true
            return true
        _:
            return false
    activity_target = target
    _doing = false
    visible = true
    var goal := map.center_of(Vector2i(17, 10)) + Vector2(_rng.randf_range(-60, 60), 40)
    if target != "" and TownTables.BUILDINGS.has(target):
        goal = map.center_of(map.door_of(target)) + (Vector2.ZERO if inside else Vector2(_rng.randf_range(-40, 40), 14))
    _inside_goal = inside and target != ""
    _path = map.find_path(position, goal)
    return true



func _start_next() -> void:
    if _start_sim():
        return
    activity = _choose()
    activity_target = ""
    _doing = false
    var goal := map.center_of(map.random_walkable(_rng))
    match activity:
        "visit":
            var b: Array = _built_buildings()
            activity_target = String(b[_rng.randi() % b.size()])
            goal = map.center_of(map.door_of(activity_target))
        "work":
            activity_target = hero.hq_assignment
            goal = map.center_of(map.door_of(activity_target))
        "train":
            activity_target = "barracks"
            goal = map.center_of(map.door_of("barracks")) + Vector2(_rng.randf_range(-60, 60), 20)
        "rest":
            goal = map.center_of(Vector2i(17, 10)) + Vector2(_rng.randf_range(-70, 70), _rng.randf_range(30, 50))
        "chat":
            var others := town_heroes.filter(func(o): return o != self and o.visible)
            if others.is_empty():
                activity = "wander"
            else:
                var mate = others[_rng.randi() % others.size()]
                activity_target = mate.hero.hero_name.split(" ")[0]
                goal = mate.position + Vector2(22, 0)
    _path = map.find_path(position, goal)


func _process(delta: float) -> void:
    if hero == null or map == null:
        return
    if _bubble_t > 0.0:
        _bubble_t -= delta
    _sync_t -= delta
    if _sync_t <= 0.0:
        _sync_t = SYNC_EVERY
        if hero.activity_state != sim_state:
            _start_next()                     # the simulation moved this hero on
    if not _path.is_empty():
        _walk(delta)
    else:
        _timer -= delta
        if not _doing:
            _arrive()
        elif activity == "train" or (activity in ["sim_work", "sim_build"] and not _inside_goal):
            _swing -= delta
            if _swing <= 0.0:
                _swing = 0.6
                _sprite.stop()
                _sprite.play("attack_" + ("left" if _rng.randf() < 0.5 else "right"))
        elif not _sprite.animation.begins_with("attack"):
            _play("idle_" + _facing)
        if _timer <= 0.0 and not activity.begins_with("sim_") and activity != "away":
            visible = true
            _start_next()
    queue_redraw()


func _arrive() -> void:
    _doing = true
    if activity.begins_with("sim_"):
        if _inside_goal:
            visible = false                    # inside the building while the state lasts
        elif activity == "sim_social":
            _say(HeroChatter.town_line(hero, _rng))
        return
    _timer = _rng.randf_range(3.0, 7.0)
    match activity:
        "visit", "work":
            visible = false                    # inside the building
            _timer = _rng.randf_range(4.0, 9.0)
        "chat":
            _say(HeroChatter.town_line(hero, _rng))
        "rest":
            _facing = "down"
            if _rng.randf() < 0.4:
                _say(HeroChatter.town_line(hero, _rng))


func _say(text: String) -> void:
    _bubble = text
    _bubble_t = 3.5


func _walk(delta: float) -> void:
    var to := _path[0] - position
    var step := SPEED * delta * (0.5 if activity == "sim_treat" else 1.0)   # the sick walk slowly
    if to.length() <= step:
        position = _path[0]
        _path.remove_at(0)
        return
    var dir := to.normalized()
    position += dir * step
    if absf(dir.x) >= absf(dir.y):
        _facing = "right" if dir.x > 0.0 else "left"
    else:
        _facing = "down" if dir.y > 0.0 else "up"
    _play("walk_" + _facing)


func _play(anim: String) -> void:
    if _sprite != null and _sprite.animation != anim:
        _sprite.play(anim)


func _draw() -> void:
    if hero == null:
        return
    draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(hero.star_color(), 0.6), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var font := ThemeDB.fallback_font
    if _bubble_t > 0.0:
        var bw := font.get_string_size(_bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
        var box := Rect2(-bw * 0.5 - 5, -66, bw + 10, 17)
        draw_rect(box, Color(0.98, 0.97, 0.92, 0.95))
        draw_rect(box, Color(0.2, 0.18, 0.15), false, 1.0)
        draw_colored_polygon(PackedVector2Array([Vector2(-3, -49), Vector2(3, -49), Vector2(0, -44)]), Color(0.98, 0.97, 0.92))
        draw_string(font, Vector2(-bw * 0.5, -53), _bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.12, 0.1))
    elif hovered:
        var txt := hero.display_name()
        var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_rect(Rect2(-w * 0.5 - 4, -58, w + 8, 16), Color(0.08, 0.07, 0.12, 0.85))
        draw_string(font, Vector2(-w * 0.5, -46), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hero.star_color())
