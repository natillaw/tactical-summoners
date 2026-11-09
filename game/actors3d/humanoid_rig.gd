## HumanoidRig — modelo 3D con el esqueleto UE de Quaternius y las librerías UAL.
##
## Carga un modelo (warrior.glb, maniquí...) y le añade un AnimationPlayer con
## las librerías "ual1" y "ual2". Todos los modelos humanos del juego comparten
## los mismos 65 huesos, así que cualquier animación sirve para cualquiera.
##
## Ofrece lo que necesita la presentación de combate:
##  - play()/play_clip(): animaciones con blend, y clips recortados por fracción
##    con una velocidad calculada para que el impacto caiga en un tiempo dado.
##  - hit-stop (congelar la pose unas centésimas) y flash de daño.
##  - attach_to_hand(): ancla un arma al puño derecho usando la geometría de
##    los nudillos, sin offsets mágicos por modelo.
class_name HumanoidRig
extends Node3D

const UAL1 := "res://assets/models/anims/UAL1_Standard.glb"
const UAL2 := "res://assets/models/anims/UAL2_Standard.glb"

const SPELLS := "res://assets/models/anims/spells.res"
const CLASS_ANIMS := "res://assets/models/anims/class_anims.res"

static var _libraries: Dictionary = {}
static var _warned: Dictionary = {}

var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
## Segundo reproductor para animaciones de tren superior (castear mientras corres).
var overlay: AnimationPlayer
var _overlay_end: float = -1.0
var meshes: Array[MeshInstance3D] = []

var _clip_end: float = -1.0
var _clip_after: String = ""
var _clip_after_blend: float = 0.15
var _clip_post_speed: float = -1.0
var _clip_contact: float = -1.0
var _speed: float = 1.0
var _hitstop: float = 0.0
var _flash_material: StandardMaterial3D
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE


func setup(model_path: String) -> void:
	setup_model((load(model_path) as PackedScene).instantiate() as Node3D)


## Igual que setup(), con un modelo ya construido (CharacterBuilder).
func setup_model(p_model: Node3D) -> void:
	model = p_model
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Algunos glTF (el maniquí de UAL) traen su propio AnimationPlayer con las
	# mismas animaciones en la librería "". Si se reutiliza, Godot no registra
	# esas animaciones otra vez bajo "ual1/...", así que se descarta y se crea
	# uno limpio para todos los modelos.
	var own := model.find_child("AnimationPlayer", true, false)
	if own != null:
		own.get_parent().remove_child(own)
		own.free()
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	for lib_name: String in ["ual1", "ual2"]:
		if not player.has_animation_library(lib_name):
			player.add_animation_library(lib_name, _library(lib_name))

	# Animaciones propias (retargeteadas desde Mixamo con tools/bake_thrust.gd).
	if not player.has_animation_library("custom"):
		var custom := AnimationLibrary.new()
		custom.add_animation("thrust", load("res://assets/models/anims/thrust_retargeted.res"))
		player.add_animation_library("custom", custom)

	# Hechizos (Magic Spell Pack retargeteado con tools/bake_spells.gd): cada clip tiene
	# versión completa y "_upper" (solo tren superior) para el overlay.
	if ResourceLoader.exists(SPELLS):
		var spells := load(SPELLS) as AnimationLibrary
		player.add_animation_library("spell", spells)
		overlay = AnimationPlayer.new()
		overlay.name = "Overlay"
		model.add_child(overlay)  # después de `player`: procesa más tarde y gana en el tren superior
		overlay.root_node = player.root_node
		overlay.add_animation_library("spell", spells)

	# Animaciones por clase (Mixamo retargeteado): arquero, rogue, patada, saltos, bloqueo...
	if ResourceLoader.exists(CLASS_ANIMS):
		var class_lib := load(CLASS_ANIMS) as AnimationLibrary
		for clip_name: StringName in class_lib.get_animation_list():
			var key := String(clip_name)
			if "walk" in key or "idle" in key or "fall" in key:
				class_lib.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		player.add_animation_library("class", class_lib)
		if overlay != null:
			overlay.add_animation_library("class", class_lib)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_material.albedo_color = Color(1, 1, 1, 0)


