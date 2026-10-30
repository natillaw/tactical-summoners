class_name SandboxHero
extends Combatant
## One deployed hero in a mission: animated sprite, movement, autonomous basic attacks, skills and
## direct orders. Health, damage, statuses, downed/agony and death live in Combatant (D-035..D-037).
## Orders are always obeyed (D-016: no random refusal); the order state decides what autonomy may do.

const ARRIVE_EPS := 1.0
const REPATH_EVERY := 0.4

var hero: HeroData
var slot: int = 0                 # 0-4 -> key 1-5
var selected: bool = false : set = _set_selected
var path: Array[Vector2] = []
var facing: String = "down"
var speed: float = 90.0
var stats: Dictionary = {}        # derived combat stats (CombatRules.derive)
var _sprite: AnimatedSprite2D
var _anim_lock: float = 0.0          # T-023: blocks idle/walk from overriding an attack/cast pose
var _side: String = "right"          # last horizontal facing (up/down attacks reuse it)
var chatter_text: String = ""
var chatter_timer: float = 0.0

## Order state (D-040): "auto" | "move" | "attack" | "attack_move" | "hold" | "follow" | "retreat" | "rescue".
var order: String = "auto"
var order_point: Vector2 = Vector2.ZERO     # attack-move destination / hold spot
var follow_leader: SandboxHero = null
var _dodge_t: float = 0.0
const KITE_DISTANCE := 70.0
const FOLLOW_DISTANCE := 90.0
const FOLLOW_LEASH := 170.0
const ORDER_LABELS := {"auto": "Auto", "move": "Moving", "attack": "Attacking", "attack_move": "Attack-moving",
	"hold": "Holding", "follow": "Following", "retreat": "Retreating", "rescue": "Rescuing"}
var auto_path: bool = false         # true while walking toward a target on its own
var target: SandboxEnemy = null
var rescue_target: SandboxHero = null
var rescue_progress: float = 0.0
var _repath: float = 0.0
var _last_delta: float = 0.0
var _cooldown: float = 0.0
var _flash: float = 0.0
var carrying: bool = false          # holds the mission relic (T-011)
var skill: Dictionary = {}          # one active skill, from SkillTables (T-009; Phase 3 replaces)
var skill_cd: float = 0.0           # seconds until the skill is ready
var _fx: float = 0.0                # skill visual timer
var _fx_to: Vector2 = Vector2.ZERO
var _fx_radius: float = 0.0


func say(text: String, duration: float = 4.0) -> void:
	chatter_text = text
	chatter_timer = duration
	queue_redraw()


func _init(h: HeroData = null, slot_index: int = 0) -> void:
	hero = h
	slot = slot_index


func _ready() -> void:
	if hero == null:
		return
	stats = hero.get_stats()
	speed = float(stats["move"])
	setup_combat(int(stats["hp"]), int(stats["def"]), int(stats["mres"]), float(stats["crit"]), float(stats["status_resist"]), hero.hero_seed)
	can_be_downed = true
	skill = SkillTables.for_class(hero.hero_class)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteComposer.build_frames(hero)
	_sprite.offset = Vector2(0, -16)            # feet at the node origin
	add_child(_sprite)
	_play("idle_down")


func is_moving() -> bool:
	return not path.is_empty()


func power() -> int:
	return int(stats["mag"]) if String(stats.get("kind", "physical")) == "magical" else int(stats["atk"])


# --- orders (never randomly refused, D-016) -----------------------------------------------------

func order_move(waypoints: Array[Vector2]) -> void:
	path = waypoints.duplicate()
	auto_path = false
	target = null
	rescue_target = null
	rescue_progress = 0.0
	order = "move"


## Attack a specific enemy until it dies or another order arrives (chases it, no perception limit).
func order_attack(enemy: SandboxEnemy) -> void:
	target = enemy
	rescue_target = null
	rescue_progress = 0.0
	path.clear()
	auto_path = true
	order = "attack"
	_repath = 0.0


## Go to a downed ally and carry them back to their feet (D-036).
func order_rescue(ally: SandboxHero) -> void:
	rescue_target = ally
	rescue_progress = 0.0
	target = null
	path.clear()
	auto_path = false
	order = "rescue"
	_repath = 0.0


