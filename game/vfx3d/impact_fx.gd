## ImpactFx — golpe en 3D: destello, chispas y anillo en el suelo.
class_name ImpactFx
extends Node3D

const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float fade = 1.0;
void vertex() {
	// Billboard.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	float glow = pow(1.0 - clamp(r, 0.0, 1.0), 2.0);
	// Estrella de cuatro puntas.
	float star = pow(max(1.0 - abs(p.x * p.y) * 18.0, 0.0), 3.0) * (1.0 - smoothstep(0.2, 1.0, r));
	ALBEDO = mix(color.rgb, vec3(1.0), core);
	ALPHA = clamp((core + glow * 0.6 + star) * fade * color.a, 0.0, 1.0);
}
"""

static var _flash_shader: Shader


func setup(color: Color, heavy: bool, size: float = 1.0) -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER

	var quad := QuadMesh.new()
	var flash_size := (1.3 if heavy else 0.9) * size
	quad.size = Vector2(flash_size, flash_size)
	var flash := MeshInstance3D.new()
	flash.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	mat.set_shader_parameter("color", color)
	mat.render_priority = 2
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)

	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 18 if heavy else 11
	sparks.lifetime = 0.32
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.5 * size
	sparks.initial_velocity_max = (8.5 if heavy else 6.5) * size
	sparks.gravity = Vector3(0, -14, 0)
	sparks.damping_min = 2.0
	sparks.damping_max = 4.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.035, 0.035, 0.16)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = color.lerp(Color.WHITE, 0.4)
	spark_mat.emission_enabled = true
	spark_mat.emission = color
	spark_mat.emission_energy_multiplier = 3.0
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	sparks.particle_flag_align_y = true
	add_child(sparks)

	var tw := create_tween().set_parallel(true)
	flash.scale = Vector3.ONE * 0.4
	tw.tween_property(flash, "scale", Vector3.ONE * 1.15, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.16).set_delay(0.03)
	tw.chain().tween_interval(0.3)
	tw.chain().tween_callback(queue_free)
