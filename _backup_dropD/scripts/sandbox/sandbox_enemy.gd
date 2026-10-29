class_name SandboxEnemy
extends Node2D
## Placeholder enemy (T-010): perceives the nearest hero, chases, then winds up a telegraphed
## strike. The strike lands only on heroes still inside the marked circle when the wind-up ends,
## so the player can dodge by ordering a move.

enum State { IDLE, CHASE, WINDUP, RECOVER }

var enemy_name: String = "Grunt"
var max_hp: int = 60
var hp: int = 60
var atk: int = 12
var defense: int = 3
var speed: float = 62.0
var perception: float = 230.0
var strike_range: float = 40.0
var strike_radius: float = 44.0
var windup_time: float = 0.7
var recover_time: float = 0.8
var alive: bool = true
var state: State = State.IDLE
var _timer: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _flash: float = 0.0
signal died(e: SandboxEnemy)


func is_telegraphing() -> bool:
    return state == State.WINDUP


func tick(delta: float, heroes: Array, map: SandboxMap) -> void:
    if not alive:
        return
    if _flash > 0.0:
        _flash = maxf(0.0, _flash - delta)
    match state:
        State.WINDUP:
            _timer -= delta
            if _timer <= 0.0:
                _strike(heroes)
                state = State.RECOVER
                _timer = recover_time
        State.RECOVER:
            _timer -= delta
            if _timer <= 0.0:
                state = State.IDLE
        _:
            var t := _nearest_hero(heroes)
            if t == null:
                state = State.IDLE
            elif position.distance_to(t.position) <= strike_range:
                state = State.WINDUP
                _timer = windup_time
                _aim = t.position
            else:
                state = State.CHASE
                _step_toward(t.position, delta, map)
    queue_redraw()


func _step_toward(goal: Vector2, delta: float, map: SandboxMap) -> void:
    var p := map.find_path(position, goal)
    if p.is_empty():
        return
    var to: Vector2 = p[0] - position
    if to.length() > 0.5:
        var np := position + to.normalized() * speed * delta
        if not map.is_blocked(np):
            position = np


func _nearest_hero(heroes: Array) -> SandboxHero:
    var best: SandboxHero = null
    var best_d := perception
    for h in heroes:
        if not h.alive:
            continue
        var d: float = position.distance_to(h.position)
        if d < best_d:
            best_d = d
            best = h
    return best


func _strike(heroes: Array) -> void:
    for h in heroes:
        if h.alive and h.position.distance_to(_aim) <= strike_radius:
            h.take_damage(CombatRules.damage(atk, int(h.hero.get_stats()["def"])), self)


func take_damage(amount: int, _source: Node2D = null) -> void:
    if not alive:
        return
    hp = maxi(0, hp - amount)
    _flash = 0.12
    if hp <= 0:
        alive = false
        died.emit(self)
        visible = false


func _draw() -> void:
    if not alive:
        return
    var body := Color(0.85, 0.30, 0.30) if _flash <= 0.0 else Color.WHITE
    draw_circle(Vector2(0, -12), 12.0, body)
    draw_rect(Rect2(-15, -34, 30, 4), Color(0.1, 0.1, 0.1, 0.8))
    draw_rect(Rect2(-15, -34, 30.0 * float(hp) / float(maxi(1, max_hp)), 4), Color(0.9, 0.35, 0.35))
    if state == State.WINDUP:
        var k := 1.0 - clampf(_timer / windup_time, 0.0, 1.0)
        draw_set_transform(_aim - position, 0.0, Vector2(1.0, 0.55))
        draw_circle(Vector2.ZERO, strike_radius, Color(1.0, 0.2, 0.2, 0.15 + 0.25 * k))
        draw_arc(Vector2.ZERO, strike_radius, 0.0, TAU, 32, Color(1.0, 0.3, 0.3), 2.0)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
