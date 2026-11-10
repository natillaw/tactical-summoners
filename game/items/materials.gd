## Materials — materiales de crafteo y recolección.
##
## Escala pensada para 100 pisos: cada tramo de 10 pisos (un "tier" de bioma) usa 2 grados de material.
## Praderas (pisos 1–10): grado 1 en pisos 1–5 (cobre, cuero basto, fibra, madera, hierba, polvo arcano) y
## grado 2 en pisos 6–10 (hierro, cuero curtido, lino, roble, salvia, esencia arcana). Los Colosos de los
## pisos 5 y 10 sueltan una pieza única (llave de tramo). `grade` = grado; `floor_min` = primer piso donde sale.
class_name Materials
extends RefCounted

const GRADE2_FLOOR := 6  # primer piso con materiales de grado 2

const DEFS := {
	# --- comunes, sin grado (todos los pisos) ---
	"piedra": {"name": "Piedra", "color": Color(0.7, 0.7, 0.75), "grade": 1, "kind": "mineral"},
	"flor_silvestre": {"name": "Flor Silvestre", "color": Color(1.0, 0.6, 0.85), "grade": 1, "kind": "hierba"},
	"hongo": {"name": "Hongo del Bosque", "color": Color(1.0, 0.85, 0.4), "grade": 1, "kind": "hierba"},
	"hueso": {"name": "Hueso", "color": Color(0.95, 0.93, 0.85), "grade": 1, "kind": "botin"},
	# --- grado 1 (pisos 1-5) ---
	"mena_cobre": {"name": "Mena de Cobre", "color": Color(1.0, 0.55, 0.25), "grade": 1, "kind": "mineral"},
	"madera": {"name": "Madera", "color": Color(0.72, 0.5, 0.28), "grade": 1, "kind": "madera"},
	"fibra": {"name": "Fibra Vegetal", "color": Color(0.8, 0.9, 0.5), "grade": 1, "kind": "hierba"},
	"hierba_curativa": {"name": "Hierba Curativa", "color": Color(0.4, 1.0, 0.5), "grade": 1, "kind": "hierba"},
	"cuero_basto": {"name": "Cuero Basto", "color": Color(0.7, 0.5, 0.35), "grade": 1, "kind": "botin"},
	"polvo_arcano": {"name": "Polvo Arcano", "color": Color(0.8, 0.55, 1.0), "grade": 1, "kind": "botin"},
	# --- grado 2 (pisos 6-10) ---
	"mena_hierro": {"name": "Mena de Hierro", "color": Color(0.62, 0.72, 0.9), "grade": 2, "kind": "mineral"},
	"roble": {"name": "Roble", "color": Color(0.5, 0.33, 0.18), "grade": 2, "kind": "madera"},
	"lino": {"name": "Lino", "color": Color(0.92, 0.9, 0.78), "grade": 2, "kind": "hierba"},
	"salvia": {"name": "Salvia Plateada", "color": Color(0.7, 0.95, 0.85), "grade": 2, "kind": "hierba"},
	"cuero_curtido": {"name": "Cuero Curtido", "color": Color(0.5, 0.33, 0.22), "grade": 2, "kind": "botin"},
	"esencia_arcana": {"name": "Esencia Arcana", "color": Color(0.5, 0.85, 1.0), "grade": 2, "kind": "botin"},
	# --- piezas únicas de Coloso (no se fabrican ni se encuentran en cofres) ---
	"colmillo_umbral": {"name": "Colmillo del Umbral", "color": Color(1.0, 0.8, 0.4), "grade": 1, "kind": "jefe"},
	"corazon_pradera": {"name": "Corazón de la Pradera", "color": Color(1.0, 0.35, 0.45), "grade": 2, "kind": "jefe"},
	# --- consumibles ---
	"pocion_vida": {"name": "Poción de Vida", "color": Color(1.0, 0.35, 0.4), "grade": 1, "kind": "consumible"},
	"elixir_fuerza": {"name": "Elixir de Fuerza", "color": Color(1.0, 0.7, 0.2), "grade": 1, "kind": "consumible"},
	"pocion_arcana": {"name": "Poción Arcana", "color": Color(0.5, 0.6, 1.0), "grade": 1, "kind": "consumible"},
	"pocion_vida_mayor": {"name": "Poción de Vida Mayor", "color": Color(1.0, 0.3, 0.5), "grade": 2, "kind": "consumible"},
	"elixir_fuerza_mayor": {"name": "Elixir de Fuerza Mayor", "color": Color(1.0, 0.6, 0.1), "grade": 2, "kind": "consumible"},
	"pocion_arcana_mayor": {"name": "Poción Arcana Mayor", "color": Color(0.4, 0.8, 1.0), "grade": 2, "kind": "consumible"},
}

