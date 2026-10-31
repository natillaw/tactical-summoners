class_name SandboxHero
extends Combatant
## One deployed hero in a mission: animated sprite, movement, autonomous basic attacks, skills (SkillDefs) and
## direct orders. Health, damage, statuses, downed/agony and death live in Combatant (D-035..D-037).
## Orders are always obeyed (D-016: no random refusal); the order state decides what autonomy may do.

const ARRIVE_EPS := 1.0
const REPATH_EVERY := 0.4
# Movement feel (game feel report): full speed in ACCEL_TIME (no perceptible input lag), a short ease-in
# over the last ARRIVE_EASE pixels, idle only after IDLE_GRACE without a path (no idle/walk flicker
# between repaths), and a facing that changes axis only when the new axis clearly dominates.
const ACCEL_TIME := 0.07
const ARRIVE_EASE := 10.0
const IDLE_GRACE := 0.12
const FACING_HYSTERESIS := 1.3
const WALK_ANIM_SPEED := 85.0       # move speed at which the walk cycle plays at its authored rate
const ATTACK_LEAD := 0.12           # the attack pose starts this early so the blow lands on the damage

var hero: HeroData
var slot: int = 0                 # 0-4 -> key 1-5
var selected: bool = false : set = _set_selected
var path: Array[Vector2] = []
var facing: String = "down"
var speed: float = 90.0
var stats: Dictionary = {}        # derived combat stats (CombatRules.derive)
var _sprite: AnimatedSprite2D
var _anim_lock: float = 0.0          # T-023: blocks idle/walk from overriding an attack/cast pose
var velocity: Vector2 = Vector2.ZERO # last step's real velocity (camera look-ahead, debug overlay)
var _cur_speed: float = 0.0
var _idle_t: float = 0.0
var _prerolled: bool = false         # attack pose already started for the coming blow
## Authority (D-053): "ai" = autonomy decides; "player" = the player drives this hero directly, so
## autonomy never moves it on its own (no dodging, kiting or chasing beyond reach).
var controller: String = "ai"
## What this hero did this expedition (ExpeditionResults / MVP): damage, kills, healing, shield,
## rescues, explored, objective, gathered, tanked.
var contrib: Dictionary = {}
var anchor: SandboxHero = null       # hero the player drives: autonomous ones stay around it (set by the screen)
var rally_point: Vector2 = Vector2.INF   # squad centre (set by the screen): where a hurt hero falls back to
var explore_goal: Vector2 = Vector2.INF  # fog frontier picked by the screen for an idle explorer
var _fallback_cd: float = 0.0
const ANCHOR_LEASH := 150.0
var _dodge_seen: Dictionary = {}     # enemy instance id -> strike number already rolled for (D-052)
var _kite_cd: float = 0.0
var _pending: Array = []             # [{"t": seconds, "f": Callable}]: hits in flight (D-054)
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
# Active skills (Phase 3): class resource (D-041), W/E/R slots (D-059), casting (D-042).
const CAST_BREAK_CD := 2.0          # cooldown left after a cast is broken by control
const SHIELD_TIME := 10.0
const REGEN_PER_MAG := 0.4          # Sanctuary heals this much per second per point of magic power
var res_kind: String = "stamina"
var res: float = 0.0
var res_max: float = 100.0
var slots: Array = []               # skill ids, keys W E R (D-059; Q = basic attack)
var cds: Dictionary = {}            # skill id -> seconds until ready
var casting: String = ""            # skill being cast ("" = none)
var cast_left: float = 0.0
var cast_target: Combatant = null
var cast_point: Vector2 = Vector2.ZERO
var last_refusal: String = ""       # why the last skill request was refused (shown to the player)
var _cast_enemies: Array = []
var _cast_allies: Array = []
var _map: NavMap = null
var _firing: String = ""            # id of the skill being resolved (for its look)
var _cast_fx: Node2D = null         # cast circle under the hero while casting
var _aim: Vector2 = Vector2.INF     # where the player aimed the skill being started (INF = autonomy picks)
# Equipment powers (ItemDefs.apply_equipment "mods") and carried consumables (HeroData.bag).
var item_mods: Dictionary = {}
var was_downed: bool = false        # for the expedition's after-effects (Game.after_expedition)
var was_poisoned: bool = false
var _potion_cd: float = 0.0
const POTION_AT := 0.35             # drinks a potion below this HP fraction (bounded autonomy)
const POTION_HEAL := 0.4
const POTION_CD := 8.0
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
	item_mods = stats.get("mods", {})
	_setup_skills()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteComposer.build_frames(hero)
	_sprite.offset = Vector2(0, -16)            # feet at the node origin
	_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # pose tweens run in idle
	add_child(_sprite)
	_play("idle_down")


## Sight radius in cells for the fog of war (CombatRules.VISION_CELLS; scouts see further).
func vision_cells() -> int:
	if downed:
		return CombatRules.DOWNED_VISION
	var v := CombatRules.VISION_CELLS + int(item_mods.get("vision", 0))
	if hero != null and CombatRules.SCOUT_CLASSES.has(hero.hero_class):
		v += CombatRules.SCOUT_VISION_BONUS
	return v


func credit(kind: String, amount: float) -> void:
	if amount > 0.0:
		contrib[kind] = float(contrib.get(kind, 0.0)) + amount


func is_controlled() -> bool:
	return controller == "player"


## D-051: deterministic, never a roll.
func obeys() -> bool:
	return hero == null or hero.obedience >= CombatRules.OBEY_MIN


## Something that lands later (a projectile in flight); runs on the simulation clock, so it is
## deterministic and pauses with the mission.
func _later(seconds: float, f: Callable) -> void:
	if seconds <= 0.02:
		f.call()
		return
	_pending.append({"t": seconds, "f": f})


