shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.7, 1.0, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	float bands = pow(max(0.0, sin(UV.y * 75.398)), 18.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (1.2 + rim * 1.4);
	ALPHA = tint.a * (rim * 0.48 + bands * 0.045);
}
