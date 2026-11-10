## Main3D — punto de entrada del prototipo 3D de Reflections.
##
## Los nodos (Arena, Level, HUD…) están en main_3d.tscn; aquí solo se crea la
## simulación y se traduce el input. Cámara en tercera persona: el apuntado es un
## rayo desde la mira central al suelo y WASD es relativo a la cámara.
##
## LMB/RMB = M1/M2; Shift/Q/E/R/F = slots; Space = saltar; rueda = zoom.
## Tab abre el editor (pausa TickManager), F2 reinicia, F4 rellena Rage/Ultimate,
## F5/F6/F7 = debug de nivel y armas.
extends Node3D

@onready var arena: Arena3D = $Arena
@onready var hud: GameHud = $HudLayer/Hud
@onready var crosshair: Control = $HudLayer/Crosshair
@onready var status_label: Label = $HudLayer/Status
@onready var loadout_panel: LoadoutPanel = $LoadoutLayer/LoadoutPanel
@onready var debug_overlay: CanvasLayer = $DebugOverlay

var world: CombatWorld
var _loot_rng := RandomNumberGenerator.new()
var _quick_cast_enabled: bool = true  # X alterna; solo aplica en top-down
var _floor: Dictionary = {}
var _town: Dictionary = {}
var _floor_save: Dictionary = {}
var floor_ctl: FloorController
var reward_panel: RewardPanel
var _exit_open: bool = false
## Niveles de calidad. El juego arranca en el más nítido (MSAA 2x) y baja solo si los FPS caen de ~52,
## para sostener los 60 sin perder definición más de lo necesario. F11 los recorre a mano.
const QUALITY := [
	{"name": "Alta (MSAA 2x)", "msaa": Viewport.MSAA_2X, "fxaa": false, "scale": 1.0, "reach": 1.0},
	{"name": "Media (FXAA)", "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "scale": 1.0, "reach": 0.8},
	{"name": "Rendimiento (FXAA, 85% FSR)", "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "scale": 0.85, "reach": 0.65},
	{"name": "Mínima (FXAA, 70% FSR)", "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "scale": 0.7, "reach": 0.5},
]
var _auto_quality: bool = true
var _fps_clock: float = 0.0
var _fps_frames: int = 0
var _slow_windows: int = 0
var npc_panel: NpcPanel
var char_panel: CharacterPanel
var unit_bars: UnitBars
var _elixir_time: float = 0.0
var _elixir_factor: float = 1.25
var _potions_used: int = 0
var _quest_label: Label
var _quest_done: bool = false
var _mats_label: Label
var _hint_label: Label
var _toast_label: Label
var _toast_time: float = 0.0
var _drop_rng := RandomNumberGenerator.new()
const GATHER_RANGE := 75.0


func _ready() -> void:
	_loaded_at = Time.get_ticks_msec()
	_apply_quality(CharacterProfile.quality_step)
	status_label.position = Vector2(8.0, 6.0)  # el panel de recursos ahora va abajo: la esquina queda libre
	world = CombatWorld.new(1337)
	if CharacterProfile.chosen:
		world.warrior.set_class(CharacterProfile.class_id)
	_loot_rng.seed = 4242
	var w := world.warrior
	if CharacterProfile.level > 1:
		w.progression.set_level(CharacterProfile.level)
		w.progression.xp = CharacterProfile.xp
	if CharacterProfile.weapon != null:
		w.equip_weapon(CharacterProfile.weapon)
	for piece: Item in CharacterProfile.armor.values():
		w.equip_armor(piece)
	if not CharacterProfile.started:  # kit inicial: dos pociones de vida
		CharacterProfile.started = true
		Materials.add("pocion_vida", 2)
	match CharacterProfile.mode:
		"floor":
			var fl := CharacterProfile.current_floor
			if not CharacterProfile.floor_saves.has(fl):  # primera visita: se genera y queda guardado
				CharacterProfile.floor_saves[fl] = {"seed": randi() % 1000000 + 1, "dead": [], "gathered": [], "done": false, "mission_state": {}, "rewarded": false}
			_floor_save = CharacterProfile.floor_saves[fl]
			_floor = MeadowFloor.generate(int(_floor_save["seed"]), fl, CharacterProfile.force_mission)
			_quest_done = bool(_floor_save["done"])
			_exit_open = _quest_done
			arena.build_floor(world, _floor, _floor_save)
			arena.boss_phase.connect(func(boss: WarriorSim, phase: int) -> void: _toast("¡%s entra en fase %d!" % [boss.display_name, phase]))
			_build_quest_ui()
			_drop_rng.seed = int(_floor_save["seed"]) * 7919
			for fighter: WarriorSim in world.fighters:
				var f := fighter
				f.died.connect(func() -> void: _on_enemy_died(f))
			floor_ctl = FloorController.new()
			add_child(floor_ctl)
			floor_ctl.setup(self, arena, world, _floor, _floor_save)
			reward_panel = RewardPanel.new()
			reward_panel.sfx = Callable(self, "_ui_sfx")
			$HudLayer.add_child(reward_panel)
			floor_ctl.completed.connect(func(result: Dictionary) -> void: reward_panel.show_result(result))
		"town":
			_town = Town.generate(7)
			arena.build_town(world, _town)
			_build_quest_ui()
			npc_panel = NpcPanel.new()
			npc_panel.sfx = Callable(self, "_ui_sfx")
			$HudLayer.add_child(npc_panel)
		_:
			arena.build(world)
	unit_bars = UnitBars.new()
	unit_bars.arena = arena
	$HudLayer.add_child(unit_bars)
	$HudLayer.move_child(unit_bars, 0)
	char_panel = CharacterPanel.new()
	char_panel.warrior = world.warrior
	char_panel.sfx = Callable(self, "_ui_sfx")
	$HudLayer.add_child(char_panel)
	hud.bind(world)
	loadout_panel.set_world(world)
	world.warrior.progression.leveled_up.connect(func(_l: int) -> void:
		_refresh_status()
		arena.play_sfx(&"levelup", -4.0)
		_toast("¡Subiste de nivel!"))
	world.warrior.weapon_changed.connect(func(_i: Item) -> void: _refresh_status())
	_refresh_status()
	TickManager.register(world)
	if CharacterProfile.chosen:
		SaveGame.save()


func _ui_sfx(category: StringName, volume_db: float = -8.0) -> void:
	arena.play_sfx(category, volume_db)


func _apply_quality(step: int) -> void:
	CharacterProfile.quality_step = clampi(step, 0, QUALITY.size() - 1)
	var q: Dictionary = QUALITY[CharacterProfile.quality_step]
	var vp := get_viewport()
	vp.msaa_3d = q["msaa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if float(q["scale"]) < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = float(q["scale"])
	arena.set_decor_reach(float(q["reach"]))  # menos distancia de dibujo de vegetación en calidades bajas
	if _toast_label != null:
		_toast("Calidad gráfica: %s" % q["name"])


## Si el promedio de FPS de 5 s baja de 52, baja un nivel de calidad (con 6 s de gracia tras cargar).
func _auto_quality_tick(delta: float) -> void:
	if not _auto_quality:
		return
	_fps_clock += delta
	_fps_frames += 1
	if _fps_clock < 5.0:
		return
	var avg := float(_fps_frames) / _fps_clock
	var settled := Time.get_ticks_msec() - _loaded_at > 10000
	_fps_clock = 0.0
	_fps_frames = 0
	_slow_windows = _slow_windows + 1 if (settled and avg < 52.0) else 0
	if _slow_windows >= 2 and CharacterProfile.quality_step < QUALITY.size() - 1:  # dos ventanas lentas seguidas
		_slow_windows = 0
		_apply_quality(CharacterProfile.quality_step + 1)


func _modal_open() -> bool:
	return (npc_panel != null and npc_panel.visible) or (char_panel != null and char_panel.visible) or (reward_panel != null and reward_panel.visible)


func _save_progress() -> void:
	_save_progress_state()
	if CharacterProfile.chosen:  # solo partidas reales (no escenas de prueba)
		SaveGame.save()


func _save_progress_state() -> void:
	if floor_ctl != null and not _floor_save.is_empty():
		floor_ctl.save_into(_floor_save)
	if world != null and CharacterProfile.mode == "floor" and not _floor_save.is_empty():
		var dead: Array = (_floor_save["dead"] as Array).duplicate()
		for fighter: WarriorSim in arena.enemy_index:
			var index: int = arena.enemy_index[fighter]
			if not fighter.alive and not (index in dead):  # sin duplicados: se guarda al cambiar de modo y otra vez al salir
				dead.append(index)
		_floor_save["dead"] = dead
		var gathered: Array = []
		for i in range(arena.gather_nodes.size()):
			if not arena.gather_nodes[i]["left"]:
				gathered.append(i)
		_floor_save["gathered"] = gathered
		_floor_save["done"] = _quest_done
	if world != null:
		CharacterProfile.level = world.warrior.progression.level
		CharacterProfile.xp = world.warrior.progression.xp


## Cambia de modo (town / floor / training) recargando la escena; guarda nivel y XP.
func _goto(mode: String) -> void:
	_save_progress()
	CharacterProfile.mode = mode
	get_tree().reload_current_scene()


func _build_quest_ui() -> void:
	_quest_label = Label.new()
	_quest_label.position = Vector2(260.0, 6.0)
	_quest_label.add_theme_font_size_override("font_size", 11)
	_quest_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quest_label.add_theme_constant_override("outline_size", 6)
	$HudLayer.add_child(_quest_label)
	_mats_label = _label(Vector2(8.0, 40.0), 8, Color(0.9, 0.95, 1.0))
	_hint_label = _label(Vector2(250.0, 232.0), 11, Color(1.0, 1.0, 0.7))
	_toast_label = _label(Vector2(250.0, 214.0), 11, Color(0.7, 1.0, 0.75))


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	$HudLayer.add_child(label)
	return label


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_time = 2.5


func _on_enemy_died(fighter: WarriorSim) -> void:
	if floor_ctl != null:
		floor_ctl.on_enemy_died(fighter)
	var drops := Materials.drops_for(fighter.archetype_id, _drop_rng, int(_floor.get("floor", 1)))
	var parts: Array = []
	for id: String in drops:
		Materials.add(id, int(drops[id]))
		parts.append("+%d %s" % [drops[id], Materials.display(id)])
	var drop := Loot.roll(EnemyArchetypes.tier_of(fighter.archetype_id) if EnemyArchetypes.TYPES.has(fighter.archetype_id) else "minion", int(_floor.get("floor", 1)), world.warrior.class_id, _drop_rng)
	if drop != null:
		parts.append(Loot.give(drop, world.warrior))
		arena.play_sfx(&"coin", -4.0)
	if not parts.is_empty():
		_toast(", ".join(parts))


## F: recoge el nodo de recolección más cercano (mineral, hierba, madera...).
func _nearest_station() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for st: Dictionary in _town.get("stations", []):
		var d := world.warrior.position.distance_to(st["pos"])
		if d < float(st["radius"]) and d < best_d:
			best_d = d
			best = st
	return best


func _nearest_exit() -> bool:
	return CharacterProfile.mode == "floor" and _quest_done and int(_floor["floor"]) < MeadowFloor.MAX_FLOOR and world.warrior.position.distance_to(_floor["exit"]) < 150.0


func _interact() -> void:
	if not world.warrior.alive or _modal_open():
		return
	if _nearest_exit():
		arena.play_sfx(&"portal", -4.0)
		CharacterProfile.current_floor = int(_floor["floor"]) + 1
		_goto("floor")
		return
	if floor_ctl != null and floor_ctl.try_interact():
		return
	var st := _nearest_station()
	if not st.is_empty():
		if st["id"] == "portal":
			arena.play_sfx(&"portal", -4.0)
			_goto("floor")
		else:
			arena.play_sfx(&"npc_talk", -6.0)
			arena.play_sfx(&"ui_open", -8.0)
			npc_panel.open_for(st, world.warrior)
		return
	var near := _nearest_gather()
	if not near.is_empty():
		_gather(near)


## Usa la poción del tipo pedido; si tienes la versión Mayor (grado 2) se gasta primero.
func _use_potion(base_id: String) -> void:
	var id: String = String(Materials.UPGRADE.get(base_id, base_id))
	if int(Materials.inventory.get(id, 0)) <= 0:
		id = base_id
	if int(Materials.inventory.get(id, 0)) <= 0 or not world.warrior.alive or _modal_open():
		return
	var big := id != base_id
	var w := world.warrior
	match base_id:
		"pocion_vida":
			if w.health >= w.max_health:
				return
			var frac := 0.7 if big else 0.4
			w.health = minf(w.max_health, w.health + w.max_health * frac)
			arena.play_sfx(&"drink", -6.0)
			arena.play_sfx(&"heal", -10.0)
			_toast("%s: +%d%% de vida" % [Materials.display(id), int(frac * 100.0)])
		"elixir_fuerza":
			if _elixir_time > 0.0:
				return
			_elixir_factor = 1.4 if big else 1.25
			w.mods["damage_mult"] = float(w.mods.get("damage_mult", 1.0)) * _elixir_factor
			_elixir_time = 60.0
			arena.play_sfx(&"drink", -6.0)
			arena.play_sfx(&"buff", -8.0)
			_toast("%s: +%d%% de daño (60 s)" % [Materials.display(id), int((_elixir_factor - 1.0) * 100.0)])
		"pocion_arcana":
			var share := 1.0 if big else 0.6
			w.resource.current_amount = minf(w.resource.max_amount, w.resource.current_amount + w.resource.max_amount * share)
			arena.play_sfx(&"drink", -6.0)
			arena.play_sfx(&"absorb", -9.0)
			_toast("%s: recurso restaurado" % Materials.display(id))
	_potions_used += 1
	if floor_ctl != null:
		floor_ctl.on_potion()
	Materials.inventory[id] = int(Materials.inventory[id]) - 1


func _nearest_gather() -> Dictionary:
	var best: Dictionary = {}
	var best_d := GATHER_RANGE
	for entry: Dictionary in arena.gather_nodes:
		if not entry["left"]:
			continue
		var d := world.warrior.position.distance_to(entry["data"]["pos"])
		if d < best_d:
			best_d = d
			best = entry
	return best


func _open_chest(entry: Dictionary) -> void:
	entry["left"] = false
	(entry["node"] as Node3D).visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_floor_save["seed"]) * 31 + int((entry["data"]["pos"] as Vector2).x)  # el botín depende de la semilla del piso
	var loot := Materials.roll_chest(rng, int(_floor["floor"]))
	var parts: Array = []
	for id: String in loot:
		Materials.add(id, int(loot[id]))
		parts.append("+%d %s" % [loot[id], Materials.display(id)])
	var chest_item := Loot.roll("chest", int(_floor["floor"]), world.warrior.class_id, rng)
	if chest_item != null:
		parts.append(Loot.give(chest_item, world.warrior))
	arena.play_sfx(&"coin", -5.0)
	arena.play_sfx(&"gather_wood", -9.0)
	ArcaneFx.burst(arena, View3D.to3(entry["data"]["pos"], 0.8), Color(1.0, 0.85, 0.35), 30, 2.6, 0.13)
	_toast("Cofre: " + ", ".join(parts))
	if floor_ctl != null:
		floor_ctl.on_chest({"pos": entry["data"]["pos"], "secret": entry["data"].get("secret", false), "trapped": entry["data"].get("trapped", false)})


func _gather(entry: Dictionary) -> void:
	if String(entry["data"]["kind"]) == "chest":
		_open_chest(entry)
		return
	entry["left"] = false
	(entry["node"] as Node3D).visible = false
	var mat := String(entry["data"]["mat"])
	var amount := int(entry["amount"])
	Materials.add(mat, amount)
	var at := View3D.to3(entry["data"]["pos"], 0.6)
	match String(entry["data"]["kind"]):
		"ore", "stone": arena.play_sfx(&"gather_ore", -8.0)
		"wood": arena.play_sfx(&"gather_wood", -8.0)
		"herb", "flower", "fiber": arena.play_sfx(&"gather_herb", -8.0)
		_: arena.play_sfx(&"gather_misc", -8.0)
	ArcaneFx.burst(arena, at, Materials.DEFS[mat]["color"], 22, 2.2, 0.12)
	var text := "+%d %s" % [amount, Materials.display(mat)]
	if Materials.HEAL.has(mat):
		var w := world.warrior
		var healed: float = float(Materials.HEAL[mat]) * amount
		w.health = minf(w.max_health, w.health + healed)
		text += "  (+%d vida)" % int(healed)
	_toast(text)
	if floor_ctl != null:
		floor_ctl.on_gather(String(entry["data"]["kind"]), amount)


func _update_gather_ui(delta: float) -> void:
	if _hint_label == null:
		return
	_mats_label.visible = not _modal_open()
	_toast_label.visible = not _modal_open()
	var near := _nearest_gather()
	var station := _nearest_station()
	if npc_panel != null and npc_panel.visible:
		_hint_label.text = ""
	elif not station.is_empty():
		_hint_label.text = ("[F] Entrar a la Torre: piso %d   (←/→ cambiar · máx %d)" % [CharacterProfile.current_floor, CharacterProfile.max_floor]) if station["id"] == "portal" else "[F] Hablar con %s" % station["npc"]
	else:
		var iact: Dictionary = floor_ctl.nearest_interact() if floor_ctl != null else {}
		if not iact.is_empty():
			_hint_label.text = "[F] %s" % iact["label"]
		else:
			_hint_label.text = "[F] Subir al piso %d" % (int(_floor["floor"]) + 1) if _nearest_exit() else "" if near.is_empty() else "[F] Recoger: %s" % Materials.NODES[near["data"]["kind"]]["label"]
	if _elixir_time > 0.0:
		_elixir_time -= delta
		if _elixir_time <= 0.0:
			world.warrior.mods["damage_mult"] = float(world.warrior.mods.get("damage_mult", 1.0)) / _elixir_factor
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast_label.modulate.a = clampf(_toast_time, 0.0, 1.0)
	var lines: Array = []
	for id: String in Materials.DEFS:
		if int(Materials.inventory.get(id, 0)) > 0:
			lines.append("%s x%d" % [Materials.display(id), Materials.inventory[id]])
	_mats_label.text = "Materiales
" + "
".join(lines) if not lines.is_empty() else ""


func _update_quest() -> void:
	if _quest_label == null:
		return
	if CharacterProfile.mode == "town":
		_quest_label.text = "PUEBLO · Portal al norte"
		_quest_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		return
	if floor_ctl == null:
		return
	_quest_done = floor_ctl.runtime.complete
	_quest_label.text = floor_ctl.hud_text()
	_quest_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5) if _quest_done else Color(1.0, 0.92, 0.6))


func _refresh_status() -> void:
	var w := world.warrior
	var weapon := w.weapon
	var line1 := "Nv.%d   XP %d/%d   ·   %s [%s]" % [
		w.progression.level, w.progression.xp, Progression.xp_to_next(w.progression.level),
		weapon.item_name, ItemRarity.display(weapon.rarity),
	]
	var line2 := "%d–%d daño · vel %.1f · AP %d · golpe medio %d" % [
		weapon.weapon_min, weapon.weapon_max, weapon.weapon_speed, w.stats.get_attack_power(), w.average_hit(),
	]
	status_label.text = line1 + "\n" + line2
	status_label.add_theme_color_override("font_color", ItemRarity.color(weapon.rarity))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		arena.toggle_topdown()  # C: alterna tercera persona <-> top-down
	if event.is_action_pressed("toggle_quickcast"):
		_quick_cast_enabled = not _quick_cast_enabled
	if event.is_action_pressed("tilt_up"):
		arena.tilt_topdown(0.1)
	if event.is_action_pressed("tilt_down"):
		arena.tilt_topdown(-0.1)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F: _interact()
			KEY_F11:  # calidad gráfica manual (desactiva el ajuste automático)
				_auto_quality = false
				_apply_quality((CharacterProfile.quality_step + 1) % QUALITY.size())
			KEY_LEFT, KEY_RIGHT:  # junto al portal del pueblo: elegir piso entre los desbloqueados
				var here := _nearest_station()
				if CharacterProfile.mode == "town" and not here.is_empty() and here["id"] == "portal":
					CharacterProfile.current_floor = clampi(CharacterProfile.current_floor + (1 if event.physical_keycode == KEY_RIGHT else -1), 1, CharacterProfile.max_floor)
			KEY_I:
				if not (npc_panel != null and npc_panel.visible):
					char_panel.toggle()
			KEY_H: _use_potion("pocion_vida")
			KEY_J: _use_potion("elixir_fuerza")
			KEY_K: _use_potion("pocion_arcana")
			KEY_F3:
				var order := ["town", "floor", "training"]
				_goto(order[(order.find(CharacterProfile.mode) + 1) % order.size()])
			KEY_ENTER, KEY_KP_ENTER:
				if _quest_done and not _modal_open():
					_goto("town")
			KEY_F5: world.warrior.progression.set_level(world.warrior.progression.level + 5)
			KEY_F6:
				var item := ItemFactory.roll_weapon(_loot_rng, world.warrior.progression.level)
				world.warrior.equip_weapon(item)
				print(item.describe())
			KEY_F7: world.warrior.progression.set_level(Progression.MAX_LEVEL)
			KEY_F10:  # enjambre: 4 esbirros alrededor
				arena.spawn_swarm("esbirro", 4, world.warrior.position + Vector2(280.0, 0.0), world.warrior.progression.level)
			KEY_F9:  # enemigo de clase al azar delante del jugador (con su nivel)
				var pool: Array = EnemyArchetypes.ids()
				arena.spawn_class_enemy(StringName(String(pool[randi() % pool.size()])), world.warrior.position + Vector2(260.0, randf_range(-90.0, 90.0)), world.warrior.progression.level)
	if loadout_panel.visible:
		return
	if event is InputEventMouseMotion:
		if not arena.topdown:
			arena.tp_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arena.tp_zoom_by(-0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arena.tp_zoom_by(0.1)


var _autosave_clock: float = 0.0
var _loaded_at: int = 0


func _process(_delta: float) -> void:
	_auto_quality_tick(_delta)
	_autosave_clock += _delta
	if _autosave_clock > 45.0 and CharacterProfile.chosen:  # autoguardado cada 45 s
		_autosave_clock = 0.0
		_save_progress()
	var want := Input.MOUSE_MODE_CAPTURED if not (loadout_panel.visible or arena.topdown) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	crosshair.visible = not loadout_panel.visible and not arena.topdown
	_update_ground_marker()
	_update_quest()
	_update_gather_ui(_delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()


func _exit_tree() -> void:
	_save_progress()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if TickManager.is_paused():
		TickManager.set_paused(false)
	if world != null and TickManager.is_registered(world):
		TickManager.unregister(world)


func _physics_process(_delta: float) -> void:
	if world == null:
		return

	if Input.is_action_just_pressed("toggle_loadout"):
		loadout_panel.toggle()

	if loadout_panel.visible or _modal_open():
		return

	if Input.is_action_just_pressed("restart_training"):
		world.reset()

	if Input.is_action_just_pressed("refill_resources"):
		world.warrior.debug_refill()

	world.warrior.quick_cast = _quick_cast_enabled and arena.topdown
	world.submit_input(_read_input())


func _read_input() -> InputMessage:
	var message := InputMessage.new()
	message.tick = TickManager.current_tick + 1
	message.peer_id = 1
	message.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fwd := arena.cam_forward_sim()
	var right := Vector2(-fwd.y, fwd.x)
	message.move_dir = (fwd * -message.move_dir.y + right * message.move_dir.x).limit_length(1.0)

	message.aim_dir = world.warrior.aim_dir
	var mouse: Variant = arena.mouse_sim()
	if mouse != null:
		var aim: Vector2 = mouse - world.warrior.position
		if aim.length_squared() > 4.0:
			message.aim_dir = aim.normalized()
		message.aim_point = mouse
		message.has_aim_point = true

	var in_town := CharacterProfile.mode == "town"
	if in_town:  # en el pueblo se camina, no se corre ni se pelea
		message.move_dir *= 0.5
	message.actions = {
		"m1": not in_town and Input.is_action_pressed("attack_m1"),
		"m2": not in_town and Input.is_action_pressed("attack_m2"),
		"shift": not in_town and Input.is_action_pressed("slot_shift"),
		"q": not in_town and Input.is_action_pressed("slot_q"),
		"e": not in_town and Input.is_action_pressed("slot_e"),
		"s1": not in_town and Input.is_action_pressed("slot_1"),
		"s2": not in_town and Input.is_action_pressed("slot_2"),
		"r": not in_town and Input.is_action_pressed("slot_r"),  # ultimate
		"interact": Input.is_action_just_pressed("interact"),
	}
	return message


## Marcador de skills de suelo (Smite): sigue a la mira, limitado al alcance.
func _update_ground_marker() -> void:
	if world == null:
		return
	arena.set_aim_indicator(arena.topdown and world.warrior.alive and not loadout_panel.visible, world.warrior.position, world.warrior.aim_dir)
	var warrior := world.warrior
	var mouse: Variant = arena.mouse_sim()
	var slot := warrior.ground_slot_ready()
	if slot.is_empty() or mouse == null or loadout_panel.visible:
		arena.set_ground_marker(false, Vector2.ZERO, 0.0)
		return
	var ability := warrior.ability_for_slot(slot)
	var point := warrior.clamp_ground_point(mouse, ability)
	arena.set_ground_marker(true, point, float(ability.get("radius", 100.0)), warrior.position, float(ability.get("range", 0.0)))
