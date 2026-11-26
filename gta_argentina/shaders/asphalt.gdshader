shader_type spatial;
// Asfalto procedural con variación y manchas.
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wp.xz * 0.3) * 0.45 + vnoise(wp.xz * 1.7) * 0.3 + vnoise(wp.xz * 9.0) * 0.25;
	float patch = smoothstep(0.62, 0.7, vnoise(wp.xz * 0.12 + 4.0));
	vec3 a = vec3(0.12, 0.12, 0.135) * (0.7 + 0.7 * n);
	a = mix(a, vec3(0.08, 0.08, 0.09), patch * 0.7);
	ALBEDO = a;
	ROUGHNESS = 0.82 - 0.15 * patch;
}
