// stream_water.gdshader — 風格化溪流水面
//
// 【什麼是 shader？】一支「跑在顯示卡上、決定每個頂點/每個像素長怎樣」的小程式。
//   ‧ vertex()   每個「頂點」執行一次 → 用來讓水面上下起伏(做波浪)
//   ‧ fragment() 每個「像素」執行一次 → 用來決定那一點是什麼顏色
// 這支水面做了四件事：流動波紋法線、低粗糙度反射、菲涅耳(掠角變亮)、深淺水色漸層。
// 反射場景(樹林)需要在 WorldEnvironment 開啟 SSR (ss_reflections_enabled)。

shader_type spatial;          // spatial = 給 3D 物體用的材質 shader
render_mode cull_disabled;    // 正反兩面都畫(預設只畫正面)，水面從下方也看得到

// ── uniform = 可從外部(Inspector / GDScript)調整的參數 ───────────────
// 改這些數值就能即時調水的外觀，不必動 shader 程式碼本身。
uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable; // 水面底圖
uniform sampler2D noise_tex : repeat_enable;          // 雜訊圖，用來算波紋起伏
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.28);    // 深水顏色
uniform vec3 shallow_color : source_color = vec3(0.20, 0.48, 0.55); // 淺水顏色
uniform vec2 flow_dir = vec2(1.0, 0.0);   // 水流方向(這裡沿 X 軸流)
uniform float flow_speed = 0.05;          // 流速
uniform float uv_scale = 0.12;            // 貼圖縮放(越小紋路越大)
uniform float wave_height = 0.05;         // 波浪上下起伏的高度
uniform float ripple_strength = 0.35;     // 波紋法線強度(影響反光的扭曲程度)
uniform float water_roughness = 0.05;     // 粗糙度(越低越像鏡面、反射越清晰)
uniform float fresnel_power = 4.0;        // 菲涅耳次方(控制掠角變亮的範圍)
uniform float water_alpha = 0.9;          // 透明度參數(此版水面為不透明，保留備用)

// varying = 在 vertex() 算好、傳給 fragment() 共用的變數。
// 這裡傳「這個點在世界空間(整個場景的絕對座標)的位置」。
varying vec3 wpos;

void vertex() {
	// 把頂點從模型自身座標轉成世界座標。MODEL_MATRIX 負責這個轉換。
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 取一點雜訊(隨時間 TIME 捲動)，讓每個位置的波相位都不同，看起來更亂、更自然。
	float n = texture(noise_tex, wpos.xz * 0.04 + flow_dir * flow_speed * TIME).r;
	// 用 sin 波讓頂點 Y(高度)上下擺動 → 水面起伏。n*6.2831(≈2π) 把雜訊轉成相位偏移。
	VERTEX.y += sin(wpos.x * 0.7 + TIME * 1.5 + n * 6.2831) * wave_height;
}

void fragment() {
	vec2 base = wpos.xz * uv_scale;          // 用世界 XZ 當取樣座標(俯視水面的平面座標)
	vec2 fl = flow_dir * flow_speed * TIME;  // 隨時間移動的偏移 → 讓紋路「流動」
	float e = 0.02;                          // 取樣間距，用來估算斜率(算法線用)

	// ── 算波紋法線 ──
	// 法線 = 表面朝向。水面其實是平的，但我們用雜訊「假裝」它凹凸不平，
	// 這樣反光才會跟著扭動。做法：取三個鄰近點的高度差，推出斜率。
	// 兩層 noise(不同縮放、反方向捲動)疊加，避免重複感。
	float h  = texture(noise_tex, base + fl).r + texture(noise_tex, base * 1.9 - fl * 0.7).r;
	float hx = texture(noise_tex, base + vec2(e, 0.0) + fl).r + texture(noise_tex, (base + vec2(e, 0.0)) * 1.9 - fl * 0.7).r; // 往 X 偏一點的高度
	float hz = texture(noise_tex, base + vec2(0.0, e) + fl).r + texture(noise_tex, (base + vec2(0.0, e)) * 1.9 - fl * 0.7).r; // 往 Z 偏一點的高度
	// (中心高度 - 鄰近高度) = 斜率；組成法線向量並正規化(長度變 1)。
	vec3 ripple_n = normalize(vec3((h - hx) * ripple_strength * 12.0, 1.0, (h - hz) * ripple_strength * 12.0));

	// 把法線轉到「view space(以攝影機為基準的座標)」，Godot 的 NORMAL 與菲涅耳都用這個空間。
	vec3 vn = normalize((VIEW_MATRIX * vec4(ripple_n, 0.0)).xyz);
	NORMAL = vn;
	// 菲涅耳：視線越「掠過」水面(接近平視)時值越大 → 邊緣比正上方更亮，是水的真實特性。
	float fres = pow(1.0 - clamp(dot(VIEW, vn), 0.0, 1.0), fresnel_power);

	// ── 上色 ──
	vec3 tex = texture(water_tex, base + fl).rgb;                       // 流動中的水面底圖
	vec3 col = mix(deep_color, shallow_color, clamp(h * 0.5, 0.0, 1.0)); // 依高度混深/淺水色
	col = mix(col, col * tex * 1.6, 0.35);                              // 疊一點底圖紋理
	col += shallow_color * fres * 0.6;                                  // 掠角(邊緣)加亮，模擬反射

	// ── 輸出給 Godot 的標準材質欄位 ──
	ALBEDO = col;                  // 基礎顏色
	METALLIC = 0.0;                // 非金屬
	ROUGHNESS = water_roughness;   // 低粗糙 → 像鏡面，反射清晰
	SPECULAR = 0.7;                // 高光強度
	// 註：刻意維持不透明，這樣 SSR(螢幕空間反射)才能把場景樹林反射到水面上。
}
