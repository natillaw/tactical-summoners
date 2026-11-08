extends Node
## Perf: corre main_3d 10 s con el Warrior moviéndose y atacando; imprime FPS.
var _t := 0.0
var _samples: Array = []
func _ready() -> void:
	var main := (load("res://game/main_3d.tscn") as PackedScene).instantiate()
	add_child(main)
	var mode := OS.get_environment("PERF_MODE")
	for n in main.find_children("*", "DirectionalLight3D", true, false):
		if mode.contains("noshadow"):
			n.shadow_enabled = false
	for n in main.find_children("*", "WorldEnvironment", true, false):
		if mode.contains("noglow"):
			n.environment.glow_enabled = false
		if mode.contains("nofog"):
			n.environment.fog_enabled = false
	if mode.contains("nochars"):
		for n in main.find_children("Rig", "", true, false):
			n.visible = false
	if mode.contains("nofloor"):
		for n in main.find_children("Floor", "", true, false):
			n.visible = false
func _process(delta: float) -> void:
	_t += delta
	var phase := int(_t / 1.5) % 4
	for a in ["move_up", "move_right", "move_down", "move_left"]:
		Input.action_release(a)
	Input.action_press(["move_up", "move_right", "move_down", "move_left"][phase])
	if fmod(_t, 1.0) < 0.5:
		Input.action_press("attack_m1")
	else:
		Input.action_release("attack_m1")
	if _t > 3.0:
		_samples.append(1.0 / maxf(delta, 0.0001))
	if _t > 11.0:
		_samples.sort()
		var total := 0.0
		for s: float in _samples:
			total += s
		print("PERF avg=%.1f p5=%.1f frames=%d" % [total / _samples.size(), _samples[int(_samples.size() * 0.05)], _samples.size()])
		get_tree().quit()