## Walk to a point, fighting anything met on the way, then go back to Auto.
func order_attack_move(point: Vector2, map: NavMap) -> bool:
	_clear_orders()
	order = "attack_move"
	order_point = point
	path = map.find_path(position, point)
	return not path.is_empty()


## Stay here: fight only what comes into range, never chase.
func order_hold() -> void:
	_clear_orders()
	order = "hold"
	order_point = position


## Stay close to another hero, fight near them, never wander off.
func order_follow(leader: SandboxHero) -> void:
	_clear_orders()
	order = "follow"
	follow_leader = leader


## Run to the extraction point without stopping to fight (then hold there).
func order_retreat(point: Vector2, map: NavMap) -> bool:
	_clear_orders()
	order = "retreat"
	path = map.find_path(position, point)
	return not path.is_empty()


func order_label() -> String:
	return String(ORDER_LABELS.get(order, order))


func _clear_orders() -> void:
	path.clear()
	auto_path = false
	target = null
	rescue_target = null
	rescue_progress = 0.0
	follow_leader = null
	_repath = 0.0


func stop() -> void:
	_clear_orders()
	order = "auto"


# --- simulation --------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_last_delta = delta
	tick_combat(delta)
	if not alive:
		if downed:
			queue_redraw()
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	_repath = maxf(0.0, _repath - delta)
	_dodge_t = maxf(0.0, _dodge_t - delta)
	if chatter_timer > 0.0:
		chatter_timer = maxf(0.0, chatter_timer - delta)
	if _fx > 0.0:
		_fx = maxf(0.0, _fx - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if path.is_empty() or not can_move():
		_play("idle_" + facing)
		return
	var next_wp: Vector2 = path[0]
	var to := next_wp - position
	var dist := to.length()
	var step := speed * move_mult() * delta
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
	return float(stats.get("interval", CombatRules.hero_interval(int(stats.get("spd", 5)))))


## Autonomy + order execution for one step. Explicit orders come first (D-016); within an order
## the hero still fights sensibly: keeps range by role, needs line of sight to shoot, steps out of
## telegraphed strikes (bounded autonomy, D-014) and never chases while holding or following.
func combat_tick(enemies: Array, map: NavMap) -> void:
	if not alive:
		return
	if _dodge_t > 0.0 and not path.is_empty():
		return                                   # finishing a dodge step
	if order != "move" and order != "retreat" and order != "rescue" and can_move():
		if _try_dodge(enemies, map):
			return
	match order:
		"rescue":
			_rescue_tick(map)
			return
		"move":
			if not path.is_empty():
				return                               # obeying a direct move
			order = "auto"
		"retreat":
			if path.is_empty():
				order_hold()
			return                                   # no fighting while retreating
		"follow":
			if follow_leader == null or not is_instance_valid(follow_leader) or not follow_leader.alive:
				order = "auto"
			elif position.distance_to(follow_leader.position) > FOLLOW_DISTANCE and (path.is_empty() or _repath <= 0.0) and target == null:
				_repath = REPATH_EVERY
				path = map.find_path(position, follow_leader.position)
	if not can_act():
		return
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
		if order == "attack":
			order = "auto"
			FloatingText.spawn(self, "target down", Color(0.8, 0.8, 0.8), false)
	if target == null:
		var radius := attack_range() if order == "hold" else CombatRules.HERO_PERCEPTION
		target = _nearest(enemies, radius)
		if target == null:
			match order:
				"attack_move":
					if path.is_empty():
						if position.distance_to(order_point) < 30.0:
							order = "auto"
						else:
							path = map.find_path(position, order_point)
				"follow", "hold":
					pass
				_:
					if auto_path:
						path.clear()
						auto_path = false
			return
	var d := position.distance_to(target.position)
	var sees := not is_ranged() or map.has_line_of_sight(position + Vector2(0, -12), target.position + Vector2(0, -12))
	if d <= attack_range() and sees:
		if is_ranged() and d < KITE_DISTANCE and order != "hold" and _kite(target, map):
			return
		path.clear()
		auto_path = false
		_face(target.position - position)
		if _cooldown <= 0.0:
			_cooldown = attack_interval()
			_basic_attack(target)
		return
	if order == "hold":
		target = null                            # out of reach: holding means not chasing
		return
	if order == "follow" and follow_leader != null and target.position.distance_to(follow_leader.position) > FOLLOW_LEASH:
		target = null
		return
	if _repath <= 0.0 or path.is_empty():
		_repath = REPATH_EVERY
		var p := map.find_path(position, target.position)
		if not p.is_empty():
			path = p
			auto_path = true


## Steps out of an enemy's telegraphed strike circle if there is still time (D-014: bounded,
## predictable, never overrides an explicit move/retreat/rescue order).
func _try_dodge(enemies: Array, map: NavMap) -> bool:
	for e in enemies:
		if not e.alive or not e.is_telegraphing() or e.windup_left() < 0.15:
			continue
		var aim: Vector2 = e.aim_point()
		var r: float = e.strike_radius
		if position.distance_to(aim) > r + 4.0:
			continue
		var away := position - aim
		if away.length() < 1.0:
			away = Vector2.RIGHT.rotated(float(slot))
		var spot := aim + away.normalized() * (r + 22.0)
		if map.is_blocked(spot):
			spot = aim - away.normalized().orthogonal() * (r + 22.0)
		if map.is_blocked(spot):
			return false
		path.clear()
		path.append(spot)
		auto_path = true
		_dodge_t = 0.6
		return true
	return false


## Ranged heroes back off when a foe gets too close (keep their role distance).
func _kite(foe: SandboxEnemy, map: NavMap) -> bool:
	var spot := position + (position - foe.position).normalized() * 80.0
	if map.is_blocked(spot) or not map.has_line_of_sight(position, spot):
		return false
	path.clear()
	path.append(spot)
	auto_path = true
	_dodge_t = 0.4
	return true


func _basic_attack(t: SandboxEnemy) -> void:
	_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged())
	if is_ranged():
		CombatVFX.spawn_strip16(get_parent(), t.position + Vector2(0, -12), "spritepilot-combat-pack", "arrow-16px_strip4.png", 2.0)
	else:
		CombatVFX.spawn_strip16(get_parent(), t.position + Vector2(0, -12), "spritepilot-combat-pack", "sword-slash-16px_strip7.png")
	t.take_hit(DamageInfo.make(float(power()), String(stats.get("kind", "physical")), self, crit_chance, combat_rng))


