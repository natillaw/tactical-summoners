## CharacterBuilder — ensambla un personaje humano a partir de las piezas de Quaternius.
##
## Todos los modelos comparten el mismo esqueleto UE (65 huesos), así que el cuerpo
## base aporta el Skeleton3D y el pelo, las cejas y la ropa se "injertan": se mueven
## sus MeshInstance3D al esqueleto del cuerpo (el skin enlaza por nombre de hueso).
##
## opciones = {sex, skin, hair, hair_color, brows, outfit}  (ver los catálogos).
class_name CharacterBuilder
extends RefCounted

const DIR := "res://assets/models/creator/"

const SEXES := {"male": "Hombre", "female": "Mujer"}
const BODY_FILE := {"male": "Superhero_Male_FullBody.gltf", "female": "Superhero_Female_FullBody.gltf"}
const BROW_FILE := {"male": "Eyebrows_Regular.gltf", "female": "Eyebrows_Female.gltf"}

## Tonos de piel (multiplican la textura base).
const SKINS := {
	"claro": Color(1.0, 1.0, 1.0), "trigueño": Color(0.88, 0.74, 0.6), "moreno": Color(0.66, 0.5, 0.38),
	"oscuro": Color(0.45, 0.33, 0.26), "pálido": Color(1.0, 0.92, 0.9),
}

const HAIRS := {
	"none": {"name": "Sin pelo", "file": ""},
	"buzzed": {"name": "Rapado", "file": "Hair_Buzzed.gltf"},
	"buzzed_f": {"name": "Rapado (mujer)", "file": "Hair_BuzzedFemale.gltf"},
	"parted": {"name": "Raya", "file": "Hair_SimpleParted.gltf"},
	"long": {"name": "Largo", "file": "Hair_Long.gltf"},
	"buns": {"name": "Moños", "file": "Hair_Buns.gltf"},
	"beard": {"name": "Barba", "file": "Hair_Beard.gltf"},
	"bob": {"name": "Media melena (bob)", "file": "Hair_Bob_M.gltf", "file_f": "Hair_Bob_F.gltf"},
	"shoulder": {"name": "Al hombro ondulado", "file": "Hair_Shoulder_M.gltf", "file_f": "Hair_Shoulder_F.gltf"},
	"wavy": {"name": "Largo ondulado", "file": "Hair_Wavy_M.gltf", "file_f": "Hair_Wavy_F.gltf"},
	"pompadour": {"name": "Tupé", "file": "Hair_Pompadour_M.gltf", "file_f": "Hair_Pompadour_F.gltf"},
	"messy": {"name": "Desordenado", "file": "Hair_Messy_M.gltf", "file_f": "Hair_Messy_F.gltf"},
	"poof": {"name": "Voluminoso", "file": "Hair_Poof_M.gltf", "file_f": "Hair_Poof_F.gltf"},
	"crop": {"name": "Corto texturado", "file": "Hair_Crop_M.gltf", "file_f": "Hair_Crop_F.gltf"},
	"twin_buns": {"name": "Doble moño", "file": "Hair_TwinBuns_M.gltf", "file_f": "Hair_TwinBuns_F.gltf"},
	"long_beard": {"name": "Barba larga", "file": "Hair_LongBeard_M.gltf", "file_f": "Hair_LongBeard_F.gltf"},
	"goatee": {"name": "Perilla", "file": "Hair_Goatee_M.gltf", "file_f": "Hair_Goatee_F.gltf"},
}

const HAIR_COLORS := {
	"castaño": Color(0.45, 0.3, 0.2), "negro": Color(0.1, 0.09, 0.09), "rubio": Color(0.9, 0.75, 0.4),
	"pelirrojo": Color(0.7, 0.3, 0.15), "gris": Color(0.7, 0.7, 0.72), "blanco": Color(0.95, 0.95, 0.95),
	"azul": Color(0.3, 0.45, 0.95), "morado": Color(0.6, 0.3, 0.85),
}

