// Suelo de losas procedural (sin texturas): variación por losa, juntas y grietas suaves.
shader_type spatial;

uniform float tile = 1.0;                 // metros por losa
uniform vec3 base_color : source_color = vec3(0.30, 0.31, 0.34);
uniform vec3 dark_color : source_color = vec3(0.21, 0.22, 0.25);
uniform vec3 grout_color : source_color = vec3(0.10, 0.10, 0.12);
uniform float grout = 0.035;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	// Hileras desplazadas como un aparejo de piedra.
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float h = hash(cell);
	float n = noise(world_pos.xz * 3.0) * 0.5 + noise(world_pos.xz * 11.0) * 0.25;
	vec3 col = mix(dark_color, base_color, h * 0.7 + n * 0.4);
	float g = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float joint = 1.0 - smoothstep(grout * 0.5, grout, g);
	col = mix(col, grout_color, joint);
	// Bisel: las losas oscurecen un poco hacia sus bordes.
	col *= 0.88 + 0.12 * smoothstep(0.0, 0.18, g);
	ALBEDO = col;
	ROUGHNESS = 0.85 - h * 0.1;
	METALLIC = 0.0;
}
