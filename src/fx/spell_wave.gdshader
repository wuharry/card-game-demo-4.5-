shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.08, 1.0);
uniform float phase : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float radius = mix(0.08, 0.92, phase);
	float ring = exp(-pow((r - radius) * 35.0, 2.0));
	float inner = exp(-pow((r - radius * 0.7) * 55.0, 2.0)) * 0.4;
	float core = exp(-r * r * 32.0) * (1.0 - phase);
	float fade = pow(1.0 - phase, 1.4);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 3.0;
	ALPHA = (ring + inner + core * 0.4) * fade * (1.0 - smoothstep(0.95, 1.0, r));
}
