## Main3D — punto de entrada del prototipo 3D de Reflections.
##
## Igual que main.gd (2D) pero con Arena3D: la simulación, el HUD, el editor de
## loadout y el overlay de debug son exactamente los mismos. Solo cambia cómo se
## lee el apuntado: un rayo desde la cámara al plano del suelo.
##
## Esquema Battlerite: LMB/RMB = M1/M2; Space/Q/E/R/F = slots seleccionables.
## Tab abre el editor (pausa TickManager), F2 reinicia y F4 rellena Rage/Ultimate.
extends Node3D

const DebugOverlayScene := preload("res://ui/debug_overlay.tscn")

var world: CombatWorld
var arena: Arena3D
var hud: GameHud
var loadout_panel: LoadoutPanel
var crosshair: Control


func _ready() -> void:
	world = CombatWorld.new(1337)

	arena = Arena3D.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(world)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = GameHud.new()
	hud.name = "Hud"
	hud_layer.add_child(hud)
	hud.bind(world)

	var loadout_layer := CanvasLayer.new()
	loadout_layer.name = "LoadoutLayer"
	loadout_layer.layer = 20
	add_child(loadout_layer)

	loadout_panel = LoadoutPanel.new()
	loadout_panel.name = "LoadoutPanel"
	loadout_layer.add_child(loadout_panel)
	loadout_panel.set_world(world)

	var debug_overlay: CanvasLayer = DebugOverlayScene.instantiate()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)
	# Oculto por defecto (tapa el HUD); F3 lo muestra.
	debug_overlay.visible = false

	crosshair = Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	hud_layer.add_child(crosshair)

	TickManager.register(world)


func _unhandled_input(event: InputEvent) -> void:
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
		"space": Input.is_action_pressed("slot_space"),
		"q": Input.is_action_pressed("slot_q"),
		"e": Input.is_action_pressed("slot_e"),
		"r": Input.is_action_pressed("slot_r"),
		"f": Input.is_action_pressed("slot_f"),
	}
	return message


## Mira central para el modo tercera persona.
class Crosshair extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.9)
		draw_circle(c, 2.0, col)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 8.0, c + d * 16.0, col, 2.0)
