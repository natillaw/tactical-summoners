## FxShape — plano con fx_shape.gdshader: telegraphs, barridos, ondas y auras.
##
## Se usa de dos formas:
##  - Persistente (telegraph del muñeco, aura de Last Stand): se crea una vez y
##    se actualizan sus parámetros con set_param().
##  - Efímera: animate() lo hace crecer / barrer / desvanecerse y lo libera.
class_name FxShape
extends MeshInstance3D

enum Mode { DISC, RING, SECTOR, RECT }

const SHADER := preload("res://game/vfx3d/fx_shape.gdshader")

var _mat: ShaderMaterial


## size_m: radio (disco/anillo/sector) o Vector2(ancho, largo) para RECT.
func setup(mode: int, size_m: Variant, color: Color) -> FxShape:
	var plane := PlaneMesh.new()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = 1
	if mode == Mode.RECT:
		var s: Vector2 = size_m
		plane.size = Vector2(s.x, s.y)
		# El origen queda en la base del rectángulo; se alarga hacia +Z.
		plane.center_offset = Vector3(0.0, 0.0, s.y * 0.5)
	else:
		var r := float(size_m)
		plane.size = Vector2(r * 2.0, r * 2.0)
	mesh = plane
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_param("mode", mode)
	set_param("color", color)
	return self


func set_param(param: String, value: Variant) -> void:
	_mat.set_shader_parameter(param, value)


func get_param(param: String) -> Variant:
	return _mat.get_shader_parameter(param)


## Barrido de espada: revela el sector de 0 a 1 en `sweep_time` y se apaga en `fade_time`.
func animate_sweep(sweep_time: float, fade_time: float) -> void:
	set_param("sweep", 0.0)
	set_param("fade", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: set_param("sweep", v), 0.0, 1.0, maxf(sweep_time, 0.01)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: set_param("fade", v), 1.0, 0.0, maxf(fade_time, 0.01))
	tw.tween_callback(queue_free)


## Onda expansiva: escala de `from` a 1 mientras se desvanece.
func animate_burst(duration: float, from: float = 0.2) -> void:
	scale = Vector3.ONE * from
	set_param("fade", 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: set_param("fade", v), 1.0, 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


## Destello que se desvanece sin moverse.
func animate_fade(duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: set_param("fade", v), 1.0, 0.0, duration)
	tw.tween_callback(queue_free)
