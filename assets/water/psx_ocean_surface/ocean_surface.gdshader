// ocean_surface.gdshader — PSX 復古像素風海面水 shader
//
// ⚠️ 注意：這支是素材包附帶的範例，目前「沒有被遊戲場景使用」(戰場用的是 stream_water.gdshader)。
//          留著當學習參考，要清理專案時可連同 psx_ocean_surface/ 一起刪。
//
// 做法重點：兩張水面貼圖各自捲動 + 混合，再把 UV「量化」成方格 → 製造低解析像素感(PSX 風)。
//   ‧ vertex()   讓水面用 sin 波上下起伏
//   ‧ fragment() 算兩層流動貼圖、做像素化、混色後輸出

shader_type spatial;   // 3D 物體用的材質 shader

// ── uniform = 外部可調參數(Inspector / GDScript 設定) ──────────────
uniform vec3 albedo : source_color;        // 整體染色(會乘在水色上)
uniform sampler2D water_texture1;          // 第一張水面貼圖
uniform sampler2D water_texture2;          // 第二張水面貼圖
uniform sampler2D noise_texture;           // 雜訊圖(給波浪起伏用)
uniform vec2 scroll_speed1 = vec2(0.05, 0.0);  // 第一張貼圖的捲動速度/方向
uniform vec2 scroll_speed2 = vec2(-0.03, 0.0); // 第二張(反方向)，兩層交錯更自然
uniform float blend_factor = 0.5;          // 兩張貼圖的混合比例(0=全用1, 1=全用2)
uniform vec2 scale1 = vec2(1.0, 1.0);      // 第一張的 UV 縮放(紋路大小)
uniform vec2 scale2 = vec2(1.0, 1.0);      // 第二張的 UV 縮放
uniform float wave_strength = 1.0;         // 波浪高度
uniform float wave_scale = 0.02;           // 雜訊取樣縮放(影響波浪疏密)
uniform int pixelation_level = 64;         // 像素化等級(越小格子越大、越復古)

void vertex() {
    // 頂點的世界座標 XZ(俯視平面位置)，當作雜訊取樣座標。
    vec2 global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    // 取一點雜訊，讓不同位置的波相位不同。
    float noise_value = texture(noise_texture, global_position * wave_scale).r;
    // 用 sin 波算出這個頂點要抬升多少 → 水面起伏。隨 TIME 變化所以會動。
    float wave = sin(global_position.x * 0.2 + global_position.y * 0.2 + TIME + noise_value * 10.0) * wave_strength;
    VERTEX.y += wave;   // 把頂點往上抬 wave 的高度
}

void fragment() {
    // 1) 先把 UV 各自縮放(控制兩層紋路大小)
    vec2 scaledUV1 = UV * scale1;
    vec2 scaledUV2 = UV * scale2;
    // 2) 隨時間加上捲動偏移 → 讓水面紋路「流動」
    vec2 scrolledUV1 = scaledUV1 + scroll_speed1 * TIME;
    vec2 scrolledUV2 = scaledUV2 + scroll_speed2 * TIME;
    // 3) mod(..., 1.0) 把 UV 包回 0~1 範圍，避免捲動到超出貼圖
    scrolledUV1 = mod(scrolledUV1, vec2(1.0, 1.0));
    scrolledUV2 = mod(scrolledUV2, vec2(1.0, 1.0));
    // 4) 像素化：floor(UV * 格數) / 格數 → 把連續座標「卡」成方格，做出 PSX 低解析感
    scrolledUV1 = floor(scrolledUV1 * float(pixelation_level)) / float(pixelation_level);
    scrolledUV2 = floor(scrolledUV2 * float(pixelation_level)) / float(pixelation_level);

    // 5) 用處理過的 UV 取兩張水面貼圖的顏色
    vec4 water_color1 = texture(water_texture1, scrolledUV1);
    vec4 water_color2 = texture(water_texture2, scrolledUV2);
    // 6) 依 blend_factor 把兩層混在一起
    vec4 blended_water_color = mix(water_color1, water_color2, blend_factor);

    // ── 輸出 ──
    ALBEDO = blended_water_color.rgb * albedo;  // 水色 × 染色
    METALLIC = 0.0;                             // 非金屬
    ROUGHNESS = 1.0;                            // 全粗糙(不反光，純色塊感，配合像素風)
}
