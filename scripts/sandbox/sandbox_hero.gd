class_name SandboxHero
extends Node2D
## One deployed hero in the real-time sandbox: animated sprite, speed from the SPD stat,
## waypoint following. Orders are always obeyed (D-016: no random refusal).

const ARRIVE_EPS := 1.0

var hero: HeroData
var slot: int = 0                 # 0-4 -> key 1-5
var selected: bool = false : set = _set_selected
var path: Array[Vector2] = []
var facing: String = "down"
var speed: float = 90.0
var _sprite: AnimatedSprite2D
var _anim_lock: float = 0.0          # T-023: blocks idle/walk from overriding an attack/cast pose
var _side: String = "right"          # last horizontal facing (up/down attacks reuse it)
var chatter_text: String = ""
var chatter_timer: float = 0.0

func say(text: String, duration: float = 4.0) -> void:
	chatter_text = text
	chatter_timer = duration
	queue_redraw()

# --- combat (T-007). Provisional numbers (D-012): tune in CombatRules only. ---
var max_hp: int = 1
var hp: int = 1
var alive: bool = true
var auto_path: bool = false         # true while walking toward a target on its own
var target: SandboxEnemy = null
var _cooldown: float = 0.0
var _flash: float = 0.0
var killed_by: String = ""          # name of whatever dealt the last hit (memorial cause)
var carrying: bool = false          # holds the mission relic (T-011)
var skill: Dictionary = {}          # one active skill, from SkillTables (T-009)
var skill_cd: float = 0.0           # seconds until the skill is ready
var _fx: float = 0.0                # skill visual timer
var _fx_to: Vector2 = Vector2.ZERO
var _fx_radius: float = 0.0
signal died(h: SandboxHero)


func _init(h: HeroData = null, slot_index: int = 0) -> void:
	hero = h
	slot = slot_index


func _ready() -> void:
	if hero == null:
		return
	speed = 70.0 + float(hero.get_stats()["spd"]) * 3.0
	max_hp = int(hero.get_stats()["hp"])
	hp = max_hp
	skill = SkillTables.for_class(hero.hero_class)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteComposer.build_frames(hero)
	_sprite.offset = Vector2(0, -16)            # feet at the node origin
	add_child(_sprite)
	_play("idle_down")


func is_moving() -> bool:
	return not path.is_empty()


## Direct orders are never refused and always cancel autonomous behavior (D-016).
func order_move(waypoints: Array[Vector2]) -> void:
	path = waypoints.duplicate()
	auto_path = false
	target = null


func stop() -> void:
	path.clear()


func tick(delta: float) -> void:
	if not alive:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	if chatter_timer > 0.0:
		chatter_timer = maxf(0.0, chatter_timer - delta)
		queue_redraw()
	if _fx > 0.0:
		_fx = maxf(0.0, _fx - delta)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	if path.is_empty():
		_play("idle_" + facing)
		return
	var next_wp: Vector2 = path[0]
	var to := next_wp - position
	var dist := to.length()
	var step := speed * delta
	if dist <= step + ARRIVE_EPS:
		position = next_wp
		path.remove_at(0)
	else:
		var dir := to / dist
		position += dir * step
		_face(dir)
		_play("walk_" + facing)


func is_ranged() -> bool:
	return String(HeroTables.CLASSES[hero.hero_class]["reach"]) == "ranged"


func attack_range() -> float:
	return CombatRules.HERO_RANGED_RANGE if is_ranged() else CombatRules.HERO_MELEE_RANGE


func attack_interval() -> float:
	return CombatRules.hero_interval(int(hero.get_stats()["spd"]))


func attack_damage(target_def: int) -> int:
	var st := hero.get_stats()
	return CombatRules.damage(maxi(int(st["atk"]), int(st["mag"])), target_def)


## Autonomous basic attacks. Idle heroes (no player order) pick the nearest perceived enemy,
## walk into range and strike on cooldown. A player move order always wins.
func combat_tick(enemies: Array, map: NavMap) -> void:
	if not alive:
		return
	if not path.is_empty() and not auto_path:
		return                                   # obeying a direct order
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
	if target == null:
		target = _nearest(enemies, CombatRules.HERO_PERCEPTION)
		if target == null:
			if auto_path:
				path.clear()
				auto_path = false
			return
	var d := position.distance_to(target.position)
	if d <= attack_range():
		path.clear()
		auto_path = false
		_face(target.position - position)
		if _cooldown <= 0.0:
			_cooldown = attack_interval()
			_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged())
			CombatVFX.spawn_effect(get_parent(), target.position, "spritepilot-combat-pack", "16px", "sword-slash-16px_strip7.png", 16, 16, 7, 2.5)
			target.take_damage(attack_damage(target.defense), self)
	elif path.is_empty() or auto_path:
		var p := map.find_path(position, target.position)
		if not p.is_empty():
			path = p
			auto_path = true


func _nearest(enemies: Array, radius: float) -> SandboxEnemy:
	var best: SandboxEnemy = null
	var best_d := radius
	for e in enemies:
		if not e.alive:
			continue
		var d: float = position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func skill_ready() -> bool:
	return alive and skill_cd <= 0.0