## Ropa: "sex" = una versión por sexo ({sex}_Archivo), si no, un único archivo.
## "hide" = piezas (por nombre) que no se muestran, p. ej. la capucha.
const OUTFITS := {
	"none": {"name": "Sin ropa (cuerpo base)"},
	"peasant": {"name": "Campesino", "dir": "outfits/", "file": "Peasant.gltf", "sex": true},
	"ranger": {"name": "Explorador", "dir": "outfits/", "file": "Ranger.gltf", "sex": true, "hide": ["Hood"]},
	"ranger_hood": {"name": "Explorador (capucha)", "dir": "outfits/", "file": "Ranger.gltf", "sex": true},

	# Sets de inicio por clase (recolores/variantes generados con tools/outfits/*.py a partir de Ranger y Peasant).
	# "parts": lista de piezas; "tex" cambia la textura base de la pieza; "only"/"hide" filtran mallas por nombre;
	# "mat_from" toma el material de otra malla ya injertada (piezas extra sin textura propia).
	"warrior": {"name": "Guerrero", "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood"], "tex": "Ranger_BaseColor_warrior"},
		{"file": "Warrior_Acc_PauldronR.gltf", "sex": true, "optional": true, "mat_from": "Pauldron"},
	]},
	"mage": {"name": "Mago", "parts": [
		{"file": "Peasant.gltf", "sex": true, "hide": ["Legs"], "tex": "Peasant_BaseColor_mage"},
		{"file": "Mage_Robe.gltf", "sex": true, "mat_from": "Body"},
		{"file": "Ranger.gltf", "sex": true, "only": ["Hood"], "tex": "Ranger_BaseColor_mage"},
	]},
	"archer": {"name": "Arquero", "parts": [{"file": "Ranger.gltf", "sex": true, "hide": ["Hood"], "tex": "Ranger_BaseColor_archer"}]},

	# Sets de armadura completos (vista previa/creador). En juego las piezas se equipan una a una: opts["gear"] = {ranura: set}.
	"armor_footman": {"name": "Armadura: Soldado de Leva", "gear": "footman"},
	"armor_knight": {"name": "Armadura: Escudero de Acero", "gear": "knight"},
	"armor_hoplite": {"name": "Armadura: Panoplia de Bronce", "gear": "hoplite"},
	"armor_norse": {"name": "Armadura: Cota del Norte", "gear": "norse"},
	"armor_dark": {"name": "Armadura: Hierro Ennegrecido", "gear": "dark"},
	"armor_montero": {"name": "Arquero: Montero Novato", "gear": "montero"},
	"armor_llanura": {"name": "Arquero: Explorador de la Llanura", "gear": "llanura"},
	"armor_guardabosques": {"name": "Arquero: Guardabosques", "gear": "guardabosques"},
	"armor_centinela": {"name": "Arquero: Centinela del Norte", "gear": "centinela"},
	"armor_dunas": {"name": "Arquero: Rastreador de Dunas", "gear": "dunas"},
	"armor_aprendiz": {"name": "Mago: Aprendiz de Magia", "gear": "aprendiz"},
	"armor_brasa": {"name": "Mago: Chispa de Brasa", "gear": "brasa"},
	"armor_escarcha": {"name": "Mago: Escarcha del Norte", "gear": "escarcha"},
	"armor_sabio": {"name": "Mago: Sabio Errante", "gear": "sabio"},
	"armor_osario": {"name": "Mago: Osario Penitente", "gear": "osario"},
	"armor_ladron": {"name": "Picaro: Ladron de Callejon", "gear": "ladron"},
	"armor_cuervo": {"name": "Picaro: Sombra de Cuervo", "gear": "cuervo"},
	"armor_desierto": {"name": "Picaro: Bribon del Desierto", "gear": "desierto"},
	"armor_bosque": {"name": "Picaro: Batidor del Bosque", "gear": "bosque"},
	"armor_carmesi": {"name": "Picaro: Hoja Carmesi", "gear": "carmesi"},
	"rogue": {"name": "Pícaro", "parts": [{"file": "Ranger.gltf", "sex": true, "tex": "Ranger_BaseColor_rogue"}]},
}


static func default_options() -> Dictionary:
	return {"sex": "male", "skin": "claro", "hair": "buzzed", "hair_color": "castaño", "brows": true, "outfit": "ranger"}


