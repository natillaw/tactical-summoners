## RewardPanel — resumen al completar un piso: desglose de la experiencia (atribuciones) y botín.
class_name RewardPanel
extends Control

const GOLD := Color(0.95, 0.78, 0.35)

var _window: PanelContainer
var _text: RichTextLabel
var sfx: Callable = Callable()


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_window = PanelContainer.new()
	_window.theme = GameTheme.make(11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.075, 0.05, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_window.add_theme_stylebox_override("panel", style)
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_window.add_child(column)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	var button := Button.new()
	button.text = "Continuar (Enter)"
	button.custom_minimum_size = Vector2(0, 28)
	button.pressed.connect(close_panel)
	column.add_child(button)


func show_result(result: Dictionary) -> void:
	var text := "[center][font_size=18][color=#f2c75a]Piso %d completado[/color][/font_size][/center]\n" % int(result["floor"])
	text += "[center][color=#c9b27a]%s[/color][/center]\n\n" % result["title"]
	text += "[color=#c9b27a]Experiencia por atribuciones[/color]\n"
	for line: Array in result["lines"]:
		text += "  %s  [color=#80ff80]+%d%%[/color]\n" % [line[0], int(round(float(line[1]) * 100.0))]
	text += "\n[b]Total: %d XP[/b]  (×%.2f)" % [int(result["xp"]), float(result["multiplier"])]
	text += "\nNivel %d" % int(result["level_after"])
	text += "\n\n[color=#c9b27a]Botín del piso[/color]\n"
	for id: String in result["loot"]:
		text += "  [img=16]res://assets/ui/items/%s.png[/img] %s x%d\n" % [id, Materials.display(id), int(result["loot"][id])]
	if result.get("item") != null:
		var item: Item = result["item"]
		text += "  [color=#%s]%s[/color]  [%s]\n" % [ItemRarity.color(item.rarity).to_html(false), item.item_name, ItemRarity.display(item.rarity)]
	text += "\nEnemigos derrotados: %d/%d  ·  Tiempo: %s" % [int(result["kills"]), int(result["total"]), MissionCatalog.clock(float(result["elapsed"]))]
	_text.text = text
	var vp := get_viewport_rect().size
	_window.custom_minimum_size = Vector2(vp.x * 0.6, 0.0)
	_window.size = Vector2(vp.x * 0.6, 10.0)
	_window.position = Vector2(vp.x * 0.2, vp.y * 0.12)
	visible = true
	if sfx.is_valid():
		sfx.call(&"levelup", -6.0)


func close_panel() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_ESCAPE):
		close_panel()
		get_viewport().set_input_as_handled()