## Direct skill activation (T-009). Returns true if it fired. Refused only on cooldown or when
## there is no valid target; never by a random roll (D-016). Heals need no target.
func use_skill(enemies: Array) -> bool:
	if not skill_ready() or skill.is_empty():
		return false
	var st := hero.get_stats()
	var power := maxi(int(st["atk"]), int(st["mag"]))
	var kind := String(skill["kind"])
	if kind == "self_heal":
		if hp >= max_hp:
			return false
		hp = mini(max_hp, hp + roundi(float(max_hp) * float(skill["heal"])))
		_fire_fx(position, 0.0)
		_anim_lock = HeroAnim.play_cast(_sprite, _side)
		skill_cd = float(skill["cooldown"])
		return true
	var tgt: SandboxEnemy = null
	var reach := float(skill.get("range", 0.0))
	if kind == "self_aoe":
		reach = float(skill["radius"])
	var best_d := reach
	for e in enemies:
		if not e.alive:
			continue
		var d: float = position.distance_to(e.position)
		if d <= best_d:
			best_d = d
			tgt = e
	if target != null and is_instance_valid(target) and target.alive and position.distance_to(target.position) <= reach:
		tgt = target                             # prefer the current target when in reach
	if tgt == null:
		return false
	if kind == "target":
		tgt.take_damage(CombatRules.skill_damage(power, float(skill["mult"]), tgt.defense), self)
		_fire_fx(tgt.position, 0.0)
	else:
		var centre: Vector2 = position if kind == "self_aoe" else tgt.position
		var radius := float(skill["radius"])
		for e in enemies:
			if e.alive and e.position.distance_to(centre) <= radius:
				e.take_damage(CombatRules.skill_damage(power, float(skill["mult"]), e.defense), self)
		_fire_fx(centre, radius)
	_face(tgt.position - position)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)
	skill_cd = float(skill["cooldown"])
	return true


func _fire_fx(at: Vector2, radius: float) -> void:
	_fx = 0.35
	_fx_to = at - position
	_fx_radius = radius
	queue_redraw()


func take_damage(amount: int, _source: Node2D = null) -> void:
	if not alive:
		return
	if _source != null and _source.get("enemy_name") != null:
		killed_by = str(_source.get("enemy_name"))
	hp = maxi(0, hp - amount)
	_flash = 0.15
	queue_redraw()
	if hp > 0 and _source != null:
		HeroAnim.play_hit(_sprite, (position - _source.position).normalized())
	if hp <= 0:
		HeroAnim.spawn_death(self, _sprite, facing, _side)
		alive = false
		path.clear()
		# Permanent death (D-011): flagged here; memorial/ledger handled by T-013.
		died.emit(self)
		visible = false


func _face(dir: Vector2) -> void:
	if absf(dir.x) >= absf(dir.y):
		facing = "right" if dir.x > 0.0 else "left"
	else:
		facing = "down" if dir.y > 0.0 else "up"
	if facing == "left" or facing == "right":
		_side = facing


func _play(anim: String) -> void:
	if _anim_lock > 0.0:
		return
	if _sprite != null and _sprite.animation != anim:
		_sprite.play(anim)


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	if hero == null or not alive:
		return
	var w := 30.0
	draw_rect(Rect2(-w * 0.5, -46, w, 4), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, -46, w * float(hp) / float(maxi(1, max_hp)), 4), Color(0.45, 0.85, 0.50))
	if carrying:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -64), Vector2(6, -58), Vector2(0, -52), Vector2(-6, -58)]), Color(1.0, 0.82, 0.25))
	if _fx > 0.0:
		var a := _fx / 0.35
		if _fx_radius > 0.0:
			draw_arc(_fx_to, _fx_radius, 0.0, TAU, 32, Color(1.0, 0.7, 0.25, a), 3.0)
		elif _fx_to.length() > 1.0:
			draw_line(Vector2(0, -16), _fx_to + Vector2(0, -12), Color(1.0, 0.9, 0.5, a), 3.0)
		else:
			draw_arc(Vector2(0, -16), 22.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6, a), 3.0)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.55))
	var col := hero.star_color()
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 28, Color.WHITE if selected else Color(col, 0.55), 3.0 if selected else 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-4, -52), str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col)
	if chatter_timer > 0.0 and chatter_text != "":
		var text_w: float = font.get_string_size(chatter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16
		var box_rect := Rect2(-text_w * 0.5 - 8, -85, text_w + 16, 26)
		draw_rect(box_rect, Color(0.1, 0.1, 0.15, 0.9))
		draw_rect(box_rect, Color(0.6, 0.7, 0.9, 0.8), false, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -59), Vector2(4, -59), Vector2(0, -52)]), Color(0.1, 0.1, 0.15, 0.9))
		draw_string(font, Vector2(-text_w * 0.5, -68), chatter_text, HORIZONTAL_ALIGNMENT_CENTER, text_w + 16, 12, Color.WHITE)
