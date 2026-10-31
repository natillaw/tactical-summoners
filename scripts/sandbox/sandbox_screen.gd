class_name SandboxScreen
extends Control
## Real-time control sandbox (T-004..T-006, partial T-008). No pause, no time-slow (D-014).
## LMB select / drag-box   RMB move order   1-5 focus hero   Tab group view   G select squad.
## Camera switching never changes selection-independent orders: heroes keep walking.

signal back_requested

const TEST_SQUAD := [[101, 3], [202, 2], [303, 4], [404, 1], [505, 5]]   # [seed, stars] used if the party is not full
const SEPARATION := 26.0
const FORMATION_RADIUS := 44.0
const GROUP_ZOOM_MIN := 0.75
const GROUP_ZOOM_MAX := 2.0
const FOLLOW_ZOOM := 2.5

enum Mission { ACTIVE, SUCCESS, FAILED }

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
var camera: Camera2D
var camera_target: Vector2 = Vector2.ZERO
var camera_zoom_target: float = 1.0

var _viewport: SubViewport
var _world: Node2D
var _info: Label
var _hint: Label
var _squad_label: Label
var _skill_btns: Array[Button] = []    # Q W E R (D-040)
var _overlay: Control
var _band: ColorRect
var _drag_start: Vector2 = Vector2.ZERO
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
	_viewport.add_child(_world)
	_world.add_child(SandboxMapView.new(map))
	camera = Camera2D.new()
	_viewport.add_child(camera)
	camera.make_current()

	mission_type = String(TowerExpedition.get_floor_config(floor_number)["mission"]) if floor_number > 0 else "retrieval"
	_rng.seed = hash(floor_number) ^ 0x5eed
	relic = SandboxRelic.new("captive" if mission_type == "rescue" else "relic")
	relic.position = map.center_of(map.relic_cell)      # never the extraction cell (F-003)
	_world.add_child(relic)
	_build_squad()
	_build_enemies()
	_setup_mission()
	_build_ui()
	select_all()
	group_view()
	update_camera_targets()
	camera.position = camera_target
	camera.zoom = Vector2.ONE * camera_zoom_target
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


func _build_enemies() -> void:
	var cells: Array[Vector2i] = map.enemy_spawn_cells
	if cells.is_empty():
		cells = [Vector2i(10, 10)]
	for i in cells.size():
		_spawn_enemy(cells[i], TowerExpedition.foe_for(floor_number, i) if floor_number > 0 else ENEMY_TYPES[i % ENEMY_TYPES.size()])


func _spawn_enemy(c: Vector2i, type_id: String) -> SandboxEnemy:
	var e := SandboxEnemy.new()
	e.setup_type(type_id)
	e.position = map.center_of(c)
	e.died.connect(func(_e): defeated += 1)
	_world.add_child(e)
	enemies.append(e)
	return e


## Per-floor objective (D-031 floors use the mission type from TowerExpedition).
func _setup_mission() -> void:
	relic.visible = mission_type == "retrieval" or mission_type == "rescue"
	match mission_type:
		"boss":
			if not enemies.is_empty():
				boss = enemies[0]
				boss.make_boss()
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