func _tick_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var due: Array = []
	for p in _pending:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			due.append(p)
	for p in due:
		_pending.erase(p)
		(p["f"] as Callable).call()


func is_moving() -> bool:
	return not path.is_empty()


func power() -> int:
	return int(stats["mag"]) if String(stats.get("kind", "physical")) == "magical" else int(stats["atk"])


# --- orders (never randomly refused, D-016) -----------------------------------------------------

func order_move(waypoints: Array[Vector2]) -> void:
	if casting != "":
		interrupt_cast("cast cancelled")
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
	_tick_pending(delta)
	if not alive:
		if downed:
			queue_redraw()
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	for sid in cds:
		cds[sid] = maxf(0.0, float(cds[sid]) - delta)
	_tick_resource(delta)
	_use_consumables(delta)
	_repath = maxf(0.0, _repath - delta)
	_dodge_t = maxf(0.0, _dodge_t - delta)
	_kite_cd = maxf(0.0, _kite_cd - delta)
	_fallback_cd = maxf(0.0, _fallback_cd - delta)
	if chatter_timer > 0.0:
		chatter_timer = maxf(0.0, chatter_timer - delta)
	if _fx > 0.0:
		_fx = maxf(0.0, _fx - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if casting != "":
		_tick_cast(delta)
		return
	_walk(delta)


## Follows the path. The leftover of a step carries on to the next waypoint (no speed dip at every
## corner); speed ramps up in ACCEL_TIME and eases in on the last few pixels.
func _walk(delta: float) -> void:
	var before := position
	if path.is_empty() or not can_move():
		_cur_speed = 0.0
		velocity = Vector2.ZERO
		_idle_t += delta
		if _idle_t >= IDLE_GRACE or not can_move():
			_set_walk_rate(1.0)
			_play("idle_" + facing)
		return
	_idle_t = 0.0
	var top := speed * move_mult()
	_cur_speed = move_toward(_cur_speed, top, top / ACCEL_TIME * delta)
	var budget := _cur_speed * delta
	while budget > 0.0 and not path.is_empty():
		var next_wp: Vector2 = path[0]
		var to := next_wp - position
		var dist := to.length()
		if path.size() == 1 and dist < ARRIVE_EASE:
			budget = minf(budget, maxf(top * 0.35 * delta, dist * 0.5))
		if dist <= budget + ARRIVE_EPS:
			position = next_wp
			path.remove_at(0)
			budget -= dist
		else:
			var dir := to / dist
			position += dir * budget
			_face(dir)
			budget = 0.0
	velocity = (position - before) / maxf(0.0001, delta)
	_set_walk_rate(velocity.length() / WALK_ANIM_SPEED)
	_play("walk_" + facing)


func _set_walk_rate(k: float) -> void:
	if _sprite != null and _anim_lock <= 0.0:
		_sprite.speed_scale = clampf(k, 0.6, 1.4)


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
	_map = map
	if not alive or casting != "":
		return
	if _dodge_t > 0.0 and not path.is_empty():
		return                                   # finishing a dodge step
	if order != "move" and order != "retreat" and order != "rescue" and can_move() and not is_controlled():
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
	if _maybe_fall_back(map):
		return
	if is_controlled():
		target = null                            # D-059: the player attacks with Q, aimed at the cursor
		return
	if target != null and (not is_instance_valid(target) or not target.alive):
		target = null
		if order == "attack":
			order = "auto"
			FloatingText.spawn(self, "target down", Color(0.8, 0.8, 0.8), false)
	if target == null:
		var radius := attack_range() if order == "hold" or (is_controlled() and order == "auto") else chase_radius()
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
					_stay_near_anchor(map)
			return
	var d := position.distance_to(target.position)
	var sees := not is_ranged() or map.has_line_of_sight(position + Vector2(0, -12), target.position + Vector2(0, -12))
	if d <= attack_range() and sees:
		if is_ranged() and d < KITE_DISTANCE and order != "hold" and not is_controlled() and _kite(target, map):
			return
		path.clear()
		auto_path = false
		_face(target.position - position)
		if _cooldown <= 0.0:
			_cooldown = attack_interval()
			_basic_attack(target)
		elif _cooldown <= ATTACK_LEAD and not _prerolled:
			_prerolled = true                    # anticipation: the swing starts, the blow lands on time
			_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged(), true)
		return
	if order == "hold" or (is_controlled() and order == "auto"):
		target = null                            # out of reach: holding (or a player-driven hero) does not chase
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


## D-059: the driven hero's basic attack, aimed at a world point (Q). Same weapon, reach, interval,
## damage and projectile as the autonomous attack; only the aim is the player's.
## Ranged: the shot flies toward the cursor up to its reach and hits the FIRST visible foe on its line
## (trees stop it). Melee: a swing in a cone toward the cursor hits the closest foe in reach; it can miss.
## Returns false only when the attack is not ready (interval, stun, casting, down).
const AIM_CONE := 0.9             # radians either side of the aim for a melee swing
const SHOT_WIDTH := 10.0          # half-width of a shot's lane, added to the foe's body


