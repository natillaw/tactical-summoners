## Laboratorio de Balance — interfaz para simular y ajustar las clases sin abrir el juego.
##
## Abrir: godot --path . res://tools/balance/balance_lab.tscn   (o F6 sobre la escena en el editor)
##
## Qué permite:
##  - DPS en muñeco: cuánto daño hace una clase en N segundos y qué aporta cada skill.
##  - Duelos 1v1, 2v2 y 1v2 entre bots (misma IA que los enemigos de clase), con N repeticiones.
##  - Matriz de clases: quién gana a quién.
##  - Cambiar stats base de cada clase (multiplicadores) y los números de cada skill.
##  - Guardar el balance (res://data/balance.json), que el juego lee al arrancar.
extends Control

const MODES := ["DPS en muñeco", "Duelo 1v1", "Duelo 2v2", "Duelo 1v2"]
const MOD_LABELS := {
	"damage_mult": ["Daño ×", "Multiplica TODO el daño que hace la clase (1.0 = normal)."],
	"health_mult": ["Vida ×", "Multiplica la vida máxima."],
	"speed_mult": ["Velocidad ×", "Multiplica la velocidad de movimiento."],
	"crit_bonus": ["Crítico +", "Suma probabilidad de crítico (0.10 = +10 puntos)."],
	"cooldown_mult": ["Cooldowns ×", "Multiplica los cooldowns de las skills (menos = más rápido)."],
	"regen_mult": ["Regeneración ×", "Multiplica la regeneración de maná/energía."],
}
const SKILL_FIELDS := ["damage_mult", "cooldown", "cost", "windup", "active", "recovery", "range", "radius"]
const FIELD_HELP := {
	"damage_mult": "Multiplicador del daño base (arma + fuerza).",
	"cooldown": "Segundos de espera extra tras usarla.",
	"cost": "Coste de maná / energía / rage.",
	"windup": "Segundos de preparación (en skills con barra de cast = tiempo de cast).",
	"active": "Segundos de fase activa.",
	"recovery": "Segundos de recuperación al terminar.",
	"range": "Alcance en píxeles (40 px = 1 m).",
	"radius": "Radio del área en píxeles.",
}

