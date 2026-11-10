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
var npc_panel: NpcPanel
var _elixir_time: float = 0.0
var _quest_label: Label
var _quest_done: bool = false
var _mats_label: Label
var _hint_label: Label
var _toast_label: Label
var _toast_time: float = 0.0
var _drop_rng := RandomNumberGenerator.new()
const GATHER_RANGE := 75.0


func _ready() -> void:
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
			_floor = MeadowFloor.generate(CharacterProfile.floor_seed)
			arena.build_floor(world, _floor)
			_build_quest_ui()
			_drop_rng.seed = CharacterProfile.floor_seed * 7919
			for fighter: WarriorSim in world.fighters:
				var f := fighter
				f.died.connect(func() -> void: _on_enemy_died(f))
		"town":
			_town = Town.generate(7)
			arena.build_town(world, _town)
			_build_quest_ui()
			npc_panel = NpcPanel.new()
			$HudLayer.add_child(npc_panel)
		_:
			arena.build(world)
	hud.bind(world)
	loadout_panel.set_world(world)
	world.warrior.progression.leveled_up.connect(func(_l: int) -> void: _refresh_status())
	world.warrior.weapon_changed.connect(func(_i: Item) -> void: _refresh_status())
	_refresh_status()
	TickManager.register(world)


func _save_progress() -> void:
	if world != null:
		CharacterProfile.level = world.warrior.progression.level
		CharacterProfile.xp = world.warrior.progression.xp


## Cambia de modo (town / floor / training) recargando la escena; guarda nivel y XP.
func _goto(mode: String) -> void:
	_save_progress()
	CharacterProfile.mode = mode
	if mode == "floor":
		CharacterProfile.floor_seed = randi() % 1000000 + 1  # cada entrada a la Torre es un mapa nuevo
	get_tree().reload_current_scene()


func _build_quest_ui() -> void:
	_quest_label = Label.new()
	_quest_label.position = Vector2(260.0, 6.0)
	_quest_label.add_theme_font_size_override("font_size", 14)
	_quest_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quest_label.add_theme_constant_override("outline_size", 6)
	$HudLayer.add_child(_quest_label)
	_mats_label = _label(Vector2(8.0, 125.0), 14, Color(0.9, 0.95, 1.0))
	_hint_label = _label(Vector2(300.0, 230.0), 18, Color(1.0, 1.0, 0.7))
	_toast_label = _label(Vector2(300.0, 200.0), 18, Color(0.7, 1.0, 0.75))


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
	var drops := Materials.drops_for(fighter.archetype_id, _drop_rng)
	var parts: Array = []
	for id: String in drops:
		Materials.add(id, int(drops[id]))
		parts.append("+%d %s" % [drops[id], Materials.display(id)])
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


func _interact() -> void:
	if not world.warrior.alive or (npc_panel != null and npc_panel.visible):
		return
	var st := _nearest_station()
	if not st.is_empty():
		if st["id"] == "portal":
			_goto("floor")
		else:
			npc_panel.open_for(st, world.warrior)
		return
	var near := _nearest_gather()
	if not near.is_empty():
		_gather(near)


func _use_potion(id: String) -> void:
	if int(Materials.inventory.get(id, 0)) <= 0 or not world.warrior.alive:
		return
	var w := world.warrior
	match id:
		"pocion_vida":
			if w.health >= w.max_health:
				return
			w.health = minf(w.max_health, w.health + w.max_health * 0.4)
			_toast("Poción de Vida: +40% de vida")
		"elixir_fuerza":
			if _elixir_time > 0.0:
				return
			w.mods["damage_mult"] = float(w.mods.get("damage_mult", 1.0)) * 1.25
			_elixir_time = 60.0
			_toast("Elixir de Fuerza: +25% de daño (60 s)")
		"pocion_arcana":
			w.resource.current_amount = minf(w.resource.max_amount, w.resource.current_amount + w.resource.max_amount * 0.6)
			_toast("Poción Arcana: recurso restaurado")
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


func _gather(entry: Dictionary) -> void:
	entry["left"] = false
	(entry["node"] as Node3D).visible = false
	var mat := String(entry["data"]["mat"])
	var amount := int(entry["amount"])
	Materials.add(mat, amount)
	var at := View3D.to3(entry["data"]["pos"], 0.6)
	ArcaneFx.burst(arena, at, Materials.DEFS[mat]["color"], 22, 2.2, 0.12)
	var text := "+%d %s" % [amount, Materials.display(mat)]
	if mat == "hierba_curativa":
		var w := world.warrior
		w.health = minf(w.max_health, w.health + Materials.HERB_HEAL * amount)
		text += "  (+%d vida)" % int(Materials.HERB_HEAL * amount)
	_toast(text)


func _update_gather_ui(delta: float) -> void:
	if _hint_label == null:
		return
	var near := _nearest_gather()
	var station := _nearest_station()
	if npc_panel != null and npc_panel.visible:
		_hint_label.text = ""
	elif not station.is_empty():
		_hint_label.text = "[F] Entrar a la Torre" if station["id"] == "portal" else "[F] Hablar con %s" % station["npc"]
	else:
		_hint_label.text = "" if near.is_empty() else "[F] Recoger: %s" % Materials.NODES[near["data"]["kind"]]["label"]
	if _elixir_time > 0.0:
		_elixir_time -= delta
		if _elixir_time <= 0.0:
			world.warrior.mods["damage_mult"] = float(world.warrior.mods.get("damage_mult", 1.0)) / 1.25
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
	var quest: Dictionary = _floor["quest"]
	var kills := 0
	for fighter: WarriorSim in world.fighters:
		if fighter.team == 1 and not fighter.alive:
			kills += 1
	var goal := int(quest["kill"])
	if kills >= goal:
		_quest_done = true
	if _quest_done:
		_quest_label.text = "PISO %d · %s
¡Misión cumplida! (%d/%d)
Enter: volver al pueblo  ·  F3: cambiar modo" % [_floor["floor"], _floor["name"], kills, goal]
		_quest_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
	else:
		_quest_label.text = "PISO %d · %s
Misión: %s (%d/%d)" % [_floor["floor"], _floor["name"], quest["title"], kills, goal]
		_quest_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))


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
			KEY_H: _use_potion("pocion_vida")
			KEY_J: _use_potion("elixir_fuerza")
			KEY_K: _use_potion("pocion_arcana")
			KEY_F3:
				var order := ["town", "floor", "training"]
				_goto(order[(order.find(CharacterProfile.mode) + 1) % order.size()])
			KEY_ENTER, KEY_KP_ENTER:
				if _quest_done:
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


func _process(_delta: float) -> void:
	var want := Input.MOUSE_MODE_CAPTURED if not (loadout_panel.visible or arena.topdown) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	crosshair.visible = not loadout_panel.visible and not arena.topdown
	_update_ground_marker()
	_update_quest()
	_update_gather_ui(_delta)


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

	if loadout_panel.visible or (npc_panel != null and npc_panel.visible):
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

	message.actions = {
		"m1": Input.is_action_pressed("attack_m1"),
		"m2": Input.is_action_pressed("attack_m2"),
		"shift": Input.is_action_pressed("slot_shift"),
		"q": Input.is_action_pressed("slot_q"),
		"e": Input.is_action_pressed("slot_e"),
		"s1": Input.is_action_pressed("slot_1"),
		"s2": Input.is_action_pressed("slot_2"),
		"r": Input.is_action_pressed("slot_r"),  # ultimate
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
