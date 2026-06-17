shader_type spatial;
render_mode cull_disabled;
// 風格化溪流：流動波紋法線 + 低粗糙度反射 + 菲涅耳 + 深淺水色。
// 反射場景（樹林）需在 WorldEnvironment 開啟 SSR（ss_reflections_enabled）。

uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.28);
uniform vec3 shallow_color : source_color = vec3(0.20, 0.48, 0.55);
uniform vec2 flow_dir = vec2(1.0, 0.0);   // 沿 X 流動
uniform float flow_speed = 0.05;
uniform float uv_scale = 0.12;
uniform float wave_height = 0.05;
uniform float ripple_strength = 0.35;
uniform float water_roughness = 0.05;
uniform float fresnel_power = 4.0;
uniform float water_alpha = 0.9;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, wpos.xz * 0.04 + flow_dir * flow_speed * TIME).r;
	VERTEX.y += sin(wpos.x * 0.7 + TIME * 1.5 + n * 6.2831) * wave_height;
}

void fragment() {
	vec2 base = wpos.xz * uv_scale;
	vec2 fl = flow_dir * flow_speed * TIME;
	float e = 0.02;

	// 兩層捲動 noise 疊加，從高度差推出波紋法線
	float h  = texture(noise_tex, base + fl).r + texture(noise_tex, base * 1.9 - fl * 0.7).r;
	float hx = texture(noise_tex, base + vec2(e, 0.0) + fl).r + texture(noise_tex, (base + vec2(e, 0.0)) * 1.9 - fl * 0.7).r;
	float hz = texture(noise_tex, base + vec2(0.0, e) + fl).r + texture(noise_tex, (base + vec2(0.0, e)) * 1.9 - fl * 0.7).r;
	vec3 ripple_n = normalize(vec3((h - hx) * ripple_strength * 12.0, 1.0, (h - hz) * ripple_strength * 12.0));

	// 轉到 view space 給 NORMAL 與菲涅耳用
	vec3 vn = normalize((VIEW_MATRIX * vec4(ripple_n, 0.0)).xyz);
	NORMAL = vn;
	float fres = pow(1.0 - clamp(dot(VIEW, vn), 0.0, 1.0), fresnel_power);

	vec3 tex = texture(water_tex, base + fl).rgb;
	vec3 col = mix(deep_color, shallow_color, clamp(h * 0.5, 0.0, 1.0));
	col = mix(col, col * tex * 1.6, 0.35);
	col += shallow_color * fres * 0.6;   // 邊緣/掠角更亮，模擬反射

	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = water_roughness;
	SPECULAR = 0.7;
	// 不透明：讓 SSR（螢幕空間反射）能把場景樹林反射到水面
}
