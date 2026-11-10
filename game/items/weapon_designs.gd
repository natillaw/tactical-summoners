## WeaponDesigns — las armas con modelo propio (assets/models/weapons/custom/<id>.glb) y su receta.
##
## Una sola tabla alimenta tres cosas: el modelo que se ve en la mano (`WeaponCatalog`), la receta de
## crafteo (`Crafting.all_recipes`) y los drops con aspecto propio (`Loot`). Así no puede haber un arma
## sin receta ni una receta sin modelo: `tools/items/recipe_table.gd` lo comprueba contra la carpeta.
##
## Reglas de diseño:
##  - `grade` 1 = pisos 1-5 (cobre, madera, fibra, cuero basto, polvo arcano); `grade` 2 = pisos 6-10
##    (hierro, roble, lino, cuero curtido, esencia arcana). El coste se escribe con claves genéricas
##    (`metal`, `wood`, `leather`, `cloth`, `arcane`, `herb`) que se traducen al material del grado.
##  - Presupuesto: `dps` (multiplicador de DPS) y los extras suman lo mismo dentro de un grado (±5 %):
##    un arma con crítico o poder de ataque pega algo menos de base. El golpe está normalizado por
##    velocidad, así que la velocidad solo cambia la dispersión de la tirada, no el DPS de las skills.
class_name WeaponDesigns
extends RefCounted

const GENERIC := {
	1: {"metal": "mena_cobre", "wood": "madera", "leather": "cuero_basto", "cloth": "fibra", "arcane": "polvo_arcano", "herb": "hierba_curativa"},
	2: {"metal": "mena_hierro", "wood": "roble", "leather": "cuero_curtido", "cloth": "lino", "arcane": "esencia_arcana", "herb": "salvia"},
}

