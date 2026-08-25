extends SceneTree
## 「這張像素圖是真像素還是 AI 生的偽像素?」——量三個指標,拿現有素材當對照組。
##   godot --headless -s tests/probe_pixel_purity.gd
##
## 為什麼要量:AI 生成的「像素風」常有反鋸齒半透明邊緣、顏色數爆量、
## 像素塊大小不一。這些在 TEXTURE_FILTER_NEAREST 下會直接糊掉或閃爍,
## 肉眼看縮圖分辨不出來,放進遊戲才發現——所以先量。

const TARGETS := [
	["新素材(AI 生成)", "res://assets/ChatGPT Image 2026年8月20日 下午01_09_10.png"],
	["對照:Warlock_Idle", "res://assets/packs/tiny_rpg_characters/Tiny RPG Character Asset Pack 02 -Full 20 Characters/Characters(100x100 split)/Warlock/Warlock/Warlock_Idle.png"],
	["對照:卡框圖集", "res://assets/ui/card_frames/pixel_template/cards_sheet.png"],
	["對照:法術圖示", "res://assets/ui/icons/antahonist_spells/spell_icons_32x32.png"],
]


func _initialize() -> void:
	for t in TARGETS:
		_measure(t[0], t[1])
	quit(0)


func _measure(label: String, path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		print("\n讀不到:%s" % path)
		return
	var w := img.get_width()
	var h := img.get_height()
	var colors := {}
	var semi := 0          # 半透明像素(0 < a < 1):反鋸齒的指紋
	var opaque := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.02:
				continue
			if c.a < 0.98:
				semi += 1
			opaque += 1
			colors[Color8(int(c.r * 255), int(c.g * 255), int(c.b * 255)).to_rgba32()] = true
	# 像素塊大小:水平掃「同色連續長度」的最小值。真像素圖的最小 run 等於像素塊尺寸,
	# 而且會是一致的整數;AI 生成的會出現大量 run=1(每格一個色 = 沒有像素塊感)。
	var run1 := 0
	var runs := 0
	for y in range(0, h, 3):
		var run := 1
		for x in range(1, w):
			if img.get_pixel(x, y).is_equal_approx(img.get_pixel(x - 1, y)):
				run += 1
			else:
				runs += 1
				if run == 1:
					run1 += 1
				run = 1
	print("\n══ %s ══" % label)
	print("  尺寸 %d×%d,不透明像素 %d" % [w, h, opaque])
	print("  顏色數:%d" % colors.size())
	print("  半透明(反鋸齒)像素:%d(%.2f%% of 不透明)" % [
		semi, 100.0 * semi / maxf(opaque, 1)])
	print("  單像素 run 佔比:%.1f%%(越高 = 越沒有「像素塊」感)" % [
		100.0 * run1 / maxf(runs, 1)])
