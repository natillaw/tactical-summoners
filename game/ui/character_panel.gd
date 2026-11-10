## CharacterPanel — ficha del personaje (tecla I): slots de equipo, stats y mochila.
## Clic en un slot de armadura lo desequipa; clic en un objeto de la mochila lo equipa.
class_name CharacterPanel
extends Control

const GOLD := Color(0.95, 0.78, 0.35)
const SLOT_ORDER := ["weapon", "head", "chest", "legs", "hands", "boots"]

var warrior: WarriorSim
var _window: PanelContainer
var _slots: VBoxContainer
var _stats: RichTextLabel
var _bag: VBoxContainer
var _mats: RichTextLabel
var sfx: Callable = Callable()


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_window = PanelContainer.new()
	_window.theme = GameTheme.make(11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.075, 0.05, 0.96)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_window.add_theme_stylebox_override("panel", style)
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_window.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "Personaje  (I para cerrar)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD)
	bar.add_child(title)
	var close := Button.new()
	close.text = " X "
	close.pressed.connect(toggle)
	bar.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	_slots = _column(body, "Equipo", 1.4)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 0.9
	body.add_child(mid)
	var mid_title := Label.new()
	mid_title.text = "Atributos"
	mid_title.add_theme_color_override("font_color", GOLD)
	mid.add_child(mid_title)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_stats)
	var right := _column(body, "Mochila (clic: equipar)", 1.0)
	_bag = right
	_mats = RichTextLabel.new()
	_mats.bbcode_enabled = true
	_mats.fit_content = true
	_mats.custom_minimum_size = Vector2(0, 30)
	column.add_child(_mats)


func _column(parent: Control, title: String, ratio: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = ratio
	parent.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", GOLD)
	box.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func toggle() -> void:
	visible = not visible
	if sfx.is_valid():
		sfx.call(&"ui_open" if visible else &"ui_close", -8.0)
	if visible:
		var vp := get_viewport_rect().size
		_window.custom_minimum_size = vp * 0.88
		_window.size = vp * 0.88
		_window.position = vp * 0.06
		refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


func _item_button(item: Item, prefix: String = "") -> Button:
	var b := Button.new()
	b.text = prefix + item.item_name
	b.clip_text = true
	b.icon = HeroItemIcons.get_icon(item.id)
	b.add_theme_constant_override("icon_max_width", 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", ItemRarity.color(item.rarity))
	b.tooltip_text = item.describe()
	b.custom_minimum_size = Vector2(0, 26)
	return b


func refresh() -> void:
	if warrior == null:
		return
	for c in _slots.get_children():
		c.queue_free()
	for slot: String in SLOT_ORDER:
		var item := Gear.equipped(warrior, slot)
		var label := String(Gear.SLOT_NAMES[slot])
		if item == null:
			var empty := Button.new()
			empty.text = "%s: — vacío —" % label
			empty.alignment = HORIZONTAL_ALIGNMENT_LEFT
			empty.disabled = true
			empty.custom_minimum_size = Vector2(0, 26)
			_slots.add_child(empty)
			continue
		var b := _item_button(item, label + ": ")
		if slot != "weapon":
			b.pressed.connect(func() -> void:
				Gear.unequip(slot, warrior)
				if sfx.is_valid():
					sfx.call(&"unequip", -6.0)
				refresh())
		_slots.add_child(b)
	for c in _bag.get_children():
		c.queue_free()
	if CharacterProfile.bag.is_empty():
		var hint := Label.new()
		hint.text = "Vacía. Lo que forjes y no uses, o lo que te quites, aparece aquí."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		_bag.add_child(hint)
	for item: Item in CharacterProfile.bag:
		var b := _item_button(item)
		b.pressed.connect(func() -> void:
			Gear.equip(item, warrior)
			if sfx.is_valid():
				sfx.call(&"equip", -6.0)
			refresh())
		_bag.add_child(b)
	var s := warrior.stats
	var w := warrior.weapon
	var lines: Array = [
		"Nivel %d  ·  %s" % [warrior.progression.level, String(warrior.kit.CLASS_NAME)],
		"Vida  %d" % int(warrior.max_health),
		"Poise (armadura)  %d" % int(warrior.max_poise),
		"Fuerza  %d" % int(s.get_stat(&"strength")),
		"Poder de ataque  %d" % int(s.get_attack_power()),
		"Crítico  %.1f%%" % (s.get_stat(&"crit_chance") * 100.0),
		"Golpe medio  %d" % int(warrior.average_hit()),
	]
	if w != null:
		lines.append("Arma: %.1f DPS (%d–%d)" % [w.dps(), w.weapon_min, w.weapon_max])
	_stats.text = "\n".join(lines)
	var mats: Array = []
	for id: String in Materials.DEFS:
		if int(Materials.inventory.get(id, 0)) > 0:
			mats.append("[img=16]res://assets/ui/items/%s.png[/img] %s x%d" % [id, Materials.display(id), Materials.inventory[id]])
	_mats.text = "Materiales:  " + ("   ".join(mats) if not mats.is_empty() else "ninguno")
	if sfx.is_valid():
		Sfx.wire_buttons(self, sfx)
