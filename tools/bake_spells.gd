## Retarget (por dirección de huesos) de las animaciones Mixamo del Magic Spell Pack
## al esqueleto UAL. Uso: godot --headless --path . --script res://tools/bake_spells.gd
## Opcional: -- <carpeta con FBX de Mixamo> <salida .res> (p. ej. para las animaciones del Warrior:
##   -- res://assets/models/anims/warrior/ res://assets/models/anims/warrior_anims.res)
## Por defecto guarda res://assets/models/anims/spells.res (AnimationLibrary) con, por clip,
## la versión completa ("nombre") y la de solo tren superior ("nombre_upper"), que se
## reproduce encima de la locomoción para castear y moverse a la vez.
extends SceneTree

var DIR := "res://assets/models/anims/spells/"
const DST := "res://assets/models/characters/warrior.glb"
var OUT := "res://assets/models/anims/spells.res"
const FPS := 30.0
const LOWER := ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]
const CHAINS := {
	"pelvis": ["Hips", "spine_01", "Spine"],
	"spine_01": ["Spine", "spine_02", "Spine1"],
	"spine_02": ["Spine1", "spine_03", "Spine2"],
	"spine_03": ["Spine2", "neck_01", "Neck"],
	"neck_01": ["Neck", "Head", "Head"],
	"Head": ["Head", "", ""],
	"clavicle_l": ["LeftShoulder", "upperarm_l", "LeftArm"],
	"upperarm_l": ["LeftArm", "lowerarm_l", "LeftForeArm"],
	"lowerarm_l": ["LeftForeArm", "hand_l", "LeftHand"],
	"hand_l": ["LeftHand", "middle_01_l", "LeftHandMiddle1"],
	"clavicle_r": ["RightShoulder", "upperarm_r", "RightArm"],
	"upperarm_r": ["RightArm", "lowerarm_r", "RightForeArm"],
	"lowerarm_r": ["RightForeArm", "hand_r", "RightHand"],
	"hand_r": ["RightHand", "middle_01_r", "RightHandMiddle1"],
	"thigh_l": ["LeftUpLeg", "calf_l", "LeftLeg"],
	"calf_l": ["LeftLeg", "foot_l", "LeftFoot"],
	"foot_l": ["LeftFoot", "ball_l", "LeftToeBase"],
	"thigh_r": ["RightUpLeg", "calf_r", "RightLeg"],
	"calf_r": ["RightLeg", "foot_r", "RightFoot"],
	"foot_r": ["RightFoot", "ball_r", "RightToeBase"],
}


func _skel_xform(root: Node, sk: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = sk
	while n != null and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _globals(sk: Skeleton3D, rest: bool) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in sk.get_bone_count():
		var l := sk.get_bone_rest(i) if rest else sk.get_bone_pose(i)
		var par := sk.get_bone_parent(i)
		out.append(l if par < 0 else out[par] * l)
	return out


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		DIR = args[0]
		OUT = args[1]
	var dst_root: Node = (load(DST) as PackedScene).instantiate()
	var dsk := dst_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var lib := AnimationLibrary.new()
	var dir := DirAccess.open(DIR)
	for file in dir.get_files():
		if not file.ends_with(".fbx"):
			continue
		var clip_name := file.get_basename()
		var full := _bake(DIR + file, dst_root, dsk, false)
		if full == null:
			continue
		lib.add_animation(clip_name, full)
		lib.add_animation(clip_name + "_upper", _bake(DIR + file, dst_root, dsk, true))
		print("BAKED ", clip_name, " len=", full.length)
	print("SAVE ", ResourceSaver.save(lib, OUT))
	quit()


func _bake(src_path: String, dst_root: Node, dsk: Skeleton3D, upper_only: bool) -> Animation:
	var src_root: Node = (load(src_path) as PackedScene).instantiate()
	var ssk := src_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := src_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ssk == null or ap == null:
		return null
	var sanim: Animation = null
	for a in ap.get_animation_list():
		if a != "RESET":
			sanim = ap.get_animation(a)
	if sanim == null:
		return null
	var sx := _skel_xform(src_root, ssk)
	var dx := _skel_xform(dst_root, dsk)
	var prefix := String(dst_root.get_path_to(dsk))
	var mm := {}
	for i in ssk.get_bone_count():
		mm[ssk.get_bone_name(i).replace("mixamorig_", "")] = i
	var rest_g: Array[Transform3D] = []
	for t in _globals(dsk, true):
		rest_g.append(dx * t)
	var srest_g := {}
	var sr := _globals(ssk, true)
	for k in mm:
		srest_g[k] = sx * sr[mm[k]]
	var rm: Vector3 = srest_g["LeftArm"].origin - srest_g["RightArm"].origin
	var ru: Vector3 = rest_g[dsk.find_bone("upperarm_l")].origin - rest_g[dsk.find_bone("upperarm_r")].origin
	var yfix := Basis(Vector3.UP, -(atan2(rm.x, rm.z) - atan2(ru.x, ru.z)))

	var out := Animation.new()
	out.length = sanim.length
	out.step = 1.0 / FPS
	var tracks := {}
	for i in dsk.get_bone_count():
		var bone_name := dsk.get_bone_name(i)
		if upper_only and (LOWER.has(bone_name) or not CHAINS.has(bone_name)):
			continue
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("%s:%s" % [prefix, bone_name]))
		tracks[i] = tr
	for f in int(ceil(sanim.length * FPS)) + 1:
		var t := minf(f / FPS, sanim.length)
		ssk.reset_bone_poses()
		for tr in sanim.get_track_count():
			var bone := String(sanim.track_get_path(tr)).get_slice(":", 1)
			var bi := ssk.find_bone(bone)
			if bi < 0:
				continue
			match sanim.track_get_type(tr):
				Animation.TYPE_ROTATION_3D: ssk.set_bone_pose_rotation(bi, sanim.rotation_track_interpolate(tr, t))
				Animation.TYPE_POSITION_3D: ssk.set_bone_pose_position(bi, sanim.position_track_interpolate(tr, t))
		var sgl := _globals(ssk, false)
		var sg := {}
		for k in mm:
			sg[k] = sx * sgl[mm[k]]
		var g: Array[Basis] = []
		g.resize(dsk.get_bone_count())
		for i in dsk.get_bone_count():
			var name := dsk.get_bone_name(i)
			var par := dsk.get_bone_parent(i)
			var rest_b := rest_g[i].basis.orthonormalized()
			if CHAINS.has(name):
				var c: Array = CHAINS[name]
				if String(c[1]) == "":
					var d: Basis = sg[c[0]].basis.orthonormalized() * srest_g[c[0]].basis.orthonormalized().inverse()
					g[i] = yfix * d * yfix.inverse() * rest_b
				else:
					var ci := dsk.find_bone(c[1])
					var du: Vector3 = (rest_g[ci].origin - rest_g[i].origin).normalized()
					var dm: Vector3 = yfix * (sg[c[2]].origin - sg[c[0]].origin).normalized()
					g[i] = Basis(Quaternion(du, dm)) * rest_b
			else:
				var rl := dsk.get_bone_rest(i).basis.orthonormalized()
				g[i] = (g[par] * rl) if par >= 0 else rest_b
			if tracks.has(i):
				var local: Basis = (g[par].inverse() * g[i]) if par >= 0 else g[i]
				out.rotation_track_insert_key(tracks[i], t, local.get_rotation_quaternion())
	out.loop_mode = Animation.LOOP_NONE
	return out
