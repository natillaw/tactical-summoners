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
	if String(hair["file"]) != "":
		var hair_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + String(hair["file"]), skeleton, []):
			_tint(mi, hair_color)
	if bool(o["brows"]):
		var brow_color: Color = HAIR_COLORS.get(String(o["hair_color"]), Color.WHITE)
		for mi: MeshInstance3D in _graft(DIR + "hair/" + String(BROW_FILE[sex]), skeleton, []):
			_tint(mi, brow_color)

	var outfit: Dictionary = OUTFITS.get(String(o["outfit"]), OUTFITS["none"])
	var path := ""
	if outfit.has("file"):
		var file := String(outfit["file"])
		if bool(outfit.get("sex", false)):
			file = ("Male_" if sex == "male" else "Female_") + file
		path = DIR + String(outfit["dir"]) + file
	if path != "":
		_graft(path, skeleton, outfit.get("hide", []))
	return root


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Mueve las mallas de otra escena al esqueleto `skeleton`; devuelve las mallas injertadas.
static func _graft(path: String, skeleton: Skeleton3D, hide_names: Array) -> Array[MeshInstance3D]:
	var grafted: Array[MeshInstance3D] = []
	var scene := (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in _meshes(scene):
		var skip := false
		for h: String in hide_names:
			skip = skip or h in String(mi.name)
		mi.get_parent().remove_child(mi)
		if skip:
			mi.free()
			continue
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		grafted.append(mi)
	scene.free()
	return grafted


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
