shader_type spatial;
// Fachada procedural: pared con ruido y suciedad, cornisas por piso, ventanas con marco,
// planta baja comercial (persianas o vidriera) y ventanas encendidas de noche.
global uniform float night;
uniform vec4 wall_color : source_color = vec4(0.9, 0.85, 0.75, 1.0);
uniform vec4 window_color : source_color = vec4(0.25, 0.35, 0.45, 1.0);
uniform vec4 frame_color : source_color = vec4(0.92, 0.92, 0.9, 1.0);
uniform float size_y = 10.0;
uniform float floor_h = 3.2;
uniform float spacing_h = 3.4;
uniform float seed = 0.0;
varying vec3 lp;
varying vec3 ln;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	float side = step(abs(ln.y), 0.5);
	float h = abs(ln.x) > 0.5 ? lp.z : lp.x;
	float yb = lp.y + size_y * 0.5;
	vec2 g = vec2(h / spacing_h, yb / floor_h);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float n = vnoise(vec2(h * 0.9, yb * 0.9) + seed * 7.0);
	float n2 = vnoise(vec2(h * 6.0, yb * 6.0) + seed);
	vec3 col = wall_color.rgb * (0.84 + 0.22 * n + 0.07 * n2);
	col *= mix(0.65, 1.0, smoothstep(0.0, 7.0, yb));
	float upper = side * step(floor_h, yb) * (1.0 - step(size_y - 0.9, yb));
	// cornisa entre pisos y parapeto
	float band = smoothstep(0.07, 0.0, f.y) * step(floor_h, yb) * side;
	col = mix(col, col * 0.72, band);
	col = mix(col, col * 1.12, side * step(size_y - 0.5, yb));
	// ventanas con marco
	float in_frame = step(0.15, f.x) * step(f.x, 0.85) * step(0.2, f.y) * step(f.y, 0.84) * upper;
	float in_glass = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.8) * upper;
	float lit = step(0.62, hash(cell + vec2(seed * 13.0, floor(h * 0.0) + 3.0)));
	vec3 glass = window_color.rgb * (0.55 + 0.8 * f.y);
	col = mix(col, frame_color.rgb * 0.9, in_frame);
	col = mix(col, glass, in_glass);
	// planta baja: persiana o vidriera
	float ground = side * (1.0 - step(floor_h, yb));
	float shutter = step(0.5, hash(vec2(cell.x, seed)));
	float stripes = step(0.5, fract(yb * 7.0));
	vec3 shut = mix(vec3(0.36, 0.38, 0.41), vec3(0.28, 0.3, 0.33), stripes);
	float shop_win = step(0.08, f.x) * step(f.x, 0.92) * step(0.12, f.y) * step(f.y, 0.85) * (1.0 - shutter);
	vec3 gfront = mix(wall_color.rgb * 0.7, mix(shut, glass * 1.2, shop_win), 1.0);
	col = mix(col, shutter > 0.5 ? shut : mix(wall_color.rgb * 0.55, glass * 1.3, shop_win), ground);
	// techo
	col = mix(vec3(0.28, 0.28, 0.3) * (0.8 + 0.4 * n), col, side);
	ALBEDO = col;
	ROUGHNESS = mix(0.88, 0.1, in_glass + ground * (1.0 - shutter) * shop_win);
	METALLIC = (in_glass + ground * (1.0 - shutter) * shop_win) * 0.4;
	vec3 warm = vec3(1.0, 0.8, 0.48);
	EMISSION = warm * (in_glass * lit * 1.6 + ground * (1.0 - shutter) * shop_win * 1.2) * night;
}
