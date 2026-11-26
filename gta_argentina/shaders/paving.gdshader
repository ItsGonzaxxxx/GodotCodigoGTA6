shader_type spatial;
// Vereda con baldosas (o pasto si grass = 1).
uniform vec4 base : source_color = vec4(0.62, 0.62, 0.64, 1.0);
uniform float tile = 0.6;
uniform float grass = 0.0;
varying vec3 wp;
varying vec3 ln;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; ln = NORMAL; }
void fragment() {
	float top = step(0.5, ln.y);
	vec2 uv = wp.xz / tile;
	vec2 f = fract(uv);
	vec2 id = floor(uv);
	float line = clamp(step(f.x, 0.035) + step(f.y, 0.035), 0.0, 1.0);
	vec3 col = base.rgb * (0.9 + hash(id) * 0.14) * (0.9 + 0.2 * vnoise(wp.xz * 3.0));
	col = mix(col, col * 0.55, line);
	vec3 gr = mix(vec3(0.14, 0.3, 0.1), vec3(0.27, 0.46, 0.16), vnoise(wp.xz * 1.3)) * (0.75 + 0.5 * vnoise(wp.xz * 9.0));
	col = mix(col, gr, grass);
	col = mix(base.rgb * 0.75, col, top);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 1.0, grass);
}
