## ArmorSets — sets de armadura de nivel bajo (guerrero). Las piezas se fabrican en la herrería
## (recetas con "set" en Crafting); el set da el aspecto: `CharacterBuilder.OUTFITS["armor_<id>"]`.
class_name ArmorSets
extends RefCounted

const SETS := {
	"ladron": {"name": "Ladrón de Callejón", "desc": "Cuero y paño oscuro para pasar desapercibido en la ciudad."},
	"cuervo": {"name": "Sombra de Cuervo", "desc": "Negro violáceo y capucha picuda: pega fuerte, aguanta poco."},
	"desierto": {"name": "Bribón del Desierto", "desc": "Lino claro y botas ligeras: ágil y fresco."},
	"bosque": {"name": "Batidor del Bosque", "desc": "Cuero verde y hombreras ligeras: un poco más de aguante."},
	"carmesi": {"name": "Hoja Carmesí", "desc": "Rojo oscuro de duelista: el más agresivo y el más frágil."},
	"footman": {"name": "Soldado de Leva", "desc": "Malla y tabardo: mucha protección, nada de adornos."},
	"knight": {"name": "Escudero de Acero", "desc": "Placas completas: la más protectora, pero cara de forjar."},
	"hoplite": {"name": "Panoplia de Bronce", "desc": "Bronce ligero de hoplita: protege y da algo de fuerza."},
	"norse": {"name": "Cota del Norte", "desc": "Malla y escamas de los clanes del norte: aguante y empuje."},
	"dark": {"name": "Hierro Ennegrecido", "desc": "Placas ligeras y púas: protege poco, pero muerde."},
}


static func set_name(id: String) -> String:
	return String(SETS.get(id, {}).get("name", id))


## Aspecto según la armadura equipada, pieza a pieza: {ranura: set}. Las piezas sin set (cobre...) no
## cambian el aspecto. Vacío = ropa elegida en el creador.
static func gear_for(armor: Dictionary) -> Dictionary:
	var gear := {}
	for slot: String in armor:
		var piece: Item = armor[slot]
		if piece != null and piece.set_id != "":
			gear[slot] = piece.set_id
	return gear