func aimed_attack(point: Vector2, enemies: Array, map: NavMap) -> bool:
	if not alive or not can_act() or casting != "" or _cooldown > 0.0:
		return false
	var dir := point - position
	if dir.length() < 1.0:
		dir = HeroAnim.dir_vec(facing)
	dir = dir.normalized()
	_face(dir)
	_cooldown = attack_interval()
	_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged())
	var reach := attack_range()
	var from := position + Vector2(0, -16)
	var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
	var hit: SandboxEnemy = null
	if is_ranged():
		var end := position + dir * reach
		if map != null:                          # the shot stops at the first tree / wall
			var steps := ceili(reach / 12.0)
			for k in range(1, steps + 1):
				var p := position + dir * minf(reach, 12.0 * float(k))
				if map.is_blocked(p):
					end = position + dir * maxf(0.0, 12.0 * float(k - 1))
					break
		var best_t := INF
		for e in enemies:
			if not e.alive or not e.visible:
				continue
			var t: float = (e.position - position).dot(dir)
			if t < 0.0 or t > position.distance_to(end) + e.body_radius:
				continue
			var off: float = (position + dir * t).distance_to(e.position)
			if off <= e.body_radius + SHOT_WIDTH and t < best_t:
				best_t = t
				hit = e
		var to := (hit.position + Vector2(0, -12)) if hit != null else end + Vector2(0, -16)
		CombatVFX.projectile(get_parent(), from, to, String(wf.get("proj", "arrow")), String(wf["hit"]) if hit != null else "", CombatRules.PROJECTILE_SPEED, 1.0, float(wf.get("scale", 1.0)))
		if hit != null:
			var info := DamageInfo.make(float(power()) * _busy_mult(hit), String(stats.get("kind", "physical")), self, crit_chance, combat_rng)
			var aim_at := to
			var target_e := hit
			_later(from.distance_to(to) / CombatRules.PROJECTILE_SPEED, func(): _land_basic(target_e, info, aim_at))
		return true
	var best_d := INF
	for e in enemies:
		if not e.alive or not e.visible:
			continue
		var v: Vector2 = e.position - position
		if v.length() > reach + e.body_radius:
			continue
		if v.length() > 1.0 and absf(dir.angle_to(v)) > AIM_CONE:
			continue
		if v.length() < best_d:
			best_d = v.length()
			hit = e
	var swing_at := (hit.position + Vector2(0, -12)) if hit != null else position + dir * reach * 0.6 + Vector2(0, -12)
	CombatVFX.play(get_parent(), swing_at, String(wf["hit"]), float(wf.get("scale", 1.0)), dir.x < 0.0)
	if hit != null:
		if wf.has("extra"):
			CombatVFX.play(get_parent(), hit.position, String(wf["extra"]), 0.8)
		_land_basic(hit, DamageInfo.make(float(power()) * _busy_mult(hit), String(stats.get("kind", "physical")), self, crit_chance, combat_rng), swing_at)
	return true


func attack_ready() -> bool:
	return alive and can_act() and casting == "" and _cooldown <= 0.0


## Autonomous reaction to a telegraphed strike (D-052): one roll per strike against a small chance
## from AGI and level (zero at level 1). On a failed roll the hero keeps doing what it was doing and
## takes the blow. Never overrides an explicit move/retreat/rescue order, never for a player-driven hero.
func _try_dodge(enemies: Array, map: NavMap) -> bool:
	for e in enemies:
		if not e.alive or not e.is_telegraphing() or e.windup_left() < CombatRules.DODGE_REACTION:
			continue
		var aim: Vector2 = e.aim_point()
		var r: float = e.strike_radius
		if position.distance_to(aim) > r + 4.0:
			continue
		var key: int = e.get_instance_id()
		if int(_dodge_seen.get(key, -1)) == int(e.strike_seq):
			continue                             # already decided for this strike
		_dodge_seen[key] = e.strike_seq
		var lvl := hero.level if hero != null else 1
		if combat_rng.randf() >= CombatRules.auto_dodge_chance(int(stats.get("spd", 5)), lvl):
			continue                             # did not react in time
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


## Hurt and in a fight, an autonomous hero breaks off toward the driven hero or the squad centre
## (cautious ones sooner, reckless ones later). Never overrides an order, never for a driven hero.
func _maybe_fall_back(map: NavMap) -> bool:
	if is_controlled() or order != "auto" or target == null or _fallback_cd > 0.0:
		return false
	if float(hp) > float(max_hp) * fallback_hp():
		return false
	var to := anchor.position if anchor != null and is_instance_valid(anchor) and anchor.alive else rally_point
	if to == Vector2.INF or to.distance_to(position) < 60.0:
		return false
	_fallback_cd = 4.0
	var p := map.find_path(position, to)
	if p.is_empty():
		return false
	path = p
	auto_path = true
	target = null
	_dodge_t = 0.8                                  # commit to the step back for a moment
	FloatingText.spawn(self, "falling back", Color(0.85, 0.85, 1.0), false)
	return true


## With nothing to fight, an autonomous hero does not stand still while the player walks another
## hero away: it moves back within ANCHOR_LEASH of it (cautious heroes keep closer, see leash()).
func _stay_near_anchor(map: NavMap) -> void:
	if is_controlled() or order != "auto":
		return
	if explore_goal != Vector2.INF and path.is_empty() and float(hp) > float(max_hp) * 0.6:
		var p := map.find_path(position, explore_goal)   # an idle explorer peeks into the fog nearby
		explore_goal = Vector2.INF
		if not p.is_empty():
			path = p
			auto_path = true
			return
	if anchor == null or not is_instance_valid(anchor) or not anchor.alive:
		return
	if position.distance_to(anchor.position) > leash() and (path.is_empty() or _repath <= 0.0):
		_repath = REPATH_EVERY * 2.0
		var side := Vector2.RIGHT.rotated(float(slot) * 1.3) * 40.0
		var p := map.find_path(position, anchor.position + side)
		if not p.is_empty():
			path = p
			auto_path = true


## Temperament from traits (HeroTables.AGGRESSION), -3 (very cautious) .. 3 (reckless).
func aggression() -> int:
	if hero == null:
		return 0
	var a := 0
	for t in hero.traits:
		a += int(HeroTables.AGGRESSION.get(t, 0))
	return clampi(a, -3, 3)


func is_explorer() -> bool:
	if hero == null:
		return false
	if CombatRules.SCOUT_CLASSES.has(hero.hero_class):
		return true
	for t in hero.traits:
		if HeroTables.EXPLORER_TRAITS.has(t):
			return true
	return false


