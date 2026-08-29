// mana_portal.gdshader — 靜態像素 Sprite 的內圈漩渦動畫。
// 外圈冷鐵框固定；越靠中心 UV 旋轉越快，形成持續吸入而非整張貼圖轉盤。
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

uniform sampler2D portal_texture : source_color, filter_nearest_mipmap;
uniform vec4 tint : source_color = vec4(0.82, 0.90, 1.0, 1.0);
uniform float spin_speed : hint_range(0.0, 1.0) = 0.16;

const float TAU_F = 6.2831853;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float radius = length(p);
	// 0.31 內完全轉動，0.47 前淡回靜態；金屬外框完全不動。
	float moving_mask = 1.0 - smoothstep(0.31, 0.47, radius);
	float radial_speed = mix(1.15, 0.38, smoothstep(0.04, 0.47, radius));
	float angle = TIME * spin_speed * TAU_F * radial_speed;
	float cs = cos(angle);
	float sn = sin(angle);
	vec2 spun_uv = mat2(vec2(cs, -sn), vec2(sn, cs)) * p + vec2(0.5);

	vec4 still_tex = texture(portal_texture, UV);
	vec4 moving_tex = texture(portal_texture, spun_uv);
	vec4 tex = mix(still_tex, moving_tex, moving_mask);
	float breath = 1.0 + 0.055 * sin(TIME * 2.1);

	ALBEDO = tex.rgb * tint.rgb;
	EMISSION = tex.rgb * tint.rgb * (0.13 + moving_mask * 0.14) * breath;
	ALPHA = tex.a * tint.a;
}
