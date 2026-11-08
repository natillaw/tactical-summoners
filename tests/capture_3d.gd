## Captura visual del prototipo 3D (no es una suite pass/fail).
##
## Abre la escena real, apunta al muñeco, encadena el combo M1, M2 y las
## skills del loadout por defecto, y guarda PNGs en el momento del impacto.
## Necesita renderer real (no --headless):
##
##   godot --path . --resolution 1280x720 res://tests/capture_3d.tscn
##
## Las capturas van a $CAPTURE_DIR o a user://captures_3d.
extends Node

const MainScene := preload("res://game/main_3d.tscn")

var _dir: String = ""
var _main: Node3D = null
var _world: CombatWorld = null
var _track: bool = false
var _fps_samples: Array = []


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures_3d")
	DirAccess.make_dir_recursive_absolute(_dir)

	_main = MainScene.instantiate()
	add_child(_main)
	var world: CombatWorld = _main.get("world")
	_world = world

	await _wait(1.5)
	await _shot("01_arena")

	_track = true
	_aim_at_dummy(world)
	Input.action_press("move_up")
	await _wait(0.45)
	Input.action_release("move_up")
	await _wait(0.2)

	_aim_at_dummy(world)
	Input.action_press("attack_m1")
	await _shot("02_m1_hit1", 0.17)
	await _shot("03_m1_hit2", 0.46)
	await _shot("04_m1_finisher", 0.46)
	Input.action_release("attack_m1")
	await _wait(0.6)

	_aim_at_dummy(world)
	Input.action_press("attack_m2")
	await _shot("05_m2_thrust", 0.2)
	Input.action_release("attack_m2")
	await _wait(0.6)

	world.warrior.debug_refill()
	_aim_at_dummy(world)
	Input.action_press("slot_r")
	await _shot("06_seismic_windup", 0.2)
	await _shot("07_seismic_slam", 0.15)
	Input.action_release("slot_r")
	await _wait(0.8)

	world.warrior.debug_refill()
	Input.action_press("slot_f")
	await _shot("08_bladestorm", 0.6)
	Input.action_release("slot_f")
	await _wait(1.8)

	world.warrior.debug_refill()
	_aim_at_dummy(world)
	Input.action_press("slot_shift")
	await _shot("09_roll", 0.14)
	Input.action_release("slot_shift")
	await _wait(0.6)

	_aim_at_dummy(world)
	Input.action_press("slot_e")
	await _shot("10_charge", 0.2)
	Input.action_release("slot_e")
	await _wait(0.8)

	Input.action_press("slot_q")
	await _shot("11_parry", 0.15)
	Input.action_release("slot_q")
	await _wait(0.6)

	_track = false
	Input.action_press("move_right")
	await _shot("12_run", 0.5)
	Input.action_release("move_right")

	world.warrior.take_damage(99999.0, Vector2.ZERO)
	await _shot("13_death", 1.2)

	var total := 0.0
	for f: float in _fps_samples:
		total += f
	print("FPS medio (tras calentar): %.1f, min %.1f" % [total / maxf(_fps_samples.size(), 1.0), _fps_samples.min() if not _fps_samples.is_empty() else 0.0])
	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _process(_delta: float) -> void:
	if _world != null and _track:
		_aim_at_dummy(_world)
	if Time.get_ticks_msec() > 4000:
		_fps_samples.append(Engine.get_frames_per_second())


func _aim_at_dummy(world: CombatWorld) -> void:
	var arena: Arena3D = _main.get("arena")
	var target: Vector2 = world.dummies[0].position
	var screen := arena.camera.unproject_position(View3D.to3(target, 0.0))
	get_viewport().warp_mouse(screen)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String, wait: float = 0.0) -> void:
	if wait > 0.0:
		await _wait(wait)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	var err := image.save_png(path)
	print("shot ", shot_name, " err=", err)
