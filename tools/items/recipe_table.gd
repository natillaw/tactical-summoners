extends SceneTree
## Genera la tabla receta → arma y comprueba que no haya armas huérfanas ni materiales sin uso.
##
##   godot --headless --path . -s tools/items/recipe_table.gd -- [out=docs/RECETAS.md]
##
## Sale con código 1 si: un .glb de assets/models/weapons/custom no tiene receta, una receta apunta a un
## modelo que no existe, un material recolectable no se usa en ninguna receta, o una receta pide un
## material de un grado superior al suyo.

const STATION := {"blacksmith": "Herrería", "carpenter": "Carpintería", "leatherworker": "Peletería", "tailor": "Sastrería", "alchemy": "Alquimia"}
const TYPE := {"sword": "Espada", "axe": "Hacha", "mace": "Maza", "spear": "Lanza", "dagger": "Daga", "bow": "Arco", "staff": "Bastón"}
const CLASS_NAMES := {&"warrior": "Guerrero", &"rogue": "Pícaro", &"mage": "Mago", &"ranger": "Arquero"}


func _init() -> void:
	var out_path := "docs/RECETAS.md"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out_path = arg.substr(4)
	var problems: Array = []
	var on_disk := {}
	for f in DirAccess.open("res://assets/models/weapons/custom").get_files():
		if f.ends_with(".glb"):
			on_disk[f.get_basename()] = true
	var lines: Array = ["# Recetas de armas (generado por tools/items/recipe_table.gd)", "",
		"Grado 1 = pisos 1-5 · Grado 2 = pisos 6-10 (se desbloquea al llegar al piso 6). DPS base = (2 + 0.7·nivel) × mult; la calidad al forjar lo multiplica ×1.1 / ×1.25 / ×1.45.", "",
		"| Arma | Tipo | Clases | Grado | Nv | Taller | Vel | DPS base | Extra | Coste | Modelo |", "|---|---|---|---|---|---|---|---|---|---|---|"]
	var used := {}
	var with_model := {}
	var weapons := 0
	for r: Dictionary in Crafting.all_recipes():
		var grade := int(r.get("grade", 1))
		for id: String in r["cost"]:
			used[id] = true
			if not Materials.DEFS.has(id):
				problems.append("%s pide un material que no existe: %s" % [r["id"], id])
			elif int(Materials.DEFS[id]["grade"]) > grade:
				problems.append("%s (grado %d) pide un material de grado superior: %s" % [r["id"], grade, id])
		if not r.has("weapon"):
			continue
		weapons += 1
		var type := String(r["weapon"])
		var classes: Array = []
		for c: StringName in Gear.CLASS_WEAPONS:
			if type in Gear.CLASS_WEAPONS[c]:
				classes.append(CLASS_NAMES[c])
		var level := int(r.get("level", Crafting.ITEM_LEVEL))
		var extra: Array = []
		for k: String in r.get("stats", {}):
			extra.append("+%s %s" % [("%d%%" % int(float(r["stats"][k]) * 100.0)) if k == "crit_chance" else str(int(r["stats"][k])), k])
		var cost: Array = []
		for id: String in r["cost"]:
			cost.append("%d %s" % [int(r["cost"][id]), Materials.display(id)])
		var model := String(r.get("model", ""))
		if model != "":
			with_model[model] = true
			if not on_disk.has(model):
				problems.append("la receta %s apunta a un modelo que no existe: custom/%s.glb" % [r["id"], model])
		lines.append("| %s | %s | %s | %d | %d | %s | %.1f | %.1f | %s | %s | %s |" % [
			r["name"], TYPE[type], ", ".join(classes), grade, level, STATION[r["station"]],
			float(r.get("speed", ItemFactory.WEAPON_TYPES[type]["speed"])), (2.0 + 0.7 * level) * float(r.get("dps_mult", 1.0)),
			", ".join(extra) if not extra.is_empty() else "—", ", ".join(cost), ("custom/%s.glb" % model) if model != "" else "(según rareza)"])
	for id: String in on_disk:
		if not with_model.has(id):
			problems.append("arma huérfana (sin receta): custom/%s.glb" % id)
	var unused: Array = []
	for id: String in Materials.DEFS:
		var kind := String(Materials.DEFS[id]["kind"])
		if kind != "consumible" and kind != "jefe" and not used.has(id):
			unused.append(id)
			problems.append("material sin uso en recetas: " + id)
	lines.append("")
	lines.append("## Comprobaciones")
	lines.append("")
	lines.append("- Recetas de arma: %d (%d con modelo propio de %d modelos en disco)." % [weapons, with_model.size(), on_disk.size()])
	lines.append("- Recetas totales: %d." % Crafting.all_recipes().size())
	lines.append("- Armas huérfanas: %s." % ("ninguna" if problems.filter(func(p: String) -> bool: return p.begins_with("arma huérfana")).is_empty() else "ver abajo"))
	lines.append("- Materiales sin uso: %s." % ("ninguno" if unused.is_empty() else ", ".join(unused)))
	lines.append("- Piezas de jefe (`colmillo_umbral`, `corazon_pradera`): reservadas, sin receta todavía (llaves de tramo).")
	for p: String in problems:
		lines.append("- **PROBLEMA:** " + p)
	var file := FileAccess.open("res://" + out_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("recetas de arma: %d · con modelo: %d/%d · problemas: %d" % [weapons, with_model.size(), on_disk.size(), problems.size()])
	for p: String in problems:
		print("PROBLEMA: " + p)
	quit(1 if not problems.is_empty() else 0)
