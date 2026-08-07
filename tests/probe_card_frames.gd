extends SceneTree
## 卡框素材體檢:量出換卡框需要的所有座標——「用量的代替用猜的」(§12)。
##   godot --headless -s tests/probe_card_frames.gd
##
## 用 Image.load_from_file 讀原始檔,**繞過 Godot 匯入系統**(§23):
## 新素材還沒被編輯器掃描過、沒有 .import,用 load() 會失敗,這條後門讀得到。
##
## 這是探針不是回歸測試:輸出給人看、不做斷言(素材換了數字本來就會變)。

const SHEET := "res://assets/ui/card_frames/pixel_template/cards_sheet.png"
## 由上一輪掃描推出的格子公式:欄距 80、排距 112、格子 64×96、起點 (16,16)。
const CELL_W := 64
const CELL_H := 96
const COL_STEP := 80
const ROW_STEP := 112
const ORIGIN := Vector2i(16, 16)


func _initialize() -> void:
	var img := Image.load_from_file(SHEET)
	if img == null:
		print("讀不到 %s" % SHEET)
		quit(1)
		return
	print("cards_sheet.png %d×%d" % [img.get_width(), img.get_height()])
	print("格子公式:Rect2(%d + 欄×%d, %d + 排×%d, %d, %d)" % [
		ORIGIN.x, COL_STEP, ORIGIN.y, ROW_STEP, CELL_W, CELL_H])
	for row in 4:
		_dissect(img, row, 0)
	print("\n── 第 5 欄(卡背候選)──")
	for row in 4:
		_cell_summary(img, row, 4)
	print("\n── 右側零件區(x 420~512)──")
	_parts(img)
	quit(0)


func _lum(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	if c.a < 0.5:
		return -1.0
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## 拆一格:逐列量亮度,找出「卡圖窗」(連續亮列)與其餘結構。
func _dissect(img: Image, row: int, col: int) -> void:
	var ox := ORIGIN.x + col * COL_STEP
	var oy := ORIGIN.y + row * ROW_STEP
	print("\n══ 排 %d 欄 %d — 格子 Rect2(%d, %d, %d, %d) ══" % [
		row, col, ox, oy, CELL_W, CELL_H])
	# 逐列算「該列的平均亮度」,亮列 = 卡圖窗(白底)或淺色文字列
	var bands: Array = []      # [起y, 迄y, 平均亮度]
	var cur_start := -1
	var cur_sum := 0.0
	var cur_n := 0
	var prev_bright := false
	# ⚠ 不能用「整列平均亮度」:卡圖窗是白色小塊、周圍是深色木紋,平均會被拉低到抓不到。
	# 改數「夠亮的像素佔該列的比例」——問的是「這一列有沒有一大段是亮的」。
	for dy in CELL_H:
		var lit := 0
		var n := 0
		for dx in CELL_W:
			var l := _lum(img, ox + dx, oy + dy)
			if l >= 0.0:
				n += 1
				if l > 0.62:
					lit += 1
		var avg := (float(lit) / n) if n > 0 else -1.0
		var bright := avg > 0.45
		if bright and not prev_bright:
			cur_start = dy
			cur_sum = 0.0
			cur_n = 0
		if bright:
			cur_sum += avg
			cur_n += 1
		if not bright and prev_bright:
			bands.append([cur_start, dy - 1, cur_sum / cur_n])
		prev_bright = bright
	if prev_bright:
		bands.append([cur_start, CELL_H - 1, cur_sum / cur_n])
	if bands.is_empty():
		print("  沒有亮區(整格深色):卡圖窗與文字列都是暗色版")
	for b in bands:
		var y0: int = b[0]
		var y1: int = b[1]
		print("  亮區 相對y %d~%d(高 %d)亮像素佔比 %.2f  → 絕對 y %d~%d" % [
			y0, y1, y1 - y0 + 1, b[2], oy + y0, oy + y1])
	# 量最大亮區的左右邊界(卡圖窗的 x 範圍)
	if not bands.is_empty():
		var best: Array = bands[0]
		for b in bands:
			if b[1] - b[0] > best[1] - best[0]:
				best = b
		var mid: int = oy + int((best[0] + best[1]) / 2.0)
		var x0 := -1
		var x1 := -1
		for dx in CELL_W:
			if _lum(img, ox + dx, mid) > 0.55:
				if x0 < 0:
					x0 = dx
				x1 = dx
		print("  最大亮區的 x 範圍:相對 %d~%d(寬 %d)→ 絕對 x %d~%d" % [
			x0, x1, x1 - x0 + 1, ox + x0, ox + x1])


func _cell_summary(img: Image, row: int, col: int) -> void:
	var ox := ORIGIN.x + col * COL_STEP
	var oy := ORIGIN.y + row * ROW_STEP
	var opaque := 0
	for dy in CELL_H:
		for dx in CELL_W:
			if img.get_pixel(ox + dx, oy + dy).a >= 0.5:
				opaque += 1
	var pct := 100.0 * opaque / float(CELL_W * CELL_H)
	print("  排 %d:Rect2(%d, %d, 64, 96) 不透明 %.0f%%%s" % [
		row, ox, oy, pct, "  ← 有內容" if pct > 50.0 else "  (空)"])


## 右側零件:逐行/逐列找非空區間,幫忙定位分隔線與 12 顆小徽章。
func _parts(img: Image) -> void:
	var h := img.get_height()
	for x0 in [420]:
		var runs: Array = []
		var start := -1
		for y in h:
			var empty := true
			for x in range(x0, img.get_width()):
				if img.get_pixel(x, y).a >= 0.5:
					empty = false
					break
			if not empty and start < 0:
				start = y
			elif empty and start >= 0:
				runs.append([start, y - 1])
				start = -1
		if start >= 0:
			runs.append([start, h - 1])
		for r in runs:
			var y0: int = r[0]
			var y1: int = r[1]
			# 該橫帶內的 x 範圍
			var mnx := img.get_width()
			var mxx := -1
			for y in range(y0, y1 + 1):
				for x in range(x0, img.get_width()):
					if img.get_pixel(x, y).a >= 0.5:
						mnx = mini(mnx, x)
						mxx = maxi(mxx, x)
			print("  橫帶 y %d~%d(高 %d), x %d~%d(寬 %d)" % [
				y0, y1, y1 - y0 + 1, mnx, mxx, mxx - mnx + 1])
