## Retarget (por dirección de huesos) de la animación Mixamo "Upward Thrust" al
## esqueleto UAL del Warrior. Uso: godot --headless --script res://tools/bake_thrust.gd
## Guarda res://assets/models/anims/thrust_retargeted.res
extends SceneTree

const SRC := "res://assets/models/anims/xbot_upward_thrust.fbx"
const DST := "res://assets/models/characters/warrior.glb"
const OUT := "res://assets/models/anims/thrust_retargeted.res"
const FPS := 30.0
## Piernas y pelvis salen de UAL Sword_Dash (una estocada a pie): el original de
## Mixamo es un salto. Ventana usada en el juego (fracciones): 0.30–0.62 -> Dash 0–0.46.
const DASH_LIB := "res://assets/models/anims/UAL2_Standard.glb"
const DASH_ANIM := "Sword_Dash"
const WINDOW := Vector2(0.30, 0.62)
const DASH_END := 0.46
const FROM_DASH := ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]
# hueso UAL: [hueso mixamo, hueso UAL hijo, hueso mixamo hijo]
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
	var src_root: Node = (load(SRC) as PackedScene).instantiate()
	var dst_root: Node = (load(DST) as PackedScene).instantiate()
	var ssk := src_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var dsk := dst_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var sx := _skel_xform(src_root, ssk)
	var dx := _skel_xform(dst_root, dsk)
	var sanim := (src_root.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation("mixamo_com")
	var prefix := String(dst_root.get_path_to(dsk))
	var dash_root: Node = (load(DASH_LIB) as PackedScene).instantiate()
	var dash := (dash_root.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation(DASH_ANIM)
	var dash_rot := {}
	var dash_pos := -1
	for tr in dash.get_track_count():
		var bone := String(dash.track_get_path(tr)).get_slice(":", 1)
		if dash.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			dash_rot[bone] = tr
		elif dash.track_get_type(tr) == Animation.TYPE_POSITION_3D and bone == "pelvis":
			dash_pos = tr

	var mm := {}  # nombre mixamo corto -> índice
	for i in ssk.get_bone_count():
		mm[ssk.get_bone_name(i).replace("mixamorig_", "")] = i
	# poses globales de reposo UAL
	var rest_g: Array[Transform3D] = []
	for t in _globals(dsk, true):
		rest_g.append(dx * t)
	var srest_g := {}
	var sr := _globals(ssk, true)
	for k in mm: srest_g[k] = sx * sr[mm[k]]

	# corrección de guiñada: ambos personajes con el mismo frente
	var rm: Vector3 = srest_g["LeftArm"].origin - srest_g["RightArm"].origin
	var ru: Vector3 = rest_g[dsk.find_bone("upperarm_l")].origin - rest_g[dsk.find_bone("upperarm_r")].origin
	var yaw := atan2(rm.x, rm.z) - atan2(ru.x, ru.z)
	var yfix := Basis(Vector3.UP, -yaw)
	var hips_h_m: float = srest_g["Hips"].origin.y
	var hips_h_u: float = rest_g[dsk.find_bone("pelvis")].origin.y
	var scale := hips_h_u / maxf(hips_h_m, 0.001)
	print("yaw fix deg=", rad_to_deg(yaw), " scale=", scale)

	var out := Animation.new()
	out.length = sanim.length
	out.step = 1.0 / FPS
	var n_frames := int(ceil(sanim.length * FPS)) + 1
	var tracks := {}
	for i in dsk.get_bone_count():
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("%s:%s" % [prefix, dsk.get_bone_name(i)]))
		tracks[i] = tr
	var ptr := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(ptr, NodePath("%s:pelvis" % prefix))
	var pelvis_i := dsk.find_bone("pelvis")
	var pelvis_local_rest := dsk.get_bone_rest(pelvis_i)

	for f in n_frames:
		var t := minf(f / FPS, sanim.length)
		ssk.reset_bone_poses()
		for tr in sanim.get_track_count():
			var p := String(sanim.track_get_path(tr))
			var bone := p.get_slice(":", 1)
			var bi := ssk.find_bone(bone)
			if bi < 0: continue
			match sanim.track_get_type(tr):
				Animation.TYPE_ROTATION_3D: ssk.set_bone_pose_rotation(bi, sanim.rotation_track_interpolate(tr, t))
				Animation.TYPE_POSITION_3D: ssk.set_bone_pose_position(bi, sanim.position_track_interpolate(tr, t))
		var frac := t / sanim.length
		var dt := clampf((frac - WINDOW.x) / (WINDOW.y - WINDOW.x), 0.0, 1.0) * DASH_END * dash.length
		var sgl := _globals(ssk, false)
		var sg := {}
		for k in mm: sg[k] = sx * sgl[mm[k]]
		var g: Array[Basis] = []
		g.resize(dsk.get_bone_count())
		for i in dsk.get_bone_count():
			var name := dsk.get_bone_name(i)
			var par := dsk.get_bone_parent(i)
			var rest_b := rest_g[i].basis.orthonormalized()
			if FROM_DASH.has(name) and dash_rot.has(name):
				var dl := Basis(dash.rotation_track_interpolate(dash_rot[name], dt))
				g[i] = (g[par] * dl) if par >= 0 else dl
			elif CHAINS.has(name):
				var c: Array = CHAINS[name]
				if String(c[1]) == "":
					# cabeza: rotación global relativa al reposo mixamo
					var d: Basis = sg[c[0]].basis.orthonormalized() * srest_g[c[0]].basis.orthonormalized().inverse()
					g[i] = yfix * d * yfix.inverse() * rest_b
				else:
					var ci := dsk.find_bone(c[1])
					var du: Vector3 = (rest_g[ci].origin - rest_g[i].origin).normalized()
					var dm: Vector3 = yfix * (sg[c[2]].origin - sg[c[0]].origin).normalized()
					g[i] = Basis(Quaternion(du, dm)) * rest_b
			else:
				# sin mapeo: conserva la pose local de reposo
				var rl := dsk.get_bone_rest(i).basis.orthonormalized()
				g[i] = (g[par] * rl) if par >= 0 else rest_b
			var local: Basis = (g[par].inverse() * g[i]) if par >= 0 else g[i]
			out.rotation_track_insert_key(tracks[i], t, local.get_rotation_quaternion())
		var hp: Vector3 = yfix * (sg["Hips"].origin - srest_g["Hips"].origin) * scale
		hp.y *= 0.35  # el original es un salto; aquí queda casi a ras de suelo
		var ppos: Vector3 = dash.position_track_interpolate(dash_pos, dt) if dash_pos >= 0 else pelvis_local_rest.origin + hp
		out.position_track_insert_key(ptr, t, ppos)
	out.loop_mode = Animation.LOOP_NONE
	print("SAVE ", ResourceSaver.save(out, OUT), " frames=", n_frames, " prefix=", prefix)
	quit()
