## ArmorSets — sets de armadura de nivel bajo (guerrero). Las piezas se fabrican en la herrería
## (recetas con "set" en Crafting); el set da el aspecto: `CharacterBuilder.OUTFITS["armor_<id>"]`.
class_name ArmorSets
extends RefCounted

const SETS := {
	"footman": {"name": "Soldado de Leva", "desc": "Malla y tabardo: mucha protección, nada de adornos."},
	"knight": {"name": "Escudero de Acero", "desc": "Placas completas: la más protectora, pero cara de forjar."},
	"hoplite": {"name": "Panoplia de Bronce", "desc": "Bronce ligero de hoplita: protege y da algo de fuerza."},
	"norse": {"name": "Cota del Norte", "desc": "Malla y escamas de los clanes del norte: aguante y empuje."},
	"dark": {"name": "Hierro Ennegrecido", "desc": "Placas ligeras y púas: protege poco, pero muerde."},
}


static func set_name(id: String) -> String:
	return String(SETS.get(id, {}).get("name", id))


## Aspecto (id de outfit del CharacterBuilder) según la armadura equipada: manda el set del peto,
## o el de cualquier pieza si no hay peto. "" = sin set.
static func outfit_for(armor: Dictionary) -> String:
	var chest: Item = armor.get("chest")
	var id := chest.set_id if chest != null else ""
	if id == "":
		for piece: Item in armor.values():
			if piece.set_id != "":
				id = piece.set_id
				break
	return ("armor_" + id) if id != "" else ""