## How far from the driven hero this hero is willing to be (cautious closer, reckless further).
func leash() -> float:
	return clampf(HeroTables.LEASH_BASE + HeroTables.LEASH_PER_AGGRESSION * float(aggression()), 90.0, 330.0)


## How far an autonomous hero goes looking for a fight.
func chase_radius() -> float:
	return CombatRules.HERO_PERCEPTION + HeroTables.CHASE_PER_AGGRESSION * float(aggression())


func fallback_hp() -> float:
	return clampf(HeroTables.FALLBACK_HP - HeroTables.FALLBACK_PER_AGGRESSION * float(aggression()), 0.1, 0.6)


## Ranged heroes back off when a foe gets too close (keep their role distance). Not while that foe
## is already winding up a blow (stepping away then would be a free dodge, D-052), and not too often.
func _kite(foe: SandboxEnemy, map: NavMap) -> bool:
	if foe.is_telegraphing() or _kite_cd > 0.0:
		return false
	var spot := position + (position - foe.position).normalized() * 80.0
	if map.is_blocked(spot) or not map.has_line_of_sight(position, spot):
		return false
	_kite_cd = CombatRules.KITE_COOLDOWN
	path.clear()
	path.append(spot)
	auto_path = true
	_dodge_t = 0.4
	return true


## Carried potions and antidotes are used on their own (bounded autonomy, never instead of an order).
func _use_consumables(delta: float) -> void:
	if has_status("poison"):
		was_poisoned = true
	if hero == null:
		return
	_potion_cd = maxf(0.0, _potion_cd - delta)
	if _potion_cd > 0.0:
		return
	if float(hp) < float(max_hp) * POTION_AT and int(hero.bag.get("potion", 0)) > 0:
		_spend("potion")
		heal(roundi(float(max_hp) * POTION_HEAL))
		CombatVFX.play(get_parent(), position + Vector2(0, -14), "heal", 1.0)
		FloatingText.spawn(self, "potion", Color(0.5, 1.0, 0.6), false)
	elif has_status("poison") and int(hero.bag.get("antidote", 0)) > 0:
		_spend("antidote")
		statuses.erase("poison")
		CombatVFX.play(get_parent(), position + Vector2(0, -18), "sparkle_small", 1.0)
		FloatingText.spawn(self, "antidote", Color(0.6, 1.0, 0.5), false)


func _spend(res: String) -> void:
	hero.bag[res] = int(hero.bag[res]) - 1
	if int(hero.bag[res]) <= 0:
		hero.bag.erase(res)
	_potion_cd = POTION_CD


func move_mult() -> float:
	var m := super.move_mult()
	if item_mods.has("slow_immune") and has_status("slow"):
		m /= float(CombatRules.STATUS["slow"]["move"])
	return m


## Damage bonus from equipment against a foe busy fighting someone else (Nightstalker set).
func _busy_mult(t: Node) -> float:
	if item_mods.has("busy_bonus") and t.get("focus") != null and t.get("focus") != self:
		return 1.0 + float(item_mods["busy_bonus"])
	return 1.0


## Weapon the hero swings: the equipped main-hand base, else the class's default (look only).
func weapon_id() -> String:
	if hero != null and hero.equipment.has("main_hand"):
		return String(hero.equipment["main_hand"].get("base", "fist"))
	return String(CombatVFX.CLASS_WEAPON.get(hero.hero_class if hero != null else "", "fist"))


func _basic_attack(t: SandboxEnemy) -> void:
	if not _prerolled:
		_anim_lock = HeroAnim.play_attack(_sprite, facing, _side, is_ranged())
	_prerolled = false
	var wf: Dictionary = CombatVFX.WEAPON_FX.get(weapon_id(), CombatVFX.WEAPON_FX["fist"])
	var aim := t.position + Vector2(0, -12)
	var sc := float(wf.get("scale", 1.0))
	var travel := 0.0
	if wf.has("proj"):
		var from := position + Vector2(0, -16)
		CombatVFX.projectile(get_parent(), from, aim, String(wf["proj"]), String(wf["hit"]), CombatRules.PROJECTILE_SPEED, 1.0, sc)
		travel = from.distance_to(aim) / CombatRules.PROJECTILE_SPEED
	else:
		CombatVFX.play(get_parent(), aim, String(wf["hit"]), sc, t.position.x < position.x)
		if wf.has("extra"):
			CombatVFX.play(get_parent(), t.position, String(wf["extra"]), 0.8)
	var info := DamageInfo.make(float(power()) * _busy_mult(t), String(stats.get("kind", "physical")), self, crit_chance, combat_rng)
	_later(travel, func(): _land_basic(t, info, aim))     # D-054: an arrow hurts when it arrives


func _land_basic(t: SandboxEnemy, info: DamageInfo, aim: Vector2) -> void:
	if not is_instance_valid(t) or not t.alive:
		return                                   # the target died while the shot was in flight
	var dealt := t.take_hit(info)
	if info.crit:
		CombatVFX.play(get_parent(), aim + Vector2(0, -8), "crit", 0.8)
		CombatFeel.freeze(_sprite, "crit")
		CombatFeel.freeze(t.get("_sprite"), "crit")
		CombatFeel.shake(self, "small", t.position - position)
	gain_resource(float(SkillDefs.RESOURCES[res_kind]["on_hit"]))
	_on_dealt(t, dealt)


