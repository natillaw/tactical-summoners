## CharacterPanel — ficha del personaje (tecla I), estilo WoW.
##
## Izquierda: el personaje en idle (SubViewport con su modelo y lo que lleva puesto; arrastra para girarlo) con
## los slots de equipo alrededor. Centro: atributos. Derecha: mochila en cuadrícula. Abajo: materiales.
## Clic en un slot de armadura lo desequipa; clic en un objeto de la mochila lo equipa. El detalle sale al pasar el ratón.
class_name CharacterPanel
extends Control

const GOLD := Color(0.95, 0.78, 0.35)
const DIM := Color(0.62, 0.55, 0.42)
const SLOT_BG := Color(0.07, 0.055, 0.04, 0.95)
const LEFT_SLOTS := ["head", "chest", "hands"]
const RIGHT_SLOTS := ["legs", "boots", "weapon"]
const SLOT_SIZE := 36.0
const BAG_COLUMNS := 5
const FALLBACK_MODEL := "res://assets/models/characters/warrior.glb"
const ANIM_IDLE := "ual1/Idle"

var warrior: WarriorSim
var sfx: Callable = Callable()
var _window: PanelContainer
var _slot_boxes: Dictionary = {}   # ranura -> VBoxContainer (botón + etiqueta)
var _stats: RichTextLabel
var _bag: GridContainer
var _bag_hint: Label
var _mats: RichTextLabel
var _viewport: SubViewport
var _doll_root: Node3D
var _rig: HumanoidRig
var _look_key: String = ""
var _dragging: bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_window = PanelContainer.new()
	_window.theme = GameTheme.make(10)
	_window.add_theme_stylebox_override("panel", _box(Color(0.1, 0.075, 0.05, 0.97), GOLD, 2, 10))
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_window.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "Personaje"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", GameTheme.font(true))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", GOLD)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "I / Esc: cerrar"
	hint.add_theme_color_override("font_color", DIM)
	bar.add_child(hint)
	var close := Button.new()
	close.text = " X "
	close.pressed.connect(toggle)
	bar.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	_build_doll(body)
	_build_stats(body)
	_build_bag(body)
	_mats = RichTextLabel.new()
	_mats.bbcode_enabled = true
	_mats.fit_content = true
	_mats.custom_minimum_size = Vector2(0, 22)
	column.add_child(_mats)


func _box(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(margin)
	return style


## Muñeco: columna de slots · modelo en idle · columna de slots.
func _build_doll(parent: Control) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.5
	frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.05, 0.045, 0.9), Color(0.4, 0.32, 0.18), 1, 6))
	parent.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	frame.add_child(row)
	row.add_child(_slot_column(LEFT_SLOTS))
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(520, 760)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_build_stage()
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.mouse_default_cursor_shape = Control.CURSOR_DRAG
	view.tooltip_text = "Arrastra para girar"
	view.gui_input.connect(_on_doll_input)
	row.add_child(view)
	row.add_child(_slot_column(RIGHT_SLOTS))


func _slot_column(slots: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	for slot: String in slots:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		column.add_child(box)
		_slot_boxes[slot] = box
	return column


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.74, 0.8)
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, 35.0, 0.0)
	key.light_energy = 1.25
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	rim.light_color = Color(1.0, 0.82, 0.55)
	rim.light_energy = 0.6
	_viewport.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 3.6)
	cam.fov = 32.0
	_viewport.add_child(cam)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	_doll_root = Node3D.new()
	_viewport.add_child(_doll_root)


func _build_stats(parent: Control) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.0
	frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.05, 0.045, 0.9), Color(0.4, 0.32, 0.18), 1, 8))
	parent.add_child(frame)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.scroll_active = false
	frame.add_child(_stats)


