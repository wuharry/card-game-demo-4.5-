// card_art_window.gdshader — 卡圖窗的真正圓角遮罩。
// Frame PNG 的外圍也有透明像素；只靠「把矩形卡圖放在框後面」會從角落漏出黑方塊。
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled, shadows_disabled;

#include "card_art_window.gdshaderinc"