## Equipment powers after a hit: lifesteal, on-hit statuses (uniques), heal on kill.
func _on_dealt(t: Combatant, dealt: int) -> void:
	if dealt > 0 and item_mods.has("lifesteal"):
		heal(roundi(float(dealt) * float(item_mods["lifesteal"])))
	for p in item_mods.get("procs", []):
		if t.alive and combat_rng.randf() < float(p["chance"]):
			t.apply_status(String(p["on_hit_status"]), float(p["dur"]), float(power()) * float(p["mult"]), self)
			CombatVFX.play(t.get_parent(), t.position + Vector2(0, -14), "spark_fire" if String(p["on_hit_status"]) == "burn" else "frost_burst", 0.6)
	if not t.alive and item_mods.has("kill_heal"):
		heal(roundi(float(max_hp) * float(item_mods["kill_heal"])))
		CombatVFX.play(get_parent(), position + Vector2(0, -14), "heal", 0.7)


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
			CombatVFX.play(get_parent(), rescue_target.position + Vector2(0, -16), "level_up", 1.0)
			credit("rescues", 1.0)
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


# --- active skills (combat Phase 3, D-040..D-043) -------------------------------------------------

func _setup_skills() -> void:
	res_kind = SkillDefs.resource_of(hero.hero_class)
	var rd: Dictionary = SkillDefs.RESOURCES[res_kind]
	res_max = float(rd["base"])
	if rd.has("per_attr"):
		res_max += float(hero.attributes().get(String(rd["per_attr"]), 0)) * float(rd["per"])
	res = res_max * float(rd["start"])
	slots.clear()
	for sid in hero.loadout:
		if SkillDefs.SKILLS.has(sid):
			slots.append(String(sid))


func _tick_resource(delta: float) -> void:
	var rd: Dictionary = SkillDefs.RESOURCES[res_kind]
	res += float(rd["regen"]) * delta
	if target == null:
		res -= float(rd["decay"]) * delta         # Fury cools down out of combat
	res = clampf(res, 0.0, res_max)


func gain_resource(amount: float) -> void:
	res = clampf(res + amount, 0.0, res_max)


func slot_skill(i: int) -> Dictionary:
	return SkillDefs.info(slots[i]) if i >= 0 and i < slots.size() else {}


func skill_cd(i: int) -> float:
	return float(cds.get(slots[i], 0.0)) if i >= 0 and i < slots.size() else 0.0


func skill_ready(i: int = 0) -> bool:
	var sk := slot_skill(i)
	return alive and not sk.is_empty() and skill_cd(i) <= 0.0 and res >= float(sk["cost"]) and casting == ""


func is_casting() -> bool:
	return casting != ""


## Direct skill activation (D-059: W E R = slots 0-2; D-040 had them on Q W E R). Returns true if it fired or started its
## cast. Refused only for a concrete reason, never by a random roll (D-016); the reason is kept in
## last_refusal for the UI. allies = every hero of the squad (self included).
func use_skill_slot(i: int, enemies: Array, allies: Array, aim: Vector2 = Vector2.INF) -> bool:
	last_refusal = ""
	_aim = aim
	var sk := slot_skill(i)
	if sk.is_empty():
		return _refuse("no skill learned")
	if not alive:
		return _refuse("down")
	if casting != "":
		return _refuse("already casting")
	if not can_act():
		return _refuse("stunned")
	if skill_cd(i) > 0.0:
		return _refuse("cooldown %.0fs" % ceilf(skill_cd(i)))
	if res < float(sk["cost"]):
		return _refuse("not enough %s" % String(SkillDefs.RESOURCES[res_kind]["name"]).to_lower())
	var tgt := _skill_target(sk, enemies, allies)
	if tgt == null:
		return _refuse(last_refusal if last_refusal != "" else "no target in range")
	res -= float(sk["cost"])
	cds[slots[i]] = float(sk["cd"])
	if tgt != self:
		_face(tgt.position - position)
	var point := tgt.position
	if String(sk["target"]) == "target_aoe" and _aim != Vector2.INF:
		point = position + (_aim - position).limit_length(float(sk["range"]))   # aimed area, within reach
		tgt = self
	if float(sk["cast"]) > 0.0:
		casting = slots[i]
		_start_cast_fx(casting)
		cast_left = float(sk["cast"])
		cast_target = tgt
		cast_point = point
		_cast_enemies = enemies
		_cast_allies = allies
		path.clear()
		_anim_lock = HeroAnim.play_cast(_sprite, _side)
		return true
	_firing = slots[i]
	_fire_skill(sk, tgt, point, enemies, allies)
	return true


func _refuse(reason: String) -> bool:
	last_refusal = reason
	return false


## Who the skill is aimed at. Self-centred skills return self; null = nothing valid in range.
func _skill_target(sk: Dictionary, enemies: Array, allies: Array) -> Combatant:
	var reach := float(sk["range"])
	match String(sk["target"]):
		"self":
			if _only_heals_self(sk) and hp >= max_hp:
				last_refusal = "already at full health"
				return null
			return self
		"self_aoe":
			for e in enemies:
				if e.alive and position.distance_to(e.position) <= reach:
					return self
			return null
		"ally_low":
			var best: Combatant = null
			var best_k := 1.0
			var needs_hurt := _effects_have(sk, ["heal"]) and not _effects_have(sk, ["cleanse", "shield"])
			for a in allies:
				if not is_instance_valid(a) or not a.alive or position.distance_to(a.position) > reach:
					continue
				var k := float(a.hp) / float(maxi(1, a.max_hp))
				if (k < best_k) or (best == null and not needs_hurt):
					best_k = k
					best = a
			if best == null and needs_hurt:
				last_refusal = "nobody is hurt"
			return best
		"target_aoe" when _aim != Vector2.INF:
			return self                          # aimed at the ground by the player: no foe needed there
		_:
			if _aim != Vector2.INF:              # aimed by the player: the foe in reach closest to the cursor
				var pick: Combatant = null
				var pick_d := INF
				for e in enemies:
					if e.alive and e.visible and position.distance_to(e.position) <= reach and e.position.distance_to(_aim) < pick_d:
						pick_d = e.position.distance_to(_aim)
						pick = e
				if pick == null:
					last_refusal = "out of range"
				return pick
			if target != null and is_instance_valid(target) and target.alive and position.distance_to(target.position) <= reach:
				return target                    # prefer the current target when in reach
			var best_e: Combatant = null
			var best_d := reach
			for e in enemies:
				if not e.alive or not e.visible:
					continue
				var d: float = position.distance_to(e.position)
				if d <= best_d:
					best_d = d
					best_e = e
			return best_e


