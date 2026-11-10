## NpcPanel — ventana de NPC estilo WoW: lista de recetas a la izquierda, detalle y materiales
## a la derecha, botón Crear. La taberna es un diálogo (descansar / rumores).
class_name NpcPanel
extends Control

signal closed()

const GOLD := Color(0.95, 0.78, 0.35)
const HAVE := Color(0.5, 1.0, 0.5)

var warrior: WarriorSim
var _station: Dictionary = {}
var _selected: Dictionary = {}
var _category: String = ""
var _title: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _detail: RichTextLabel
var _create: Button
var _message: Label
var _body: HBoxContainer
var _dialog: VBoxContainer
var _window: PanelContainer
var sfx: Callable = Callable()


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var window := PanelContainer.new()
	_window = window
	window.theme = GameTheme.make(11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.075, 0.05, 0.96)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	window.add_theme_stylebox_override("panel", style)
	add_child(window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	window.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", GOLD)
	bar.add_child(_title)
	var close := Button.new()
	close.text = " X "
	close.pressed.connect(close_panel)
	bar.add_child(close)
	_tabs = HBoxContainer.new()
	column.add_child(_tabs)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	column.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.8
	_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	_body.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	_create = Button.new()
	_create.text = "Crear"
	_create.custom_minimum_size = Vector2(0, 40)
	_create.pressed.connect(_on_create)
	right.add_child(_create)
	_dialog = VBoxContainer.new()
	_dialog.add_theme_constant_override("separation", 10)
	column.add_child(_dialog)
	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	column.add_child(_message)


## Una línea de cada vecino (ver docs/LORE.md) al abrir su ventana.
const LORE := {
	"blacksmith": "\"Subí hasta el piso cuatro con mi hermano. Forjo para que nadie suba mal armado.\"",
	"alchemy": "\"La esencia de los Ecos es lo único que impide que la Torre se los lleve de vuelta.\"",
	"leatherworker": "\"El cuero de los Ecos aún recuerda el frío. Se nota al cortarlo.\"",
	"tailor": "\"Remiendo lo que la Torre rompe. Mis telas son ligeras: para quien prefiere no ser alcanzado.\"",
	"carpenter": "\"Hice el marco del portal. La madera de los Pliegues crece sola, jurado.\"",
}


func open_for(station: Dictionary, p_warrior: WarriorSim) -> void:
	warrior = p_warrior
	_station = station
	_message.text = String(LORE.get(String(station["id"]), ""))
	_title.text = "%s  —  <%s>" % [station["npc"], station["label"]]
	var tavern: bool = station["id"] == "tavern"
	_body.visible = not tavern
	_tabs.visible = not tavern
	_dialog.visible = tavern
	if tavern:
		_build_tavern()
	else:
		_build_tabs()
	var vp := get_viewport_rect().size
	_window.custom_minimum_size = vp * 0.86
	_window.size = vp * 0.86
	_window.position = vp * 0.07
	visible = true


func close_panel() -> void:
	if sfx.is_valid():
		sfx.call(&"ui_close", -8.0)
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F):
		close_panel()
		get_viewport().set_input_as_handled()


func _build_tavern() -> void:
	for c in _dialog.get_children():
		c.queue_free()
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(300, 60)
	text.text = "\"Bienvenido, viajero. La Torre se traga a muchos, pero los que vuelven siempre beben aquí. ¿Un descanso?\""
	_dialog.add_child(text)
	var rest := Button.new()
	rest.text = "Descansar: recuperar toda la vida"
	rest.pressed.connect(func() -> void:
		warrior.health = warrior.max_health
		warrior.health_changed.emit(warrior.health, warrior.max_health)
		_message.text = "Descansas junto al fuego. Vida restaurada.")
	_dialog.add_child(rest)
	var rumor := Button.new()
	rumor.text = "Pedir rumores"
	var rumors := [
		"\"Los filones de cobre brillan entre las rocas del bosque. Del piso seis en adelante hay hierro.\"",
		"\"La Torre se sube un piso a la vez. Los que corren no vuelven.\"",
		"\"Un Eco no muere: se acuerda de que murió. Por eso pelean como los héroes que fueron.\"",
		"\"Cada diez pisos hay un Coloso con una Llave. Sin ella, el Pliegue siguiente no se abre.\"",
		"\"Si ves un cartel junto al inicio de un piso, puedes elegir camino: el difícil paga mejor.\"",
		"\"Las hierbas curativas crecen cerca de los claros. Elowen las convierte en pociones.\"",
		"\"Los élites del piso uno aprenden de ti: no los subestimes, y lleva pociones.\"",
		"\"Cada vez que entras, la Torre es distinta. Nadie recorre el mismo bosque dos veces.\"",
	]
	rumor.pressed.connect(func() -> void: _message.text = rumors[randi() % rumors.size()])
	_dialog.add_child(rumor)
	_wire()


