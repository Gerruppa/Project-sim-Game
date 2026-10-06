shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Cloud shell: covers a share `cover` (0-1) of the sky and drifts slowly.

uniform vec3 seed_offset = vec3(0.0);
uniform float cover = 0.1;

varying vec3 sphere_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.21, 0.613, 0.919));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	sphere_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(sphere_pos);
	// Bands along latitudes, like real weather.
	vec3 p = vec3(n.x * 4.0, n.y * 9.0, n.z * 4.0) + seed_offset + vec3(TIME * 0.01, 0.0, 0.0);
	float c = fbm(p);
	float threshold = 1.0 - cover;
	ALBEDO = vec3(1.0);
	ALPHA = smoothstep(threshold * 0.7 + 0.05, threshold * 0.7 + 0.2, c) * 0.6;
	ROUGHNESS = 1.0;
}