func _only_heals_self(sk: Dictionary) -> bool:
	for e in sk["effects"]:
		if not (String(e["t"]) in ["heal", "heal_pct"]):
			return false
	return true


func _effects_have(sk: Dictionary, kinds: Array) -> bool:
	for e in sk["effects"]:
		if kinds.has(String(e["t"])):
			return true
	return false


## D-042: a cast is broken only by control (stun). The cost and cooldown are given back.
func interrupt_cast(reason: String = "interrupted") -> void:
	if casting == "":
		return
	var sk := SkillDefs.info(casting)
	res = minf(res_max, res + float(sk["cost"]))
	cds[casting] = minf(float(cds.get(casting, 0.0)), CAST_BREAK_CD)
	casting = ""
	cast_target = null
	_anim_lock = 0.0
	_clear_cast_fx()
	CombatVFX.play(get_parent(), position + Vector2(0, -20), "parry", 0.8)
	FloatingText.spawn(self, reason, Color(1.0, 0.6, 0.4), false)


func _tick_cast(delta: float) -> void:
	if not can_act():
		interrupt_cast()
		return
	cast_left -= delta
	if cast_left > 0.0:
		return
	var sk := SkillDefs.info(casting)
	var tgt := cast_target
	_firing = casting
	casting = ""
	cast_target = null
	_clear_cast_fx()
	if tgt == null or not is_instance_valid(tgt) or not tgt.alive:
		if String(sk["target"]) != "target_aoe":
			FloatingText.spawn(self, "target lost", Color(0.8, 0.8, 0.8), false)
			return
		tgt = self                                # area skills still land where they were aimed
	_fire_skill(sk, tgt, cast_point, _cast_enemies, _cast_allies)


## Fires a skill: the look plays now; the effects land when its projectile arrives (D-054) or at once.
func _fire_skill(sk: Dictionary, tgt: Combatant, point: Vector2, enemies: Array, allies: Array) -> void:
	var id := _firing
	var centre := position
	match String(sk["target"]):
		"enemy":
			centre = tgt.position
		"target_aoe":
			centre = point if tgt == self else tgt.position
	var travel := _skill_travel(id, centre)
	_skill_vfx(id, String(sk["target"]), centre, float(sk.get("radius", sk["range"])), sk)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)
	_later(travel, func(): _resolve_skill(sk, tgt, point, enemies, allies))


## Seconds the skill's projectile flies before it lands (0 = no projectile).
func _skill_travel(id: String, centre: Vector2) -> float:
	var fx: Dictionary = CombatVFX.SKILL_FX.get(id, {})
	if not fx.has("proj"):
		return 0.0
	var aim := centre + Vector2(0, -12)
	if fx.get("rain", false):
		return 0.45
	if fx.get("sky", false):
		return (centre + Vector2(-160, -420)).distance_to(aim) / 520.0
	return (position + Vector2(0, -16)).distance_to(aim) / float(fx.get("speed", 650.0))


func _resolve_skill(sk: Dictionary, tgt: Combatant, point: Vector2, enemies: Array, allies: Array) -> void:
	if not alive and not downed:
		return
	if tgt != self and (not is_instance_valid(tgt) or not tgt.alive):
		if String(sk["target"]) != "target_aoe":
			return                               # single target died in flight: the shot is wasted
		tgt = self
	var tmode := String(sk["target"])
	var foes: Array = []
	var friends: Array = []
	var centre := position
	match tmode:
		"enemy":
			foes.append(tgt)
			centre = tgt.position
		"self_aoe":
			for e in enemies:
				if e.alive and position.distance_to(e.position) <= float(sk["range"]):
					foes.append(e)
		"target_aoe":
			centre = point if tgt == self else tgt.position
			for e in enemies:
				if e.alive and centre.distance_to(e.position) <= float(sk.get("radius", 80.0)):
					foes.append(e)
		_:
			friends.append(tgt)
	for eff in sk["effects"]:
		_apply_effect(eff, foes, friends, centre, enemies, allies)
	_skill_vfx(_firing, tmode, centre, float(sk.get("radius", sk["range"])), sk)
	_anim_lock = HeroAnim.play_cast(_sprite, _side)


