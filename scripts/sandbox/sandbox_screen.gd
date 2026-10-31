class_name SandboxScreen
extends Control
## Real-time control sandbox (T-004..T-006, partial T-008). No pause, no time-slow (D-014).
## LMB select / drag-box   RMB move order   1-5 focus hero   Tab group view   G select squad.
## Camera switching never changes selection-independent orders: heroes keep walking.

signal back_requested

const TEST_SQUAD := [[101, 3], [202, 2], [303, 4], [404, 1], [505, 5]]   # [seed, stars] used if the party is not full
const SEPARATION := 26.0
const FORMATION_RADIUS := 44.0
# D-063: the world is drawn at the 640x360 base with whole-number zoom only (crisp pixel art): x1 normally,
# x0.5 when the squad is too spread out to fit. The whole-map overview (M) fits the map instead.
const GROUP_ZOOM_MIN := 0.5
const GROUP_ZOOM_MAX := 1.0
const FOLLOW_ZOOM := 1.0
# Camera feel (game feel report): look-ahead along the followed hero's motion, and a group zoom that
# only re-targets when the needed zoom moved by more than ZOOM_HYSTERESIS (no "breathing" while the
# squad walks). Easing itself lives in FeelCamera.
const LOOK_AHEAD := 0.18          # seconds of the hero's velocity
const LOOK_AHEAD_MAX := 28.0      # world pixels
const ZOOM_HYSTERESIS := 0.06

enum Mission { ACTIVE, SUCCESS, FAILED, ESCAPED }

const MISSION_NAME := "Recover the relic"
const PICKUP_RADIUS := 40.0
const EXTRACT_RADIUS := 56.0
const REWARD_GEMS := 100          # placeholder rewards (T-020): real tuning comes with the economy
const REWARD_STONES := 1
const SURVIVE_TIME := 75.0        # survival: seconds to hold out
const HOLD_TIME := 60.0           # defense: seconds a hero must stand at the shrine
const SHRINE_RADIUS := 120.0
const WAVE_EVERY := 12.0
const WAVE_MAX_ALIVE := 14
const CLUE_RADIUS := 56.0
const MISSION_TITLES := {"retrieval": "Recover the relic", "combat": "Clear the floor", "rescue": "Rescue the villager",
	"exploration": "Explore the forest", "survival": "Survive the onslaught", "defense": "Hold the shrine", "boss": "Defeat the chieftain"}

var floor_number: int = 0
var map: NavMap = null
var heroes: Array[SandboxHero] = []
var enemies: Array[SandboxEnemy] = []
var selected: Array[SandboxHero] = []
var mission_state: Mission = Mission.ACTIVE
var relic: SandboxRelic
var expedition_applied: bool = false
var town_report: Dictionary = {}
var mission_type: String = "retrieval"      # from TowerExpedition (floor 0 = training ground relic)
var mission_timer: float = 0.0
var clues: Array[SandboxRelic] = []
var shrine: SandboxRelic = null
var boss: SandboxEnemy = null
var reward: Dictionary = {}
var _wave_timer: float = 0.0
var _escort: AnimatedSprite2D = null           # rescued villager following its carrier
var _rng := RandomNumberGenerator.new()
var carrier: SandboxHero = null
var defeated: int = 0
var elapsed: float = 0.0
var fallen: Array = []                        # display names of heroes lost this mission
var real_squad: bool = false                  # true when the squad is the player's saved party
var reward_given: bool = false
var follow_slot: int = -1                     # -1 = group view
var overview: bool = false                    # M: whole-map view (camera only, never pauses)
var camera: FeelCamera
var debug_overlay: CombatDebugDraw = null       # F3 in debug builds only
var fog: FogMap = null                          # D-056: sight belongs to the heroes, not the camera
var _fog_view: FogView = null
var _fog_t: float = 0.0
var _scout_t: float = 0.0
const SCOUT_EVERY := 2.0
const SCOUT_REACH := 10                         # cells an idle explorer looks around itself for fog
var camera_target: Vector2 = Vector2.ZERO
var camera_zoom_target: float = 1.0

var _viewport: SubViewport
var _world: Node2D
var _info: Label
var _hint: Label
var _squad_label: Label
var _skill_btns: Array[Button] = []    # skill slots 0-2 on W E R (D-059; Q = aimed basic attack)
const SKILL_KEYS := "WER"
var _q_held: bool = false                 # holding Q keeps firing at the cursor whenever ready
var _overlay: Control
var _band: ColorRect
var _hud: ExpeditionHud = null
var _menu: GameMenu = null
var _preview_slot: int = -1
var _look_at: Vector2 = Vector2.INF
var _look_t: float = 0.0
const LOOK_HOLD := 3.0
var _drag_start: Vector2 = Vector2.ZERO
var aiming_slot: int = -1                 # W/E/R held on the driven hero: indicator shown, cast on release
var _rmb_held: bool = false
var _rmb_t: float = 0.0
var _aim_view: SkillAimView = null
const RMB_REPEAT := 0.12                  # holding right click keeps steering the driven hero
var _dragging: bool = false


func _init(p_floor: int = 0) -> void:
	floor_number = p_floor


func _ready() -> void:
	if map == null:
		if floor_number > 0:
			var game_node := get_node_or_null("/root/Game")
			if game_node != null and game_node.has_method("get_or_create_tower_floor_map"):
				map = game_node.get_or_create_tower_floor_map(floor_number)
			else:
				map = SandboxMap.new()
		else:
			map = SandboxMap.new()

	clip_contents = true
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	UIKit.fill(container)
	_viewport = SubViewport.new()
	_viewport.handle_input_locally = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(_viewport)

	_world = Node2D.new()
	_world.y_sort_enabled = true                 # lower on screen = in front (units, corpses, props)
	_viewport.add_child(_world)
	var ground := SandboxMapView.new(map)
	ground.z_index = -10                         # floor < zones (-5) < ground effects (-4) < units (0) < air effects (20)
	_world.add_child(ground)
	fog = FogMap.new(map.width, map.height)
	if floor_number > 0:
		fog.unpack(Game.floor_explored(floor_number))     # what this account already explored here
	_fog_view = FogView.new(fog)
	_world.add_child(_fog_view)
	camera = FeelCamera.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.bounds = Rect2(Vector2.ZERO, map.world_size())
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON   # eased per tick, drawn interpolated
	_viewport.add_child(camera)
	camera.make_current()
	# Smooth motion on any refresh rate: the rules tick at the physics rate and the world is drawn
	# interpolated between ticks, and so is the camera (eased in the same tick). The HUD is not. Turned off again when the mission screen closes.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	get_tree().physics_interpolation = true

	mission_type = String(TowerExpedition.get_floor_config(floor_number)["mission"]) if floor_number > 0 else "retrieval"
	_rng.seed = hash(floor_number) ^ 0x5eed
	relic = SandboxRelic.new("captive" if mission_type == "rescue" else "relic")
	relic.position = map.center_of(map.relic_cell)      # never the extraction cell (F-003)
	_world.add_child(relic)
	_build_squad()
	_build_enemies()
	_spawn_nodes()
	_setup_mission()
	_build_ui()
	update_fog()
	select_all()
	group_view()
	update_camera_targets()
	camera.target_position = camera_target
	camera.target_zoom = camera_zoom_target
	camera.snap()
	_refresh_info()
	if not heroes.is_empty():
		var leader: SandboxHero = heroes[0]
		leader.say(HeroChatter.get_entry_line(leader.hero), 5.5)


