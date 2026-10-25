shader_type spatial;
// The planet's surface. The continents are fixed for a planet (noise moved by
// its number); everything else follows PlanetState through PlanetView.look:
// sea level, ice, desert, heat, and life drawn by layers (bacterial mats and
// algae in the sea, moss, shrubs and trees on land). Presentation only.

uniform vec3 seed_offset = vec3(0.0);
uniform float sea_level = 0.5;
uniform float ice_line = 0.85;
uniform float dryness = 0.0;
uniform float heat = 0.0;
uniform float bacteria = 0.0;
uniform float algae = 0.0;
uniform float moss = 0.0;
uniform float shrub = 0.0;
uniform float tree = 0.0;

varying vec3 sphere_pos;

const vec3 DEEP = vec3(0.03, 0.10, 0.22);
const vec3 SHALLOW = vec3(0.07, 0.30, 0.45);
const vec3 BACTERIA = vec3(0.45, 0.28, 0.40);
const vec3 ALGAE = vec3(0.10, 0.42, 0.30);
const vec3 ROCK = vec3(0.42, 0.36, 0.30);
const vec3 ROCK_LIGHT = vec3(0.60, 0.53, 0.44);
const vec3 DESERT = vec3(0.80, 0.64, 0.40);
const vec3 SCORCHED = vec3(0.55, 0.25, 0.15);
const vec3 MOSS = vec3(0.50, 0.58, 0.28);
const vec3 SHRUB = vec3(0.28, 0.50, 0.20);
const vec3 TREE = vec3(0.10, 0.32, 0.12);
const vec3 ICE = vec3(0.92, 0.96, 0.99);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
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
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

// Life covers a share `cover` (0-1) of the places where `spot` allows it.
float covered(float cover, float spot) {
	return smoothstep(1.0 - cover, 1.0 - cover + 0.06, spot);
}

void vertex() {
	sphere_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(sphere_pos);
	float height = fbm(n * 1.7 + seed_offset);
	float latitude = abs(n.y);
	float jitter = (fbm(n * 6.0 + seed_offset * 1.3) - 0.5) * 0.2;
	vec3 color;
	float roughness = 0.9;
	if (height < sea_level) {
		float depth = clamp((sea_level - height) * 6.0, 0.0, 1.0);
		color = mix(SHALLOW, DEEP, depth);
		color = mix(color, BACTERIA, bacteria * 0.45 * (1.0 - depth * 0.7));
		color = mix(color, ALGAE, algae * 0.75 * (1.0 - depth * 0.4));
		roughness = 0.35;
	} else {
		float rise = clamp((height - sea_level) * 5.0, 0.0, 1.0);
		color = mix(ROCK, ROCK_LIGHT, noise(n * 14.0 + seed_offset));
		color = mix(color, DESERT, dryness * (1.0 - latitude * 0.8));
		color = mix(color, SCORCHED, heat * 0.7);
		float spot = fbm(n * 5.0 + seed_offset * 1.7) * (1.0 - rise * 0.5);
		color = mix(color, BACTERIA * 0.8, covered(bacteria * 0.3, spot) * 0.5);
		color = mix(color, MOSS, covered(moss, spot));
		color = mix(color, SHRUB, covered(shrub * 0.9, spot));
		color = mix(color, TREE, covered(tree * 0.8, spot));
		color = mix(color, ICE * 0.95, smoothstep(0.85, 1.0, rise) * 0.6);
	}
	if (latitude + jitter > ice_line) {
		color = ICE;
		roughness = 0.6;
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
