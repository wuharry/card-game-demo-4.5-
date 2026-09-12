## 收斂成一套可重用的暗黑奇幻 UI 語彙。
## 色彩刻意只留深靛黑、舊金與低彩度紫，避免每個面板各自發光。
extends RefCounted

const SETTINGS: GDScript = preload("res://src/settings/app_settings.gd")

const INK := Color("080a16")
const INK_GLASS := Color(0.035, 0.04, 0.05, 0.97)
const INK_SOFT := Color(0.055, 0.06, 0.07, 0.95)
const GOLD := Color("e3c77d")
const GOLD_BRIGHT := Color("fff1c7")
const GOLD_DIM := Color("bba874")
const AMETHYST := Color("8f73bb")
const AMETHYST_BRIGHT := Color("c9b2ef")
const TEXT := Color("eee9df")
const TEXT_DIM := Color("b8b2bd")
const DANGER := Color("d06e72")
const STEEL := Color("989b99")
const STEEL_DIM := Color("666b70")
const TURN_BLUE := Color("17334a")
const TURN_BLUE_LIT := Color("214c69")


static func panel(accent: Color = GOLD, strong: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var contrast: bool = SETTINGS.current().high_contrast
	sb.bg_color = Color(0.01, 0.012, 0.03, 0.99) if contrast \
		else (INK_GLASS if strong else INK_SOFT)
	sb.border_color = Color(accent, 1.0 if contrast else (0.78 if strong else 0.58))
	sb.set_border_width_all(3 if contrast else (2 if strong else 1))
	sb.set_corner_radius_all(5)
	sb.corner_detail = 7
	sb.set_content_margin_all(16.0 if strong else 13.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42 if strong else 0.25)
	sb.shadow_size = 10 if strong else 6
	sb.anti_aliasing = true
	return sb


static func button(resting: bool = true, danger: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var accent := DANGER if danger else (STEEL_DIM if resting else GOLD_DIM)
	var contrast: bool = SETTINGS.current().high_contrast
	sb.bg_color = Color(0.005, 0.006, 0.02, 1.0) if contrast \
		else (Color(0.045, 0.05, 0.06, 0.94) if resting \
		else Color(0.10, 0.115, 0.13, 0.98))
	sb.border_color = Color(accent, 1.0 if contrast else (0.48 if resting else 0.92))
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(9.0)
	if not resting:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.shadow_size = 4
	return sb


## 戰鬥 HUD 的窄條：只有一層霧黑底與細銀線，不使用寶石或顆粒紋理。
static func battle_strip() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var contrast: bool = SETTINGS.current().high_contrast
	sb.bg_color = Color(0.015, 0.018, 0.026, 0.98) if contrast \
		else Color(0.035, 0.04, 0.055, 0.90)
	sb.border_color = Color(STEEL, 1.0 if contrast else 0.68)
	sb.set_border_width_all(2 if contrast else 1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	sb.shadow_size = 4
	return sb


## 左上離開鍵：小塊深鐵框，刻意與右側的回合操作隔開。
static func battle_leave_button(lit: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.075, 0.96) if lit \
		else Color(0.028, 0.032, 0.043, 0.92)
	sb.border_color = STEEL if lit else STEEL_DIM
	sb.set_border_width_all(2 if lit else 1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10.0)
	return sb


## 簡化圓形回合鍵：保留藍心與金屬環，不畫 PP 珠列、翅膀或紋章。
static func battle_round_button(lit: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TURN_BLUE_LIT if lit else TURN_BLUE
	sb.border_color = Color(STEEL, 0.95 if lit else 0.72)
	sb.set_border_width_all(4 if lit else 3)
	sb.set_corner_radius_all(64)
	sb.corner_detail = 12
	sb.set_content_margin_all(14.0)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	sb.shadow_size = 7 if lit else 5
	sb.anti_aliasing = true
	return sb


static func field() -> StyleBoxFlat:
	var sb := panel(AMETHYST, false)
	sb.bg_color = Color(0.025, 0.028, 0.035, 0.98)
	sb.set_content_margin_all(10.0)
	return sb


## 焦點只畫邊框，避免覆蓋按下／停用的底色。
static func focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = GOLD_BRIGHT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb


static func primary_button() -> StyleBoxFlat:
	var sb := button(false)
	sb.bg_color = Color("273b46")
	sb.border_color = GOLD_DIM
	sb.border_width_left = 4
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
