extends Node
## Diagnóstico de árboles: CAPTURE_DIR=... godot --path . res://tests/capture_trees.tscn
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var names := ["Pine_1", "CommonTree_1", "CommonTree_2", "TwistedTree_1", "Bush_Common", "Bush_Common_Flowers", "DeadTree_1"]
	for i in range(names.size()):
		var node := (load("res://assets/models/nature/%s.gltf" % names[i]) as PackedScene).instantiate() as Node3D
		node.position = Vector3(i * 6.0, 0, 0)
		add_child(node)
	var cam := Camera3D.new()
	cam.position = Vector3(18, 9, 22)
	add_child(cam)
	cam.look_at(Vector3(18, 3, 0))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("CAPTURE_DIR") + "/trees.png")
	get_tree().quit()