func _build_squad() -> void:
	var squad: Array = Game.party_heroes()
	real_squad = squad.size() == Game.PARTY_SIZE
	if not real_squad:
		squad = []
		for entry in TEST_SQUAD:
			squad.append(HeroGenerator.generate(int(entry[0]), int(entry[1])))
	for i in squad.size():
		var h := SandboxHero.new(squad[i], i)
		var sc: Vector2i = map.spawn_cells[i % map.spawn_cells.size()]
		h.position = map.center_of(sc)
		h.died.connect(_on_hero_died)
		h.went_down.connect(_on_hero_down)
		_world.add_child(h)
		heroes.append(h)


## Visual type per spawn (T-024). Cosmetic only: all enemies keep the same provisional stats for now.
const ENEMY_TYPES := ["orc", "orc_warrior", "skeleton_base", "skeleton_mage", "orc_rogue"]


## v2 floors place encounters (groups, patrols, ambushes, guards); older maps one creature per cell.
func _build_enemies() -> void:
	if map is ProceduralMap and not (map as ProceduralMap).encounters.is_empty():
		for enc in (map as ProceduralMap).encounters:
			_spawn_encounter(enc)
		return
	var cells: Array[Vector2i] = map.enemy_spawn_cells
	if cells.is_empty():
		cells = [Vector2i(10, 10)]
	for i in cells.size():
		_spawn_enemy(cells[i], TowerExpedition.foe_for(floor_number, i) if floor_number > 0 else ENEMY_TYPES[i % ENEMY_TYPES.size()])


var objective_enemies: Array[SandboxEnemy] = []   # the guards of the goal (the boss is the first one)
## Expedition ledger (vertical slice): what was gathered and dropped. Kept on success and on escape,
## lost if the squad is wiped. kill_xp = worth of the creatures killed (shared as XP at the end).
var ledger: Dictionary = {}
var kill_xp: int = 0
var nodes: Array[GatherNode] = []
var results: Dictionary = {}                     # Game.finish_expedition report, for the results screen
const EXTRACT_GATHER := 1.8                      # escaping: every standing hero within this x EXTRACT_RADIUS


func _add_loot(res: String, n: int, at: Node2D) -> void:
	if n <= 0:
		return
	ledger[res] = int(ledger.get(res, 0)) + n
	if at != null and at.is_inside_tree():
		FloatingText.spawn(at, "+%d %s" % [n, String(EconomyDefs.RESOURCES.get(res, {}).get("name", res)).to_lower()], Color(0.95, 0.85, 0.45), false, 1.4)


func _on_enemy_died(e: SandboxEnemy) -> void:
	defeated += 1
	kill_xp += roundi(float(e.base_max_hp) * EnemyDefs.XP_PER_HP)
	var killer = e.get_meta("last_hitter") if e.has_meta("last_hitter") else null
	if killer != null and is_instance_valid(killer) and killer.has_method("credit"):
		killer.credit("kills", 1.0)
	var drops: Dictionary = EnemyDefs.DROPS.get(e.type_id, {})
	for res in drops:
		var d: Array = drops[res]
		if _rng.randf() < float(d[0]):
			_add_loot(String(res), _rng.randi_range(int(d[1]), int(d[2])), e)


func _spawn_nodes() -> void:
	if not (map is ProceduralMap):
		return
	for n in (map as ProceduralMap).resource_nodes:
		var def: Dictionary = EconomyDefs.NODES.get(String(n["kind"]), {})
		var amounts := {}
		for res in def.get("res", {}):
			var r: Array = def["res"][res]
			amounts[res] = _rng.randi_range(int(r[0]), int(r[1]))
		var g := GatherNode.new(String(n["kind"]), amounts)
		g.position = map.center_of(n["cell"])
		_world.add_child(g)
		nodes.append(g)


## A hero next to a gathering spot and not fighting collects it (one gatherer at a time).
func _tick_gathering(delta: float) -> void:
	for g in nodes:
		if g.taken:
			continue
		g.visible = fog == null or fog.is_explored(map.cell_of(g.position))
		var who: SandboxHero = null
		for h in heroes:
			if h.alive and h.target == null and not h.is_casting() and h.position.distance_to(g.position) <= GatherNode.RANGE:
				who = h
				break
		if who == null:
			if g.progress > 0.0:
				g.progress = 0.0
				g.queue_redraw()
			continue
		g.progress += delta
		g.queue_redraw()
		if g.progress >= EconomyDefs.GATHER_TIME:
			g.taken = true
			for res in g.amounts:
				_add_loot(String(res), int(g.amounts[res]), who)
				who.credit("gathered", float(g.amounts[res]))
			g.queue_free()


## "" when the squad can escape now (every standing hero near the extraction point), else why not.
func extract_block() -> String:
	if mission_state != Mission.ACTIVE:
		return "the mission is over"
	var at := map.center_of(map.extract_cell)
	var standing := heroes.filter(func(h): return h.alive)
	if standing.is_empty():
		return "nobody is standing"
	for h in standing:
		if h.position.distance_to(at) > EXTRACT_RADIUS * EXTRACT_GATHER:
			return "%s is not at the extraction point" % h.hero.display_name()
	return ""


## Escape (vertical slice): keep what was gathered and dropped, lose the completion reward. Heroes
## lying downed away from the exit cannot be carried out and are lost (D-036 "left behind").
func extract() -> bool:
	if extract_block() != "":
		FloatingText.spawn(heroes[0], extract_block(), Color(1.0, 0.6, 0.5), false, 2.0)
		return false
	var at := map.center_of(map.extract_cell)
	for h in heroes:
		if h.downed and h.position.distance_to(at) > EXTRACT_RADIUS * EXTRACT_GATHER:
			h.killed_by = "left behind"
			h.die()
	_end_mission(Mission.ESCAPED)
	return true


