extends Node3D
## Pose check: renders rigs side by side playing given clips, close camera.

const CASES := [
	["res://assets/models/characters/warrior.glb", "custom/thrust", 0.1],
	["res://assets/models/characters/warrior.glb", "custom/thrust", 0.25],
	["res://assets/models/characters/warrior.glb", "custom/thrust", 0.4],
	["res://assets/models/characters/warrior.glb", "custom/thrust", 0.55],
	["res://assets/models/characters/warrior.glb", "custom/thrust", 0.7],
]

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var rigs := []
	for i in range(CASES.size()):
		var rig := HumanoidRig.new()
		add_child(rig)
		rig.setup(CASES[i][0])
		rig.position = Vector3((i - 2) * 1.6, 0, 0)
		if CASES[i][0].contains("warrior"):
			rig.attach_to_hand((load("res://assets/models/props/sword_bronze.glb") as PackedScene).instantiate())
		rig.play(CASES[i][1], 0.0)
		rigs.append(rig)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 3.0, 7.0)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(rigs.size()):
		var rig: HumanoidRig = rigs[i]
		rig.player.seek(rig.length_of(CASES[i][1]) * CASES[i][2], true)
		rig.player.pause()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR").path_join("pose_front.png"))
	cam.position = Vector3(7.5, 1.6, 0.0)
	cam.look_at(Vector3(0, 0.9, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR").path_join("pose_side.png"))
	get_tree().quit()
