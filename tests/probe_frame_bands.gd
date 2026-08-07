extends SceneTree
## 新卡框的橫向結構:卡名木牌、描述木框各佔哪一段 y——擺 Label3D 前要量的東西。
##   godot --headless -s tests/probe_frame_bands.gd
##
## 做法:逐列取「該列的平均顏色」,顏色跳變處就是結構分界。
## 不用亮度單一維度(那會把棕木牌和深棕木框看成同一段),用 RGB 距離。

const SHEET := "res://assets/ui/card_frames/pixel_template/cards_sheet.png"
const CELL_W := 64
const CELL_H := 96
## 排 1 = 有卡圖窗、下半留白的那排(預覽用的就是它)
const ROW := 1


func _initialize() -> void:
	var img := Image.load_from_file(SHEET)
	if img == null:
		print("讀不到 %s" % SHEET)
		quit(1)
		return
	for col in 4:
		_bands(img, col)
	quit(0)


func _bands(img: Image, col: int) -> void:
	var ox := 16 + col * 80
	var oy := 16 + ROW * 112
	print("\n══ 排 %d 欄 %d(Rect2(%d,%d,64,96))══" % [ROW, col, ox, oy])
	var prev := Color(-1, -1, -1)
	var start := 0
	var acc := Color(0, 0, 0)
	var n := 0
	for dy in CELL_H:
		var c := _row_color(img, ox, oy + dy)
		if prev.r < 0.0:
			prev = c
			acc = c
			n = 1
			continue
		# RGB 距離跳變 > 0.10 視為換了一段結構
		var d := absf(c.r - prev.r) + absf(c.g - prev.g) + absf(c.b - prev.b)
		if d > 0.10:
			_print_band(start, dy - 1, acc, n)
			start = dy
			acc = c
			n = 1
		else:
			acc += c
			n += 1
		prev = c
	_print_band(start, CELL_H - 1, acc, n)


## 一列的「代表色」:只算不透明像素的平均(透明的卡圖窗會被跳過)
func _row_color(img: Image, ox: int, y: int) -> Color:
	var sum := Color(0, 0, 0)
	var n := 0
	for dx in CELL_W:
		var c := img.get_pixel(ox + dx, y)
		if c.a >= 0.5:
			sum += Color(c.r, c.g, c.b)
			n += 1
	if n == 0:
		return Color(-1, -1, -1)   # 整列透明 = 卡圖窗
	return Color(sum.r / n, sum.g / n, sum.b / n)


func _print_band(y0: int, y1: int, acc: Color, n: int) -> void:
	if n <= 0:
		return
	var avg := Color(acc.r / n, acc.g / n, acc.b / n)
	var h := y1 - y0 + 1
	if h < 2:
		return   # 1px 的過渡線不列
	var tag := ""
	if avg.r < 0.0:
		tag = "  ← 透明(卡圖窗)"
	elif avg.r > 0.45 and avg.g > 0.30 and avg.b < 0.35:
		tag = "  ← 木頭色(木牌/木框)"
	elif avg.r < 0.22 and avg.g < 0.22:
		tag = "  ← 深色底"
	# 換算成卡片本地座標(卡高 2.4,頂 +1.2):中心 y
	var cy := 1.2 - ((y0 + y1 + 1) / 2.0 / CELL_H) * 2.4
	var hh := (h / float(CELL_H)) * 2.4
	print("  y %2d~%2d(高 %2d)RGB(%.2f,%.2f,%.2f)→ 本地中心 y=%+.3f 高=%.3f%s" % [
		y0, y1, h, avg.r, avg.g, avg.b, cy, hh, tag])
