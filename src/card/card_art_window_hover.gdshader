// hover 專用：保留相同卡圖與圓角，避免鄰卡先寫入的深度擋住它。
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

#include "card_art_window.gdshaderinc"