func _spawn_encounter(enc: Dictionary) -> void:
	var group: Array = []
	var cells: Array = enc["cells"]
	for i in cells.size():
		var e := _spawn_enemy(cells[i], String(enc["members"][i]))
		e.home = e.position
		match String(enc["kind"]):
			"ambush":
				e.dormant = true
				e.visible = false
			"patrol":
				for c in enc["patrol"]:
					e.patrol.append(map.center_of(c))
		group.append(e)
		if String(enc["zone"]) == "objective":
			objective_enemies.append(e)
	for e in group:
		e.group_mates = group


func _spawn_enemy(c: Vector2i, type_id: String) -> SandboxEnemy:
	var e := SandboxEnemy.new()
	e.setup_type(type_id, floor_number)
	e.position = map.center_of(c)
	e.died.connect(_on_enemy_died)
	_world.add_child(e)
	enemies.append(e)
	return e


## Per-floor objective (D-031 floors use the mission type from TowerExpedition).
func _setup_mission() -> void:
	relic.visible = mission_type == "retrieval" or mission_type == "rescue"
	match mission_type:
		"boss":
			if not objective_enemies.is_empty():
				boss = objective_enemies[0]          # v2: the boss waits at the goal with its guards
			elif not enemies.is_empty():
				boss = enemies[0]
			if boss != null:
				boss.make_boss(String(TowerExpedition.get_floor_config(floor_number).get("boss_name", "Orc Chieftain")))
		"exploration":
			var spots: Array[Vector2i] = []
			for c in map.treasure_cells + map.enemy_spawn_cells:
				if not spots.has(c) and Vector2(c).distance_to(Vector2(map.extract_cell)) > 8.0:
					spots.append(c)
			spots.append(map.relic_cell)
			for i in mini(3, spots.size()):
				var clue := SandboxRelic.new("clue")
				clue.position = map.center_of(spots[spots.size() - 1 - i])
				_world.add_child(clue)
				clues.append(clue)
		"defense":
			shrine = SandboxRelic.new("shrine")
			shrine.position = map.center_of(map.extract_cell) + Vector2(0, -40)
			_world.add_child(shrine)


func mission_title() -> String:
	return String(MISSION_TITLES.get(mission_type, MISSION_NAME))


func _spawn_wave() -> void:
	if living_enemies().size() >= WAVE_MAX_ALIVE or map.enemy_spawn_cells.is_empty():
		return
	for i in 2:
		var c: Vector2i = map.enemy_spawn_cells[_rng.randi() % map.enemy_spawn_cells.size()]
		_spawn_enemy(c, TowerExpedition.foe_for(floor_number, _rng.randi()))


func living_heroes() -> Array:
	return heroes.filter(func(h): return h.alive)


func living_enemies() -> Array:
	return enemies.filter(func(e): return e.alive)


## Creatures the squad can see right now (fog of war): what heroes target and what can be clicked.
func visible_enemies() -> Array:
	return enemies.filter(func(e): return e.alive and e.visible)


## Shared context for autonomy, refreshed every SCOUT_EVERY seconds: the squad centre (where hurt
## heroes fall back to) and, for idle explorers with no foe in sight, the nearest unexplored spot within
## reach of them and of the driven hero (they scout, they do not wander off alone).
func _direct_autonomy() -> void:
	var alive := heroes.filter(func(h): return h.alive)
	if alive.is_empty():
		return
	var centre := Vector2.ZERO
	for h in alive:
		centre += h.position
	centre /= float(alive.size())
	var danger := not visible_enemies().is_empty()
	for h in alive:
		h.rally_point = centre
		if danger or h.is_controlled() or h.order != "auto" or not h.is_explorer() or h.is_moving() or fog == null:
			continue
		var spot := _fog_frontier(map.cell_of(h.position))
		var leash_from: Vector2 = h.anchor.position if h.anchor != null else centre
		if spot != Vector2.INF and spot.distance_to(leash_from) <= h.leash() + 140.0:
			h.explore_goal = spot


## Nearest walkable cell (breadth-first over walkable cells, up to SCOUT_REACH) next to never-seen fog.
func _fog_frontier(from: Vector2i) -> Vector2:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or absi(n.x - from.x) > SCOUT_REACH or absi(n.y - from.y) > SCOUT_REACH:
				continue
			seen[n] = true
			if not fog.is_explored(n):
				return map.center_of(c)
			if not map.is_blocked_cell(n):
				queue.append(n)
	return Vector2.INF


## Recomputes sight from the heroes (never from the camera) and shows only creatures in sight.
func update_fog() -> void:
	if fog == null:
		return
	var viewers: Array = []
	var lookers: Array = []
	for h in heroes:
		if not h.dead:
			viewers.append([map.cell_of(h.position), h.vision_cells()])
			lookers.append(h)
	var found: Array = fog.update(viewers, map)
	for i in lookers.size():
		lookers[i].credit("explored", float(found[i]))
	for e in enemies:
		if e.alive:
			e.visible = not e.dormant and fog.is_visible(map.cell_of(e.position))
	if _fog_view != null:
		_fog_view.refresh()