## id -> {name, type, grade, station, len (m), speed, dps, cost, stats?}
const DESIGNS := {
	# --- Espadas (herrería) ---
	"espada_recluta": {"name": "Espada de Recluta", "type": "sword", "grade": 1, "station": "blacksmith", "len": 0.95, "speed": 2.4, "dps": 1.0, "cost": {"metal": 3, "wood": 2}},
	"espada_xifos": {"name": "Xifos de Bronce", "type": "sword", "grade": 1, "station": "blacksmith", "len": 0.85, "speed": 2.2, "dps": 1.02, "cost": {"metal": 4, "wood": 1, "leather": 1}},
	"espada_alfanje": {"name": "Alfanje del Desierto", "type": "sword", "grade": 1, "station": "blacksmith", "len": 0.95, "speed": 2.0, "dps": 0.97, "cost": {"metal": 4, "leather": 2, "piedra": 1}, "stats": {"crit_chance": 0.02}},
	"espada_larga": {"name": "Espada Larga de Acero", "type": "sword", "grade": 2, "station": "blacksmith", "len": 1.15, "speed": 2.8, "dps": 1.03, "cost": {"metal": 6, "wood": 2, "leather": 1}},
	"espada_colmillo": {"name": "Colmillo de Sangre", "type": "sword", "grade": 2, "station": "blacksmith", "len": 1.3, "speed": 3.0, "dps": 0.98, "cost": {"metal": 6, "hueso": 3, "arcane": 1, "leather": 2}, "stats": {"attack_power_bonus": 6}},
	# --- Hachas (herrería) ---
	"hacha_lenador": {"name": "Hacha de Leñador", "type": "axe", "grade": 1, "station": "blacksmith", "len": 0.8, "speed": 3.0, "dps": 1.0, "cost": {"metal": 3, "wood": 3}},
	"tomahawk": {"name": "Tomahawk", "type": "axe", "grade": 1, "station": "blacksmith", "len": 0.65, "speed": 2.4, "dps": 0.97, "cost": {"metal": 3, "wood": 2, "leather": 1}, "stats": {"crit_chance": 0.02}},
	"hacha_doble_bronce": {"name": "Hacha Doble de Bronce", "type": "axe", "grade": 1, "station": "blacksmith", "len": 1.0, "speed": 3.4, "dps": 1.03, "cost": {"metal": 6, "wood": 2}},
	"hacha_hierro": {"name": "Hacha de Hierro", "type": "axe", "grade": 2, "station": "blacksmith", "len": 0.9, "speed": 3.0, "dps": 1.0, "cost": {"metal": 5, "wood": 3}},
	"hacha_verdugo": {"name": "Hacha del Verdugo", "type": "axe", "grade": 2, "station": "blacksmith", "len": 1.1, "speed": 3.6, "dps": 0.98, "cost": {"metal": 7, "wood": 2, "leather": 2}, "stats": {"attack_power_bonus": 6}},
	# --- Mazas (herrería / carpintería) ---
	"garrote_clavos": {"name": "Garrote de Clavos", "type": "mace", "grade": 1, "station": "carpenter", "len": 0.85, "speed": 3.0, "dps": 1.0, "cost": {"wood": 5, "metal": 1}},
	"mazo_piedra": {"name": "Mazo de Piedra", "type": "mace", "grade": 1, "station": "carpenter", "len": 0.9, "speed": 3.4, "dps": 0.97, "cost": {"wood": 3, "piedra": 4, "cloth": 1}, "stats": {"stamina": 3}},
	"maza_hierro": {"name": "Maza de Hierro", "type": "mace", "grade": 2, "station": "blacksmith", "len": 0.85, "speed": 3.0, "dps": 1.0, "cost": {"metal": 5, "wood": 2}},
	"maza_estrellada": {"name": "Maza Estrellada", "type": "mace", "grade": 2, "station": "blacksmith", "len": 0.9, "speed": 2.8, "dps": 0.97, "cost": {"metal": 6, "wood": 2, "leather": 1}, "stats": {"crit_chance": 0.02}},
	"martillo_guerra": {"name": "Martillo de Guerra", "type": "mace", "grade": 2, "station": "blacksmith", "len": 1.05, "speed": 3.6, "dps": 1.03, "cost": {"metal": 8, "wood": 3}},
	# --- Lanzas ---
	"lanza_caza": {"name": "Lanza de Caza", "type": "spear", "grade": 1, "station": "carpenter", "len": 1.9, "speed": 3.2, "dps": 1.0, "cost": {"wood": 4, "piedra": 2}},
	"lanza_bronce": {"name": "Lanza de Bronce", "type": "spear", "grade": 1, "station": "blacksmith", "len": 1.95, "speed": 3.4, "dps": 1.03, "cost": {"metal": 3, "wood": 4}},
	"pica_soldado": {"name": "Pica de Soldado", "type": "spear", "grade": 2, "station": "blacksmith", "len": 2.1, "speed": 3.4, "dps": 1.0, "cost": {"metal": 3, "wood": 5}},
	"tridente": {"name": "Tridente", "type": "spear", "grade": 2, "station": "blacksmith", "len": 1.9, "speed": 3.2, "dps": 0.97, "cost": {"metal": 5, "wood": 3}, "stats": {"crit_chance": 0.02}},
	"alabarda": {"name": "Alabarda", "type": "spear", "grade": 2, "station": "blacksmith", "len": 2.05, "speed": 3.6, "dps": 0.98, "cost": {"metal": 6, "wood": 4, "leather": 1}, "stats": {"attack_power_bonus": 6}},
	# --- Dagas (herrería) ---
	"daga_hueso": {"name": "Daga de Hueso", "type": "dagger", "grade": 1, "station": "blacksmith", "len": 0.42, "speed": 1.7, "dps": 1.0, "cost": {"hueso": 3, "leather": 1}},
	"daga_ladron": {"name": "Daga de Ladrón", "type": "dagger", "grade": 1, "station": "blacksmith", "len": 0.44, "speed": 1.8, "dps": 0.97, "cost": {"metal": 3, "leather": 1}, "stats": {"crit_chance": 0.02}},
	"cuchillo_curvo": {"name": "Cuchillo Curvo", "type": "dagger", "grade": 1, "station": "blacksmith", "len": 0.46, "speed": 1.9, "dps": 1.03, "cost": {"metal": 4, "leather": 2}},
	"daga_veneno": {"name": "Daga Envenenada", "type": "dagger", "grade": 2, "station": "blacksmith", "len": 0.45, "speed": 1.8, "dps": 0.98, "cost": {"metal": 3, "leather": 1, "herb": 3}, "stats": {"attack_power_bonus": 6}},
	"punal_ceremonial": {"name": "Puñal Ceremonial", "type": "dagger", "grade": 2, "station": "blacksmith", "len": 0.48, "speed": 1.7, "dps": 0.97, "cost": {"metal": 4, "leather": 1, "arcane": 1}, "stats": {"crit_chance": 0.02}},
	# --- Arcos (carpintería) ---
	"arco_corto": {"name": "Arco Corto", "type": "bow", "grade": 1, "station": "carpenter", "len": 1.05, "speed": 2.4, "dps": 1.0, "cost": {"wood": 4, "cloth": 2}},
	"arco_cazador": {"name": "Arco de Cazador", "type": "bow", "grade": 1, "station": "carpenter", "len": 1.15, "speed": 2.8, "dps": 0.97, "cost": {"wood": 5, "cloth": 3, "leather": 1}, "stats": {"crit_chance": 0.02}},
	"arco_largo": {"name": "Arco Largo", "type": "bow", "grade": 2, "station": "carpenter", "len": 1.3, "speed": 3.0, "dps": 1.03, "cost": {"wood": 6, "cloth": 3}},
	"arco_cuerno": {"name": "Arco de Cuerno", "type": "bow", "grade": 2, "station": "carpenter", "len": 1.1, "speed": 2.6, "dps": 0.98, "cost": {"wood": 4, "hueso": 3, "cloth": 2}, "stats": {"attack_power_bonus": 6}},
	"arco_runico": {"name": "Arco Rúnico", "type": "bow", "grade": 2, "station": "carpenter", "len": 1.2, "speed": 2.8, "dps": 0.97, "cost": {"wood": 5, "cloth": 2, "arcane": 2}, "stats": {"crit_chance": 0.02}},
	# --- Bastones (carpintería) ---
	"vara_arcana": {"name": "Vara Arcana", "type": "staff", "grade": 1, "station": "carpenter", "len": 1.2, "speed": 2.6, "dps": 1.0, "cost": {"wood": 3, "arcane": 1}},
	"cayado_cristal": {"name": "Cayado de Cristal", "type": "staff", "grade": 1, "station": "carpenter", "len": 1.6, "speed": 3.0, "dps": 0.97, "cost": {"wood": 4, "arcane": 2, "piedra": 1}, "stats": {"crit_chance": 0.02}},
	"baston_roble": {"name": "Bastón de Roble", "type": "staff", "grade": 2, "station": "carpenter", "len": 1.55, "speed": 3.0, "dps": 1.03, "cost": {"wood": 5, "arcane": 1}},
	"baston_fuego": {"name": "Bastón de Fuego", "type": "staff", "grade": 2, "station": "carpenter", "len": 1.6, "speed": 3.2, "dps": 0.98, "cost": {"wood": 4, "arcane": 3, "hongo": 2}, "stats": {"attack_power_bonus": 6}},
	"baston_hielo": {"name": "Bastón de Hielo", "type": "staff", "grade": 2, "station": "carpenter", "len": 1.6, "speed": 3.0, "dps": 0.97, "cost": {"wood": 4, "arcane": 3, "flor_silvestre": 2}, "stats": {"crit_chance": 0.02}},
}

