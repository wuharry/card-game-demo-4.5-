extends SceneTree
## 這張 AI 素材救不救得回來?量三件事:背景是什麼、像素塊多大、格線在哪。
##   godot --headless -s tests/probe_ai_sheet.gd
const SRC := "res://assets/ChatGPT Image 2026年8月20日 下午01_09_10.png"

func _initialize() -> void:
	var img := Image.load_from_file(SRC)
	if img == null:
		print("讀不到"); quit(1); return
	var w := img.get_width()
	var h := img.get_height()

	# 1) 顏色頻率 top 8:棋盤格背景會是壓倒性的前兩名
	var freq := {}
	for y in h:
		for x in w:
			var k := img.get_pixel(x, y).to_rgba32()
			freq[k] = freq.get(k, 0) + 1
	var keys := freq.keys()
	keys.sort_custom(func(a, b): return freq[a] > freq[b])
	print("=== 顏色頻率 top 8(總 %d 色)===" % freq.size())
	var total := w * h
	for i in mini(8, keys.size()):
		var c := Color(keys[i])
		print("  #%d  RGB(%.3f,%.3f,%.3f)  %d px  %.1f%%" % [
			i, c.r, c.g, c.b, freq[keys[i]], 100.0 * freq[keys[i]] / total])

	# 2) 棋盤格週期:沿最上一列走,量同色 run 長度的眾數
	var runs := {}
	var run := 1
	for x in range(1, w):
		if img.get_pixel(x, 0).is_equal_approx(img.get_pixel(x - 1, 0)):
			run += 1
		else:
			runs[run] = runs.get(run, 0) + 1
			run = 1
	var rk := runs.keys(); rk.sort_custom(func(a, b): return runs[a] > runs[b])
	print("\n=== 最上一列的同色 run 長度分布(前 5)===")
	for i in mini(5, rk.size()):
		print("  run=%d 出現 %d 次" % [rk[i], runs[rk[i]]])

	# 3) 角色區的像素塊:取一格中央的橫線,量 run
	var cy := 100
	var runs2 := {}
	run = 1
	for x in range(1, 400):
		if img.get_pixel(x, cy).is_equal_approx(img.get_pixel(x - 1, cy)):
			run += 1
		else:
			runs2[run] = runs2.get(run, 0) + 1
			run = 1
	var rk2 := runs2.keys(); rk2.sort_custom(func(a, b): return runs2[a] > runs2[b])
	print("\n=== 角色所在橫線(y=100)的 run 分布(前 6)===")
	for i in mini(6, rk2.size()):
		print("  run=%d 出現 %d 次" % [rk2[i], runs2[rk2[i]]])
	quit(0)