func _build_ui() -> void:
	# D-063: the expedition HUD (party, skills, orders, objective, minimap, boss). The old text panel lives
	# on as the Details panel (I): _info and _squad_label are refreshed as before.
	_info = UIKit.label("", 14, UIKit.TEXT)
	_info.custom_minimum_size = Vector2(240, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_squad_label = UIKit.label("", 12, UIKit.MUTED)
	_squad_label.custom_minimum_size = Vector2(240, 0)
	_hud = ExpeditionHud.new(self)
	add_child(_hud)

	_band = ColorRect.new()
	_band.color = Color(ArtPalette.GREEN[3], 0.22)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	add_child(_band)
	UIKit.music("boss" if mission_type == "boss" else ("explore" if floor_number > 0 else "battle"))


## Esc / the menu button: options and a way out, the expedition keeps running (D-062, D-014).
func open_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.close()
		return
	_menu = GameMenu.new()
	_menu.leave_label = "Leave (the squad abandons the floor)" if mission_state == Mission.ACTIVE and floor_number > 0 else "Back to the town"
	_menu.leave_requested.connect(func(_to): back_requested.emit())
	add_child(_menu)


## Hovering a skill in the HUD shows its reach (and area at the mouse) for the hero in focus.
func preview_skill(slot: int) -> void:
	_preview_slot = slot
	if slot >= 0 and _aim_view == null:
		_aim_view = SkillAimView.new()
		_world.add_child(_aim_view)


## Minimap click: look at a point for a few seconds (camera only; orders and focus unchanged).
func look_at_world(p: Vector2) -> void:
	overview = false
	_look_at = p
	_look_t = LOOK_HOLD


# --- selection / camera commands (public so tests and a future HUD can call them) ----------

func select_only(list: Array) -> void:
	selected.clear()
	for h in heroes:
		h.selected = h.alive and list.has(h) and h.obeys()      # D-051: no obedience, no orders
		if h.selected:
			selected.append(h)
		elif h.alive and list.has(h) and not h.obeys():
			_refuse_command(h)
	_refresh_info()


## D-051: a hero below the obedience threshold ignores the command and says so.
func _refuse_command(h: SandboxHero) -> void:
	FloatingText.spawn(h, "ignores you (Obedience %d)" % h.hero.obedience, Color(1.0, 0.6, 0.4), false, 1.6)


## The hero the player drives right now (D-053), or null in group view.
func controlled() -> SandboxHero:
	for h in heroes:
		if h.is_controlled():
			return h
	return null


func _set_controlled(h: SandboxHero) -> void:
	for o in heroes:
		o.controller = "player" if o == h else "ai"
		o.anchor = h if o != h else null


## D-053: 1-5 (Shift+1-5 = heroes 6-10 in a raid) focuses AND takes direct control of that hero.
## Same hero, same skills, cooldowns and rules: only who decides changes. Refused, with the reason, for
## an empty/fallen slot or a hero without obedience (D-051).
func select_slot(i: int) -> void:
	if i < 0 or i >= heroes.size():
		return
	var h := heroes[i]
	if not h.alive:
		if h.downed or h.dead:
			FloatingText.spawn(h, "down" if h.downed else "fallen", Color(0.8, 0.8, 0.8), false)
		return
	if not h.obeys():
		_refuse_command(h)
		return
	overview = false
	select_only([h])
	follow_slot = i
	_set_controlled(h)


func select_all() -> void:
	select_only(heroes)


func group_view() -> void:
	follow_slot = -1
	_set_controlled(null)                        # everybody back to autonomy


## Pure data: where the camera wants to be. update_camera() eases toward it each frame.
func update_camera_targets() -> void:
	if heroes.is_empty():
		return
	if _look_t > 0.0 and _look_at != Vector2.INF:
		camera_target = _look_at
		return
	if overview:
		var ws: Vector2 = map.world_size()
		var vs := Vector2(_viewport.size) if _viewport != null and _viewport.size.x > 0 else Vector2(1280, 670)
		camera_target = ws * 0.5
		camera_zoom_target = minf(vs.x / ws.x, vs.y / ws.y)
		return
	if follow_slot >= 0:
		camera_target = heroes[follow_slot].position
		camera_zoom_target = FOLLOW_ZOOM
		return
	var lo := heroes[0].position
	var hi := heroes[0].position
	for h in heroes:
		lo = lo.min(h.position)
		hi = hi.max(h.position)
	camera_target = (lo + hi) * 0.5
	var view := _viewport.size if _viewport != null and _viewport.size.x > 0 else Vector2i(1280, 670)
	var need := (hi - lo) + Vector2(180, 150)
	var z := clampf(minf(view.x / need.x, view.y / need.y), GROUP_ZOOM_MIN, GROUP_ZOOM_MAX)
	z = GROUP_ZOOM_MAX if z >= 0.9 else GROUP_ZOOM_MIN          # whole steps only (D-063)
	if absf(z - camera_zoom_target) > camera_zoom_target * ZOOM_HYSTERESIS or z >= GROUP_ZOOM_MAX or z <= GROUP_ZOOM_MIN:
		camera_zoom_target = z


func screen_to_world(p: Vector2) -> Vector2:
	var view := Vector2(_viewport.size)
	return camera.position + camera.offset + (p - view * 0.5) / camera.zoom.x      # offset = screen shake


var _arming_attack_move: bool = false


## A: the next left click is an attack-move destination.
func arm_attack_move() -> void:
	_arming_attack_move = not selected.is_empty()


func attack_move_selected(world_point: Vector2) -> void:
	var n := selected.size()
	for i in n:
		var offset := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * float(i - 1) / float(maxi(1, n - 1))) * FORMATION_RADIUS
		if not selected[i].order_attack_move(world_point + offset, map):
			FloatingText.spawn(selected[i], "can't reach", Color(1.0, 0.6, 0.4), false)
	_mark(world_point, Color(1.0, 0.6, 0.3))


func hold_selected() -> void:
	for h in selected:
		h.order_hold()
		_mark(h.position, Color(0.6, 0.8, 1.0))


## F: the selection follows the focused hero (key 1-5), else the first living hero not selected.
func follow_selected() -> void:
	var leader: SandboxHero = heroes[follow_slot] if follow_slot >= 0 and follow_slot < heroes.size() else null
	if leader == null or not leader.alive or selected.size() == 1 and selected[0] == leader:
		leader = null
		for h in heroes:
			if h.alive and not selected.has(h):
				leader = h
				break
	if leader == null:
		for h in selected:
			FloatingText.spawn(h, "no one to follow", Color(1.0, 0.6, 0.4), false)
		return
	for h in selected:
		if h != leader:
			h.order_follow(leader)


## C: the selection gathers around its centre, then goes back to Auto.
func regroup_selected() -> void:
	var live := selected.filter(func(h): return h.alive)
	if live.is_empty():
		return
	var c := Vector2.ZERO
	for h in live:
		c += h.position
	c /= float(live.size())
	order_move_selected(map.nearest_walkable(c))
	_mark(c, Color(0.6, 1.0, 0.6))


## X: run to the extraction point, no fighting on the way.
func retreat_selected() -> void:
	var exit := map.center_of(map.extract_cell)
	for i in selected.size():
		var offset := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(1, selected.size()))) * 26.0
		if not selected[i].order_retreat(exit + offset, map):
			FloatingText.spawn(selected[i], "no way out", Color(1.0, 0.6, 0.4), false)
	_mark(exit, Color(0.4, 1.0, 0.7))


func order_move_selected(world_point: Vector2) -> void:
	var n := selected.size()
	for i in n:
		var offset := Vector2.ZERO
		if n > 1 and i > 0:
			offset = Vector2.RIGHT.rotated(TAU * float(i - 1) / float(n - 1)) * FORMATION_RADIUS
		var p := map.find_path(selected[i].position, world_point + offset)
		if p.is_empty():
			FloatingText.spawn(selected[i], "can't reach", Color(1.0, 0.6, 0.4), false)
		selected[i].order_move(p)