static func _library(lib_name: String) -> AnimationLibrary:
	if _libraries.has(lib_name):
		return _libraries[lib_name]
	var path := UAL1 if lib_name == "ual1" else UAL2
	var root: Node = (load(path) as PackedScene).instantiate()
	var src := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib := AnimationLibrary.new()
	for anim_name: StringName in src.get_animation_list():
		var anim: Animation = src.get_animation(anim_name)
		# El importador de Godot quita el sufijo "_Loop" del nombre y marca esas
		# animaciones como bucle (Idle_Loop -> "Idle"). Sword_Idle no lo lleva
		# pero también es un bucle.
		if String(anim_name) == "Sword_Idle":
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(anim_name, anim)
	root.free()
	_libraries[lib_name] = lib
	return lib


func has(anim: String) -> bool:
	if player != null and player.has_animation(anim):
		return true
	if not _warned.has(anim):
		_warned[anim] = true
		push_warning("HumanoidRig: no existe la animación '%s'" % anim)
	return false


func length_of(anim: String) -> float:
	return player.get_animation(anim).length if has(anim) else 0.0


func current() -> String:
	return String(player.current_animation) if player != null else ""


## Animación normal con blend. No reinicia si ya está sonando (salvo force).
func play(anim: String, blend: float = 0.15, speed: float = 1.0, force: bool = false) -> void:
	if not has(anim):
		return
	_clip_end = -1.0
	_speed = speed
	if not force and current() == anim and player.is_playing():
		_apply_speed()
		return
	player.play(anim, blend, 1.0)
	_apply_speed()


## Reproduce un tramo [from, to] (fracciones de la duración) de un clip.
## `contact` es la fracción donde cae el golpe y `time_to_contact` los segundos
## que deben pasar hasta él; después del contacto el resto del tramo dura
## `after_contact` segundos. Al terminar enlaza con `then`.
func play_clip(
		anim: String,
		from: float,
		to: float,
		contact: float,
		time_to_contact: float,
		after_contact: float,
		then: String = "",
		blend: float = 0.06
) -> void:
	if not has(anim):
		return
	var length := length_of(anim)
	var start := clampf(from, 0.0, 1.0) * length
	var hit := clampf(contact, from, to) * length
	var end := clampf(to, contact, 1.0) * length
	_speed = maxf((hit - start) / maxf(time_to_contact, 0.016), 0.05)
	_clip_contact = hit
	_clip_post_speed = maxf((end - hit) / maxf(after_contact, 0.016), 0.05)
	player.play(anim, blend, 1.0)
	player.seek(start, true)
	_apply_speed()
	_clip_end = end
	_clip_after = then
	_clip_after_blend = 0.18


## Reproduce un tramo de un clip de tren superior encima de la locomoción. Tiempos en
## segundos del clip: empieza en `start`, el golpe cae en `contact` (que ocurrirá a los
## `to_contact` segundos) y termina en `end`.
func play_overlay(anim: String, start: float, contact: float, end: float, to_contact: float, blend: float = 0.08) -> void:
	if overlay == null or not overlay.has_animation(anim):
		return
	overlay.play(anim, blend, maxf((contact - start) / maxf(to_contact, 0.03), 0.1))
	overlay.seek(start, true)
	_overlay_end = end


const LOWER_BONES := ["pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r", "root"]


## Nombre (en el overlay) de la versión de solo tren superior de un clip de las librerías
## UAL; se crea al vuelo quitando las pistas de piernas y pelvis.
func upper_variant(path: String) -> String:
	if overlay == null or not player.has_animation(path):
		return path
	var key := path.replace("/", "_")
	if not overlay.has_animation("up/" + key):
		var copy := player.get_animation(path).duplicate() as Animation
		for i in range(copy.get_track_count() - 1, -1, -1):
			if String(copy.track_get_path(i)).get_slice(":", 1) in LOWER_BONES:
				copy.remove_track(i)
		var lib: AnimationLibrary
		if overlay.has_animation_library("up"):
			lib = overlay.get_animation_library("up")
		else:
			lib = AnimationLibrary.new()
			overlay.add_animation_library("up", lib)
		lib.add_animation(key, copy)
	return "up/" + key


func stop_overlay() -> void:
	if overlay != null:
		overlay.stop()
	_overlay_end = -1.0


func set_speed(speed: float) -> void:
	_speed = speed
	_apply_speed()


func hitstop(seconds: float) -> void:
	_hitstop = maxf(_hitstop, seconds)
	_apply_speed()


func flash(color: Color = Color(1, 1, 1), seconds: float = 0.12) -> void:
	_flash = seconds
	_flash_color = color
	for mi in meshes:
		mi.material_overlay = _flash_material


func _apply_speed() -> void:
	if player != null:
		player.speed_scale = 0.0 if _hitstop > 0.0 else _speed