func _rescue_tick(map: NavMap) -> void:
	if rescue_target == null or not is_instance_valid(rescue_target) or not rescue_target.downed:
		stop()
		return
	if position.distance_to(rescue_target.position) <= CombatRules.RESCUE_RANGE:
		path.clear()
		_face(rescue_target.position - position)
		_play("ready_" + _side)
		rescue_progress += _last_delta
		if rescue_progress >= CombatRules.RESCUE_TIME:
			rescue_target.revive(CombatRules.RESCUE_HP)
			if hero != null and rescue_target.hero != null:
				hero.rescue_hero(rescue_target.hero)          # memory, bond and Trust (Phase 3 data)
			FloatingText.spawn(rescue_target, "Rescued!", Color(0.5, 1.0, 0.6), true)
			stop()
	elif path.is_empty() or _repath <= 0.0:
		_repath = REPATH_EVERY
		path = map.find_path(position, rescue_target.position)


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


## Direct skill activation (T-009). Returns true if it fired. Refused only on cooldown, stun or when
## there is no valid target; never by a random roll (D-016). Heals need no target.
func use_skill(enemies: Array) -> bool:
	if not skill_ready() or skill.is_empty() or not can_act():
		return false
	var kind := String(skill["kind"])
	var dkind := String(stats.get("kind", "physical"))
	if kind == "self_heal":
		if hp >= max_hp:
			return false
		heal(roundi(float(max_hp) * float(skill["heal"])))
		_fire_fx(position, 0.0)
		CombatVFX.spawn_strip16(get_parent(), position + Vector2(0, -14), "spritepilot-magic-pack", "healing-aura-16px_strip8.png", 3.0)
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
	var amount := float(power()) * float(skill["mult"])
	if kind == "target":
		tgt.take_hit(DamageInfo.make(amount, dkind, self, crit_chance, combat_rng))
		_fire_fx(tgt.position, 0.0)
		CombatVFX.spawn_strip16(get_parent(), tgt.position + Vector2(0, -12), "spritepilot-combat-pack", "critical-hit-16px_strip8.png", 3.0)
	else:
		var centre: Vector2 = position if kind == "self_aoe" else tgt.position
		var radius := float(skill["radius"])
		for e in enemies:
			if e.alive and e.position.distance_to(centre) <= radius:
				e.take_hit(DamageInfo.make(amount, dkind, self, crit_chance, combat_rng))
		_fire_fx(centre, radius)
		if kind == "self_aoe":
			CombatVFX.spawn_strip16(get_parent(), centre, "spritepilot-combat-pack", "shockwave-16px_strip8.png", 5.0)
		else:
			CombatVFX.spawn_strip16(get_parent(), centre + Vector2(0, -12), "spritepilot-magic-pack", "fireball-16px_strip8.png", 4.0)
	_face(tgt.position - position)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)
	skill_cd = float(skill["cooldown"])
	return true


