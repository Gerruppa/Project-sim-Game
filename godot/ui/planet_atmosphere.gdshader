shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;
// The air seen at the planet's edge: orange haze while the air has little
// oxygen, turning blue and brighter as oxygen grows.

uniform vec3 glow_color = vec3(0.4, 0.7, 1.0);
uniform float strength = 0.3;
// 1 - sqrt(1 - (1 / 1.06)^2): where the planet (radius 1) ends on this shell (1.06).
const float EDGE = 0.67;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// The planet's edge is seen at rim EDGE of this shell: the glow peaks
	// there, thins over the planet's face and fades out into space.
	float glow = pow(clamp(rim / EDGE, 0.0, 1.0), 4.0) * (1.0 - smoothstep(EDGE, 1.0, rim));
	ALBEDO = glow_color * glow * strength;
}
