## 收斂成一套可重用的暗黑奇幻 UI 語彙。
## 色彩刻意只留深靛黑、舊金與低彩度紫，避免每個面板各自發光。
extends RefCounted

const INK := Color("080a16")
const INK_GLASS := Color(0.035, 0.04, 0.10, 0.94)
const INK_SOFT := Color(0.055, 0.06, 0.13, 0.90)
const GOLD := Color("e3c77d")
const GOLD_BRIGHT := Color("fff1c7")
const GOLD_DIM := Color("bba874")
const AMETHYST := Color("8f73bb")
const AMETHYST_BRIGHT := Color("c9b2ef")
const TEXT := Color("eee9df")
const TEXT_DIM := Color("b8b2bd")
const DANGER := Color("d06e72")


static func panel(accent: Color = GOLD, strong: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK_GLASS if strong else INK_SOFT
	sb.border_color = Color(accent, 0.78 if strong else 0.58)
	sb.set_border_width_all(2 if strong else 1)
	sb.set_corner_radius_all(5)
	sb.corner_detail = 7
	sb.set_content_margin_all(16.0 if strong else 13.0)
	sb.shadow_color = Color(0.19, 0.10, 0.34, 0.42 if strong else 0.25)
	sb.shadow_size = 10 if strong else 6
	sb.anti_aliasing = true
	return sb


static func button(resting: bool = true, danger: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var accent := DANGER if danger else (GOLD_DIM if resting else AMETHYST_BRIGHT)
	sb.bg_color = Color(0.045, 0.045, 0.11, 0.78) if resting \
		else Color(0.14, 0.09, 0.24, 0.94)
	sb.border_color = Color(accent, 0.48 if resting else 0.92)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(9.0)
	if not resting:
		sb.shadow_color = Color(0.40, 0.22, 0.64, 0.42)
		sb.shadow_size = 8
	return sb


static func field() -> StyleBoxFlat:
	var sb := panel(AMETHYST, false)
	sb.bg_color = Color(0.025, 0.028, 0.07, 0.96)
	sb.set_content_margin_all(10.0)
	return sb


static func separator_gradient() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(GOLD, 0.0), Color(GOLD_DIM, 0.7), GOLD_BRIGHT,
		Color(GOLD_DIM, 0.7), Color(GOLD, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 256
	return tex
