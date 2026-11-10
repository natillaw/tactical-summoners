extends Node3D
## Captures every hair style on a male and a female head (front, side, back). CAPTURE_DIR must be set.
## godot --path . --resolution 1900x800 res://tools/hair_preview.tscn
## Env HAIR_COLOR picks the colour name (default castaño); HAIR_ONLY="a,b" limits to those ids.

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	var ids: Array = CharacterBuilder.HAIRS.keys().filter(func(k: String) -> bool: return k != "none")
	var only := OS.get_environment("HAIR_ONLY")
	if only != "":
		ids = Array(only.split(","))
	var color := OS.get_environment("HAIR_COLOR") if OS.get_environment("HAIR_COLOR") != "" else "castaño"
	var holder := Node3D.new()
	add_child(holder)
	var n := ids.size()
	var only_sex := OS.get_environment("HAIR_SEX")
	for sex_i in 2:
		if only_sex != "" and only_sex != ["male", "female"][sex_i]:
			continue
		for i in n:
			var c := CharacterBuilder.build({"sex": ["male", "female"][sex_i], "outfit": "none", "hair": ids[i], "hair_color": color, "skin": "claro"})
			c.position = Vector3((i - (n - 1) * 0.5) * 0.45, (0.0 if only_sex != "" else -sex_i * 0.42), 0)
			holder.add_child(c)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(1.0, n * 0.45 / 1.75)
	add_child(cam)
	cam.position = Vector3(0, 1.5, 6.0)
	cam.make_current()
	var dir := OS.get_environment("CAPTURE_DIR")
	var views := {"front": 0.0, "side": 90.0, "back": 180.0, "three": 35.0}
	for v: String in views:
		holder.rotation_degrees.y = views[v]
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("hair_%s.png" % v))
	get_tree().quit()