static func random_options(rng: RandomNumberGenerator) -> Dictionary:
	var sex: String = SEXES.keys()[rng.randi() % SEXES.size()]
	return {
		"sex": sex, "skin": SKINS.keys()[rng.randi() % SKINS.size()],
		"hair": HAIRS.keys()[rng.randi() % HAIRS.size()], "hair_color": HAIR_COLORS.keys()[rng.randi() % HAIR_COLORS.size()],
		"brows": rng.randf() < 0.8, "outfit": OUTFITS.keys()[rng.randi() % OUTFITS.size()],
	}


static func build(opts: Dictionary) -> Node3D:
	var o := default_options()
	o.merge(opts, true)
	var sex := String(o["sex"])
	var root := (load(DIR + "body/" + String(BODY_FILE[sex])) as PackedScene).instantiate() as Node3D
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D

	var tone: Color = SKINS.get(String(o["skin"]), Color.WHITE)
	var gear := _gear_of(o)
	var has_outfit := String(o["outfit"]) != "none" or not gear.is_empty()
	for mi: MeshInstance3D in _meshes(root):
		var mesh_name := String(mi.name)
		if mesh_name == "Eyebrows":
			# Las cejas propias del cuerpo no se pueden teñir bien: se usan las del pack de pelo.
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		if mesh_name == "Eyes":
			continue
		_tint(mi, tone)
		if has_outfit:
			_crop_to_head_and_hands(mi, skeleton)

	var hair: Dictionary = HAIRS.get(String(o["hair"]), HAIRS["none"])
	var hair_file := String(hair.get("file_f", hair["file"])) if sex == "female" else String(hair["file"])
	var outfit_def: Dictionary = OUTFITS.get(String(o["outfit"]), OUTFITS["none"])
	if hair_file != "" and not _hair_hidden(String(o["hair"]), gear):
		var hair_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + hair_file, skeleton, []):
			_tint(mi, hair_color)
	if bool(o["brows"]):
		var brow_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + String(BROW_FILE[sex]), skeleton, []):
			_tint(mi, brow_color)

	var outfit: Dictionary = OUTFITS.get(String(o["outfit"]), OUTFITS["none"])
	var parts: Array = outfit.get("parts", []) if gear.is_empty() else _gear_parts(gear)
	if parts.is_empty() and outfit.has("file") and gear.is_empty():
		parts = [{"file": outfit["file"], "dir": outfit["dir"], "sex": outfit.get("sex", false), "hide": outfit.get("hide", [])}]
	var grafted: Array[MeshInstance3D] = []
	for part: Dictionary in parts:
		if part.has("armor"):
			var apath := ARMOR_DIR + ("Male_" if sex == "male" else "Female_") + "Armor_" + String(part["armor"]).capitalize() + "_" + String(part["slot"]) + ".gltf"
			if ResourceLoader.exists(apath):
				for mi: MeshInstance3D in _graft(apath, skeleton, [], []):
					_armor_materials(mi, String(part["armor"]))
			elif not bool(part.get("optional", false)):
				push_warning("CharacterBuilder: falta " + apath)
			continue
		var file := String(part["file"])
		if bool(part.get("sex", false)):
			file = ("Male_" if sex == "male" else "Female_") + file
		var path := DIR + String(part.get("dir", "outfits/")) + file
		if not ResourceLoader.exists(path):
			if bool(part.get("optional", false)):
				continue  # p. ej. la mujer ya trae las dos hombreras
			push_warning("CharacterBuilder: falta " + path)
			continue
		var tex: Texture2D = null
		if part.has("tex"):
			tex = load(DIR + "outfits/T_" + String(part["tex"]) + ".png") as Texture2D
		var meshes := _graft(path, skeleton, part.get("hide", []), part.get("only", []))
		for mi: MeshInstance3D in meshes:
			if part.has("mat_from"):
				_borrow_material(mi, grafted, String(part["mat_from"]))
			elif tex != null:
				_retexture(mi, tex)
		grafted.append_array(meshes)
	return root


## Piezas de armadura que lleva el personaje: {ranura: set}. Viene de opts["gear"] o de un outfit "armor_<set>" (set completo).
static func _gear_of(o: Dictionary) -> Dictionary:
	if o.has("gear") and not (o["gear"] as Dictionary).is_empty():
		return o["gear"]
	var def: Dictionary = OUTFITS.get(String(o["outfit"]), {})
	if def.has("gear"):
		var full := {}
		for slot: String in ARMOR_SLOTS:
			full[slot] = String(def["gear"])
		return full
	return {}


