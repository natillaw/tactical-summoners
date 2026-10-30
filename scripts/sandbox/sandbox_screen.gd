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

var floor_number: int = 0
var map: NavMap = null
var heroes: Array[SandboxHero] = []
var enemies: Array[SandboxEnemy] = []
var selected: Array[SandboxHero] = []
var mission_state: Mission = Mission.ACTIVE
var relic: SandboxRelic
var carrier: SandboxHero = null
var defeated: int = 0
var elapsed: float = 0.0
var fallen: Array = []                        # display names of heroes lost this mission
var real_squad: bool = false                  # true when the squad is the player's saved party
var reward_given: bool = false
var follow_slot: int = -1                     # -1 = group view
var camera: Camera2D
var camera_target: Vector2 = Vector2.ZERO
var camera_zoom_target: float = 1.0

var _viewport: SubViewport
var _world: Node2D
var _info: Label
var _hint: Label
var _squad_label: Label
var _skill_btn: Button
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

	relic = SandboxRelic.new()
	relic.position = map.center_of(map.relic_cell)      # never the extraction cell (F-003)
	_world.add_child(relic)
	_build_squad()
	_build_enemies()
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
		_world.add_child(h)
		heroes.append(h)


## Visual type per spawn (T-024). Cosmetic only: all enemies keep the same provisional stats for now.
const ENEMY_TYPES := ["orc", "orc_warrior", "skeleton_base", "skeleton_mage", "orc_rogue"]


func _build_enemies() -> void:
	var cells: Array[Vector2i] = map.enemy_spawn_cells
	if cells.is_empty():
		cells = [Vector2i(10, 10)]
	for i in cells.size():
		var c: Vector2i = cells[i]
		var e := SandboxEnemy.new()
		e.setup_type(ENEMY_TYPES[i % ENEMY_TYPES.size()])
		e.position = map.center_of(c)
		e.died.connect(func(_e): defeated += 1)
		_world.add_child(e)
		enemies.append(e)


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
	panel.position = Vector2(12, 56)
	add_child(panel)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pv)
	_info = UIKit.label("", 15, UIKit.TEXT)
	_info.custom_minimum_size = Vector2(340, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_info)
	var row := HBoxContainer.new()
	pv.add_child(row)
	_skill_btn = UIKit.button("Skill (Q)", func(): use_skill_selected(), Vector2(150, 34))
	_skill_btn.focus_mode = Control.FOCUS_NONE
	row.add_child(_skill_btn)
	var stop_btn := UIKit.button("Stop (S)", func(): stop_selected(), Vector2(110, 34))
	stop_btn.focus_mode = Control.FOCUS_NONE
	row.add_child(stop_btn)
	_squad_label = UIKit.label("", 14, UIKit.MUTED)
	_squad_label.custom_minimum_size = Vector2(340, 0)
	pv.add_child(_squad_label)

	_hint = UIKit.label("LMB select / drag box    RMB move    1-5 focus hero    Tab group view    G select squad    Q skill    S stop", 14, UIKit.MUTED)
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


func order_move_selected(world_point: Vector2) -> void:
	var n := selected.size()
	for i in n:
		var offset := Vector2.ZERO
		if n > 1 and i > 0:
			offset = Vector2.RIGHT.rotated(TAU * float(i - 1) / float(n - 1)) * FORMATION_RADIUS
		selected[i].order_move(map.find_path(selected[i].position, world_point + offset))


## Orders available to the panel and the keyboard. Never randomly refused (D-016).
func stop_selected() -> void:
	for h in selected:
		h.stop()
		h.target = null


## Fires the active skill of every selected hero that can use it. Returns how many fired.
func use_skill_selected() -> int:
	var fired := 0
	var foes := living_enemies()
	for h in selected:
		if h.use_skill(foes):
			fired += 1
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
	var friends := living_heroes()
	for e in foes:
		e.tick(delta, friends, map)
	for h in heroes:
		if not h.alive and selected.has(h):
			selected.erase(h)
	_separate()
	_update_mission(delta)


# --- mission: non-combat objective + extraction + result (T-011) ------------------------

