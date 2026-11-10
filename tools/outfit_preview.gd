extends Node3D
## Captures every outfit (male + female) side by side: front and back. CAPTURE_DIR must be set.
## godot --path . --resolution 1900x700 res://tools/outfit_preview.tscn

var OUTFITS: Array = _cases()


func _cases() -> Array:
	if OS.get_environment("MIX") != "":  # piezas sueltas, 1 a 1 (crafteo pieza a pieza), con pelo
		return [{"legs": "knight"}, {"boots": "hoplite"}, {"head": "norse"}, {"chest": "dark"}, {"hands": "footman", "legs": "footman"}, {"head": "hoplite", "chest": "knight", "legs": "norse", "boots": "dark", "hands": "footman"}]
	if OS.get_environment("ROGUE") != "":
		return ["armor_ladron", "armor_cuervo", "armor_desierto", "armor_bosque", "armor_carmesi", "warrior"]
	if OS.get_environment("ARMOR") != "":
		return ["armor_footman", "armor_knight", "armor_hoplite", "armor_norse", "armor_dark", "warrior"]
	return ["peasant", "ranger", "warrior", "archer", "rogue", "mage"]

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.32, 0.36)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var n := OUTFITS.size()
	var holder := Node3D.new()
	add_child(holder)
	for sex_i in 2:
		for i in n:
			var hair_id := OS.get_environment("HAIR") if OS.get_environment("HAIR") != "" else ("parted" if sex_i == 0 else "long")
			var opts := {"sex": ["male", "female"][sex_i], "outfit": "peasant", "hair": hair_id, "skin": "claro"}
			if OUTFITS[i] is Dictionary:
				opts["gear"] = OUTFITS[i]
			else:
				opts["outfit"] = OUTFITS[i]
			var c := CharacterBuilder.build(opts)
			c.position = Vector3((i - (n - 1) * 0.5) * 1.0, 0, -sex_i * 0.0)
			c.position.y = -sex_i * 2.0
			holder.add_child(c)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2
	add_child(cam)
	cam.position = Vector3(0, -0.15, 8.0)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("CAPTURE_DIR")
	get_viewport().get_texture().get_image().save_png(dir.path_join("outfits_front.png"))
	holder.rotation_degrees.y = 180
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("outfits_back.png"))
	# close-up of outfit ZOOM (index, default last) from the front-left, both sexes
	var zi := int(OS.get_environment("ZOOM")) if OS.get_environment("ZOOM") != "" else n - 1
	holder.rotation_degrees.y = 0
	cam.size = float(OS.get_environment("ZS")) if OS.get_environment("ZS") != "" else 2.0
	cam.position = Vector3((zi - (n - 1) * 0.5) * 1.0, float(OS.get_environment("ZY")) if OS.get_environment("ZY") != "" else 1.0, 8.0)
	holder.rotation_degrees.y = 0
	for v: float in [25.0, 155.0, 90.0]:
		holder.rotation_degrees.y = v
		cam.position.y = float(OS.get_environment("ZY")) if OS.get_environment("ZY") != "" else 1.0
		cam.position.x = (zi - (n - 1) * 0.5) * cos(deg_to_rad(v)) * 1.0
		cam.position.z = 8.0 + (zi - (n - 1) * 0.5) * -sin(deg_to_rad(v)) * 1.0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("outfits_zoom_%d.png" % int(v)))
	get_tree().quit()
