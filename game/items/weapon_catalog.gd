## WeaponCatalog — modelo 3D de cada arma según su tipo y calidad (assets/models/weapons).
##
## Los modelos de Quaternius (Medieval Weapons Pack) y KayKit tienen el eje largo en +Y, con la hoja
## hacia arriba. Aquí se escalan a una longitud realista y se mueve el origen al agarre, de modo que
## el actor solo tiene que pegarlos a la mano. `variant_for` elige el modelo por rareza (los mejores
## aspectos para raro/épico/legendario) para que se vea lo que equipas.
class_name WeaponCatalog
extends RefCounted

const DIR := "res://assets/models/weapons/"

## tipo -> variantes de peor a mejor: [archivo, longitud en metros]
const VARIANTS := {
	"sword": [["sword.fbx", 1.0], ["sword_2.fbx", 1.05], ["sword_big.fbx", 1.15], ["sword_golden.fbx", 1.15], ["claymore.fbx", 1.3]],
	"axe": [["axe_small.fbx", 0.7], ["axe.fbx", 0.9], ["axe_double.fbx", 1.0], ["axe_double.fbx", 1.05]],
	"mace": [["hammer_small.fbx", 0.8], ["hammer_small.fbx", 0.85], ["hammer_double.fbx", 1.0], ["hammer_double.fbx", 1.05]],
	"spear": [["spear.fbx", 1.9], ["spear.fbx", 1.95], ["spear.fbx", 2.0], ["spear.fbx", 2.05]],
	"dagger": [["dagger.fbx", 0.42], ["dagger_2.fbx", 0.45], ["dagger_2.fbx", 0.48], ["dagger_2.fbx", 0.5]],
	"bow": [["bow_wooden.fbx", 1.1], ["bow_wooden2.fbx", 1.15], ["bow_golden.fbx", 1.2], ["bow_evil.fbx", 1.2]],
	"staff": [["kk_staff.fbx", 1.55], ["kk_staff.fbx", 1.6], ["kk_staff.fbx", 1.65], ["kk_staff.fbx", 1.7]],
}
## Armas que se agarran por el centro del mango (origen en la guarda) frente a las que ya tienen el origen en el agarre.
const GRIP_AT_HANDLE := ["sword", "axe", "mace", "dagger"]
## Espadas con diseño propio (editadas sobre las de Quaternius, tools/weapons/make_swords.py): id del objeto -> [archivo, longitud en metros].
const CUSTOM := {
	"espada_recluta": ["custom/espada_recluta.glb", 0.95], "espada_xifos": ["custom/espada_xifos.glb", 0.85],
	"espada_alfanje": ["custom/espada_alfanje.glb", 0.95], "espada_larga": ["custom/espada_larga.glb", 1.15],
	"espada_colmillo": ["custom/espada_colmillo.glb", 1.3],
}
## Arma de partida de cada clase (cuando lleva la espada inicial o es un enemigo sin arma propia).
const CLASS_DEFAULT := {&"warrior": "sword", &"rogue": "dagger", &"mage": "staff", &"ranger": "bow"}
## Aspecto de los enemigos por arquetipo: [tipo, variante].
const ENEMY_LOOK := {
	"esbirro": ["axe", 0], "guardian": ["mace", 0], "campeon": ["axe", 2], "coloso": ["mace", 3],
	"soldado": ["sword", 1], "duelista": ["dagger", 1], "cazador": ["bow", 1], "hechicero": ["staff", 1],
}

static var _bounds_cache: Dictionary = {}


## {type, variant, dual} del arma que debe verse: lo equipado (jugador) o el aspecto del arquetipo (enemigo).
static func spec_for(sim: WarriorSim, enemy: bool) -> Dictionary:
	var type: String = CLASS_DEFAULT.get(sim.class_id, "sword")
	var variant := 0
	var custom := ""
	if enemy:
		var look: Array = ENEMY_LOOK.get(sim.archetype_id, [])
		if not look.is_empty():
			type = look[0]
			variant = look[1]
		elif type == "sword":
			variant = 1
	elif sim.weapon != null and sim.weapon.id != "starter_sword":
		type = sim.weapon.weapon_type if VARIANTS.has(sim.weapon.weapon_type) else type
		variant = int(sim.weapon.rarity)
		if CUSTOM.has(sim.weapon.model_id):
			type = "sword"
			custom = sim.weapon.model_id
	variant = clampi(variant, 0, (VARIANTS[type] as Array).size() - 1)
	return {"type": type, "variant": variant, "model": custom, "dual": type == "dagger" and sim.class_id == &"rogue"}


## {node, tip, hand}: `node` tiene +Y hacia la punta, origen en el agarre y la escala ya aplicada;
## `tip` = distancia del agarre a la punta (m); `hand` = "r" o "l" (el arco va en la izquierda).
static func build(spec: Dictionary) -> Dictionary:
	var type: String = spec["type"]
	var entry: Array = CUSTOM[spec["model"]] if CUSTOM.has(String(spec.get("model", ""))) else (VARIANTS[type] as Array)[int(spec["variant"])]
	var file: String = entry[0]
	var length: float = entry[1]
	var scene := load(DIR + file) as PackedScene
	var holder := Node3D.new()
	holder.name = "Weapon_" + type
	if scene == null:
		return {"node": holder, "tip": 0.5, "hand": "r"}
	var model := scene.instantiate() as Node3D
	var bounds: Array = _bounds(file, model)  # [min_y, max_y] en unidades del modelo
	var span: float = maxf(float(bounds[1]) - float(bounds[0]), 0.001)
	var s: float = length / span
	var grip: float = float(bounds[0]) * 0.45 if type in GRIP_AT_HANDLE else 0.0
	model.scale = Vector3.ONE * s
	model.position = Vector3(0.0, -grip * s, 0.0)
	holder.add_child(model)
	return {"node": holder, "tip": (float(bounds[1]) - grip) * s, "hand": "l" if type == "bow" else "r"}


static func _bounds(file: String, model: Node3D) -> Array:
	if _bounds_cache.has(file):
		return _bounds_cache[file]
	var lo := INF
	var hi := -INF
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var walker: Node3D = mi
		while walker != null and walker != model:
			xf = walker.transform * xf
			walker = walker.get_parent() as Node3D
		var box: AABB = xf * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	_bounds_cache[file] = [lo, hi]
	return _bounds_cache[file]