## Nodos de recolección del piso: tipo -> {material base, cantidad (min,max), modelo, escala, etiqueta}.
## El material real lo decide `node_material` según el piso (grado 1 o 2).
const NODES := {
	"ore": {"mat": "mena_cobre", "amount": [1, 3], "model": "Rock_Medium_2", "scale": 0.4, "label": "Filón de mineral"},
	"stone": {"mat": "piedra", "amount": [2, 3], "model": "Rock_Medium_1", "scale": 0.3, "label": "Piedras"},
	"herb": {"mat": "hierba_curativa", "amount": [1, 2], "model": "Plant_1_Big", "scale": 0.7, "label": "Hierba medicinal"},
	"flower": {"mat": "flor_silvestre", "amount": [1, 2], "model": "Flower_3_Group", "scale": 0.8, "label": "Flores silvestres"},
	"mushroom": {"mat": "hongo", "amount": [1, 2], "model": "Mushroom_Common", "scale": 1.3, "label": "Hongos"},
	"fiber": {"mat": "fibra", "amount": [2, 3], "model": "Grass_Wispy_Tall", "scale": 1.0, "label": "Fibras"},
	"chest": {"mat": "", "amount": [1, 1], "model": "Chest_Wood", "scale": 1.0, "label": "Cofre"},
	"wood": {"mat": "madera", "amount": [2, 3], "model": "Pine_3", "scale": 0.28, "label": "Arbolito (madera)"},
}
## Familias con versión de grado 2: material de grado 1 -> grado 2.
const UPGRADE := {
	"mena_cobre": "mena_hierro", "madera": "roble", "fibra": "lino", "hierba_curativa": "salvia",
	"cuero_basto": "cuero_curtido", "polvo_arcano": "esencia_arcana",
	"pocion_vida": "pocion_vida_mayor", "elixir_fuerza": "elixir_fuerza_mayor", "pocion_arcana": "pocion_arcana_mayor",
}
## Vida que devuelve cada hierba al recogerla.
const HEAL := {"hierba_curativa": 25.0, "salvia": 45.0}
const HERB_HEAL := 25.0  # (compatibilidad)

static var inventory: Dictionary = {}


static func add(id: String, amount: int) -> void:
	inventory[id] = int(inventory.get(id, 0)) + amount


static func display(id: String) -> String:
	return String(DEFS[id]["name"]) if DEFS.has(id) else id


## ¿Un material de grado 2 sale ya en este piso?
static func grade2_unlocked(floor_number: int) -> bool:
	return floor_number >= GRADE2_FLOOR


## Material real de un nodo según el piso. En los pisos 6–10 la mayoría es de grado 2 (70 %), el resto sigue siendo grado 1.
static func node_material(kind: String, floor_number: int, rng: RandomNumberGenerator) -> String:
	var base: String = NODES[kind]["mat"]
	if grade2_unlocked(floor_number) and UPGRADE.has(base) and rng.randf() < 0.7:
		return UPGRADE[base]
	return base


## Mejora un material al grado que toca en el piso (para botín y cofres).
static func graded(base: String, floor_number: int, rng: RandomNumberGenerator) -> String:
	if grade2_unlocked(floor_number) and UPGRADE.has(base) and rng.randf() < 0.75:
		return UPGRADE[base]
	return base


## Botín de un enemigo: esbirros dan poco, élites más, Colosos sueltan además su pieza única.
static func drops_for(archetype: String, rng: RandomNumberGenerator, floor_number: int = 1) -> Dictionary:
	var out: Dictionary = {}
	var data := EnemyArchetypes.data(archetype)
	var tier := String(data.get("tier", "minion"))
	if rng.randf() < (0.55 if tier == "minion" else 1.0):
		out[graded("cuero_basto", floor_number, rng)] = 1 + (1 if tier != "minion" else 0)
	if rng.randf() < (0.3 if tier == "minion" else 0.8):
		out["hueso"] = 1 + rng.randi() % 2
	if StringName(data.get("class", &"")) == &"mage" and rng.randf() < (0.5 if tier == "minion" else 1.0):
		out[graded("polvo_arcano", floor_number, rng)] = 1 + (1 if tier != "minion" else 0)
	if tier == "boss":
		if floor_number >= 10:
			out["corazon_pradera"] = 1
		elif floor_number >= 5:
			out["colmillo_umbral"] = 1
	return out


## Botín de un cofre: 3-4 materiales (grado según el piso; más cantidad arriba) y a veces una poción.
static func roll_chest(rng: RandomNumberGenerator, floor_number: int) -> Dictionary:
	var pool: Array = []
	for id: String in DEFS:
		var kind := String(DEFS[id]["kind"])
		if kind == "consumible" or kind == "jefe":
			continue
		if int(DEFS[id]["grade"]) >= 2 and not grade2_unlocked(floor_number):
			continue
		pool.append(id)
	var out: Dictionary = {}
	for i in range(3 + rng.randi() % 2):
		var id: String = pool[rng.randi() % pool.size()]
		out[id] = int(out.get(id, 0)) + 1 + rng.randi() % (2 + floor_number / 3)
	if rng.randf() < 0.3:
		out["pocion_vida_mayor" if grade2_unlocked(floor_number) else "pocion_vida"] = 1
	return out