func _process(delta: float) -> void:
	if player == null:
		return
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
		_apply_speed()

	if _clip_end >= 0.0:
		# Durante el hit-stop (speed_scale 0) is_playing() puede dar false: no es el
		# final del clip. Darlo por terminado ahí congelaba la pose a medio golpe.
		var finished := _hitstop <= 0.0 and not player.is_playing()
		var pos := _clip_end if finished else player.current_animation_position
		if _clip_contact >= 0.0 and pos >= _clip_contact:
			_clip_contact = -1.0
			_speed = _clip_post_speed
			_apply_speed()
		if pos >= _clip_end - 0.001:
			_clip_end = -1.0
			if not _clip_after.is_empty():
				play(_clip_after, _clip_after_blend)
			else:
				player.pause()

	if _overlay_end >= 0.0 and (not overlay.is_playing() or overlay.current_animation_position >= _overlay_end):
		stop_overlay()

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		var a := clampf(_flash / 0.12, 0.0, 1.0)
		_flash_material.albedo_color = Color(_flash_color.r, _flash_color.g, _flash_color.b, 0.75 * a)
		if _flash <= 0.0:
			for mi in meshes:
				mi.material_overlay = null


## Ancla `node` al puño derecho. El eje +Y del arma sigue la línea de nudillos
## (meñique → índice), que es el eje del mango en un agarre normal, y el filo
## (+Z del arma) apunta hacia donde apuntan los dedos.
func attach_to_hand(node: Node3D, side: String = "r", grip_offset: float = 0.0) -> BoneAttachment3D:
	var attach := BoneAttachment3D.new()
	attach.name = "Hand_%s" % side
	attach.bone_name = "hand_%s" % side
	skeleton.add_child(attach)

	var hand := skeleton.find_bone("hand_%s" % side)
	var index := skeleton.find_bone("index_01_%s" % side)
	var pinky := skeleton.find_bone("pinky_01_%s" % side)
	var middle := skeleton.find_bone("middle_01_%s" % side)
	var hand_rest := skeleton.get_bone_global_rest(hand)
	var inv := hand_rest.affine_inverse()
	var p_index := inv * skeleton.get_bone_global_rest(index).origin
	var p_pinky := inv * skeleton.get_bone_global_rest(pinky).origin
	var p_middle := inv * skeleton.get_bone_global_rest(middle).origin

	var y_axis := (p_index - p_pinky).normalized()
	var fingers := p_middle.normalized()
	var z_axis := (fingers - y_axis * fingers.dot(y_axis)).normalized()
	var x_axis := y_axis.cross(z_axis).normalized()
	# Centro del puño: a medio camino hacia los nudillos, algo hacia la palma.
	var fist := p_middle * 0.62
	var basis := Basis(x_axis, y_axis, z_axis)
	node.transform = Transform3D(basis, fist + y_axis * grip_offset)
	attach.add_child(node)
	return attach


## Analiza un clip en el instante de contacto: hacia dónde apunta la punta del
## arma (ángulo en el plano del suelo, en el espacio del modelo, 0 = +Z) y en
## qué sentido barre (+1 de -X a +X, -1 al revés). `tip_in_hand` es la punta del
## arma en el espacio del hueso de la mano. Interrumpe la animación actual, así
## que se usa al cargar, no en mitad del combate.
func analyze_clip(anim: String, contact: float, tip_in_hand: Vector3, side: String = "r") -> Dictionary:
	if not has(anim):
		return {"yaw": 0.0, "sweep": 1.0}
	var hand := skeleton.find_bone("hand_%s" % side)
	var pelvis := skeleton.find_bone("pelvis")
	var length := length_of(anim)
	var dt := minf(0.03, length * 0.05)
	player.play(anim, 0.0, 1.0)
	var samples: Array[float] = []
	for t: float in [contact * length - dt, contact * length, contact * length + dt]:
		player.seek(clampf(t, 0.0, length), true)
		var tip := skeleton.get_bone_global_pose(hand) * tip_in_hand
		var hip := skeleton.get_bone_global_pose(pelvis).origin
		var d := tip - hip
		samples.append(atan2(d.x, d.z))
	var swing := wrapf(samples[2] - samples[0], -PI, PI)
	player.stop()
	return {"yaw": samples[1], "sweep": 1.0 if swing >= 0.0 else -1.0}


## Posición global de un hueso (para trails, impactos, etc.).
func bone_position(bone: String) -> Vector3:
	var idx := skeleton.find_bone(bone)
	if idx < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin
