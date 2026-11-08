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


func _ready() -> void:
	world = CombatWorld.new(1337)
	_loot_rng.seed = 4242
	arena.build(world)
	hud.bind(world)
	loadout_panel.set_world(world)
	world.warrior.progression.leveled_up.connect(func(_l: int) -> void: _refresh_status())
	world.warrior.weapon_changed.connect(func(_i: Item) -> void: _refresh_status())
	_refresh_status()
	TickManager.register(world)


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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F5: world.warrior.progression.set_level(world.warrior.progression.level + 5)
			KEY_F6:
				var item := ItemFactory.roll_weapon(_loot_rng, world.warrior.progression.level)
				world.warrior.equip_weapon(item)
				print(item.describe())
			KEY_F7: world.warrior.progression.set_level(Progression.MAX_LEVEL)
	if loadout_panel.visible:
		return
	if event is InputEventMouseMotion:
		arena.tp_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arena.tp_zoom_by(-0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arena.tp_zoom_by(0.1)


func _process(_delta: float) -> void:
	var want := Input.MOUSE_MODE_CAPTURED if not loadout_panel.visible else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	crosshair.visible = not loadout_panel.visible


func _exit_tree() -> void:
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

	if loadout_panel.visible:
		return

	if Input.is_action_just_pressed("restart_training"):
		world.reset()

	if Input.is_action_just_pressed("refill_resources"):
		world.warrior.debug_refill()

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

	message.actions = {
		"m1": Input.is_action_pressed("attack_m1"),
		"m2": Input.is_action_pressed("attack_m2"),
		"shift": Input.is_action_pressed("slot_shift"),
		"jump": Input.is_action_pressed("jump"),
		"q": Input.is_action_pressed("slot_q"),
		"e": Input.is_action_pressed("slot_e"),
		"r": Input.is_action_pressed("slot_r"),
		"f": Input.is_action_pressed("slot_f"),
	}
	return message