const ARMOR_SLOTS := ["head", "chest", "legs", "hands", "boots"]
## Sets de picaro: salen de los trajes Quaternius (Ranger/Peasant) recoloreados y editados, no de geometria propia
## (tools/outfits/make_rogue_*.py). hood = capucha; body/legs/boots = de que traje base sale cada pieza.
const QSETS := {
	# --- arqueros (base Ranger recoloreada; gorra, sombrero, cornamenta, plumas, aljaba... vienen en las piezas añadidas)
	"montero": {"pre": "ar", "hood": "", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "bracer": true, "pauldron": false, "hair": true, "beard": true},        # gorra con pluma + aljaba
	"llanura": {"pre": "ar", "hood": "", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "bracer": true, "pauldron": false, "hair": true, "beard": true},        # sombrero de ala ancha
	"guardabosques": {"pre": "ar", "hood": "", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "bracer": true, "pauldron": false, "hair": true, "beard": true},   # cornamenta + manto de piel
	"centinela": {"pre": "ar", "hood": "Ranger.gltf", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "bracer": true, "pauldron": true, "hair": true, "beard": false},  # capucha + hombreras + cuello de piel
	"dunas": {"pre": "ar", "hood": "", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "bracer": true, "pauldron": false, "hair": true, "beard": true},           # cinta de plumas + cuentas
	# --- magos (base Peasant: tunica + falda de tunica; capucha Ranger). "pre" = prefijo de las texturas recoloreadas
	"aprendiz": {"pre": "mg", "hood": "Ranger.gltf", "body": "Peasant", "legs": "Robe", "boots": "Peasant", "bracer": false, "pauldron": false, "hair": true, "beard": true},   # capucha + cuerda + bufanda
	"brasa": {"pre": "mg", "hood": "", "body": "Peasant", "legs": "Robe", "boots": "Peasant", "bracer": false, "pauldron": false, "hair": true, "beard": true},          # diadema + capelo
	"escarcha": {"pre": "mg", "hood": "Ranger.gltf", "body": "Peasant", "legs": "Robe", "boots": "Peasant", "bracer": false, "pauldron": false, "hair": true, "beard": true},   # capucha + cuello de piel
	"sabio": {"pre": "mg", "hood": "", "body": "Peasant", "legs": "Robe", "boots": "Peasant", "bracer": false, "pauldron": false, "hair": true, "beard": true},          # sombrero puntiagudo + capa
	"osario": {"pre": "mg", "hood": "Ranger.gltf", "body": "Peasant", "legs": "Robe", "boots": "Peasant", "bracer": false, "pauldron": false, "hair": true, "beard": true},    # capucha con cuernos de hueso + costillas
	"ladron": {"hood": "", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "pauldron": false, "hair": true, "beard": false},      # bandana
	"cuervo": {"hood": "Ranger_HoodPeak.gltf", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "pauldron": true, "hair": true, "beard": false},   # capucha picuda + pico
	"desierto": {"hood": "", "body": "Peasant", "legs": "Peasant", "boots": "Ranger", "pauldron": false, "hair": false, "beard": false},   # turbante + velo
	"bosque": {"hood": "Ranger.gltf", "body": "Ranger", "legs": "Ranger", "boots": "Ranger", "pauldron": true, "hair": true, "beard": false},    # capucha + bandana
	"carmesi": {"hood": "", "body": "Peasant", "legs": "Ranger", "boots": "Ranger", "pauldron": false, "hair": true, "beard": true},        # gorra con pluma + antifaz
}
const CLOSED_HELMETS := ["knight", "dark"]  ## cubren toda la cara: tampoco cabe barba


## Con casco puesto el pelo se oculta (se atravesaría); las barbas se quedan salvo bajo yelmos cerrados.
static func _hair_hidden(hair_id: String, gear: Dictionary) -> bool:
	if not gear.has("head"):
		return false
	var qs: Dictionary = QSETS.get(String(gear["head"]), {})
	if not qs.is_empty():
		return not bool(qs["beard" if hair_id in ["beard", "long_beard", "goatee"] else "hair"])
	if hair_id in ["beard", "long_beard", "goatee"]:
		return String(gear["head"]) in CLOSED_HELMETS
	return true


