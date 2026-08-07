extends SceneTree
## cards_sheet 每格的「透明挖空窗」在哪——決定卡圖要擺框前面還是後面(§9)。
##   godot --headless -s tests/probe_sheet_alpha.gd
##
## 為什麼要獨立一支:前一支探針用亮度找窗,結果只抓到格子的上下邊線。
## 亮度找不到不代表沒有窗——**窗可能是透明的**,亮度掃描對 alpha=0 的像素視而不見。
## 換個問法(數 alpha < 0.5 的像素)就水落石出。同一張圖,量錯東西就得到錯結論。

const SHEET := "res://assets/ui/card_frames/pixel_template/cards_sheet.png"


func _initialize() -> void:
	var img := Image.load_from_file(SHEET)
	if img == null:
		print("讀不到 %s" % SHEET)
		quit(1)
		return
	for row in 4:
		_cell(img, row, 0)
	print("\n── 卡背(第 5 欄排 0)──")
	_cell(img, 0, 4)
	quit(0)


func _cell(img: Image, row: int, col: int) -> void:
	var ox := 16 + col * 80
	var oy := 16 + row * 112
	var clear := 0
	var runs: Array = []
	var start := -1
	for dy in 96:
		var c := 0
		for dx in 64:
			if img.get_pixel(ox + dx, oy + dy).a < 0.5:
				c += 1
		clear += c
		var mostly := c > 32          # 過半透明才算「窗的一列」,忽略圓角零星透明
		if mostly and start < 0:
			start = dy
		elif not mostly and start >= 0:
			runs.append([start, dy - 1])
			start = -1
	if start >= 0:
		runs.append([start, 95])
	print("\n排 %d 欄 %d — Rect2(%d,%d,64,96):透明 %d/6144(%.0f%%)" % [
		row, col, ox, oy, clear, 100.0 * clear / 6144.0])
	if runs.is_empty():
		print("   沒有成片的透明帶 → 這格沒有挖空窗")
		return
	for r in runs:
		var y0: int = r[0]
		var y1: int = r[1]
		var mnx := 64
		var mxx := -1
		for dy in range(y0, y1 + 1):
			for dx in 64:
				if img.get_pixel(ox + dx, oy + dy).a < 0.5:
					mnx = mini(mnx, dx)
					mxx = maxi(mxx, dx)
		print("   透明帶 相對 y %d~%d(高 %d)x %d~%d(寬 %d)" % [
			y0, y1, y1 - y0 + 1, mnx, mxx, mxx - mnx + 1])
		print("     → 窗在圖上的絕對位置 Rect2(%d, %d, %d, %d)" % [
			ox + mnx, oy + y0, mxx - mnx + 1, y1 - y0 + 1])
		print("     → 相對格子比例:左 %.3f 上 %.3f 寬 %.3f 高 %.3f" % [
			mnx / 64.0, y0 / 96.0, (mxx - mnx + 1) / 64.0, (y1 - y0 + 1) / 96.0])
