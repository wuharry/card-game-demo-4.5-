shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0),
		vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0),
		vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float glow = exp(-dot(p, p) * 5.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 2.5;
	ALPHA = glow * (1.0 - smoothstep(0.7, 1.0, length(p)));
}
