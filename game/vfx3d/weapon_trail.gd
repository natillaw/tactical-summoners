## WeaponTrail — estela de arma: una cinta entre la base y la punta de la hoja.
##
## Cada frame en que `emitting` está activo guarda la posición global de los dos
## extremos; la cinta se dibuja con ImmediateMesh y cada muestra se apaga con
## la edad. Como sigue al hueso real, la estela siempre coincide con el golpe.
class_name WeaponTrail
extends MeshInstance3D

const LIFETIME := 0.16

var base_node: Node3D
var tip_node: Node3D
var emitting: bool = false
var color: Color = Color(1.0, 0.85, 0.55, 1.0)

var _samples: Array = []  # [{base, tip, age}]
var _imesh: ImmediateMesh
var _mat: StandardMaterial3D


func setup(p_base: Node3D, p_tip: Node3D) -> void:
	base_node = p_base
	tip_node = p_tip
	top_level = true
	global_transform = Transform3D.IDENTITY
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = false
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	for s: Dictionary in _samples:
		s["age"] = float(s["age"]) + delta
	while not _samples.is_empty() and float(_samples[0]["age"]) > LIFETIME:
		_samples.pop_front()
	if emitting and base_node != null and tip_node != null:
		_samples.append({"base": base_node.global_position, "tip": tip_node.global_position, "age": 0.0})
	_rebuild()


func _rebuild() -> void:
	_imesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s: Dictionary in _samples:
		var life := 1.0 - clampf(float(s["age"]) / LIFETIME, 0.0, 1.0)
		var tip_col := Color(color.r, color.g, color.b, color.a * life * life)
		var base_col := Color(color.r, color.g, color.b, 0.0)
		_imesh.surface_set_color(base_col)
		_imesh.surface_add_vertex(s["base"])
		_imesh.surface_set_color(tip_col)
		_imesh.surface_add_vertex(s["tip"])
	_imesh.surface_end()