## Right-click: on an enemy = attack it, on a downed ally = rescue (nearest selected hero goes),
## on the ground = move. Returns the order given ("attack" | "rescue" | "move" | "").
func order_context(world_point: Vector2) -> String:
	if selected.is_empty():
		return ""
	if controlled() != null and selected.size() == 1 and selected[0].is_controlled():
		order_move_selected(world_point)          # D-059: the driven hero only moves on right click
		_mark(world_point, Color(1, 1, 1))
		return "move"
	var foe: SandboxEnemy = null
	var foe_d := INF
	for e in visible_enemies():                 # the click area follows the body; hidden foes cannot be clicked
		var d: float = e.pick_distance(world_point)
		if d <= 0.0 and (foe == null or e.position.distance_to(world_point) < foe_d):
			foe = e
			foe_d = e.position.distance_to(world_point)
	if foe != null:
		for h in selected:
			h.order_attack(foe)
		_mark(foe.position, Color(1.0, 0.35, 0.3))
		return "attack"
	for ally in heroes:
		if ally.downed and ally.position.distance_to(world_point) <= 30.0:
			var best: SandboxHero = null
			for h in selected:
				if h.alive and (best == null or h.position.distance_to(ally.position) < best.position.distance_to(ally.position)):
					best = h
			if best != null:
				best.order_rescue(ally)
				_mark(ally.position, Color(0.5, 1.0, 0.6))
				return "rescue"
	order_move_selected(world_point)
	_mark(world_point, Color(1, 1, 1))
	return "move"


## Small fading ring where an order was given (order feedback).
func _mark(at: Vector2, color: Color) -> void:
	var m := OrderMarker.new()
	m.position = at
	m.color = color
	_world.add_child(m)


## Orders available to the panel and the keyboard. Never randomly refused (D-016).
func stop_selected() -> void:
	for h in selected:
		h.stop()
		h.target = null


## Fires skill slot `slot_index` (Q=0 .. R=3) of every selected hero. Each refusal shows its reason
## over the hero (D-016: never random). Returns how many fired.
func use_skill_selected(slot_index: int = 0, aim: Vector2 = Vector2.INF) -> int:
	var fired := 0
	var foes := living_enemies()
	for h in selected:
		if h.use_skill_slot(slot_index, foes, heroes, aim if h.is_controlled() else Vector2.INF):
			fired += 1
		elif h.alive:
			FloatingText.spawn(h, h.last_refusal, Color(0.8, 0.8, 0.8), false)
	return fired


# --- simulation ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)
	_step_camera(delta)


## Camera easing runs in the physics tick, after the units moved, so both are interpolated together.
func _step_camera(delta: float) -> void:
	_look_t = maxf(0.0, _look_t - delta)
	update_camera_targets()
	var lead := Vector2.ZERO
	if follow_slot >= 0 and follow_slot < heroes.size() and not overview:
		lead = (heroes[follow_slot].velocity * LOOK_AHEAD).limit_length(LOOK_AHEAD_MAX)
	camera.target_position = camera_target + lead
	camera.target_zoom = camera_zoom_target
	camera.step(delta)


func tick(delta: float) -> void:
	if mission_state != Mission.ACTIVE:
		return                                    # mission over: the result screen is up
	var foes := living_enemies()
	for h in heroes:
		h.tick(delta)
		h.combat_tick(foes.filter(func(e): return e.visible), map)    # heroes only fight what they see
	var targets := heroes.filter(func(h): return not h.dead)
	for e in foes:
		e._allies = foes                          # supports heal from this list
		e.tick(delta, targets, map)
	for h in heroes:
		if not h.alive and selected.has(h):
			selected.erase(h)
		if not h.alive and h.is_controlled():
			group_view()                         # the driven hero fell: back to the squad view
	_separate()
	_separate_enemies()
	_tick_gathering(delta)
	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_t = CombatRules.FOG_EVERY
		update_fog()
	_scout_t -= delta
	if _scout_t <= 0.0:
		_scout_t = SCOUT_EVERY
		_direct_autonomy()
	_update_mission(delta)


# --- mission: non-combat objective + extraction + result (T-011) ------------------------

func _update_mission(delta: float) -> void:
	elapsed += delta
	match mission_type:
		"combat":
			if living_enemies().is_empty():
				_end_mission(Mission.SUCCESS)
				return
		"boss":
			if boss != null and not boss.alive:
				_end_mission(Mission.SUCCESS)
				return
		"exploration":
			for clue in clues:
				var finder = heroes.filter(func(h): return h.alive and h.position.distance_to(clue.position) <= CLUE_RADIUS)
				if clue.visible and not finder.is_empty():
					clue.visible = false
					finder[0].credit("objective", 3.0)
			if clues.all(func(c): return not c.visible):
				_end_mission(Mission.SUCCESS)
				return
		"survival", "defense":
			_wave_timer += delta
			if _wave_timer >= WAVE_EVERY:
				_wave_timer = 0.0
				_spawn_wave()
			if mission_type == "survival":
				mission_timer += delta
			elif heroes.any(func(h): return h.alive and h.position.distance_to(shrine.position) <= SHRINE_RADIUS):
				mission_timer += delta
				for h in heroes:
					if h.alive and h.position.distance_to(shrine.position) <= SHRINE_RADIUS:
						h.credit("objective", delta / HOLD_TIME * 3.0)
				shrine.progress = clampf(mission_timer / HOLD_TIME, 0.0, 1.0)
			if mission_timer >= (SURVIVE_TIME if mission_type == "survival" else HOLD_TIME) and not living_heroes().is_empty():
				_end_mission(Mission.SUCCESS)
				return
	if mission_type != "retrieval" and mission_type != "rescue":
		if living_heroes().is_empty():
			_wipe()
		return
	if _escort != null:
		_escort.visible = carrier != null
		if carrier != null:
			_escort.position = carrier.position + Vector2(-20, 6)
	if carrier == null and relic.visible:
		for h in heroes:
			if h.alive and h.position.distance_to(relic.position) <= PICKUP_RADIUS:
				carrier = h
				h.carrying = true
				h.credit("objective", 2.0)
				h.queue_redraw()
				relic.visible = false
				if mission_type == "rescue" and _escort == null:
					_escort = AnimatedSprite2D.new()
					_escort.sprite_frames = CazArt.villager_frames(3)
					_escort.offset = Vector2(0, -16)
					_world.add_child(_escort)
					_escort.play("idle_down")
				break
	if carrier != null and carrier.position.distance_to(map.center_of(map.extract_cell)) <= EXTRACT_RADIUS:
		carrier.credit("objective", 2.0)
		_end_mission(Mission.SUCCESS)
	elif living_heroes().is_empty():
		_wipe()


