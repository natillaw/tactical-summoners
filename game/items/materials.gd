## Materials — materiales de crafteo y recolección. Los comunes (tier 1) salen en el piso 1;
## los raros se añadirán en pisos más altos (`tier` = piso mínimo en el que aparece).
class_name Materials
extends RefCounted

const DEFS := {
	"piedra": {"name": "Piedra", "color": Color(0.7, 0.7, 0.75), "tier": 1, "kind": "mineral"},
	"mena_cobre": {"name": "Mena de Cobre", "color": Color(1.0, 0.55, 0.25), "tier": 1, "kind": "mineral"},
	"madera": {"name": "Madera", "color": Color(0.72, 0.5, 0.28), "tier": 1, "kind": "madera"},
	"fibra": {"name": "Fibra Vegetal", "color": Color(0.8, 0.9, 0.5), "tier": 1, "kind": "hierba"},
	"hierba_curativa": {"name": "Hierba Curativa", "color": Color(0.4, 1.0, 0.5), "tier": 1, "kind": "hierba"},
	"flor_silvestre": {"name": "Flor Silvestre", "color": Color(1.0, 0.6, 0.85), "tier": 1, "kind": "hierba"},
	"hongo": {"name": "Hongo del Bosque", "color": Color(1.0, 0.85, 0.4), "tier": 1, "kind": "hierba"},
	"cuero_basto": {"name": "Cuero Basto", "color": Color(0.7, 0.5, 0.35), "tier": 1, "kind": "botin"},
	"hueso": {"name": "Hueso", "color": Color(0.95, 0.93, 0.85), "tier": 1, "kind": "botin"},
	"polvo_arcano": {"name": "Polvo Arcano", "color": Color(0.8, 0.55, 1.0), "tier": 1, "kind": "botin"},
	"pocion_vida": {"name": "Poción de Vida", "color": Color(1.0, 0.35, 0.4), "tier": 1, "kind": "consumible"},
	"elixir_fuerza": {"name": "Elixir de Fuerza", "color": Color(1.0, 0.7, 0.2), "tier": 1, "kind": "consumible"},
	"pocion_arcana": {"name": "Poción Arcana", "color": Color(0.5, 0.6, 1.0), "tier": 1, "kind": "consumible"},
}

## Nodos de recolección del piso: tipo -> {material, cantidad (min,max), modelo, escala, tecla de interacción}
const NODES := {
	"ore": {"mat": "mena_cobre", "amount": [1, 3], "model": "Rock_Medium_2", "scale": 0.4, "label": "Filón de cobre"},
	"stone": {"mat": "piedra", "amount": [2, 3], "model": "Rock_Medium_1", "scale": 0.3, "label": "Piedras"},
	"herb": {"mat": "hierba_curativa", "amount": [1, 2], "model": "Plant_1_Big", "scale": 0.7, "label": "Hierba curativa"},
	"flower": {"mat": "flor_silvestre", "amount": [1, 2], "model": "Flower_3_Group", "scale": 0.8, "label": "Flores silvestres"},
	"mushroom": {"mat": "hongo", "amount": [1, 2], "model": "Mushroom_Common", "scale": 1.3, "label": "Hongos"},
	"fiber": {"mat": "fibra", "amount": [2, 3], "model": "Grass_Wispy_Tall", "scale": 1.0, "label": "Fibras"},
	"chest": {"mat": "", "amount": [1, 1], "model": "Chest_Wood", "scale": 1.0, "label": "Cofre"},
	"wood": {"mat": "madera", "amount": [2, 3], "model": "Pine_3", "scale": 0.28, "label": "Arbolito (madera)"},
}

const HERB_HEAL := 25.0  # la Hierba Curativa también cura al recogerla

static var inventory: Dictionary = {}


static func add(id: String, amount: int) -> void:
	inventory[id] = int(inventory.get(id, 0)) + amount


static func display(id: String) -> String:
	return String(DEFS[id]["name"]) if DEFS.has(id) else id


## Botín de un enemigo: esbirros dan poco, élites más y con material mejor.
static func drops_for(archetype: String, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	var data := EnemyArchetypes.data(archetype)
	var tier := String(data.get("tier", "minion"))
	if rng.randf() < (0.55 if tier == "minion" else 1.0):
		out["cuero_basto"] = 1 + (1 if tier == "elite" else 0)
	if rng.randf() < (0.3 if tier == "minion" else 0.8):
		out["hueso"] = 1 + rng.randi() % 2
	if StringName(data.get("class", &"")) == &"mage" and rng.randf() < (0.5 if tier == "minion" else 1.0):
		out["polvo_arcano"] = 1 + (1 if tier == "elite" else 0)
	return out


## Botín de un cofre: 3-4 materiales comunes (más cantidad en pisos altos) y a veces una poción.
static func roll_chest(rng: RandomNumberGenerator, floor_number: int) -> Dictionary:
	var pool: Array = []
	for id: String in DEFS:
		if String(DEFS[id]["kind"]) != "consumible":
			pool.append(id)
	var out: Dictionary = {}
	for i in range(3 + rng.randi() % 2):
		var id: String = pool[rng.randi() % pool.size()]
		out[id] = int(out.get(id, 0)) + 1 + rng.randi() % (2 + floor_number / 3)
	if rng.randf() < 0.3:
		out["pocion_vida"] = 1
	return out
