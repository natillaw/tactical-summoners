extends Node3D
## Row of weapons (new custom swords on top, the base Quaternius ones below). CAPTURE_DIR must be set.
## godot --path . --position 9000,9000 --resolution 1500x800 res://tools/weapon_preview.tscn

const NEW := ["custom/espada_recluta.glb", "custom/espada_xifos.glb", "custom/espada_alfanje.glb", "custom/espada_larga.glb", "custom/espada_colmillo.glb"]
const BASE := ["sword.fbx", "sword_2.fbx", "sword.fbx", "sword_golden.fbx", "claymore.fbx"]

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	for row in 2:
		var list: Array = NEW if row == 0 else BASE
		for i in list.size():
			var m := (load("res://assets/models/weapons/" + String(list[i])) as PackedScene).instantiate() as Node3D
			var bnd: Array = WeaponCatalog._bounds(String(list[i]), m)
			var lo: float = bnd[0]
			var hi: float = bnd[1]
			var s := 1.5 / maxf(hi - lo, 0.001)
			m.scale = Vector3.ONE * s
			m.position = Vector3((i - 2) * 0.9, (0.5 - row) * 2.0 - lo * s - 0.75, 0)
			add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.1
	add_child(cam)
	cam.position = Vector3(0, 0, 6)
	cam.make_current()
	var dir := OS.get_environment("CAPTURE_DIR")
	for v: float in [0.0, 70.0]:
		for c in get_children():
			if c is Node3D and not (c is Camera3D) and not (c is DirectionalLight3D):
				(c as Node3D).rotation_degrees.y = v
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("weapons_%d.png" % int(v)))
	get_tree().quit()