func _apply_effect(eff: Dictionary, foes: Array, friends: Array, centre: Vector2, enemies: Array, allies: Array) -> void:
	match String(eff["t"]):
		"damage":
			var kind := String(eff["kind"])
			if kind == "power":
				kind = String(stats.get("kind", "physical"))
			var base := float(stats["mag"]) if kind == "magical" else float(stats["atk"])
			for f in foes:
				var amount := base * float(eff["mult"]) * _busy_mult(f)
				if eff.has("bonus_if_busy") and f.get("focus") != null and f.get("focus") != self:
					amount *= float(eff["bonus_if_busy"])
				_on_dealt(f, f.take_hit(DamageInfo.make(amount, kind, self, crit_chance, combat_rng)))
		"status":
			var mag := float(eff.get("mag", 0.0))
			if eff.has("mult"):
				mag = float(power()) * float(eff["mult"])
			for u in (foes if not foes.is_empty() else friends):
				u.apply_status(String(eff["id"]), float(eff["dur"]), mag, self)
		"heal":
			for u in friends:
				credit("healing", float(u.heal(roundi(float(stats["mag"]) * float(eff["mult"])))))
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -14), "heal", 0.9)
		"heal_pct":
			for u in friends:
				credit("healing", float(u.heal(roundi(float(u.max_hp) * float(eff["pct"])))))
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -14), "heal", 0.9)
		"shield":
			for u in friends:
				var sm := float(item_mods.get("shield_mult", 1.0))      # Warden set: shields given...
				if u != self and u.get("item_mods") != null:
					sm *= float((u.get("item_mods") as Dictionary).get("shield_mult", 1.0))   # ...and received
				u.apply_status("shield", SHIELD_TIME, float(u.max_hp) * float(eff["pct"]) * sm, self)
				credit("shield", float(u.max_hp) * float(eff["pct"]) * sm)
		"cleanse":
			for u in friends:
				u.cleanse()
				CombatVFX.play(u.get_parent(), u.position + Vector2(0, -18), "sparkle_small", 1.0)
		"interrupt":
			for f in foes:
				if f.has_method("interrupt") and f.interrupt():
					CombatVFX.play(f.get_parent(), f.position + Vector2(0, -20), "parry", 1.0)
		"knockback":
			for f in foes:
				CombatVFX.play(f.get_parent(), f.position, "dust_puff", 1.0)
				_push(f, (f.position - position).normalized(), float(eff["dist"]))
				if f.has_method("interrupt"):
					f.interrupt()
		"dash":
			if not foes.is_empty() and _map != null:
				var f: Node2D = foes[0]
				var spot := f.position + (position - f.position).normalized() * 28.0
				if not _map.is_blocked(spot):
					CombatVFX.play(get_parent(), position, "dust", 0.9, spot.x < position.x)
					var was := position
					position = spot
					path.clear()
					CombatFeel.slide(_sprite, was - position)
					CombatVFX.play(get_parent(), position, "dust_puff", 1.0)
		"blink":
			if _map != null:
				var away := Vector2.DOWN
				var near := _nearest(enemies, 9999.0)
				if near != null and near.position.distance_to(position) > 1.0:
					away = (position - near.position).normalized()
				var spot := _map.nearest_walkable(position + away * float(eff["dist"]))
				CombatVFX.play(get_parent(), position + Vector2(0, -16), "teleport", 1.0)
				position = spot
				path.clear()
				CombatVFX.play(get_parent(), position + Vector2(0, -16), "teleport", 1.0)
		"taunt":
			for e in enemies:
				if e.alive and e.position.distance_to(position) <= float(eff["radius"]) and e.has_method("taunt"):
					e.taunt(self, float(eff["dur"]))
		"zone":
			var mag := 0.0
			if String(eff["status"]) == "regen":
				mag = float(stats["mag"]) * REGEN_PER_MAG
			var units: Array = enemies if bool(eff["foes"]) else allies
			CombatZone.spawn(get_parent(), centre, float(eff["radius"]), float(eff["dur"]),
				String(eff["status"]), float(eff["sdur"]), mag, units, self, bool(eff.get("once", false)))
		"allies":
			var near_allies: Array = []
			for a in allies:
				if is_instance_valid(a) and a.alive and a.position.distance_to(position) <= float(eff["radius"]):
					near_allies.append(a)
			for inner in eff["inner"]:
				_apply_effect(inner, [], near_allies, position, enemies, allies)


## Moves a unit along dir up to dist / its mass, stopping before walls. The heavier the unit, the
## shorter the push (a huge creature barely staggers); the sprite then slides over the gap.
func _push(u: Node2D, dir: Vector2, dist: float) -> void:
	if _map == null:
		return
	var mass := float(u.get("mass")) if u.get("mass") != null else 1.0
	dist /= maxf(0.25, mass)
	var start := u.position
	var step := 8.0
	var moved := 0.0
	while moved < dist:
		var np := u.position + dir * minf(step, dist - moved)
		if _map.is_blocked(np):
			break
		u.position = np
		moved += step
	CombatFeel.slide(u.get("_sprite"), start - u.position)
	if mass >= 3.0:
		FloatingText.spawn(u, "stagger", Color(0.85, 0.85, 0.9), false)


## The skill's look (CombatVFX.SKILL_FX): projectiles fly to the target and the impacts play when
## they land; area effects are scaled to the skill's radius. Logic was already resolved.
func _skill_vfx(id: String, tmode: String, centre: Vector2, radius: float, sk: Dictionary) -> void:
	var fx: Dictionary = CombatVFX.SKILL_FX.get(id, {})
	var parent := get_parent()
	var from := position + Vector2(0, -16)
	var aim := centre + Vector2(0, -12)
	var delay := 0.0
	for k in fx.get("self", []):
		CombatVFX.play(parent, position + Vector2(0, -14), String(k), 1.0)
	if fx.has("proj"):
		var key := String(fx["proj"])
		var speed := float(fx.get("speed", 650.0))
		var ps := float(fx.get("proj_scale", 1.0))
		var n := int(fx.get("n", 1))
		if fx.get("rain", false):
			for j in n:
				var spot := centre + Vector2(combat_rng.randf_range(-1.0, 1.0), combat_rng.randf_range(-0.6, 0.6)) * radius * 0.8
				CombatVFX.projectile(parent, spot + Vector2(-60, -240 - 30 * j), spot, key, "spark_small", 700.0, ps, 0.8)
			delay = 0.45
		elif fx.get("sky", false):
			var start := centre + Vector2(-160, -420)
			CombatVFX.projectile(parent, start, aim, key, "", 520.0, ps)
			delay = start.distance_to(aim) / 520.0
		else:
			var side := (aim - from).normalized().orthogonal()
			for j in n:
				CombatVFX.projectile(parent, from + side * (float(j) - float(n - 1) * 0.5) * 8.0, aim, key, "", speed, ps)
			delay = from.distance_to(aim) / speed
	var flip := centre.x < position.x
	for k in fx.get("hit", []):
		_fx_later(String(k), aim, 1.0, delay, flip)
	var areas: Array = fx.get("area", [])
	for i in areas.size():
		if i == 0:                                     # the main effect covers the whole area (ring of copies)
			CombatVFX.area_burst(parent, centre + Vector2(0, -6), radius, String(areas[i]), delay)
		else:
			_fx_later(String(areas[i]), centre + Vector2(0, -6), CombatVFX.area_scale(String(areas[i]), radius), delay, false)
	if tmode == "self_aoe" or tmode == "target_aoe":
		_area_flash_later(centre, radius, delay)
		var weight := _skill_weight(sk, radius)
		if weight != "":
			_feel_later(weight, delay, centre)
	elif tmode == "enemy":
		_fire_fx(centre, 0.0)