## Piezas a injertar: la armadura equipada por ranura y, donde falta, la ropa base de Campesino.
static func _gear_parts(gear: Dictionary) -> Array:
	var parts: Array = []
	var sleeve_set := String(gear.get("chest", gear.values()[0]))
	var sleeve_tex: String = "Ranger_BaseColor_" + String(QSETS[sleeve_set].get("pre", "rg")) + "_" + sleeve_set if QSETS.has(sleeve_set) else {"footman": "Ranger_BaseColor_archer", "hoplite": "Ranger_BaseColor_warrior"}.get(sleeve_set, "Ranger_BaseColor_rogue")
	parts.append({"file": "Ranger.gltf", "sex": true, "only": ["Arms"], "hide": ["Bracer"], "tex": sleeve_tex})  # mangas ajustadas: bajo los brazales
	var base := {"chest": "Body", "legs": "Legs", "boots": "Feet"}
	for slot: String in ["chest", "legs", "boots"]:
		if gear.has(slot):
			parts.append_array(_set_parts(String(gear[slot]), slot))
		else:
			parts.append({"file": "Peasant.gltf", "sex": true, "only": [base[slot]]})
	for slot: String in ["head", "hands"]:
		if gear.has(slot):
			parts.append_array(_set_parts(String(gear[slot]), slot))
	return parts


