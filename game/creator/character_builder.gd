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

	# Armaduras de guerrero con casco (placas / malla): tools/outfits/make_armor.py. "armor" = piezas de armadura (material por ranura, ver ARMOR_TINTS).
	"armor_footman": {"name": "Armadura: Soldado", "hide_hair": true, "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood", "Pauldron"], "tex": "Ranger_BaseColor_archer"},
		{"armor": "footman"},
	]},
	"armor_knight": {"name": "Armadura: Caballero", "hide_hair": true, "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood", "Body", "Pauldron"], "tex": "Ranger_BaseColor_rogue"},
		{"armor": "knight"},
	]},
	"armor_hoplite": {"name": "Armadura: Hoplita", "hide_hair": true, "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood", "Body", "Pauldron"], "tex": "Ranger_BaseColor_warrior"},
		{"armor": "hoplite"},
	]},
	"armor_norse": {"name": "Armadura: Norteño", "hide_hair": true, "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood", "Body", "Pauldron"], "tex": "Ranger_BaseColor_rogue"},
		{"armor": "norse"},
	]},
	"armor_dark": {"name": "Armadura: Caballero Oscuro", "hide_hair": true, "parts": [
		{"file": "Ranger.gltf", "sex": true, "hide": ["Hood", "Body", "Pauldron"], "tex": "Ranger_BaseColor_rogue"},
		{"armor": "dark"},
	]},
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
	var has_outfit := String(o["outfit"]) != "none"
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
	if hair_file != "" and not bool(outfit_def.get("hide_hair", false)):
		var hair_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + hair_file, skeleton, []):
			_tint(mi, hair_color)
	if bool(o["brows"]):
		var brow_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + String(BROW_FILE[sex]), skeleton, []):
			_tint(mi, brow_color)

	var outfit: Dictionary = OUTFITS.get(String(o["outfit"]), OUTFITS["none"])
	var parts: Array = outfit.get("parts", [])
	if parts.is_empty() and outfit.has("file"):
		parts = [{"file": outfit["file"], "dir": outfit["dir"], "sex": outfit.get("sex", false), "hide": outfit.get("hide", [])}]
	var grafted: Array[MeshInstance3D] = []
	for part: Dictionary in parts:
		if part.has("armor"):
			var apath := ARMOR_DIR + ("Male_" if sex == "male" else "Female_") + "Armor_" + String(part["armor"]).capitalize() + ".gltf"
			if ResourceLoader.exists(apath):
				for mi: MeshInstance3D in _graft(apath, skeleton, [], []):
					_armor_materials(mi, String(part["armor"]))
			else:
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
	"plate": ["plate", 0.5, 0.15], "trim": ["plate", 0.38, 0.3], "mail": ["mail", 0.55, 0.2],
	"leather": ["leather", 0.85, 0.0], "cloth": ["cloth", 0.95, 0.0], "bone": ["leather", 0.6, 0.0],
}
const ARMOR_TINTS := {
	"knight": {"plate": Color(0.84, 0.87, 0.93), "trim": Color(0.95, 0.78, 0.38), "mail": Color(0.72, 0.75, 0.8), "leather": Color(0.38, 0.24, 0.15), "cloth": Color(0.2, 0.3, 0.66), "bone": Color(0.9, 0.85, 0.72)},
	"footman": {"plate": Color(0.74, 0.76, 0.8), "trim": Color(0.72, 0.56, 0.3), "mail": Color(0.62, 0.64, 0.68), "leather": Color(0.46, 0.3, 0.18), "cloth": Color(0.66, 0.15, 0.12), "bone": Color(0.9, 0.85, 0.72)},
	"hoplite": {"plate": Color(0.95, 0.62, 0.28), "trim": Color(1.0, 0.82, 0.36), "mail": Color(0.8, 0.55, 0.3), "leather": Color(0.52, 0.28, 0.15), "cloth": Color(0.72, 0.1, 0.1), "bone": Color(0.9, 0.85, 0.72)},
	"norse": {"plate": Color(0.46, 0.47, 0.52), "trim": Color(0.88, 0.6, 0.28), "mail": Color(0.55, 0.57, 0.62), "leather": Color(0.42, 0.27, 0.16), "cloth": Color(0.22, 0.34, 0.28), "bone": Color(0.92, 0.87, 0.72)},
	"dark": {"plate": Color(0.2, 0.2, 0.24), "trim": Color(0.78, 0.14, 0.12), "mail": Color(0.3, 0.3, 0.34), "leather": Color(0.15, 0.12, 0.12), "cloth": Color(0.4, 0.05, 0.07), "bone": Color(0.8, 0.78, 0.74)},
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