## D-036: nobody left standing to carry the fallen out -> every downed hero dies, mission failed.
func _wipe() -> void:
	for h in heroes:
		if h.downed:
			h.killed_by = "left behind"
			h.die()
	_end_mission(Mission.FAILED)


## A hero fell (not dead yet): the relic drops where they lie; an escorted villager waits there.
func _on_hero_down(h: SandboxHero) -> void:
	if carrier == h:
		carrier = null
		h.carrying = false
		relic.position = h.position
		relic.visible = true
	if selected.has(h):
		selected.erase(h)
	if h.hero != null:
		h.say("", 0.0)


## Permanent death (D-011): the saved hero is removed from the roster and written to the
## memorial. Sandbox test heroes are not on the roster, so nothing is recorded for them.
func _on_hero_died(h: SandboxHero) -> void:
	fallen.append(h.hero.display_name())
	if carrier == h:
		carrier = null
		h.carrying = false
		relic.position = h.position
		relic.visible = true
	var cause := "Slain by %s" % h.killed_by if h.killed_by != "" else "Fell in battle"
	Game.record_death(h.hero, cause, mission_title() if floor_number > 0 else MISSION_NAME)


func _end_mission(state: Mission) -> void:
	mission_state = state
	if floor_number > 0 and fog != null:
		Game.set_floor_explored(floor_number, fog.pack())   # saved with the rewards / town report below
	for h in heroes:
		h.stop()
	var outcome := "success" if state == Mission.SUCCESS else ("escaped" if state == Mission.ESCAPED else "failed")
	var entries: Array = []
	for h in heroes:
		entries.append({"hero": h.hero, "alive": not h.dead, "contrib": h.contrib})
	if real_squad and not reward_given:
		reward_given = true
		if floor_number > 0:
			results = Game.finish_expedition(floor_number, outcome, ledger, entries, kill_xp, mission_type)
			reward = results.get("reward", {})
		elif state == Mission.SUCCESS:
			Game.grant(REWARD_GEMS, REWARD_STONES, 0)
	elif not real_squad:
		# test squad: show what would have happened, keep nothing
		var preview := ExpeditionResults.compute(entries, outcome, maxi(1, floor_number), kill_xp)
		results = {"outcome": outcome, "loot": {}, "lost_loot": ledger.duplicate(), "reward": {}, "xp": [],
			"mvp": (preview["mvp"] as HeroData).display_name() if preview["mvp"] != null else "", "mvp_reason": preview["mvp_reason"]}
	if real_squad and not expedition_applied:
		# the town lives on while the squad was away; survivors come home tired, maybe sick (HQ Phase 1)
		expedition_applied = true
		var back: Array = []
		for h in heroes:
			if not h.dead:
				back.append({"hero": h.hero, "downed": h.was_downed, "poisoned": h.was_poisoned})
		town_report = Game.after_expedition(back, floor_number, fallen.size())
	_show_result()


