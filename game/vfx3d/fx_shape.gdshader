// Forma de VFX en un plano local XZ (adelante = +Z). Aditiva y sin luz.
// mode: 0 disco, 1 anillo, 2 sector (barrido de espada / cono), 3 rectángulo (línea).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float inner = 0.0;        // radio interior (fracción) para anillos y medias lunas
uniform float arc = 1.5708;       // ángulo total del sector (rad)
uniform float sweep = 1.0;        // 0..1: cuánto del sector está revelado
uniform float sweep_dir = 1.0;    // sentido del barrido
uniform float head = 0.0;         // brillo extra en el frente del barrido
uniform float trail = 0.35;       // longitud del rastro tras el frente (fracción del arco)
uniform float edge = 0.08;        // grosor del borde
uniform float fill = 0.2;         // opacidad del interior
uniform float progress = -1.0;    // relleno de telegraph (radio o largo), <0 apagado
uniform float fade = 1.0;
uniform float pulse = 0.0;        // parpadeo suave
uniform float taper = 1.0;        // RECT: ancho relativo en la punta (1 = sin estrechar)

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float mask = 0.0;
	float edge_m = 0.0;
	float prog_m = 0.0;
	float head_m = 0.0;
	float grad = 1.0;

	if (mode == 3) {
		float along = UV.y; // 0 = origen (atrás), 1 = punta
		vec2 q = abs(p);
		q.x /= mix(1.0, max(taper, 0.01), along);
		mask = step(q.x, 1.0) * step(q.y, 1.0);
		float ex = smoothstep(1.0 - edge * 2.0, 1.0, q.x);
		float ey = smoothstep(1.0 - edge, 1.0, q.y);
		edge_m = max(ex, ey) * mask;
		grad = 0.35 + 0.65 * along;
		if (progress >= 0.0) {
			prog_m = mask * step(along, progress);
		}
		head_m = head * mask * (1.0 - smoothstep(0.0, 0.18, abs(along - sweep)));
		mask *= step(along, sweep);
		edge_m *= step(along, sweep);
	} else {
		float r = length(p);
		float outer_m = 1.0 - smoothstep(0.97, 1.0, r);
		float inner_m = smoothstep(inner - 0.03, inner, r);
		mask = outer_m * inner_m;
		edge_m = smoothstep(1.0 - edge, 1.0 - edge * 0.25, r) * outer_m;
		if (mode == 1) {
			float mid = (1.0 + inner) * 0.5;
			float half_w = max((1.0 - inner) * 0.5, 0.001);
			edge_m = (1.0 - smoothstep(0.0, half_w, abs(r - mid))) * mask;
		}
		if (inner > 0.0 && mode != 1) {
			edge_m = max(edge_m, (1.0 - smoothstep(inner, inner + edge * 0.6, r)) * mask * 0.6);
		}
		if (progress >= 0.0) {
			float band = 1.0 - smoothstep(0.0, 0.04, abs(r - progress));
			prog_m = mask * (step(r, progress) * 0.6 + band);
		}
		if (mode == 2) {
			float ang = atan(p.x, p.y) * sweep_dir;
			float half_arc = arc * 0.5;
			float t = (ang + half_arc) / max(arc, 0.0001);
			float in_arc = step(0.0, t) * step(t, 1.0);
			float revealed = step(t, sweep);
			// Rastro: más brillante cerca del frente, se apaga hacia atrás.
			float behind = sweep - t;
			grad = trail > 0.0 ? clamp(1.0 - behind / trail, 0.0, 1.0) : 1.0;
			mask *= in_arc * revealed;
			edge_m *= in_arc * revealed;
			prog_m *= in_arc;
			float side = (1.0 - smoothstep(0.0, 0.03, t)) + smoothstep(0.97, 1.0, t);
			edge_m = max(edge_m, side * in_arc * outer_m * inner_m * 0.7 * step(sweep, 1.0));
			head_m = head * mask * (1.0 - smoothstep(0.0, 0.10, abs(behind)));
		}
	}

	float flick = 1.0 + pulse * 0.25 * sin(TIME * 18.0);
	float alpha = (fill * mask * grad + edge_m * grad + prog_m * 0.5 + head_m) * fade * intensity * flick;
	ALBEDO = color.rgb * (1.0 + head_m * 1.5);
	ALPHA = clamp(alpha * color.a, 0.0, 1.0);
}
