// slot_tile.gdshader — 卡槽高亮膜(鈴蘭之劍式戰棋格)
//
// 視覺構成:圓角外框線 + 內側第二道細線(雙框,印刷品的精緻感)
//           + 貼邊亮、往中心淡出的內緣漸層(讀得出範圍又不遮地面)。
// glow 參數 0=待機(細框靜止)、1=高亮(變亮+呼吸脈動),由 card_slot.gd 用 tween 推。
// 場景的 WorldEnvironment 已開 bloom(threshold 0.95),高亮時 EMISSION > 1 會自然暈開。
shader_type spatial;
// unshaded:不吃光照,顏色全由自己決定;透明混合、不寫深度(平貼地面的發光膜)、不投影。
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tile_color : source_color = vec3(0.42, 0.64, 0.86);
uniform vec3 interior_color : source_color = vec3(0.018, 0.032, 0.075);
// 卡槽平面被非等比縮放(寬≠深),圓角會被拉成橢圓;先把 x 依「寬/深」壓回等比空間。
uniform float aspect = 0.571;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
// 伏印警戒(§7 威懾):這一側場上有伏印時整排泛紅慢脈動——對手只知道
// 「有陷阱」,不知道埋在誰底下。呼吸在 shader 裡用 TIME 做,card_slot 只推開關。
uniform float ward_alert : hint_range(0.0, 1.0) = 0.0;

// 圓角矩形 SDF:回傳點 p 到「半尺寸 b、圓角半徑 r 的矩形」邊緣的有號距離
// (負=在裡面、正=在外面、0=正好在邊上)。SDF 是程序化 UI 形狀的標準武器。
float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// 先量化 UV，讓框線是清楚的像素階梯，不在像素場景裡浮著一圈向量軟線。
	vec2 pixel_grid = vec2(96.0, 144.0);
	vec2 uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
	// 以中心為原點(±0.5),x 軸做等比校正。
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	vec2 half_size = vec2(0.5 * aspect, 0.5) - 0.035;   // 四周內縮留邊
	float d = sd_rounded_box(p, half_size, 0.06);

	// 外框線:|d|≈0 的細帶;內側第二道更細、更淡的線。
	float frame = 1.0 - smoothstep(0.004, 0.024, abs(d));
	float inner_line = (1.0 - smoothstep(0.003, 0.016, abs(d + 0.052))) * 0.58;
	// 內緣漸層:只在框內(d<0),貼邊最亮、往中心迅速歸零。
	float fill = d < 0.0 ? smoothstep(-0.28, -0.02, d) * 0.46 : 0.0;
	float inside = 1.0 - step(0.0, d);

	// 呼吸脈動:乘上 glow,待機時(glow=0)完全靜止,不搶注意力。
	float breath = 1.0 + 0.22 * sin(TIME * 3.4) * glow;

	float shape = clamp(frame + inner_line + fill, 0.0, 1.0);
	// 待機也必須過 bloom 門檻；拖牌時再把亮度推高，而不是從「幾乎看不見」起跑。
	float energy = mix(1.9, 3.6, glow) * breath;

	// 伏印警戒:顏色「定紅」(不跟呼吸走)、呼吸只做亮度——
	// 顏色也乘呼吸的話,青紅各半混出灰粉色,讀不出「警戒」(第一版翻車點)。
	vec3 color = mix(tile_color, vec3(1.0, 0.16, 0.12), ward_alert);
	float alert_pulse = ward_alert * (0.55 + 0.45 * sin(TIME * 2.2));

	ALBEDO = mix(interior_color, color, clamp(shape * 0.86, 0.0, 1.0));
	EMISSION = color * (energy + alert_pulse * 1.6) * shape
		+ color * inside * 0.1;
	// 22% 暗底在雪地/冰面上刻出完整卡片 footprint；亮框待機即有 64% 不透明度。
	ALPHA = clamp(inside * 0.22
		+ shape * mix(0.64, 0.94, glow) + ward_alert * 0.22, 0.0, 1.0);
}