static var _recipes: Array = []


static func has(id: String) -> bool:
	return DESIGNS.has(id)


static func get_design(id: String) -> Dictionary:
	return DESIGNS.get(id, {})


## Coste real de un diseño (claves genéricas traducidas al material de su grado).
static func cost_of(id: String) -> Dictionary:
	var d: Dictionary = DESIGNS[id]
	var table: Dictionary = GENERIC[int(d["grade"])]
	var cost := {}
	for key: String in d["cost"]:
		cost[String(table.get(key, key))] = int(d["cost"][key])
	return cost


## Recetas de crafteo de todos los diseños (mismo formato que `Crafting.RECIPES`).
static func recipes() -> Array:
	if _recipes.is_empty():
		for id: String in DESIGNS:
			var d: Dictionary = DESIGNS[id]
			var grade := int(d["grade"])
			var r := {
				"id": id, "station": d["station"], "name": d["name"], "cost": cost_of(id), "weapon": d["type"],
				"model": id, "dps_mult": float(d["dps"]), "speed": float(d["speed"]), "grade": grade,
				"level": Crafting.GRADE2_LEVEL if grade >= 2 else Crafting.ITEM_LEVEL,
			}
			if grade >= 2:
				r["min_floor"] = Materials.GRADE2_FLOOR
			if d.has("stats"):
				r["stats"] = d["stats"]
			_recipes.append(r)
	return _recipes


## Diseños de un tipo de arma y un grado (para dar aspecto a los drops).
static func ids_for(type: String, grade: int) -> Array:
	var out: Array = []
	for id: String in DESIGNS:
		if String(DESIGNS[id]["type"]) == type and int(DESIGNS[id]["grade"]) == grade:
			out.append(id)
	return out
