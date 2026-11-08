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
## Probabilidad relativa al soltar un objeto.
const WEIGHTS := [50.0, 28.0, 13.0, 6.0, 2.0, 1.0]


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