## Piezas de una ranura de un set: armadura propia (guerrero) o piezas Quaternius recoloreadas (picaro).
static func _set_parts(set_id: String, slot: String) -> Array:
	if not QSETS.has(set_id):
		return [{"armor": set_id, "slot": slot}]
	var def: Dictionary = QSETS[set_id]
	var pre := String(def.get("pre", "rg"))
	var rtex := "Ranger_BaseColor_" + pre + "_" + set_id
	var ptex := "Peasant_BaseColor_" + pre + "_" + set_id
	var out: Array = []
	match slot:
		"head":
			if String(def["hood"]) != "":
				out.append({"file": String(def["hood"]), "sex": true, "only": ["Hood"], "tex": rtex})
		"hands":
			if bool(def.get("bracer", true)):
				out.append({"file": "Ranger.gltf", "sex": true, "only": ["Bracer"], "tex": rtex})
		"chest":
			if String(def["body"]) == "Ranger":
				out.append({"file": "Ranger.gltf", "sex": true, "only": ["Body"], "tex": rtex})
			else:
				out.append({"file": "Peasant.gltf", "sex": true, "only": ["Body"], "tex": ptex})
			if bool(def["pauldron"]):
				out.append({"file": "Ranger.gltf", "sex": true, "only": ["Pauldron"], "tex": rtex})
				out.append({"file": "Warrior_Acc_PauldronR.gltf", "sex": true, "optional": true, "mat_from": "Pauldron"})
		"legs":
			if String(def["legs"]) == "Robe":
				out.append({"file": "Peasant.gltf", "sex": true, "only": ["Legs"], "tex": ptex})
				out.append({"file": "Mage_Robe.gltf", "sex": true, "tex": ptex})
			else:
				out.append({"file": String(def["legs"]) + ".gltf", "sex": true, "only": ["Legs"], "tex": rtex if String(def["legs"]) == "Ranger" else ptex})
		"boots":
			if String(def["boots"]) == "Peasant":
				out.append({"file": "Peasant.gltf", "sex": true, "only": ["Feet"], "tex": ptex})
			else:
				out.append({"file": "Ranger.gltf", "sex": true, "only": ["Feet"], "tex": rtex})
	out.append({"armor": set_id, "slot": slot, "optional": true})  # piezas añadidas encima del traje base (bandana, capa, fajín...)
	return out


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Mueve las mallas de otra escena al esqueleto `skeleton`; devuelve las mallas injertadas.
static func _graft(path: String, skeleton: Skeleton3D, hide_names: Array, only_names: Array = []) -> Array[MeshInstance3D]:
	var grafted: Array[MeshInstance3D] = []
	var scene := (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in _meshes(scene):
		var skip := false
		for h: String in hide_names:
			skip = skip or h in String(mi.name)
		if not only_names.is_empty():
			var keep := false
			for n: String in only_names:
				keep = keep or n in String(mi.name)
			skip = skip or not keep
		mi.get_parent().remove_child(mi)
		if skip:
			mi.free()
			continue
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		grafted.append(mi)
	scene.free()
	return grafted


## Cambia la textura base de las superficies que usan el atlas de la ropa (la piel de los brazos no se toca).
static func _retexture(mi: MeshInstance3D, tex: Texture2D) -> void:
	for i in range(mi.mesh.get_surface_count()):
		var base := mi.get_active_material(i)
		if base is StandardMaterial3D:
			var old := (base as StandardMaterial3D).albedo_texture
			if old != null and ("Ranger" in old.resource_path or "Peasant" in old.resource_path):
				var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_texture = tex
				mi.set_surface_override_material(i, mat)


## Piezas extra sin material propio: copian el de otra malla ya injertada cuyo nombre contenga `key`.
static func _borrow_material(mi: MeshInstance3D, pool: Array[MeshInstance3D], key: String) -> void:
	for other: MeshInstance3D in pool:
		if key in String(other.name):
			var mat := other.get_active_material(0)
			for i in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(i, mat)
			return


## Materiales de armadura por ranura (plate/mail/leather/trim/cloth/bone): texturas neutras + tinte por set.
const ARMOR_DIR := "res://assets/models/creator/armor/"
const ARMOR_SLOT := {  # ranura -> [textura, rugosidad, metálico]
	"plate": ["plate", 0.62, 0.08], "trim": ["plate", 0.5, 0.15], "mail": ["mail", 0.65, 0.1],
	"leather": ["leather", 0.85, 0.0], "cloth": ["cloth", 0.95, 0.0], "pants": ["cloth", 0.95, 0.0], "bone": ["leather", 0.6, 0.0],
}
const ARMOR_TINTS := {  # apagados, estilo pintado de Quaternius
	"montero": {"cloth": Color(0.28, 0.42, 0.2), "leather": Color(0.38, 0.26, 0.14), "trim": Color(0.62, 0.5, 0.28), "plate": Color(0.5, 0.52, 0.45), "mail": Color(0.5, 0.52, 0.45), "pants": Color(0.25, 0.3, 0.18), "bone": Color(0.85, 0.8, 0.66)},
	"llanura": {"cloth": Color(0.78, 0.68, 0.48), "leather": Color(0.5, 0.36, 0.2), "trim": Color(0.62, 0.42, 0.24), "plate": Color(0.6, 0.55, 0.45), "mail": Color(0.6, 0.55, 0.45), "pants": Color(0.6, 0.52, 0.38), "bone": Color(0.88, 0.82, 0.68)},
	"guardabosques": {"cloth": Color(0.2, 0.34, 0.26), "leather": Color(0.3, 0.22, 0.14), "trim": Color(0.55, 0.45, 0.28), "plate": Color(0.4, 0.45, 0.4), "mail": Color(0.4, 0.45, 0.4), "pants": Color(0.18, 0.26, 0.2), "bone": Color(0.86, 0.82, 0.7)},
	"centinela": {"cloth": Color(0.4, 0.46, 0.58), "leather": Color(0.3, 0.26, 0.22), "trim": Color(0.62, 0.62, 0.68), "plate": Color(0.5, 0.54, 0.62), "mail": Color(0.5, 0.54, 0.62), "pants": Color(0.28, 0.32, 0.42), "bone": Color(0.92, 0.92, 0.94)},
	"dunas": {"cloth": Color(0.7, 0.34, 0.2), "leather": Color(0.46, 0.32, 0.18), "trim": Color(0.76, 0.58, 0.28), "plate": Color(0.6, 0.5, 0.4), "mail": Color(0.6, 0.5, 0.4), "pants": Color(0.62, 0.3, 0.18), "bone": Color(0.9, 0.85, 0.72)},
	"aprendiz": {"cloth": Color(0.4, 0.45, 0.72), "leather": Color(0.4, 0.3, 0.16), "trim": Color(0.78, 0.64, 0.32), "plate": Color(0.6, 0.6, 0.66), "mail": Color(0.6, 0.6, 0.66), "pants": Color(0.3, 0.3, 0.5), "bone": Color(0.85, 0.8, 0.7)},
	"brasa": {"cloth": Color(0.62, 0.18, 0.1), "leather": Color(0.3, 0.18, 0.1), "trim": Color(0.85, 0.66, 0.28), "plate": Color(0.6, 0.5, 0.4), "mail": Color(0.6, 0.5, 0.4), "pants": Color(0.5, 0.15, 0.08), "bone": Color(0.9, 0.85, 0.75)},
	"escarcha": {"cloth": Color(0.72, 0.82, 0.94), "leather": Color(0.45, 0.5, 0.58), "trim": Color(0.74, 0.8, 0.88), "plate": Color(0.7, 0.75, 0.82), "mail": Color(0.7, 0.75, 0.82), "pants": Color(0.55, 0.68, 0.85), "bone": Color(0.95, 0.95, 0.98)},
	"sabio": {"cloth": Color(0.42, 0.27, 0.6), "leather": Color(0.3, 0.2, 0.12), "trim": Color(0.85, 0.7, 0.35), "plate": Color(0.6, 0.55, 0.65), "mail": Color(0.6, 0.55, 0.65), "pants": Color(0.32, 0.2, 0.5), "bone": Color(0.88, 0.84, 0.74)},
	"osario": {"cloth": Color(0.16, 0.1, 0.2), "leather": Color(0.1, 0.08, 0.1), "trim": Color(0.55, 0.5, 0.6), "plate": Color(0.3, 0.3, 0.34), "mail": Color(0.3, 0.3, 0.34), "pants": Color(0.12, 0.08, 0.16), "bone": Color(0.88, 0.84, 0.72)},
	"ladron": {"cloth": Color(0.3, 0.34, 0.44), "leather": Color(0.25, 0.18, 0.13), "trim": Color(0.55, 0.5, 0.4), "plate": Color(0.5, 0.5, 0.55), "mail": Color(0.5, 0.5, 0.55), "pants": Color(0.2, 0.2, 0.26), "bone": Color(0.8, 0.76, 0.66)},
	"cuervo": {"cloth": Color(0.17, 0.15, 0.22), "leather": Color(0.14, 0.12, 0.14), "trim": Color(0.45, 0.4, 0.5), "plate": Color(0.3, 0.3, 0.36), "mail": Color(0.3, 0.3, 0.36), "pants": Color(0.12, 0.11, 0.15), "bone": Color(0.7, 0.68, 0.64)},
	"desierto": {"cloth": Color(0.8, 0.72, 0.52), "leather": Color(0.5, 0.36, 0.22), "trim": Color(0.7, 0.5, 0.25), "plate": Color(0.6, 0.55, 0.45), "mail": Color(0.6, 0.55, 0.45), "pants": Color(0.66, 0.58, 0.42), "bone": Color(0.85, 0.8, 0.68)},
	"bosque": {"cloth": Color(0.24, 0.4, 0.22), "leather": Color(0.32, 0.26, 0.14), "trim": Color(0.55, 0.5, 0.3), "plate": Color(0.45, 0.5, 0.4), "mail": Color(0.45, 0.5, 0.4), "pants": Color(0.2, 0.3, 0.18), "bone": Color(0.8, 0.76, 0.62)},
	"carmesi": {"cloth": Color(0.58, 0.14, 0.14), "leather": Color(0.22, 0.13, 0.11), "trim": Color(0.75, 0.6, 0.32), "plate": Color(0.5, 0.45, 0.45), "mail": Color(0.5, 0.45, 0.45), "pants": Color(0.3, 0.1, 0.12), "bone": Color(0.85, 0.8, 0.7)},
	"knight": {"plate": Color(0.5, 0.55, 0.64), "trim": Color(0.78, 0.64, 0.36), "mail": Color(0.58, 0.6, 0.64), "leather": Color(0.36, 0.25, 0.17), "cloth": Color(0.24, 0.32, 0.55), "pants": Color(0.2, 0.24, 0.36), "bone": Color(0.8, 0.76, 0.66)},
	"footman": {"plate": Color(0.6, 0.62, 0.66), "trim": Color(0.62, 0.5, 0.3), "mail": Color(0.52, 0.54, 0.58), "leather": Color(0.42, 0.29, 0.19), "cloth": Color(0.55, 0.2, 0.17), "pants": Color(0.42, 0.38, 0.3), "bone": Color(0.8, 0.76, 0.66)},
	"hoplite": {"plate": Color(0.72, 0.52, 0.3), "trim": Color(0.8, 0.66, 0.36), "mail": Color(0.62, 0.46, 0.3), "leather": Color(0.45, 0.28, 0.17), "cloth": Color(0.58, 0.16, 0.14), "pants": Color(0.66, 0.58, 0.44), "bone": Color(0.8, 0.76, 0.66)},
	"norse": {"plate": Color(0.4, 0.42, 0.46), "trim": Color(0.7, 0.5, 0.28), "mail": Color(0.48, 0.5, 0.54), "leather": Color(0.4, 0.27, 0.17), "cloth": Color(0.24, 0.35, 0.3), "pants": Color(0.3, 0.34, 0.26), "bone": Color(0.82, 0.78, 0.66)},
	"dark": {"plate": Color(0.24, 0.24, 0.28), "trim": Color(0.6, 0.2, 0.17), "mail": Color(0.32, 0.32, 0.36), "leather": Color(0.18, 0.14, 0.14), "cloth": Color(0.34, 0.08, 0.1), "pants": Color(0.14, 0.13, 0.16), "bone": Color(0.7, 0.68, 0.64)},
}
static var _armor_cache: Dictionary = {}


static func _armor_material(set_id: String, slot: String) -> StandardMaterial3D:
	var key := set_id + "/" + slot
	if _armor_cache.has(key):
		return _armor_cache[key]
	var def: Array = ARMOR_SLOT.get(slot, ARMOR_SLOT["plate"])
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(ARMOR_DIR + "T_" + String(def[0]) + ".png") as Texture2D
	m.albedo_color = (ARMOR_TINTS.get(set_id, ARMOR_TINTS["knight"]) as Dictionary).get(slot, Color.WHITE)
	m.vertex_color_use_as_albedo = true  # oclusión horneada en COLOR_0
	m.normal_enabled = true
	m.normal_texture = load(ARMOR_DIR + "T_" + String(def[0]) + "_n.png") as Texture2D
	m.roughness = float(def[1])
	m.metallic = float(def[2])
	_armor_cache[key] = m
	return m


static func _armor_materials(mi: MeshInstance3D, set_id: String) -> void:
	for i in range(mi.mesh.get_surface_count()):
		var base := mi.mesh.surface_get_material(i)
		var slot := String(base.resource_name) if base != null else "plate"
		mi.set_surface_override_material(i, _armor_material(set_id, slot))


static func _tint(mi: MeshInstance3D, color: Color) -> void:
	for i in range(mi.mesh.get_surface_count()):
		var base := mi.get_active_material(i)
		if base is StandardMaterial3D:
			var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = mat.albedo_color * color
			mi.set_surface_override_material(i, mat)


## Con ropa puesta, la piel del torso/brazos/piernas asomaba por los agujeros de la tela.
## Se recorta el cuerpo base a cabeza, cuello y manos (por el hueso dominante de cada vértice).
static func _crop_to_head_and_hands(mi: MeshInstance3D, skeleton: Skeleton3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or mi.skin == null:
		return
	var out := ArrayMesh.new()
	for s in range(src.get_surface_count()):
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if verts.is_empty() or bones.is_empty() or index.is_empty():
			return
		var stride := bones.size() / verts.size()
		var keep := PackedByteArray()
		keep.resize(verts.size())
		for v in range(verts.size()):
			var best := 0
			var best_weight := -1.0
			for k in range(stride):
				if weights[v * stride + k] > best_weight:
					best_weight = weights[v * stride + k]
					best = bones[v * stride + k]
			var bone_name := String(mi.skin.get_bind_name(best))
			if bone_name.is_empty():
				bone_name = skeleton.get_bone_name(mi.skin.get_bind_bone(best))
			keep[v] = 1 if _keeps_bone(bone_name) else 0
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			if keep[index[t]] == 1 and keep[index[t + 1]] == 1 and keep[index[t + 2]] == 1:
				kept.append(index[t])
				kept.append(index[t + 1])
				kept.append(index[t + 2])
		arrays[Mesh.ARRAY_INDEX] = kept
		for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[custom] = null  # el cuerpo femenino trae datos custom que no se pueden reinsertar
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out


static func _keeps_bone(bone_name: String) -> bool:
	for prefix: String in ["head", "neck", "hand", "thumb", "index", "middle", "ring", "pinky"]:
		if bone_name.to_lower().begins_with(prefix):
			return true
	return false
