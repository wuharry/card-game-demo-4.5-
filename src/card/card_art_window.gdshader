// card_art_window.gdshader — 卡圖窗的真正圓角遮罩。
// Frame PNG 的外圍也有透明像素；只靠「把矩形卡圖放在框後面」會從角落漏出黑方塊。
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

uniform sampler2D art_texture : source_color, filter_nearest;
// xy = 裁切區左上 UV；zw = 裁切區寬高。region Sprite 的 UV 仍是來源圖座標。
uniform vec4 source_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

float rounded_window(vec2 uv) {
	vec2 p = uv - vec2(0.5);
	float radius = 0.065;
	vec2 q = abs(p) - (vec2(0.5) - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(-0.003, 0.004, d);
}

void fragment() {
	vec2 local_uv = (UV - source_uv_rect.xy) / max(source_uv_rect.zw, vec2(0.0001));
	vec4 tex = texture(art_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a * rounded_window(local_uv);
}