var _mode: OptionButton
var _team_a: Array = []   # [OptionButton clase, SpinBox nivel]
var _team_b: Array = []
var _b_box: Control
var _a2_row: Control
var _b2_row: Control
var _seconds: SpinBox
var _runs: SpinBox
var _results: RichTextLabel
var _status: Label
var _mods_class: OptionButton
var _mods_grid: GridContainer
var _skills_class: OptionButton
var _skills_grid: GridContainer
var _last_text: String = ""


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1280, 720)  # el proyecto escala a 640x360: aquí se trabaja a 1280x720
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(500, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	_build_run_panel(left)
	_build_mods_panel(left)
	_build_skills_panel(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	_status = Label.new()
	_status.text = "Elige modo y equipos, y pulsa Simular."
	right.add_child(_status)
	_results = RichTextLabel.new()
	_results.bbcode_enabled = true
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.fit_content = false
	_results.scroll_active = true
	_results.text = _help_text()
	right.add_child(_results)
	_on_mode_changed(0)


func _help_text() -> String:
	return "[b]Cómo leer los resultados[/b]\n" \
		+ "[b]Casts[/b]: veces que se lanzó la skill.  [b]Hits[/b]: golpes que conectaron (los DoT cuentan cada tick).\n" \
		+ "[b]Daño[/b]: daño real hecho (no cuenta el que sobra al matar).  [b]%[/b]: parte del daño total.\n" \
		+ "[b]DPS[/b]: daño / segundo de combate.  [b]Prom.[/b]: daño medio por golpe.\n" \
		+ "[b]Tramos de 10 s[/b] (DPS en muñeco): si cae con el tiempo, la clase se queda sin recursos.\n" \
		+ "[b]Duelos[/b]: victorias de A y B, duración media, vida restante y daño recibido.\n" \
		+ "[b]Matriz[/b]: % de victorias de la fila contra la columna (50 % = igualados).\n\n" \
		+ "[b]Tip[/b]: cambia stats o números de skills a la izquierda, simula otra vez y compara. " \
		+ "'Copiar resultados' deja el texto en el portapapeles para pasárselo a Claude."


# --- Paneles ------------------------------------------------------------------------------


func _title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	parent.add_child(label)


func _class_option() -> OptionButton:
	var option := OptionButton.new()
	for id: StringName in BalanceSim.CLASS_IDS:
		option.add_item(String(ClassRegistry.kit(id).CLASS_NAME), BalanceSim.CLASS_IDS.find(id))
	return option


func _fighter_row(parent: Control, store: Array, label: String, default_index: int) -> Control:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(name_label)
	var option := _class_option()
	option.select(default_index)
	option.tooltip_text = "Clase del combatiente."
	row.add_child(option)
	var level_label := Label.new()
	level_label.text = " Nivel"
	row.add_child(level_label)
	var level := SpinBox.new()
	level.min_value = 1
	level.max_value = 60
	level.value = 1
	level.tooltip_text = "Nivel 1-60: sube vida y daño."
	row.add_child(level)
	parent.add_child(row)
	store.append([option, level])
	return row


func _build_run_panel(parent: Control) -> void:
	_title(parent, "1) Simulación")
	_mode = OptionButton.new()
	for m: String in MODES:
		_mode.add_item(m)
	_mode.tooltip_text = "DPS en muñeco mide daño. Los duelos enfrentan bots entre sí."
	_mode.item_selected.connect(_on_mode_changed)
	parent.add_child(_mode)
	var a_title := Label.new()
	a_title.text = "Equipo A"
	parent.add_child(a_title)
	_fighter_row(parent, _team_a, "A1", 0)
	_a2_row = _fighter_row(parent, _team_a, "A2", 2)
	_b_box = VBoxContainer.new()
	parent.add_child(_b_box)
	var b_title := Label.new()
	b_title.text = "Equipo B"
	_b_box.add_child(b_title)
	_fighter_row(_b_box, _team_b, "B1", 1)
	_b2_row = _fighter_row(_b_box, _team_b, "B2", 3)
	var config := HBoxContainer.new()
	var seconds_label := Label.new()
	seconds_label.text = "Segundos"
	config.add_child(seconds_label)
	_seconds = SpinBox.new()
	_seconds.min_value = 10
	_seconds.max_value = 600
	_seconds.value = 60
	_seconds.tooltip_text = "DPS en muñeco: duración. Duelos: tiempo máximo antes de empate."
	config.add_child(_seconds)
	var runs_label := Label.new()
	runs_label.text = " Repeticiones"
	config.add_child(runs_label)
	_runs = SpinBox.new()
	_runs.min_value = 1
	_runs.max_value = 200
	_runs.value = 10
	_runs.tooltip_text = "Duelos y matriz: cuántas veces repetir (con semillas distintas)."
	config.add_child(_runs)
	parent.add_child(config)
	var buttons := HBoxContainer.new()
	for spec in [["▶ Simular", _on_simulate], ["Matriz de clases", _on_matrix], ["Copiar resultados", _on_copy]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		buttons.add_child(button)
	parent.add_child(buttons)
	var file_buttons := HBoxContainer.new()
	for spec in [["Guardar balance", _on_save], ["Recargar archivo", _on_reload], ["Restablecer todo", _on_reset_all]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		file_buttons.add_child(button)
	parent.add_child(file_buttons)


func _build_mods_panel(parent: Control) -> void:
	_title(parent, "2) Stats base por clase")
	_mods_class = _class_option()
	_mods_class.item_selected.connect(func(_i: int) -> void: _fill_mods())
	parent.add_child(_mods_class)
	_mods_grid = GridContainer.new()
	_mods_grid.columns = 4
	parent.add_child(_mods_grid)
	_fill_mods()


func _fill_mods() -> void:
	for child in _mods_grid.get_children():
		child.queue_free()
	var class_id: StringName = BalanceSim.CLASS_IDS[_mods_class.selected]
	var mods := BalanceData.class_mods(class_id)
	for key: String in MOD_LABELS:
		var label := Label.new()
		label.text = String(MOD_LABELS[key][0])
		label.tooltip_text = String(MOD_LABELS[key][1])
		_mods_grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = -1.0
		spin.max_value = 10.0
		spin.step = 0.05
		spin.value = float(mods.get(key, 1.0))
		spin.tooltip_text = String(MOD_LABELS[key][1])
		spin.value_changed.connect(func(value: float) -> void: BalanceData.set_class_mod(class_id, key, value))
		_mods_grid.add_child(spin)


func _build_skills_panel(parent: Control) -> void:
	_title(parent, "3) Números de las skills")
	_skills_class = _class_option()
	_skills_class.item_selected.connect(func(_i: int) -> void: _fill_skills())
	parent.add_child(_skills_class)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	parent.add_child(scroll)
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 5
	scroll.add_child(_skills_grid)
	_fill_skills()


func _fill_skills() -> void:
	for child in _skills_grid.get_children():
		child.queue_free()
	var class_id: StringName = BalanceSim.CLASS_IDS[_skills_class.selected]
	var kit: GDScript = ClassRegistry.kit(class_id)
	var header := Label.new()
	header.text = "Skill"
	_skills_grid.add_child(header)
	for key in ["damage_mult", "cooldown", "cost", "windup"]:
		var label := Label.new()
		label.text = key
		label.tooltip_text = String(FIELD_HELP[key])
		_skills_grid.add_child(label)
	for ability: Dictionary in kit.get_skill_book():
		var id := String(ability["id"])
		var override := BalanceData.skill_override(id)
		var name_label := Label.new()
		name_label.text = String(ability.get("name", id))
		_skills_grid.add_child(name_label)
		for key in ["damage_mult", "cooldown", "cost", "windup"]:
			var raw: Variant = override.get(key, ability.get(key, null))
			if raw == null or raw is Array:
				_skills_grid.add_child(Control.new())
				continue
			var spin := SpinBox.new()
			spin.min_value = 0.0
			spin.max_value = 1000.0
			spin.step = 0.05
			spin.value = float(raw)
			spin.tooltip_text = String(FIELD_HELP[key])
			spin.value_changed.connect(func(value: float) -> void: BalanceData.set_skill_value(id, key, value))
			_skills_grid.add_child(spin)


# --- Acciones -----------------------------------------------------------------------------


func _on_mode_changed(index: int) -> void:
	_b_box.visible = index != 0
	_a2_row.visible = index == 2
	_b2_row.visible = index == 2 or index == 3
	if index == 0:
		_seconds.value = 60
	elif _seconds.value < 90:
		_seconds.value = 120


func _team(store: Array, count: int) -> Array:
	var team: Array = []
	for i in count:
		var option: OptionButton = store[i][0]
		var level: SpinBox = store[i][1]
		team.append({"class": BalanceSim.CLASS_IDS[option.selected], "level": int(level.value)})
	return team


func _on_simulate() -> void:
	_status.text = "Simulando..."
	await get_tree().process_frame
	var mode := _mode.selected
	var text := ""
	var bb := ""
	if mode == 0:
		var fighter: Dictionary = _team(_team_a, 1)[0]
		fighter["seconds"] = _seconds.value
		var result := BalanceSim.dps_race(fighter)
		text = BalanceSim.format_dps(result)
		bb = _bb_dps(result)
	else:
		var a_count := 2 if mode == 2 else 1
		var b_count := 1 if mode == 1 else 2
		var result := BalanceSim.run_many({"a": _team(_team_a, a_count), "b": _team(_team_b, b_count), "max_seconds": _seconds.value}, int(_runs.value))
		text = BalanceSim.format_match(result)
		bb = _bb_match(result)
	_last_text = text
	_results.text = bb
	_status.text = "Listo."


func _on_matrix() -> void:
	_status.text = "Calculando matriz (puede tardar unos segundos)..."
	await get_tree().process_frame
	var result := BalanceSim.matrix(int(_team_a[0][1].value), int(_runs.value), minf(_seconds.value, 120.0))
	_last_text = BalanceSim.format_matrix(result)
	_results.text = "[b]Matriz de clases[/b] (% de victorias de la fila contra la columna)\n[code]" + _last_text + "[/code]\n" + _help_text()
	_status.text = "Listo."


func _on_copy() -> void:
	DisplayServer.clipboard_set(_last_text)
	_status.text = "Resultados copiados al portapapeles."


func _on_save() -> void:
	_status.text = "Balance guardado en res://data/balance.json." if BalanceData.save_file() else "No se pudo guardar el archivo."


func _on_reload() -> void:
	BalanceData.load_file()
	_fill_mods()
	_fill_skills()
	_status.text = "Balance recargado desde el archivo."


func _on_reset_all() -> void:
	BalanceData.clear()
	_fill_mods()
	_fill_skills()
	_status.text = "Todos los ajustes quitados (sin guardar aún)."


# --- Formato de resultados (BBCode) -----------------------------------------------------


func _skill_table(lines: Array) -> String:
	var table := "[table=7]"
	for header in ["Skill", "Casts", "Hits", "Daño", "%", "DPS", "Prom."]:
		table += "[cell][b]%s[/b]   [/cell]" % header
	for line: Dictionary in lines:
		table += "[cell]%s   [/cell][cell]%.1f   [/cell][cell]%.1f   [/cell][cell]%.0f   [/cell][cell]%.1f%%   [/cell][cell]%.1f   [/cell][cell]%.1f[/cell]" % [
			str(line["name"]), float(line["casts"]), float(line["hits"]), float(line["damage"]), float(line["pct"]), float(line["dps"]), float(line["avg"])]
	return table + "[/table]\n"


func _bb_dps(result: Dictionary) -> String:
	var text := "[b]DPS en muñeco — %s, %.0f s[/b]\n" % [str(result["class"]), float(result["seconds"])]
	text += "Daño total [b]%.0f[/b]   DPS medio [b]%.1f[/b]\n" % [float(result["damage"]), float(result["dps"])]
	var bins: Array = result["bins"]
	var parts: Array = []
	for value: Variant in bins:
		parts.append("%.0f" % (float(value) / 10.0))
	text += "DPS por tramos de 10 s: %s\n\n" % " | ".join(parts)
	return text + _skill_table(result["skills"])


func _bb_match(result: Dictionary) -> String:
	var wins: Dictionary = result["wins"]
	var text := "[b]%d simulaciones[/b]: gana A %d · gana B %d · empates %d · duración media %.1f s\n\n" % [int(result["runs"]), int(wins["A"]), int(wins["B"]), int(wins["empate"]), float(result["avg_seconds"])]
	for slot: Dictionary in result["fighters"]:
		text += "[b]%s[/b] — daño %.0f (DPS %.1f), recibido %.0f, vida restante %.0f%%, sobrevive %d/%d\n" % [str(slot["label"]), float(slot["damage"]), float(slot["dps"]), float(slot["damage_taken"]), float(slot["hp_pct"]) * 100.0, int(slot["survived"]), int(result["runs"])]
		text += _skill_table(slot["skills"]) + "\n"
	return text