static func _res_line(d: Dictionary) -> String:
	var parts: Array = []
	for k in d:
		if int(d[k]) > 0:
			parts.append("%d %s" % [int(d[k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func result_text() -> String:
	var lines: Array = []
	match mission_state:
		Mission.SUCCESS:
			lines.append("MISSION COMPLETE")
		Mission.ESCAPED:
			lines.append("ESCAPED — the squad got out")
		_:
			lines.append("MISSION FAILED")
	lines.append(mission_title() if floor_number > 0 else MISSION_NAME)
	lines.append("Time: %d:%02d   Enemies defeated: %d / %d   Survivors: %d / %d" % [floori(elapsed / 60.0), int(elapsed) % 60,
		defeated, enemies.size(), living_heroes().size(), heroes.size()])
	if fog != null and floor_number > 0:
		lines.append("Explored: %d%% of the floor (remembered)" % roundi(fog.explored_fraction() * 100.0))
	if not fallen.is_empty():
		lines.append("Fallen (permanent): %s" % ", ".join(fallen))
	lines.append("")
	if not real_squad:
		lines.append("Test squad: nothing is kept.  Gathered: %s" % _res_line(ledger))
	elif mission_state == Mission.FAILED:
		lines.append("Lost in the tower: %s" % _res_line(results.get("lost_loot", ledger)))
	else:
		lines.append("Gathered and dropped (kept): %s" % _res_line(results.get("loot", {})))
	if mission_state == Mission.ESCAPED:
		lines.append("No completion reward: the objective was not finished.")
	if mission_state == Mission.SUCCESS and real_squad:
		if floor_number > 0:
			lines.append("Completion reward: %d materials, %d meals, %d gems, %d stones, %d books" % [int(reward.get("materials", 0)),
				int(reward.get("food", 0)), int(reward.get("gems", 0)), int(reward.get("stones", 0)), int(reward.get("books", 0))])
			for b in reward.get("skill_books", []):
				lines.append("Skill book found: %s" % String(SkillDefs.info(String(b)).get("name", b)))
			for it in reward.get("items", []):
				lines.append("Loot: %s" % String(it))
			if int(reward.get("left_behind", 0)) > 0:
				lines.append("%d item(s) left behind: the stash is full (upgrade the warehouse)" % int(reward["left_behind"]))
		else:
			lines.append("Reward: %d gems, %d stone (training ground)" % [REWARD_GEMS, REWARD_STONES])
	if String(results.get("mvp", "")) != "":
		lines.append("")
		lines.append("MVP OF THE EXPEDITION: %s — %s%s" % [String(results["mvp"]), String(results.get("mvp_reason", "")),
			("  (+%d XP)" % int(results.get("mvp_bonus", 0))) if int(results.get("mvp_bonus", 0)) > 0 else ""])
	if not (results.get("xp", []) as Array).is_empty():
		lines.append("Experience:")
		for x in results["xp"]:
			if not bool(x["alive"]):
				continue
			var lv := "  Lv %d -> %d" % [int(x["from"]), int(x["to"])] if int(x["levels"]) > 0 else "  Lv %d" % int(x["to"])
			lines.append("  %s%s: +%d XP%s%s" % ["* " if bool(x["mvp"]) else "", String(x["name"]), int(x["xp"]), lv, " (rank cap: ascend)" if bool(x["capped"]) else ""])
	if not town_report.is_empty():
		lines.append("Back in town: a day passed.")
		var evs: Array = town_report.get("events", [])
		for i in mini(3, evs.size()):
			lines.append("  " + String(evs[i]))
	return "\n".join(lines)


func _show_result() -> void:
	var center := CenterContainer.new()
	add_child(center)
	UIKit.fill(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)  # px
	panel.add_child(vb)
	# D-063 results: headline, then a scrollable report; the MVP stands out in gold with its reason
	if _hud != null:
		_hud.visible = false
	UIKit.music("results")
	var lines := result_text().split("
")
	var head := UIKit.label(lines[0], 28, UIKit.ACCENT if mission_state != Mission.FAILED else UIKit.BAD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 1)
	scroll.add_child(body)
	for i in range(1, lines.size()):
		var ln := String(lines[i])
		var mvp := ln.begins_with("MVP OF THE EXPEDITION")
		var l := UIKit.label(ln, 20 if mvp else 14, ArtPalette.GOLD[3] if mvp else (UIKit.ACCENT if ln.begins_with("  *") else UIKit.TEXT))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(345, 0)
		body.add_child(l)
	vb.add_child(UIKit.button("Back to town", func(): back_requested.emit(), Vector2(720, 40)))
	_overlay = center


## Anti-clumping: heroes closer than SEPARATION are pushed apart; idle ones yield first,
## and nobody is ever pushed into a wall.
func _separate() -> void:
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			var a := heroes[i]
			var b := heroes[j]
			if not a.alive or not b.alive:
				continue
			var d := b.position - a.position
			var dist := d.length()
			if dist >= SEPARATION:
				continue
			var dir := d / dist if dist > 0.01 else Vector2.RIGHT.rotated(float(i * 5 + j))
			var corr := SEPARATION - dist
			var wa := 0.3 if a.is_moving() else 1.0
			var wb := 0.3 if b.is_moving() else 1.0
			_nudge(a, -dir * corr * wa / (wa + wb))
			_nudge(b, dir * corr * wb / (wa + wb))


## Enemies keep apart from each other and from heroes (only the enemy is pushed). The gap is the sum
## of the two bodies (CombatRules.SIZE), so a golem keeps heroes out of its sprite and two rats can
## crowd together; the lighter of two creatures gives way more.
func _separate_enemies() -> void:
	var live := living_enemies()
	for i in live.size():
		var a: SandboxEnemy = live[i]
		for j in range(i + 1, live.size()):
			var b: SandboxEnemy = live[j]
			var d := b.position - a.position
			var dist := d.length()
			var gap := (a.body_radius + b.body_radius) * 0.95
			if dist < gap and dist > 0.01:
				var share := b.mass / (a.mass + b.mass)
				var push := d / dist * (gap - dist)
				_nudge_any(a, -push * share)
				_nudge_any(b, push * (1.0 - share))
		for h in heroes:
			if not h.alive:
				continue
			var d2 := a.position - h.position
			var dist2 := d2.length()
			var gap2 := (a.body_radius + CombatRules.HERO_BODY) * 0.9
			if dist2 < gap2 and dist2 > 0.01:
				_nudge_any(a, d2 / dist2 * (gap2 - dist2))


func _nudge_any(n: Node2D, v: Vector2) -> void:
	var np := n.position + v
	if not map.is_blocked(np):
		n.position = np


func _nudge(h: SandboxHero, v: Vector2) -> void:
	var np := h.position + v
	if not map.is_blocked(np):
		h.position = np


func _process(delta: float) -> void:
	if debug_overlay != null:
		debug_overlay.queue_redraw()
	var driven := controlled()
	if _q_held and driven != null and driven.attack_ready():
		attack_at_cursor()                       # holding Q fires again as soon as the attack is ready
	if _rmb_held and driven != null and mission_state == Mission.ACTIVE:
		_rmb_t -= delta                          # hold right click: the hero keeps following the cursor
		if _rmb_t <= 0.0:
			_rmb_t = RMB_REPEAT
			var p := screen_to_world(get_local_mouse_position())
			if driven.order == "move" and not driven.path.is_empty() and driven.path[driven.path.size() - 1].distance_to(p) > 16.0:
				order_move_selected(p)
	if _aim_view != null:
		var focus: SandboxHero = driven if driven != null else (selected[0] if selected.size() == 1 else null)
		_aim_view.hero = focus
		_aim_view.slot = aiming_slot if aiming_slot >= 0 else _preview_slot
		_aim_view.cursor = screen_to_world(get_local_mouse_position())
		_aim_view.queue_redraw()
	if _dragging:
		var m := get_local_mouse_position()
		_band.position = _drag_start.min(m)
		_band.size = (m - _drag_start).abs()
		_band.visible = (m - _drag_start).length() > 8.0
	_refresh_info()


# --- input ---------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _arming_attack_move:
				_arming_attack_move = false
				attack_move_selected(screen_to_world(event.position))
				return
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			elif _dragging:
				_dragging = false
				_band.visible = false
				_finish_left(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = event.pressed
			_rmb_t = RMB_REPEAT
			if event.pressed:
				order_context(screen_to_world(event.position))


func _finish_left(end: Vector2, additive: bool) -> void:
	var picked: Array = []
	if (end - _drag_start).length() > 8.0:
		var a := screen_to_world(_drag_start)
		var b := screen_to_world(end)
		var rect := Rect2(a.min(b), (a - b).abs())
		for h in heroes:
			if h.alive and rect.has_point(h.position + Vector2(0, -16)):
				picked.append(h)
	else:
		var p := screen_to_world(end)
		var best: SandboxHero = null
		var best_d := 30.0
		for h in heroes:
			if not h.alive:
				continue
			var d := (h.position + Vector2(0, -16)).distance_to(p)
			if d < best_d:
				best_d = d
				best = h
		if best != null:
			picked.append(best)
	if additive:
		for h in selected:
			if not picked.has(h):
				picked.append(h)
	elif picked.size() == 1 and (end - _drag_start).length() <= 8.0:
		select_slot(heroes.find(picked[0]))       # clicking one hero takes control of it (D-053)
		return
	if picked.size() > 1 or picked.is_empty():
		group_view()                             # a box or an empty click: squad orders, autonomy on
	select_only(picked)


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().physics_interpolation = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))


## F3 (debug builds only): bodies, strike/attack/perception ranges, paths, targets and AI state.
func toggle_debug_overlay() -> void:
	if not OS.is_debug_build():
		return
	if debug_overlay == null:
		debug_overlay = CombatDebugDraw.new(self)
		_world.add_child(debug_overlay)
	else:
		debug_overlay.queue_free()
		debug_overlay = null


## D-059: Q = the driven hero's basic attack toward the mouse (no hero driven: nothing happens).
func attack_at_cursor() -> bool:
	var driven := controlled()
	if driven == null or mission_state != Mission.ACTIVE:
		return false
	return driven.aimed_attack(screen_to_world(get_local_mouse_position()), living_enemies(), map)


func _skill_key(i: int, pressed: bool) -> void:
	var driven := controlled()
	if driven == null:
		if pressed:
			use_skill_selected(i)                # group: autonomy picks targets, as before
		return
	if pressed:
		aiming_slot = i                          # show range + area while held
		if _aim_view == null:
			_aim_view = SkillAimView.new()
			_world.add_child(_aim_view)
	elif aiming_slot == i:
		aiming_slot = -1
		use_skill_selected(i, screen_to_world(get_local_mouse_position()))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if event.keycode == KEY_Q:
		_q_held = event.pressed
		if event.pressed:
			attack_at_cursor()
		get_viewport().set_input_as_handled()
		return
	var skill_keys := {KEY_W: 0, KEY_E: 1, KEY_R: 2}
	if skill_keys.has(event.keycode):
		_skill_key(int(skill_keys[event.keycode]), event.pressed)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			select_slot(event.keycode - KEY_1 + (5 if event.shift_pressed else 0))
		KEY_TAB:
			overview = false
			group_view()
		KEY_F3:
			toggle_debug_overlay()
		KEY_M:
			overview = not overview
		KEY_G:
			select_all()
		KEY_S:
			stop_selected()
		KEY_A:
			arm_attack_move()
		KEY_H:
			hold_selected()
		KEY_F:
			follow_selected()
		KEY_C:
			regroup_selected()
		KEY_X:
			retreat_selected()
		KEY_ESCAPE:
			if _arming_attack_move:
				_arming_attack_move = false
			else:
				open_menu()
		KEY_I:
			if _hud != null:
				_hud.toggle_details()
		_:
			return
	get_viewport().set_input_as_handled()


# --- hero panel (contextual, minimal version of T-008) ---------------------------------------

func _refresh_info() -> void:
	if _info == null:
		return
	var view := "Focus: hero %d" % (follow_slot + 1) if follow_slot >= 0 else "Group view"
	var goal := "Objective: " + _objective_text()
	if selected.is_empty():
		_info.text = "%s\n%s\nNothing selected" % [view, goal]
	elif selected.size() == 1:
		var sh: SandboxHero = selected[0]
		var h: HeroData = sh.hero
		var st := h.get_stats()
		var sk_lines: Array = []
		for i in sh.slots.size():
			var sk: Dictionary = sh.slot_skill(i)
			var sk_state := "READY" if sh.skill_ready(i) else ("%.0fs" % ceilf(sh.skill_cd(i)) if sh.skill_cd(i) > 0.0 else "need %d" % int(sk["cost"]))
			sk_lines.append("%s %s [%s]" % [SKILL_KEYS[i], sk["name"], sk_state])
		_info.text = "%s\n%s\n%s  |  %d-star %s  |  Lv %d\nHP %d/%d  %s %d/%d  ATK %d  MAG %d  DEF %d\nTrust %d   Obedience %d   Composure %d\nSkills: %s\nOrder: %s%s" % [
			view, goal, h.display_name(), h.stars, h.class_title(), h.level,
			sh.hp, sh.max_hp, SkillDefs.RESOURCES[sh.res_kind]["name"], roundi(sh.res), roundi(sh.res_max), st["atk"], st["mag"], st["def"], h.trust, h.obedience, h.composure,
			"  ".join(sk_lines) if not sk_lines.is_empty() else "none", sh.order_label(), ("  · casting " + String(SkillDefs.info(sh.casting)["name"])) if sh.casting != "" else ""]
	else:
		var names: Array = []
		for s in selected:
			names.append(s.hero.hero_name.split(" ")[0])
		_info.text = "%s\n%s\n%d heroes selected: %s\nOrders: Move (right-click), Stop (S), Skills (W E R); 1-5 to drive one hero, Q to attack" % [view, goal, selected.size(), ", ".join(names)]
	for i in _skill_btns.size():
		var slot_i := i
		var b := _skill_btns[i]
		b.disabled = not selected.any(func(h): return h.skill_ready(slot_i))
		if selected.size() == 1 and i < (selected[0] as SandboxHero).slots.size():
			var nm := String((selected[0] as SandboxHero).slot_skill(i)["name"])
			b.text = "%s %s" % [SKILL_KEYS[i], nm.left(7)]
			b.tooltip_text = String((selected[0] as SandboxHero).slot_skill(i)["desc"])
		else:
			b.text = SKILL_KEYS[i]
	var rows: Array = []
	for i in heroes.size():
		var hh := heroes[i]
		var nm := hh.hero.hero_name.split(" ")[0]
		if hh.alive:
			var ready: Array = []
			for k in hh.slots.size():
				if hh.skill_ready(k):
					ready.append(SKILL_KEYS[k])
			rows.append("%d %s  HP %d/%d  %s %d  %s · %s%s" % [i + 1, nm, hh.hp, hh.max_hp, String(SkillDefs.RESOURCES[hh.res_kind]["name"]).left(1), roundi(hh.res), hh.order_label(),
				("ready " + "".join(ready)) if not ready.is_empty() else "no skill ready", "  [RELIC]" if hh.carrying else ""])
		elif hh.downed:
			rows.append("%d %s  DOWN %ds — right-click to rescue" % [i + 1, nm, ceili(hh.agony)])
		else:
			rows.append("%d %s  FALLEN" % [i + 1, nm])
	_squad_label.text = "\n".join(rows)


func _objective_text() -> String:
	match mission_state:
		Mission.SUCCESS:
			return "complete"
		Mission.FAILED:
			return "failed"
	if fog != null and floor_number > 0:
		return _mission_objective() + "  ·  explored %d%%" % roundi(fog.explored_fraction() * 100.0)
	return _mission_objective()


func _mission_objective() -> String:
	match mission_type:
		"combat":
			return "defeat every enemy (%d left)" % living_enemies().size()
		"boss":
			return "defeat the Orc Chieftain"
		"exploration":
			var left := clues.filter(func(c): return c.visible).size()
			return "discover the clues (%d left)" % left
		"survival":
			return "survive %d s" % maxi(0, int(SURVIVE_TIME - mission_timer))
		"defense":
			return "keep a hero at the shrine (%d%%)" % int(shrine.progress * 100.0)
		"rescue":
			return "escort the villager to EXTRACT" if carrier != null else "find the villager calling for help"
	if carrier != null:
		return "carry the relic to EXIT"
	if map is SandboxMap:
		return "recover the relic (far room, top right)"
	return "find the relic in the far room and bring it back to EXTRACT"