func _update_mission(delta: float) -> void:
	elapsed += delta
	if carrier == null and relic.visible:
		for h in heroes:
			if h.alive and h.position.distance_to(relic.position) <= PICKUP_RADIUS:
				carrier = h
				h.carrying = true
				h.queue_redraw()
				relic.visible = false
				break
	if carrier != null and carrier.position.distance_to(map.center_of(map.extract_cell)) <= EXTRACT_RADIUS:
		_end_mission(Mission.SUCCESS)
	elif living_heroes().is_empty():
		_end_mission(Mission.FAILED)


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
	Game.record_death(h.hero, cause, MISSION_NAME)


func _end_mission(state: Mission) -> void:
	mission_state = state
	for h in heroes:
		h.stop()
	if state == Mission.SUCCESS and real_squad and not reward_given:
		reward_given = true
		Game.grant(REWARD_GEMS, REWARD_STONES, 0)
	_show_result()


func result_text() -> String:
	var lines: Array = []
	lines.append("MISSION COMPLETE" if mission_state == Mission.SUCCESS else "MISSION FAILED")
	lines.append(MISSION_NAME)
	lines.append("Time: %d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60])
	lines.append("Enemies defeated: %d / %d" % [defeated, enemies.size()])
	lines.append("Survivors: %d / %d" % [living_heroes().size(), heroes.size()])
	if not fallen.is_empty():
		lines.append("Fallen (permanent): %s" % ", ".join(fallen))
	if mission_state == Mission.SUCCESS:
		lines.append("Reward: %d gems, %d stone (placeholder)" % [REWARD_GEMS, REWARD_STONES] if real_squad else "Reward: none (test squad)")
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
			if event.pressed:
				_drag_start = event.position
				_dragging = true
			elif _dragging:
				_dragging = false
				_band.visible = false
				_finish_left(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			order_move_selected(screen_to_world(event.position))


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
			group_view()
		KEY_G:
			select_all()
		KEY_Q:
			use_skill_selected()
		KEY_S:
			stop_selected()
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
		var sk: Dictionary = sh.skill
		var sk_state := "READY" if sh.skill_ready() else "%.0fs" % sh.skill_cd
		_info.text = "%s\n%s\n%s  |  %d-star %s  |  Lv %d\nHP %d/%d  ATK %d  MAG %d  DEF %d  SPD %d\nTrust %d   Obedience %d   Composure %d\nSkill: %s [%s] - %s\nOrders: Move (right-click), Stop (S), Skill (Q)" % [
			view, goal, h.display_name(), h.stars, h.class_title(), h.level,
			sh.hp, sh.max_hp, st["atk"], st["mag"], st["def"], st["spd"], h.trust, h.obedience, h.composure,
			sk.get("name", "-"), sk_state, sk.get("desc", "")]
	else:
		var names: Array = []
		for s in selected:
			names.append(s.hero.hero_name.split(" ")[0])
		_info.text = "%s\n%s\n%d heroes selected: %s\nOrders: Move (right-click), Stop (S), Skill (Q)" % [view, goal, selected.size(), ", ".join(names)]
	if _skill_btn != null:
		var any_ready := selected.any(func(h): return h.skill_ready())
		_skill_btn.disabled = not any_ready
	var rows: Array = []
	for i in heroes.size():
		var hh := heroes[i]
		var nm := hh.hero.hero_name.split(" ")[0]
		if hh.alive:
			rows.append("%d %s  HP %d/%d  %s%s" % [i + 1, nm, hh.hp, hh.max_hp, "skill ready" if hh.skill_ready() else "skill %.0fs" % hh.skill_cd, "  [RELIC]" if hh.carrying else ""])
		else:
			rows.append("%d %s  FALLEN" % [i + 1, nm])
	_squad_label.text = "\n".join(rows)


func _objective_text() -> String:
	match mission_state:
		Mission.SUCCESS:
			return "complete"
		Mission.FAILED:
			return "failed"
	if carrier != null:
		return "carry the relic to EXIT"
	if map is SandboxMap:
		return "recover the relic (far room, top right)"
	return "find the relic in the far room and bring it back to EXTRACT"
