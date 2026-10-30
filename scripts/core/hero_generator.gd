class_name HeroGenerator
extends RefCounted
## Turns (seed, stars) into a complete hero. Same seed + stars = same hero, always.
## Rarity shows up as MORE sprite layers (hat, held item, facial hair), fancier styles,
## more traits/passives and a higher level cap - all of it procedural.


const VERSION := 3   # 1 = Drop A. 2 adds Trust/Obedience/Composure. 3 adds the starting active skill (D-044); look/class/traits are unchanged


static func generate(hero_seed: int, stars: int) -> HeroData:
	var rng := RandomNumberGenerator.new()
	rng.seed = hero_seed
	var h := HeroData.new()
	h.hero_seed = hero_seed
	h.id = "hero_%x" % hero_seed
	h.stars = clampi(stars, 1, HeroTables.MAX_STARS)
	var sd: Dictionary = HeroTables.STAR_DATA[h.stars]

	h.appearance = _make_appearance(rng, sd)
	h.hero_class = _roll_birth_class(rng, h.stars)
	h.hero_name = _make_name(rng)
	if h.stars == 4:
		h.epithet = String(_pick(rng, HeroTables.EPITHETS_4))
	elif h.stars == 5:
		h.epithet = String(_pick(rng, HeroTables.EPITHETS_5))
	h.traits = _roll_traits(rng, int(sd["traits"]), [])
	h.passives = _roll_passives(rng, h.traits, int(sd["passives"]), [])

	var bg: Dictionary = _pick(rng, HeroTables.BACKGROUNDS)
	h.background_id = String(bg["id"])
	h.background_text = String(bg["text"]).replace("{name}", h.hero_name.split(" ")[0])
	var prof_keys: Array = HeroTables.PROFESSIONS.keys()
	h.profession = String(prof_keys[rng.randi() % prof_keys.size()])

	for k in HeroTables.STAT_KEYS:
		h.variance[k] = rng.randf_range(0.92, 1.08)

	# Social state. The first roll is the same call the old loyalty used, so existing seeds keep
	# their looks, class, traits and Trust. Obedience is a NEW roll appended after everything else.
	var trust := 50 + rng.randi_range(-10, 10)
	var obedience := 50 + rng.randi_range(-8, 8)
	for t in h.traits:
		trust += int(HeroTables.TRAITS[t]["loyalty"])
		obedience += int(HeroTables.OBEDIENCE_MODS.get(t, 0))
	h.trust = clampi(trust, 0, 100)
	h.obedience = clampi(obedience, 0, 100)
	h.composure = 100
	h.generator_version = VERSION
	h.ensure_skills()
	return h


## Called by HeroData.promote(): newly reached stars unlock a class (3+), traits, passives.
static func apply_promotion(h: HeroData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = h.hero_seed ^ (h.stars * 7919)
	var sd: Dictionary = HeroTables.STAR_DATA[h.stars]
	var pool: Array = HeroTables.PROMOTION_CLASS_POOL
	# F-007: the pool is empty until advanced classes are decided (P-07); never divide by zero.
	if h.hero_class == "class.none" and h.stars >= 3 and not pool.is_empty():
		h.hero_class = String(pool[rng.randi() % pool.size()])
	if h.traits.size() < int(sd["traits"]):
		h.traits = _roll_traits(rng, int(sd["traits"]), h.traits)
	if h.passives.size() < int(sd["passives"]):
		h.passives = _roll_passives(rng, h.traits, int(sd["passives"]), h.passives)


# --- appearance -------------------------------------------------------------

static func _make_appearance(rng: RandomNumberGenerator, sd: Dictionary) -> Dictionary:
	var rolls: int = int(sd["style_rolls"])
	var hair_color := rng.randi_range(1, 5)
	var a := {}
	a["body"] = "Body/%d" % rng.randi_range(1, 5)
	a["eyes"] = "Eyes/%d" % rng.randi_range(1, 4)
	a["rear_hair"] = _styled(rng, "rear_hair", hair_color, rolls) if rng.randf() < 0.85 else ""
	a["front_hair"] = _styled(rng, "front_hair", hair_color, rolls) if rng.randf() < 0.92 else ""
	a["facial_hair"] = _styled(rng, "facial_hair", hair_color, 1) if rng.randf() < float(sd["facial"]) else ""
	a["top"] = _styled(rng, "top", rng.randi_range(1, 5), rolls)
	a["bottom"] = _styled(rng, "bottom", rng.randi_range(1, 5), rolls)
	a["shoes"] = "Bottom/Shoes_Layer"
	a["hat"] = _styled(rng, "hat", rng.randi_range(1, 5), rolls) if rng.randf() < float(sd["hat"]) else ""
	var held_styles: Array = HeroTables.HELD_STYLES
	var held_roll := rng.randf()
	var held_style: int = int(held_styles[rng.randi() % held_styles.size()])
	a["held"] = ("Held_Item/%d" % held_style) if held_roll < float(sd["held"]) else ""
	return a


static func _styled(rng: RandomNumberGenerator, key: String, color: int, rolls: int) -> String:
	var d: Dictionary = HeroTables.LAYER_DEFS[key]
	var styles: Array = d["styles"]
	var best: int = int(styles[rng.randi() % styles.size()])
	for i in range(rolls - 1):
		best = maxi(best, int(styles[rng.randi() % styles.size()]))
	return "%s/%d_%d" % [d["folder"], best, color]


# --- class / name / traits ---------------------------------------------------

static func _roll_birth_class(rng: RandomNumberGenerator, _stars: int) -> String:
	return _weighted(rng, HeroTables.BIRTH_CLASS_WEIGHTS)


static func _make_name(rng: RandomNumberGenerator) -> String:
	var first: String = String(_pick(rng, HeroTables.NAME_START)) + String(_pick(rng, HeroTables.NAME_END))
	return "%s %s" % [first, _pick(rng, HeroTables.FAMILY_NAMES)]


static func _roll_traits(rng: RandomNumberGenerator, count: int, existing: Array) -> Array:
	var pool: Array = HeroTables.TRAITS.keys()
	var chosen: Array = existing.duplicate()
	var guard := 0
	while chosen.size() < count and guard < 200:
		guard += 1
		var t: String = String(pool[rng.randi() % pool.size()])
		if chosen.has(t) or _conflicts(t, chosen):
			continue
		chosen.append(t)
	return chosen


static func _conflicts(t: String, chosen: Array) -> bool:
	for pair in HeroTables.TRAIT_CONFLICTS:
		if pair[0] == t and chosen.has(pair[1]):
			return true
		if pair[1] == t and chosen.has(pair[0]):
			return true
	return false


static func _roll_passives(rng: RandomNumberGenerator, traits: Array, count: int, existing: Array) -> Array:
	var out: Array = existing.duplicate()
	var candidates: Array = []
	for t in traits:
		var p: String = String(HeroTables.TRAITS[t]["passive"])
		if not candidates.has(p):
			candidates.append(p)
	_shuffle(rng, candidates)
	for p in candidates:
		if out.size() >= count:
			break
		if not out.has(p):
			out.append(p)
	var pool: Array = HeroTables.PASSIVES.keys()
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var p2: String = String(pool[rng.randi() % pool.size()])
		if not out.has(p2):
			out.append(p2)
	return out


# --- small helpers -------------------------------------------------------------

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return String(weights.keys()[0])


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := int(rng.randi() % (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