func _build_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var cats := {}
	for r: Dictionary in Crafting.recipes_for(_station["id"]):
		cats[Crafting.category_of(r)] = true
	_category = String(cats.keys()[0])
	for cat: String in cats:
		var tab := Button.new()
		tab.text = cat
		tab.toggle_mode = true
		tab.button_pressed = cat == _category
		tab.pressed.connect(func() -> void:
			_category = cat
			for t in _tabs.get_children():
				(t as Button).button_pressed = (t as Button).text == cat
			_fill_list())
		_tabs.add_child(tab)
	_fill_list()


func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_selected = {}
	var first := true
	for r: Dictionary in Crafting.recipes_for(_station["id"]):
		if Crafting.category_of(r) != _category:
			continue
		var row := Button.new()
		row.text = r["name"] + ("" if Crafting.is_unlocked(r) else "  (piso %d)" % int(r["min_floor"]))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_color_override("font_color", HAVE if Crafting.can_craft(r) else Color(0.62, 0.6, 0.58))
		row.custom_minimum_size = Vector2(0, 34)
		row.icon = HeroItemIcons.get_icon(String(r["id"]), String(r.get("armor", "")))
		row.add_theme_constant_override("icon_max_width", 26)
		row.pressed.connect(func() -> void:
			_selected = r
			_refresh_detail())
		_list.add_child(row)
		if first:
			_selected = r
			first = false
	_refresh_detail()
	_wire()


func _wire() -> void:
	if sfx.is_valid():
		Sfx.wire_buttons(self, sfx)


func _icon_path(id: String, slot: String) -> String:
	var path := "res://assets/ui/items/%s.png" % id
	return path if ResourceLoader.exists(path) or slot == "" else "res://assets/ui/items/slot_%s.png" % slot


func _refresh_detail() -> void:
	if _selected.is_empty():
		_detail.text = ""
		_create.disabled = true
		return
	var r := _selected
	var text := "[img=30]%s[/img] [font_size=16][color=#f2c75a]%s[/color][/font_size]\n" % [_icon_path(String(r["id"]), String(r.get("armor", ""))), r["name"]]
	text += Crafting.describe_result(r, warrior.class_id)
	if not Crafting.is_unlocked(r):
		text += "\n[color=#ff6666]Bloqueado: llega al piso %d para aprender esta receta.[/color]" % int(r["min_floor"])
	text += "\n\n[color=#c9b27a]Materiales:[/color]\n"
	for id: String in r["cost"]:
		var have := int(Materials.inventory.get(id, 0))
		var need := int(r["cost"][id])
		text += "  [img=18]res://assets/ui/items/%s.png[/img] [color=%s]%s  %d/%d[/color]\n" % [id, "#80ff80" if have >= need else "#ff6666", Materials.display(id), have, need]
	_detail.text = text
	_create.disabled = not Crafting.can_craft(r)


func _on_create() -> void:
	if _selected.is_empty():
		return
	var made := Crafting.craft(_selected, warrior)
	_message.text = made
	if sfx.is_valid() and not made.begins_with("Faltan"):
		if _selected.has("weapon"):
			sfx.call(&"craft_weapon", -6.0)
		elif _selected.has("armor"):
			sfx.call(&"craft_armor", -6.0)
		else:
			sfx.call(&"craft_potion", -6.0)
		if Crafting.last_quality >= ItemRarity.Tier.EPICO:
			sfx.call(&"levelup", -6.0)
		elif Crafting.last_quality >= ItemRarity.Tier.RARO:
			sfx.call(&"ui_confirm", -6.0)
	elif sfx.is_valid():
		sfx.call(&"ui_denied", -8.0)
	var keep := _selected
	_fill_list()
	_selected = keep
	_refresh_detail()