func _fire_fx(at: Vector2, radius: float) -> void:
	_fx = 0.35
	_fx_to = at - position
	_fx_radius = radius
	queue_redraw()


# --- Combatant hooks ------------------------------------------------------------------------

func _on_hit(info: DamageInfo, _dmg: int) -> void:
	_flash = 0.15
	if order == "rescue" and rescue_progress > 0.0:
		rescue_progress = 0.0                         # D-036: taking damage interrupts the rescue
		FloatingText.spawn(self, "interrupted", Color(1.0, 0.6, 0.4), false)
	if hp > 0 and info.source != null and is_instance_valid(info.source):
		HeroAnim.play_hit(_sprite, (position - info.source.position).normalized())


func _on_down() -> void:
	path.clear()
	order = "auto"
	target = null
	rescue_target = null
	if _sprite != null:
		_sprite.stop()
		_sprite.play("down_" + _side)
	_anim_lock = 99999.0


func _on_revive() -> void:
	_anim_lock = 0.0
	_play("idle_" + facing)


func _on_die() -> void:
	path.clear()
	HeroAnim.spawn_death(self, _sprite, facing, _side)
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
	if hero == null or dead:
		return
	if downed:
		var k := clampf(agony / CombatRules.AGONY_TIME, 0.0, 1.0)
		draw_arc(Vector2(0, -12), 18.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.35, 0.3), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -36), "DOWN %ds" % ceili(agony), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1.0, 0.5, 0.45))
		return
	if rescue_progress > 0.0:
		draw_rect(Rect2(-15, -52, 30.0 * rescue_progress / CombatRules.RESCUE_TIME, 3), Color(0.5, 1.0, 0.6))
	var sx := -15.0
	for id in statuses:
		draw_rect(Rect2(sx, -41, 4, 4), CombatRules.STATUS[id]["color"])
		sx += 6.0
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
		var lines := _wrap_words(chatter_text, 28)
		var widest := 0.0
		for ln in lines:
			widest = maxf(widest, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		var box := Rect2(-widest * 0.5 - 6, -62 - 14 * lines.size(), widest + 12, 14 * lines.size() + 6)
		draw_rect(box, Color(0.98, 0.97, 0.92, 0.95))
		draw_rect(box, Color(0.2, 0.18, 0.15), false, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -56), Vector2(4, -56), Vector2(0, -51)]), Color(0.98, 0.97, 0.92))
		for k in lines.size():
			draw_string(font, Vector2(-widest * 0.5, box.position.y + 13 + k * 14), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.12, 0.1))


static func _wrap_words(text: String, width: int) -> Array:
	var out: Array = []
	var cur := ""
	for w in text.split(" "):
		if cur.length() + w.length() + 1 > width and cur != "":
			out.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	if cur != "":
		out.append(cur)
	return out