## How hard an area skill lands on screen: big or slow-cast areas shake more (never a light skill).
func _skill_weight(sk: Dictionary, radius: float) -> String:
	if radius >= 110.0 and float(sk["cast"]) >= 1.0:
		return "medium"
	if radius >= 90.0 or float(sk["cast"]) >= 0.8:
		return "small"
	return ""


## The real radius of the area, drawn on the ground when it lands (the art is decoration around it).
func _area_flash_later(centre: Vector2, radius: float, delay: float) -> void:
	var parent := get_parent()
	var col := Color(1.0, 0.7, 0.25)
	if delay <= 0.02 or not is_inside_tree():
		CombatFeel.area_flash(parent, centre, radius, col)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(parent):
			CombatFeel.area_flash(parent, centre, radius, col)
	)


func _feel_later(kind: String, delay: float, at: Vector2) -> void:
	if not is_inside_tree():
		return
	if delay <= 0.02:
		CombatFeel.shake(self, kind, at - position)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self):
			CombatFeel.shake(self, kind, at - position)
	)


func _fx_later(key: String, pos: Vector2, sc: float, delay: float, flip: bool) -> void:
	var parent := get_parent()
	if delay <= 0.02 or not is_inside_tree():
		CombatVFX.play(parent, pos, key, sc, flip)
		return
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(parent):
			CombatVFX.play(parent, pos, key, sc, flip)
	)


func _start_cast_fx(id: String) -> void:
	_clear_cast_fx()
	_cast_fx = CombatVFX.attach(self, String(CombatVFX.SKILL_FX.get(id, {}).get("cast", "circle_arcane")), Vector2(0, -2), 1.0, true)


func _clear_cast_fx() -> void:
	if _cast_fx != null and is_instance_valid(_cast_fx):
		_cast_fx.queue_free()
	_cast_fx = null


func _fire_fx(at: Vector2, radius: float) -> void:
	_fx = 0.35
	_fx_to = at - position
	_fx_radius = radius
	queue_redraw()


# --- Combatant hooks ------------------------------------------------------------------------

func _on_hit(info: DamageInfo, dmg: int) -> void:
	_flash = 0.15
	if dmg > 0 and item_mods.has("thorns") and info.source is SandboxEnemy and info.kind == "physical" and is_instance_valid(info.source):
		(info.source as Combatant).take_hit(DamageInfo.make(float(dmg) * float(item_mods["thorns"]), "true", self))
	gain_resource(float(SkillDefs.RESOURCES[res_kind]["on_hurt"]))
	if order == "rescue" and rescue_progress > 0.0:
		rescue_progress = 0.0                         # D-036: taking damage interrupts the rescue
		FloatingText.spawn(self, "interrupted", Color(1.0, 0.6, 0.4), false)
	if hp > 0 and info.source != null and is_instance_valid(info.source):
		HeroAnim.play_hit(_sprite, (position - info.source.position).normalized())


func _on_down() -> void:
	was_downed = true
	CombatFeel.shake(self, "medium")
	casting = ""
	_clear_cast_fx()
	CombatVFX.play(get_parent(), position, "blood", 1.0)
	cast_target = null
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


## Permanent death (D-011) is not a remove_child: the camera jolts, the body stays a while and the
## hero's name is shown as it fades (HeroAnim.spawn_death). The memorial is written by the screen.
func _on_die() -> void:
	path.clear()
	CombatFeel.shake(self, "large")
	HeroAnim.spawn_death(self, _sprite, facing, _side, hero.display_name() if hero != null else "")
	visible = false


## 4-way facing. On diagonals the current axis is kept until the other one clearly dominates
## (FACING_HYSTERESIS), so a diagonal walk does not flip between side and front frames every step.
func _face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	var horizontal := facing == "left" or facing == "right"
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if horizontal:
		horizontal = ay <= ax * FACING_HYSTERESIS
	else:
		horizontal = ax > ay * FACING_HYSTERESIS
	if horizontal:
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
		draw_rect(Rect2(sx, -39, 4, 4), CombatRules.STATUS[id]["color"])
		sx += 6.0
	var w := 30.0
	draw_rect(Rect2(-w * 0.5, -46, w, 4), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, -46, w * float(hp) / float(maxi(1, max_hp)), 4), Color(0.45, 0.85, 0.50))
	draw_rect(Rect2(-w * 0.5, -42, w, 2), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, -42, w * res / maxf(1.0, res_max), 2), SkillDefs.RESOURCES[res_kind]["color"])
	if casting != "":
		var total := float(SkillDefs.info(casting)["cast"])
		draw_rect(Rect2(-18, -58, 36, 4), Color(0.1, 0.1, 0.1, 0.85))
		draw_rect(Rect2(-18, -58, 36.0 * (1.0 - cast_left / maxf(0.01, total)), 4), Color(0.95, 0.85, 0.4))
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
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, CombatRules.HERO_BODY, Color(0, 0, 0, 0.28))      # contact shadow
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
