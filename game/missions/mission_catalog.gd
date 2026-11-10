## MissionCatalog — misiones procedurales de cada piso (ver docs/LORE.md para el tono).
##
## Cada piso tiene UNA misión principal (sorteada por semilla, nunca la misma en pisos contiguos) y un objetivo
## opcional con bonus. Esta clase solo decide el tipo y fabrica el "diseño" (posiciones, objetivos, interactuables);
## la lógica en vivo está en MissionRuntime. El piso 1 es siempre "clear" (tutorial) y los pisos 5 y 10 "boss".
class_name MissionCatalog
extends RefCounted

## tipo -> {title, text, short}. `%s`/`%d` los rellena `text_for`.
const TYPES := {
	"clear": {"title": "Limpia las praderas", "short": "Enemigos derrotados", "text": "Los Ecos aún montan guardia donde estuvo la aldea. Derrótalos a todos."},
	"hunt": {"title": "Caza al Eco marcado", "short": "Eco marcado", "text": "Un Eco de Héroe merodea el Pliegue. Está marcado: derrótalo."},
	"duel": {"title": "Duelo en el claro", "short": "Duelo", "text": "Un Eco solitario te espera en un claro apartado. Solo uno de los dos sale."},
	"guardian": {"title": "El guardián de la Costura", "short": "Guardián", "text": "Un Eco custodia la Costura. Derrótalo para que el Pliegue se acuerde de sí mismo."},
	"boss": {"title": "El Coloso del Pliegue", "short": "Coloso", "text": "La piedra del piso tomó forma. Derrota al Coloso."},
	"stealth": {"title": "Sin que lo oigan", "short": "Campamento", "text": "Limpia el campamento marcado antes de que den la alarma. Si te ven, aún cuenta, pero sin bonus."},
	"waves": {"title": "Oleadas en el altar", "short": "Oleadas", "text": "Activa el altar: los Ecos acudirán en oleadas. Resiste las %d."},
	"survivor": {"title": "Aguanta el recuerdo", "short": "Tiempo", "text": "Activa el altar y sobrevive %d s mientras los Ecos te rodean."},
	"timed": {"title": "Contrarreloj", "short": "Enemigos derrotados", "text": "Limpia el piso en menos de %s. El Pliegue se desvanece rápido."},
	"gather": {"title": "Encargo de materiales", "short": "Recogido", "text": "Reúne %d unidades de %s antes de cerrar el piso."},
	"harvest": {"title": "Cosecha de hierbas", "short": "Hierbas", "text": "Elowen necesita hierbas medicinales: recoge %d."},
	"treasure": {"title": "Busca los cofres", "short": "Cofres", "text": "El Pliegue guarda cofres en sus claros. Abre %d."},
	"ambush": {"title": "Cofres con trampa", "short": "Cofres", "text": "Estos cofres están trampeados: al abrirlos acuden Ecos. Abre %d."},
	"explore": {"title": "Recorre el Pliegue", "short": "Claros visitados", "text": "Visita %d claros distintos para que el Pliegue te reconozca."},
	"hidden": {"title": "El claro oculto", "short": "Cofre oculto", "text": "Un claro sin sendero esconde un cofre. Sigue la brújula."},
	"banners": {"title": "Derriba los estandartes", "short": "Estandartes", "text": "Derriba los 3 estandartes del campamento marcado. Te oirán."},
	"beacons": {"title": "Enciende las balizas", "short": "Balizas", "text": "Enciende las 3 balizas, en el orden que quieras."},
	"delivery": {"title": "La reliquia", "short": "Entrega", "text": "Lleva la reliquia del primer claro al segundo sin caer."},
	"rescue": {"title": "Rescate", "short": "Aldeano", "text": "Un aldeano está preso en el campamento marcado. Libéralo y escóltalo hasta la Costura."},
	"choice": {"title": "Elige tu camino", "short": "Camino", "text": "Junto al cartel puedes elegir: el camino fácil o el difícil (+50 % de recompensa)."},
}
## Misiones sorteables en pisos que no son 1, 5 ni 10.
const POOL := ["hunt", "duel", "guardian", "stealth", "waves", "survivor", "timed", "gather", "harvest", "treasure", "ambush",
	"explore", "hidden", "banners", "beacons", "delivery", "rescue", "choice"]
const OPTIONALS := {
	"no_potions": {"text": "Sin usar pociones", "bonus": 0.15},
	"speed": {"text": "Termina en menos de %s", "bonus": 0.2},
	"flawless": {"text": "Sin bajar del 50 % de vida", "bonus": 0.2},
	"all_chests": {"text": "Abre todos los cofres del piso", "bonus": 0.2},
	"no_alert": {"text": "Sin que ningún campamento se alerte", "bonus": 0.25},
}


## Tipo de misión del piso: 1 = clear, 5 y 10 = boss; el resto, sorteo por semilla (distinto al del piso anterior y siguiente).
static func pick_type(seed_value: int, floor_number: int) -> String:
	if floor_number <= 1:
		return "clear"
	if floor_number % 5 == 0:
		return "boss"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + floor_number * 131
	var index := (rng.randi() + floor_number * 5) % POOL.size()
	return POOL[index]


static func pick_optional(rng: RandomNumberGenerator, main_type: String) -> String:
	var options := OPTIONALS.keys()
	if main_type in ["stealth", "waves", "survivor"]:
		options.erase("no_alert")
	if main_type == "treasure" or main_type == "ambush":
		options.erase("all_chests")
	if main_type == "timed":
		options.erase("speed")
	return options[rng.randi() % options.size()]


static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## Texto descriptivo de una misión ya diseñada (usa los parámetros del diseño).
static func text_for(spec: Dictionary) -> String:
	var type: String = spec["type"]
	var base: String = TYPES[type]["text"]
	match type:
		"waves":
			return base % int((spec["layout"]["waves"] as Array).size())
		"survivor":
			return base % int(spec["layout"]["seconds"])
		"timed":
			return base % clock(float(spec["layout"]["seconds"]))
		"gather":
			return base % [int(spec["layout"]["count"]), String(spec["layout"]["what"])]
		"harvest", "treasure", "ambush", "explore":
			return base % int(spec["layout"]["count"])
	return base
