## Rarezas de objeto: normal, poco común, raro, épico, único y legendario.
class_name ItemRarity
extends RefCounted

enum Tier { NORMAL, POCO_COMUN, RARO, EPICO, UNICO, LEGENDARIO }

const NAMES := ["Normal", "Poco común", "Raro", "Épico", "Único", "Legendario"]
const COLORS := [
	Color(0.85, 0.85, 0.85), Color(0.35, 0.85, 0.35), Color(0.30, 0.55, 1.0),
	Color(0.70, 0.35, 0.95), Color(0.95, 0.80, 0.30), Color(1.0, 0.50, 0.12),
]
## Multiplicador del presupuesto de daño del arma.
const POWER := [1.0, 1.1, 1.25, 1.45, 1.6, 1.8]
## Afijos (stats extra) por rareza.
const AFFIXES := [0, 1, 2, 3, 3, 4]
## Probabilidad relativa genérica (sin piso; solo depuración). Los drops usan `weights_for_floor`.
const WEIGHTS := [50.0, 28.0, 13.0, 6.0, 2.0, 1.0]


## Pesos de rareza por piso (suman 100). Lo raro aparece a medida que subes la Torre:
##   Poco común = 15 + 3·piso (tope 36) · Raro = 2.5·(piso − 2) (tope 25) · Épico = piso − 5 (tope 12)
##   Único = 0.4·(piso − 8) (tope 5) · Legendario = 0.15·(piso − 19) (tope 2) · Normal = el resto.
## Piso 1: 82 / 18 / 0 / 0 / 0 / 0.  Piso 5: 62.5 / 30 / 7.5.  Piso 10: 38.2 / 36 / 20 / 5 / 0.8 / 0.
static func weights_for_floor(floor_number: int) -> Array:
	var f := float(maxi(floor_number, 1))
	var uncommon := clampf(15.0 + 3.0 * f, 0.0, 36.0)
	var rare := clampf(2.5 * (f - 2.0), 0.0, 25.0)
	var epic := clampf(f - 5.0, 0.0, 12.0)
	var unique := clampf(0.4 * (f - 8.0), 0.0, 5.0)
	var legendary := clampf(0.15 * (f - 19.0), 0.0, 2.0)
	return [100.0 - uncommon - rare - epic - unique - legendary, uncommon, rare, epic, unique, legendary]


static func roll_for_floor(rng: RandomNumberGenerator, floor_number: int) -> int:
	var weights := weights_for_floor(floor_number)
	var r := rng.randf() * 100.0
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return 0


static func display(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func color(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]


static func roll(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w: float in WEIGHTS:
		total += w
	var r := rng.randf() * total
	for i in WEIGHTS.size():
		r -= WEIGHTS[i]
		if r <= 0.0:
			return i
	return 0
