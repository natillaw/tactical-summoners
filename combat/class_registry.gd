## ClassRegistry — catálogo de kits de clase.
##
## Cada clase aporta un script de kit (datos puros) con el MISMO contrato; la
## simulación solo habla con `ClassRegistry.kit(id)`. Para añadir una clase:
## crear su kit con las claves de REQUIRED y registrarlo en KITS.
class_name ClassRegistry
extends RefCounted

const KITS := {
	&"warrior": preload("res://combat/warrior_kit.gd"),
}

## Contrato mínimo de un kit.
const REQUIRED := [
	"CLASS_ID", "CLASS_NAME", "RESOURCE_NAME", "M1", "M2", "PASSIVE",
	"DEFAULT_LOADOUT", "POOL_ABILITIES", "SELECTABLE_SLOTS",
]


static func ids() -> Array:
	return KITS.keys()


static func kit(id: StringName) -> GDScript:
	return KITS[id]


## Claves del contrato que le faltan al kit (vacío = válido).
static func missing(id: StringName) -> Array:
	var script: GDScript = KITS[id]
	var constants := script.get_script_constant_map()
	return REQUIRED.filter(func(key: String) -> bool: return not constants.has(key))
