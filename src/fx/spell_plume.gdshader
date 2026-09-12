shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.24, 0.025, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = vec2(UV.x * 9.0, UV.y * 3.2 + age * 3.0);
	float cloud = noise(p) * 0.57 + noise(p * 2.1) * 0.28 + noise(p * 4.2) * 0.15;
	float edge = sin(UV.y * 3.141593);
	float tongues = smoothstep(0.42, 0.78, cloud + edge * 0.08);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	vec3 heat = mix(tint.rgb, vec3(1.0, 0.65, 0.12), cloud * edge * 0.55);
	ALBEDO = heat;
	EMISSION = heat * (0.8 + tongues * 1.4);
	ALPHA = tongues * edge * opacity * (0.2 + rim * 0.45);
}
