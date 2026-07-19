// grave_vortex.gdshader — 墓地黑洞盤:紫藍星雲漩渦,常駐醒目(hover 與否無關)。
// 參考圖(紫藍星雲黑洞)拆成四層,由暗到亮往上疊,讓 glow 門檻(0.9~0.95)當「圖層篩子」:
//   1. 雲霧底(fbm 噪聲順著螺旋場流動)         → 亮度壓在門檻下,只當底色
//   2. 亮線條(sin 高次方壓細 × 噪聲截成長短段) → 過門檻,泛光成「光的溪流」
//   3. 光點(log-極座標格子擲骰,往內飄+閃爍)  → 過門檻,像被吸進去的星星
//   4. 視界亮環(洞口那圈)                      → 全場最亮,參考圖洞緣的白光
// 吸入感的關鍵在「相位正負號」:螺旋相位 P = 臂數*角度 + k*log(r) + 速度*TIME,
// 等相線(亮紋)滿足 log(r) = (P - 臂數*角度 - 速度*t)/k → 時間越走 r 越小
// = 亮紋往圓心移動。寫成 -TIME 就會默默往外漂,只剩「在轉」沒有「在吸」。
// 純裝飾:遊戲邏輯不戳它(脈衝/回魔金都走吸積環的 StandardMaterial3D)。
shader_type spatial;
render_mode unshaded, blend_mix, shadows_disabled, specular_disabled;

uniform vec3 color_a : source_color = vec3(0.62, 0.42, 0.95);  // 幽紫(主色,同 SOUL_PURPLE)
uniform vec3 color_b : source_color = vec3(0.30, 0.55, 1.00);  // 魔力藍
uniform vec3 color_c : source_color = vec3(0.95, 0.55, 1.00);  // 粉紫(只在雲最亮處滲出)
uniform float spin_speed : hint_range(0.0, 2.0) = 0.35;    // 整體自轉速度
uniform float inflow_speed : hint_range(0.0, 2.0) = 0.5;   // 線條/光點往內流的速度
uniform float arm_count : hint_range(1.0, 8.0) = 3.0;      // 螺旋臂數(整數才不會在 ±π 裂縫)
uniform float brightness : hint_range(0.0, 4.0) = 1.4;     // 雲霧底亮度
uniform float streak_glow : hint_range(0.0, 8.0) = 3.2;    // 亮線條強度(過 glow 門檻才會暈)
uniform float dot_glow : hint_range(0.0, 8.0) = 3.6;       // 光點強度
uniform float ring_glow : hint_range(0.0, 8.0) = 4.5;      // 視界外緣那圈的亮度

const float TAU_F = 6.2831853;

// hash → 值噪聲 → fbm:不吃貼圖的程序化雲霧三件套(shader 自給自足)
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);   // smoothstep 權重:格點間圓滑過渡
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {   // 4 個八度:大雲塊上疊小碎絮
		v += amp * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;              // UV(0~1) → 以圓心為原點(-1~1)
	float r = length(p);
	float lr = log(r + 0.001);
	float ang = atan(p.y, p.x);

	// 螺旋座標:把平面「越內圈扭越多」之後再採噪聲 → 雲天生長成漩渦狀。
	// 在直角座標上旋轉(不經過角度軸),繞一圈無接縫。
	float tw = 4.0 * lr + TIME * spin_speed * TAU_F;
	vec2 q = mat2(vec2(cos(tw), -sin(tw)), vec2(sin(tw), cos(tw))) * p;

	// ── 1. 雲霧底 ──
	float n1 = fbm(q * 3.0 + vec2(0.0, TIME * 0.15));
	float n2 = fbm(q * 6.5 - vec2(TIME * 0.1, 0.0));
	float cloud = n1 * (0.5 + 0.5 * n2);

	// ── 2. 亮線條:高次方把 sin 壓成細線,再用噪聲截成長短不一的光溪 ──
	float phase = ang * arm_count + 5.0 * lr + TIME * inflow_speed * TAU_F;
	float line1 = pow(0.5 + 0.5 * sin(phase), 10.0);
	float line2 = pow(0.5 + 0.5 * sin(phase * 2.0 + 1.7), 14.0);
	float seg = smoothstep(0.35, 0.65, fbm(q * 4.0 + 5.0));
	float streaks = (line1 + 0.6 * line2) * seg;

	// ── 3. 光點:log-極座標切格、每格擲骰放一顆星,隨流場旋進+閃爍 ──
	// 角度切「整數 24 格」→ 跨 ±π 接縫兩側格號 mod 後一致,hash 不裂
	vec2 g = vec2((ang / TAU_F + 0.5) * 24.0 + TIME * spin_speed * 3.0,
			lr * 5.0 - TIME * inflow_speed * 2.5);
	vec2 cell = vec2(mod(floor(g.x), 24.0), floor(g.y));
	vec2 fc = fract(g);
	float rnd = hash21(cell);
	vec2 star_pos = 0.2 + 0.6 * vec2(hash21(cell + 7.0), hash21(cell + 13.0));
	float twinkle = 0.6 + 0.4 * sin(TIME * (2.0 + 4.0 * rnd) + rnd * TAU_F);
	float stars = smoothstep(0.20, 0.02, length(fc - star_pos))
			* step(0.45, rnd) * twinkle;

	// ── 遮罩:方形 quad 裁圓、中心挖事件視界、洞緣一圈亮環 ──
	float edge = 1.0 - smoothstep(0.80, 1.0, r);
	float hole = smoothstep(0.13, 0.34, r);
	float ring = smoothstep(0.11, 0.17, r) * (1.0 - smoothstep(0.19, 0.30, r));

	// ── 配色:紫↔藍由雲層決定,粉紫只在雲最厚最亮處滲出 ──
	float mix_ab = clamp(n1 * 1.4 - 0.2 + 0.25 * sin(ang * 2.0 + lr * 3.0 - TIME * 0.5), 0.0, 1.0);
	vec3 col = mix(color_a, color_b, mix_ab);
	col = mix(col, color_c, 0.5 * n2 * n2);

	vec3 e = col * cloud * brightness * hole;                     // 底:壓在門檻下
	e += col * streaks * streak_glow * hole;                      // 線:過門檻泛光
	e += mix(color_c, vec3(1.0), 0.4) * stars * dot_glow * hole;  // 點:亮白偏粉
	e += mix(color_a, vec3(1.0), 0.55) * ring * ring_glow;        // 洞緣:全場最亮
	ALBEDO = vec3(0.0);
	EMISSION = e * edge;
	ALPHA = edge * 0.92;   // 近乎不透明:把底下的地面吃掉,星雲才有「深」
}