func _build_ui() -> void:
	var back := UIKit.button("< Back", func(): back_requested.emit(), Vector2(100, 36))
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(12, 10)
	add_child(back)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 0.88)
	add_child(panel)
	# bottom-left so the map and the heroes' speech stay visible
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -44
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pv)
	_info = UIKit.label("", 15, UIKit.TEXT)
	_info.custom_minimum_size = Vector2(340, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_info)
	var row := HBoxContainer.new()
	pv.add_child(row)
	for i in SkillDefs.MAX_SLOTS:
		var slot_i := i
		var sb := UIKit.button("QWER"[i], func(): use_skill_selected(slot_i), Vector2(64, 34))
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", 11)
		row.add_child(sb)
		_skill_btns.append(sb)
	var stop_btn := UIKit.button("Stop (S)", func(): stop_selected(), Vector2(110, 34))
	stop_btn.focus_mode = Control.FOCUS_NONE
	row.add_child(stop_btn)
	# D-040: every order also has a button
	var row2 := HBoxContainer.new()
	pv.add_child(row2)
	for spec in [["A-move (A)", func(): arm_attack_move()], ["Hold (H)", func(): hold_selected()],
			["Follow (F)", func(): follow_selected()], ["Regroup (C)", func(): regroup_selected()],
			["Retreat (X)", func(): retreat_selected()]]:
		var b := UIKit.button(String(spec[0]), spec[1], Vector2(66, 30))
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		row2.add_child(b)
	_squad_label = UIKit.label("", 14, UIKit.MUTED)
	_squad_label.custom_minimum_size = Vector2(340, 0)
	pv.add_child(_squad_label)

	_hint = UIKit.label("LMB select · RMB move/attack/rescue · 1-5 focus · Tab group · G squad · Q-R skills · A attack-move · H hold · F follow · C regroup · X retreat · S stop · M map", 13, UIKit.MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position += Vector2(14, -34)
	add_child(_hint)

	_band = ColorRect.new()
	_band.color = Color(0.45, 0.85, 0.50, 0.22)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	add_child(_band)


# --- selection / camera commands (public so tests and a future HUD can call them) ----------

func select_only(list: Array) -> void:
	selected.clear()
	for h in heroes:
		h.selected = h.alive and list.has(h)
		if h.selected:
			selected.append(h)
	_refresh_info()


func select_slot(i: int) -> void:
	if i < 0 or i >= heroes.size() or not heroes[i].alive:
		return
	overview = false
	select_only([heroes[i]])
	follow_slot = i


func select_all() -> void:
	select_only(heroes)


func group_view() -> void:
	follow_slot = -1


## Pure data: where the camera wants to be. update_camera() eases toward it each frame.
func update_camera_targets() -> void:
	if heroes.is_empty():
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
	var need := (hi - lo) + Vector2(360, 300)
	camera_zoom_target = clampf(minf(view.x / need.x, view.y / need.y), GROUP_ZOOM_MIN, GROUP_ZOOM_MAX)


func screen_to_world(p: Vector2) -> Vector2:
	var view := Vector2(_viewport.size)
	return camera.position + (p - view * 0.5) / camera.zoom.x


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
	for e in living_enemies():
		if (e.position + Vector2(0, -14)).distance_to(world_point) <= 26.0:
			for h in selected:
				h.order_attack(e)
			_mark(e.position, Color(1.0, 0.35, 0.3))
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
func use_skill_selected(slot_index: int = 0) -> int:
	var fired := 0
	var foes := living_enemies()
	for h in selected:
		if h.use_skill_slot(slot_index, foes, heroes):
			fired += 1
		elif h.alive:
			FloatingText.spawn(h, h.last_refusal, Color(0.8, 0.8, 0.8), false)
	return fired


# --- simulation ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if mission_state != Mission.ACTIVE:
		return                                    # mission over: the result screen is up
	var foes := living_enemies()
	for h in heroes:
		h.tick(delta)
		h.combat_tick(foes, map)
	var targets := heroes.filter(func(h): return not h.dead)
	for e in foes:
		e.tick(delta, targets, map)
	for h in heroes:
		if not h.alive and selected.has(h):
			selected.erase(h)
	_separate()
	_separate_enemies()
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
				if clue.visible and heroes.any(func(h): return h.alive and h.position.distance_to(clue.position) <= CLUE_RADIUS):
					clue.visible = false
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
	for h in heroes:
		h.stop()
	if state == Mission.SUCCESS and real_squad and not reward_given:
		reward_given = true
		if floor_number > 0:
			reward = Game.complete_floor(floor_number, mission_type)
		else:
			Game.grant(REWARD_GEMS, REWARD_STONES, 0)
	if real_squad and not expedition_applied:
		# the town lives on while the squad was away; survivors come home tired, maybe sick (HQ Phase 1)
		expedition_applied = true
		var results: Array = []
		for h in heroes:
			if not h.dead:
				results.append({"hero": h.hero, "downed": h.was_downed, "poisoned": h.was_poisoned})
		town_report = Game.after_expedition(results, floor_number, fallen.size())
	_show_result()


func result_text() -> String:
	var lines: Array = []
	lines.append("MISSION COMPLETE" if mission_state == Mission.SUCCESS else "MISSION FAILED")
	lines.append(mission_title() if floor_number > 0 else MISSION_NAME)
	lines.append("Time: %d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60])
	lines.append("Enemies defeated: %d / %d" % [defeated, enemies.size()])
	lines.append("Survivors: %d / %d" % [living_heroes().size(), heroes.size()])
	if not fallen.is_empty():
		lines.append("Fallen (permanent): %s" % ", ".join(fallen))
	if mission_state == Mission.SUCCESS:
		if not real_squad:
			lines.append("Reward: none (test squad)")
		elif floor_number > 0:
			lines.append("Reward: %d gems, %d stones, %d materials, %d books" % [int(reward.get("gems", 0)), int(reward.get("stones", 0)), int(reward.get("materials", 0)), int(reward.get("books", 0))])
			for b in reward.get("skill_books", []):
				lines.append("Skill book found: %s" % String(SkillDefs.info(String(b)).get("name", b)))
			for it in reward.get("items", []):
				lines.append("Loot: %s" % String(it))
			if int(reward.get("left_behind", 0)) > 0:
				lines.append("%d item(s) left behind: the stash is full (upgrade the warehouse)" % int(reward["left_behind"]))
		else:
			lines.append("Reward: %d gems, %d stone (placeholder)" % [REWARD_GEMS, REWARD_STONES])
	if not town_report.is_empty():
		lines.append("Back in town: a day passed.")
		var evs: Array = town_report.get("events", [])
		for i in mini(4, evs.size()):
			lines.append("  " + String(evs[i]))
	return "\n".join(lines)


func _show_result() -> void:
	var center := CenterContainer.new()
	add_child(center)
	UIKit.fill(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := UIKit.label(result_text(), 18, UIKit.TEXT)
	title.custom_minimum_size = Vector2(380, 0)
	vb.add_child(title)
	vb.add_child(UIKit.button("Back to menu", func(): back_requested.emit(), Vector2(380, 44)))
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


## Enemies keep apart from each other and from heroes (only the enemy is pushed).
func _separate_enemies() -> void:
	var live := living_enemies()
	for i in live.size():
		var a: SandboxEnemy = live[i]
		for j in range(i + 1, live.size()):
			var b: SandboxEnemy = live[j]
			var d := b.position - a.position
			var dist := d.length()
			if dist < SEPARATION * 0.9 and dist > 0.01:
				var push := d / dist * (SEPARATION * 0.9 - dist) * 0.5
				_nudge_any(a, -push)
				_nudge_any(b, push)
		for h in heroes:
			if not h.alive:
				continue
			var d2 := a.position - h.position
			var dist2 := d2.length()
			if dist2 < SEPARATION * 0.8 and dist2 > 0.01:
				_nudge_any(a, d2 / dist2 * (SEPARATION * 0.8 - dist2))


func _nudge_any(n: Node2D, v: Vector2) -> void:
	var np := n.position + v
	if not map.is_blocked(np):
		n.position = np


func _nudge(h: SandboxHero, v: Vector2) -> void:
	var np := h.position + v
	if not map.is_blocked(np):
		h.position = np


func _process(delta: float) -> void:
	update_camera_targets()
	var k := minf(1.0, delta * 6.0)
	camera.position = camera.position.lerp(camera_target, k)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * camera_zoom_target, k)
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
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
	select_only(picked)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			select_slot(event.keycode - KEY_1)
		KEY_TAB:
			overview = false
			group_view()
		KEY_M:
			overview = not overview
		KEY_G:
			select_all()
		KEY_Q:
			use_skill_selected(0)
		KEY_W:
			use_skill_selected(1)
		KEY_E:
			use_skill_selected(2)
		KEY_R:
			use_skill_selected(3)
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
			_arming_attack_move = false
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
			sk_lines.append("%s %s [%s]" % ["QWER"[i], sk["name"], sk_state])
		_info.text = "%s\n%s\n%s  |  %d-star %s  |  Lv %d\nHP %d/%d  %s %d/%d  ATK %d  MAG %d  DEF %d\nTrust %d   Obedience %d   Composure %d\nSkills: %s\nOrder: %s%s" % [
			view, goal, h.display_name(), h.stars, h.class_title(), h.level,
			sh.hp, sh.max_hp, SkillDefs.RESOURCES[sh.res_kind]["name"], roundi(sh.res), roundi(sh.res_max), st["atk"], st["mag"], st["def"], h.trust, h.obedience, h.composure,
			"  ".join(sk_lines) if not sk_lines.is_empty() else "none", sh.order_label(), ("  · casting " + String(SkillDefs.info(sh.casting)["name"])) if sh.casting != "" else ""]
	else:
		var names: Array = []
		for s in selected:
			names.append(s.hero.hero_name.split(" ")[0])
		_info.text = "%s\n%s\n%d heroes selected: %s\nOrders: Move (right-click), Stop (S), Skills (Q W E R)" % [view, goal, selected.size(), ", ".join(names)]
	for i in _skill_btns.size():
		var slot_i := i
		var b := _skill_btns[i]
		b.disabled = not selected.any(func(h): return h.skill_ready(slot_i))
		if selected.size() == 1 and i < (selected[0] as SandboxHero).slots.size():
			var nm := String((selected[0] as SandboxHero).slot_skill(i)["name"])
			b.text = "%s %s" % ["QWER"[i], nm.left(7)]
			b.tooltip_text = String((selected[0] as SandboxHero).slot_skill(i)["desc"])
		else:
			b.text = "QWER"[i]
	var rows: Array = []
	for i in heroes.size():
		var hh := heroes[i]
		var nm := hh.hero.hero_name.split(" ")[0]
		if hh.alive:
			var ready: Array = []
			for k in hh.slots.size():
				if hh.skill_ready(k):
					ready.append("QWER"[k])
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
