## CharacterCreator — pantalla inicial: elige clase y aspecto del personaje.
##
## UI construida por código: panel de opciones a la izquierda y vista previa 3D
## giratoria a la derecha. "Jugar" guarda la elección en CharacterProfile y carga
## la escena principal.
extends Control

const GAME_SCENE := "res://game/main_3d.tscn"
const ANIM_PREVIEW := "ual1/Idle"

## Clases: las que no tienen kit todavía se muestran pero no se pueden jugar.
const CLASSES := [
	{"id": &"warrior", "name": "Guerrero", "ready": true},
	{"id": &"mage", "name": "Mago (arcano)", "ready": true},
	{"id": &"rogue", "name": "Rogue (dagas, Energy)", "ready": true},
	{"id": &"ranger", "name": "Ranger (arquero, Energy)", "ready": true},
]

var _opts: Dictionary = CharacterBuilder.default_options()
var _class_index: int = 0
var _rows: Dictionary = {}
var _name_edit: LineEdit
var _play: Button
var _preview_root: Node3D
var _rig: HumanoidRig
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not CharacterProfile.save_checked:  # primera vez en esta ejecución: carga la partida guardada, si hay
		CharacterProfile.save_checked = true
		SaveGame.load_game()
	if CharacterProfile.chosen:
		_opts.merge(CharacterProfile.appearance, true)
		for i in range(CLASSES.size()):
			if CLASSES[i]["id"] == CharacterProfile.class_id:
				_class_index = i
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 12  # el UI se escala 2x (640x360): que quepan todas las filas
	theme = ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	margin.add_child(split)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_constant_override("separation", 3)
	split.add_child(panel)
	var title := Label.new()
	title.text = "CREA TU PERSONAJE"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre"
	_name_edit.text = CharacterProfile.player_name
	panel.add_child(_name_edit)

	_add_row(panel, "class", "Clase", func() -> String: return String(CLASSES[_class_index]["name"]), _step_class)
	_add_row(panel, "sex", "Cuerpo", func() -> String: return String(CharacterBuilder.SEXES[_opts["sex"]]), func(d: int) -> void: _step_key("sex", CharacterBuilder.SEXES.keys(), d))
	_add_row(panel, "skin", "Piel", func() -> String: return String(_opts["skin"]), func(d: int) -> void: _step_key("skin", CharacterBuilder.SKINS.keys(), d))
	_add_row(panel, "hair", "Pelo", func() -> String: return String(CharacterBuilder.HAIRS[_opts["hair"]]["name"]), func(d: int) -> void: _step_key("hair", CharacterBuilder.HAIRS.keys(), d))
	_add_row(panel, "hair_color", "Color de pelo", func() -> String: return String(_opts["hair_color"]), func(d: int) -> void: _step_key("hair_color", CharacterBuilder.HAIR_COLORS.keys(), d))
	_add_row(panel, "brows", "Cejas", func() -> String: return "Sí" if _opts["brows"] else "No", func(_d: int) -> void: _toggle_brows())
	_add_row(panel, "outfit", "Ropa", func() -> String: return String(CharacterBuilder.OUTFITS[_opts["outfit"]]["name"]), func(d: int) -> void: _step_key("outfit", CharacterBuilder.OUTFITS.keys(), d))

	var buttons := HBoxContainer.new()
	var random := Button.new()
	random.text = "Aleatorio"
	random.pressed.connect(_randomize)
	buttons.add_child(random)
	_play = Button.new()
	_play.text = "CONTINUAR" if CharacterProfile.chosen else "JUGAR"
	_play.pressed.connect(_on_play)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_play)
	if SaveGame.exists():
		var fresh := Button.new()
		fresh.text = "Nuevo (borra partida)"
		fresh.pressed.connect(func() -> void:
			SaveGame.delete()
			get_tree().reload_current_scene())
		buttons.add_child(fresh)
	panel.add_child(buttons)

	# Vista previa a resolución real: la UI se escala 2x (canvas_items 640x360), así que un
	# SubViewportContainer renderizaría a 640x360 y se vería pixelado. Se renderiza en
	# una textura grande y se muestra en un TextureRect.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(900, 1100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(view)
	_build_stage(viewport)
	_rebuild_preview()
	_refresh()


func _build_stage(viewport: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.85)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.0, 3.3)
	cam.fov = 38.0
	viewport.add_child(cam)
	cam.look_at(Vector3(0.0, 0.85, 0.0))
	_preview_root = Node3D.new()
	viewport.add_child(_preview_root)


func _process(delta: float) -> void:
	if _rig != null:
		_rig.rotation.y += delta * 0.6


func _add_row(parent: Control, key: String, label: String, value_fn: Callable, step_fn: Callable) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(95, 0)
	row.add_child(name_label)
	var prev := Button.new()
	prev.text = "◀"
	prev.pressed.connect(func() -> void: step_fn.call(-1))
	row.add_child(prev)
	var value := Label.new()
	value.custom_minimum_size = Vector2(140, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next := Button.new()
	next.text = "▶"
	next.pressed.connect(func() -> void: step_fn.call(1))
	row.add_child(next)
	parent.add_child(row)
	_rows[key] = {"label": value, "fn": value_fn}


func _step_key(key: String, keys: Array, delta: int) -> void:
	var i := keys.find(_opts[key])
	_opts[key] = keys[posmod(i + delta, keys.size())]
	_rebuild_preview()
	_refresh()


func _step_class(delta: int) -> void:
	_class_index = posmod(_class_index + delta, CLASSES.size())
	_refresh()


func _toggle_brows() -> void:
	_opts["brows"] = not bool(_opts["brows"])
	_rebuild_preview()
	_refresh()


func _randomize() -> void:
	_opts = CharacterBuilder.random_options(_rng)
	_rebuild_preview()
	_refresh()


func _refresh() -> void:
	for key: String in _rows:
		(_rows[key]["label"] as Label).text = (_rows[key]["fn"] as Callable).call()
	_play.disabled = not bool(CLASSES[_class_index]["ready"])


func _rebuild_preview() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = HumanoidRig.new()
	_preview_root.add_child(_rig)
	_rig.setup_model(CharacterBuilder.build(_opts))
	_rig.play(ANIM_PREVIEW, 0.0)


func _on_play() -> void:
	CharacterProfile.chosen = true
	CharacterProfile.player_name = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "Héroe"
	CharacterProfile.class_id = CLASSES[_class_index]["id"]
	CharacterProfile.appearance = _opts.duplicate()
	get_tree().change_scene_to_file(GAME_SCENE)
