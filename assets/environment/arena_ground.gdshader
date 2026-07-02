// arena_ground.gdshader — 通用「雙貼圖斑塊混合」地板
//
// 給程式生成的牌桌場景(Caverns / Frostlands)當地板。
// 概念:整片地板鋪「底貼圖」,再用一張噪聲圖當遮罩,噪聲高的地方換成「斑塊貼圖」,
// 邊界用 smoothstep 柔和過渡——視覺效果等同 arena_forest 用 GridMap 鋪出的草/泥斑塊,
// 但不需要 MeshLibrary(新素材包沒有現成 .meshlib,而 meshlib 只能在編輯器手工組)。

shader_type spatial;

// ── 貼圖 ─────────────────────────────────────────────
// filter_nearest_mipmap:鄰近取樣保住像素風的銳利邊,mipmap 避免遠處閃爍。
uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;    // 主地貌
uniform sampler2D tex_patch : source_color, filter_nearest_mipmap, repeat_enable;   // 斑塊地貌
uniform sampler2D normal_base : hint_normal, filter_nearest_mipmap, repeat_enable;  // 主地貌法線
uniform sampler2D normal_patch : hint_normal, filter_nearest_mipmap, repeat_enable; // 斑塊法線
uniform sampler2D mask_noise : repeat_enable;   // 斑塊遮罩噪聲(由腳本用 NoiseTexture2D 餵入)

// ── 可調參數 ──────────────────────────────────────────
uniform float tile_size = 2.0;        // 一塊貼圖鋪幾公尺(越大磚看起來越大)
uniform float patch_scale = 0.05;     // 斑塊噪聲頻率(越小斑塊越大片)
uniform float patch_threshold = 0.6;  // 噪聲高於此 → 斑塊(調大 = 斑塊變少)
uniform float patch_edge = 0.08;      // 過渡帶寬度(0 = 硬切邊)
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;  // 泥土/雪地都接近全霧面

varying vec3 wpos;   // 世界座標:vertex 算好傳給 fragment 共用

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 用「世界 XZ ÷ tile_size」當 UV:貼圖以固定實際尺寸無縫平鋪,
	// 與 mesh 自身的大小/UV 無關 → 地板換多大都不會拉伸變形。
	vec2 uv = wpos.xz / tile_size;
	// 噪聲遮罩:同一個世界位置永遠取到同一個值 → 斑塊位置固定、不會閃爍。
	float m = texture(mask_noise, wpos.xz * patch_scale).r;
	// smoothstep:在 threshold ± edge 的窄帶內從 0 平滑爬到 1,當混合權重。
	float w = smoothstep(patch_threshold - patch_edge, patch_threshold + patch_edge, m);
	ALBEDO = mix(texture(tex_base, uv).rgb, texture(tex_patch, uv).rgb, w);
	// 法線貼圖跟著同一個權重混,斑塊區才有自己的凹凸(像素風尺度下線性混兩張夠用)。
	NORMAL_MAP = mix(texture(normal_base, uv).rgb, texture(normal_patch, uv).rgb, w);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