func _build_bag(parent: Control) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.25
	frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.05, 0.045, 0.9), Color(0.4, 0.32, 0.18), 1, 8))
	parent.add_child(frame)
	var box := VBoxContainer.new()
	frame.add_child(box)
	var label := Label.new()
	label.text = "Mochila"
	label.add_theme_color_override("font_color", GOLD)
	box.add_child(label)
	_bag_hint = Label.new()
	_bag_hint.add_theme_color_override("font_color", DIM)
	_bag_hint.add_theme_font_size_override("font_size", 8)
	_bag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_bag_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_bag = GridContainer.new()
	_bag.columns = BAG_COLUMNS
	_bag.add_theme_constant_override("h_separation", 4)
	_bag.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_bag)


func toggle() -> void:
	visible = not visible
	if sfx.is_valid():
		sfx.call(&"ui_open" if visible else &"ui_close", -8.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if visible:
		var vp := get_viewport_rect().size
		_window.custom_minimum_size = vp * 0.9
		_window.size = vp * 0.9
		_window.position = vp * 0.05
		refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


func _on_doll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and _rig != null:
		_rig.rotation.y += event.relative.x * 0.02


## Botón cuadrado de un objeto (icono + borde del color de su rareza). `item` null = slot vacío.
func _square(item: Item, empty_text: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var border := ItemRarity.color(item.rarity) if item != null else Color(0.3, 0.25, 0.16)
	b.add_theme_stylebox_override("normal", _box(SLOT_BG, border, 2, 3))
	b.add_theme_stylebox_override("hover", _box(SLOT_BG.lightened(0.12), border.lightened(0.25), 2, 3))
	b.add_theme_stylebox_override("pressed", _box(SLOT_BG.lightened(0.2), border, 2, 3))
	b.add_theme_stylebox_override("disabled", _box(SLOT_BG, border.darkened(0.45), 2, 3))
	if item != null:
		b.icon = HeroItemIcons.get_icon(item.id, item.slot)
		b.tooltip_text = item.describe()
	else:
		b.text = empty_text
		b.disabled = true
		b.add_theme_font_size_override("font_size", 7)
		b.add_theme_color_override("font_disabled_color", Color(0.45, 0.4, 0.3))
	return b


## Aspecto actual (apariencia + sets equipados + arma): solo se reconstruye el muñeco si cambia.
func _current_look_key() -> String:
	var parts: Array = [str(CharacterProfile.chosen), str(warrior.class_id)]
	for slot: String in Gear.ARMOR_SLOTS:
		var item: Item = warrior.armor_items.get(slot)
		parts.append(item.set_id if item != null else "-")
	parts.append(str(WeaponCatalog.spec_for(warrior, false)))
	return "|".join(parts)


func _rebuild_doll() -> void:
	var key := _current_look_key()
	if key == _look_key and _rig != null:
		return
	_look_key = key
	var yaw := _rig.rotation.y if _rig != null else deg_to_rad(-18.0)
	if _rig != null:
		_rig.queue_free()
	_rig = HumanoidRig.new()
	_doll_root.add_child(_rig)
	if CharacterProfile.chosen:
		var look: Dictionary = CharacterProfile.appearance.duplicate()
		var worn := ArmorSets.gear_for(CharacterProfile.armor)
		if not worn.is_empty():
			look["gear"] = worn
		_rig.setup_model(CharacterBuilder.build(look))
	else:
		_rig.setup(FALLBACK_MODEL)
	var spec := WeaponCatalog.spec_for(warrior, false)
	var built: Dictionary = WeaponCatalog.build(spec)
	_rig.attach_to_hand(built["node"], String(built["hand"]))
	if String(spec["type"]) == "bow":
		(built["node"] as Node3D).rotate_object_local(Vector3.UP, deg_to_rad(-90.0))
	if bool(spec["dual"]):
		_rig.attach_to_hand(WeaponCatalog.build(spec)["node"], "l")
	_rig.rotation.y = yaw
	_rig.play(ANIM_IDLE, 0.0)


func refresh() -> void:
	if warrior == null:
		return
	_rebuild_doll()
	# --- slots alrededor del muñeco ---
	for slot: String in _slot_boxes:
		var box: VBoxContainer = _slot_boxes[slot]
		for c in box.get_children():
			c.queue_free()
		var item := Gear.equipped(warrior, slot)
		var b := _square(item, String(Gear.SLOT_NAMES[slot]))
		if item != null and slot != "weapon":
			b.tooltip_text = item.describe() + "\n(clic: quitar)"
			b.pressed.connect(func() -> void:
				Gear.unequip(slot, warrior)
				if sfx.is_valid():
					sfx.call(&"unequip", -6.0)
				refresh())
		box.add_child(b)
		var name := Label.new()
		name.text = String(Gear.SLOT_NAMES[slot])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 7)
		name.add_theme_color_override("font_color", ItemRarity.color(item.rarity) if item != null else DIM)
		box.add_child(name)
	# --- mochila ---
	for c in _bag.get_children():
		c.queue_free()
	_bag_hint.text = "Vacía. Lo que forjes o encuentres y no uses aparece aquí." if CharacterProfile.bag.is_empty() else "%d objetos · clic: equipar" % CharacterProfile.bag.size()
	for item: Item in CharacterProfile.bag:
		var b := _square(item)
		if not Gear.can_use(item, warrior.class_id):
			b.disabled = true
			b.tooltip_text = item.describe() + "\n(Tu clase no puede empuñarlo)"
		else:
			var current := Gear.equipped(warrior, item.slot)
			var diff := Gear.score(item) - (Gear.score(current) if current != null else 0.0)
			b.tooltip_text = item.describe() + "\n" + ("▲ mejora lo equipado" if diff > 0.0 else "▼ peor que lo equipado")
		b.pressed.connect(func() -> void:
			Gear.equip(item, warrior)
			if sfx.is_valid():
				sfx.call(&"equip", -6.0)
			refresh())
		_bag.add_child(b)
	# --- atributos ---
	var s := warrior.stats
	var w := warrior.weapon
	var prog := warrior.progression
	var gold := GOLD.to_html(false)
	var dim := DIM.to_html(false)
	var text := "[font_size=13][color=#%s]%s[/color][/font_size]\n" % [gold, CharacterProfile.player_name if CharacterProfile.chosen else "Héroe"]
	text += "Nivel %d  ·  %s\n" % [prog.level, String(warrior.kit.CLASS_NAME)]
	text += "[color=#%s]XP %d / %d[/color]\n\n" % [dim, prog.xp, Progression.xp_to_next(prog.level)]
	text += "[color=#%s]Atributos[/color]\n" % gold
	text += _row("Vida", "%d" % int(warrior.max_health))
	text += _row("Armadura", "%d  (-%d%% físico)" % [int(warrior.armor), int(warrior.physical_reduction() * 100.0)])
	text += _row("Fuerza", "%d" % int(s.get_stat(&"strength")))
	text += _row(String(warrior.kit.RESOURCE_NAME), "%d" % int(warrior.rage_max()))
	text += "\n[color=#%s]Ofensiva[/color]\n" % gold
	text += _row("Poder de ataque", "%d" % int(s.get_attack_power()))
	text += _row("Crítico", "%.1f%%" % (s.get_stat(&"crit_chance") * 100.0))
	text += _row("Golpe medio", "%d" % int(warrior.average_hit() * float(warrior.mods.get("damage_mult", 1.0))))
	if w != null:
		text += _row("Arma", "%.1f DPS" % w.dps())
		text += _row("Daño", "%d–%d · vel %.1f" % [w.weapon_min, w.weapon_max, w.weapon_speed])
	_stats.text = text
	var mats: Array = []
	for id: String in Materials.DEFS:
		if int(Materials.inventory.get(id, 0)) > 0:
			mats.append("[img=14]res://assets/ui/items/%s.png[/img] %s x%d" % [id, Materials.display(id), Materials.inventory[id]])
	_mats.text = "[color=#%s]Materiales[/color]  " % gold + ("   ".join(mats) if not mats.is_empty() else "ninguno")
	if sfx.is_valid():
		Sfx.wire_buttons(self, sfx)


func _row(label: String, value: String) -> String:
	return "[color=#%s]%s[/color]  %s\n" % [DIM.to_html(false), label, value]
