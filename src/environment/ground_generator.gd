@tool   # @tool：讓這支腳本「在編輯器裡」也會跑，不必按播放就能看到鋪好的地板
extends GridMap   # GridMap = 3D 版磚塊地圖：把 meshlib 裡的格子 mesh 一格一格拼成地形
# 用噪聲程序化鋪設地板：以純草為底，泥土依噪聲「成簇」分布、邊緣用草泥過渡磚銜接，
# 取代原本胡椒鹽式的隨機泥塊，看起來更自然。每格隨機 Y 朝向以打散重複感。
#
# 調整 export 後勾 regenerate 即可即時重鋪。泥土太多/太少調 dirt_threshold，
# 斑塊大小調 patch_scale（越小斑塊越大）。

# regenerate：Inspector 裡一個當「重新生成按鈕」用的勾選框。
# 勾下去 → set 立刻把它打回 false(永遠像個按鈕)，並重跑 _generate() 重鋪地板。
@export var regenerate: bool = false:
	set(value):
		regenerate = false
		if is_inside_tree():   # 確認節點已在場景樹中(太早呼叫會出錯)
			_generate()

@export_group("範圍")
# 範圍比戰場大很多:把「世界的盡頭」推遠、配合霧氣淡出,鏡頭裡才看不到草皮的斷邊。
# 78 × 69 ≈ 5400 格,@tool 重鋪仍是一瞬間的量級,不值得為此優化。
@export var min_x: int = -40
@export var max_x: int = 37
@export var min_z: int = -38
@export var max_z: int = 30
# 地表鋪在哪一層。磚是「紙片」貼在 cell 正中央:磚面高度 = (y_level + 0.5) × cell_size.y。
# 場景把 cell_size.y 設成 0.2(垂直步距變細),y_level -3 → 磚面 -0.5(和舊制一樣高);
# 河床(y_level - 1)只低 0.2 而非一整格 1 公尺——薄片磚沒有側壁,溝挖太深會看到漏空。
@export var y_level: int = -3

@export_group("地貌")
@export var grass_item: int = 13                       # 純草
@export var dirt_item: int = 3                          # 純泥
@export var blend_items: Array[int] = [0, 4, 5]         # 草泥過渡磚（斑塊邊緣）
@export var dirt_threshold: float = 0.30                # 噪聲高於此 → 泥土核心（越大泥越少）
@export var edge_threshold: float = 0.16               # 噪聲高於此 → 過渡帶
@export var grass_variation: float = 0.05              # 草地中混入少量過渡磚的機率
@export var patch_scale: float = 0.11                   # 噪聲頻率（越小斑塊越大）
@export var warp_amplitude: float = 5.0                 # 域扭曲強度：把噪聲取樣座標「揉皺」，斑塊邊緣從平滑圓弧變成蜿蜒犬牙（0 = 關閉）
@export var rng_seed: int = 20240617
@export var random_orientation: bool = false           # 隨機 Y 朝向會與法線貼圖打架，造成同種磚明暗斑駁，預設關閉

@export_group("河岸")
# 沿著溪流挖出一條「真的凹下去」的河床:河床磚鋪在低一層(y_level - 1),
# 兩側再用草泥過渡帶漸層回草地。水面(場景裡的 Stream 平面)要夾在
# 「草皮頂」和「河床頂」之間(草皮 -0.5、河床 -0.7,水目前 -0.62),
# 水才是局部最低點、不會浮在草上。
@export var bank_enabled: bool = true                   # 開關：要不要鋪河岸
@export var stream_z: float = 0.35                      # 溪流中心的世界 Z（要對齊場景裡 Stream 節點的 z）
@export var bank_core_width: float = 1.3                # 離溪流中心這距離內 → 純泥河床（大約蓋住水面下方＋兩側waterline）
@export var bank_edge_width: float = 2.6                # 這距離內 → 草泥過渡帶（河岸往草地的漸層）
@export var bank_jitter: float = 0.9                    # 岸線蜿蜒幅度：用噪聲沿 X 推擠岸線，0 = 兩條筆直平行線

# GridMap 用 0~23 的數字代表 24 種正交旋轉。這四個是繞 Y 軸 0/90/180/270 度。
const Y_ORIENT: Array[int] = [0, 22, 10, 16]           # 四個 Y 軸 90° 正交朝向

func _ready() -> void:
	_generate()   # 遊戲(或開場景)一啟動就先鋪一次地板

## ── 核心：用噪聲一格一格鋪滿整片地板 ──
func _generate() -> void:
	clear()   # 先清掉舊的格子，避免重複鋪疊

	# FastNoiseLite = 內建的「程序化雜訊」產生器。給同一個座標永遠回同一個值，
	# 而且相鄰座標的值會平滑變化 → 很適合做「成片成簇」的地貌(而非雜亂的胡椒鹽)。
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed                                # 種子相同 → 每次鋪出一模一樣的地圖
	noise.frequency = patch_scale                        # 頻率越低，斑塊越大片
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH # 用較柔順的 simplex 雜訊
	# 域扭曲(domain warp)：取樣前先用另一層噪聲把座標本身推歪。
	# 效果：斑塊邊緣從「平滑圓弧」變成「蜿蜒犬牙」——自然地貌的邊界很少是圓的。
	if warp_amplitude > 0.0:
		noise.domain_warp_enabled = true
		noise.domain_warp_amplitude = warp_amplitude     # 座標最多被推歪幾格
		noise.domain_warp_frequency = 0.1                # 推歪本身的粗細(低=大幅度慢彎)

	# 河岸線專用噪聲：沿 X 推擠岸線讓它蜿蜒。跟地貌噪聲分開，
	# 避免「泥斑塊」和「岸線」形狀連動(真實世界裡這兩件事無關)。
	var bank_noise := FastNoiseLite.new()
	bank_noise.seed = rng_seed + 77                      # 錯開種子，別跟主噪聲長一樣
	bank_noise.frequency = 0.13                          # 岸線彎的頻率(越低彎得越緩)

	# 另開一個亂數器，專門做「機率性的小變化」(過渡磚挑選、草地點綴)。
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 兩層迴圈掃過範圍內每一格 (x, z)。
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var n := noise.get_noise_2d(float(x), float(z))   # 這格的雜訊值，約 [-1, 1]
			var item := grass_item                            # 預設先當成草地

			# ── 河岸優先：離溪流夠近的格子直接鋪成河岸，蓋過一般地貌 ──
			# 沒有這段時，水面是「浮在草皮上的一條藍帶」；有了泥河床+過渡帶，
			# 水才像是切進地形裡的溪。
			var on_bank := false
			var cell_y := y_level   # 這格要鋪在哪一層(預設 = 地表層)
			if bank_enabled:
				# GridMap 的 cell 座標指的是格子「角落」，+0.5 才是格子中心的世界座標。
				var dist := absf((float(z) + 0.5) - stream_z)     # 這格中心離溪流中心多遠
				# 用噪聲沿 X 推擠岸線：同一個 x 永遠推一樣多(可重現)，相鄰 x 平滑變化(不鋸齒)。
				var wiggle := bank_noise.get_noise_2d(float(x), 0.0) * bank_jitter
				var d := dist + wiggle
				if d < bank_core_width:
					item = dirt_item                              # 河床/waterline：純泥
					on_bank = true
					# 河床鋪到下一層(低一個 cell 高度):地形「真的凹下去」,
					# 水面才能低於岸邊、成為局部最低點——換材質治標,換高度治本。
					cell_y = y_level - 1
				elif d < bank_edge_width:
					# 河岸往草地的漸層：隨機挑草泥過渡磚
					item = blend_items[rng.randi_range(0, blend_items.size() - 1)]
					on_bank = true

			# ── 不在河岸上，才走一般的噪聲地貌 ──
			if not on_bank:
				# 依雜訊高低決定這格鋪什麼：
				if n > dirt_threshold:
					item = dirt_item                              # 噪聲很高 → 泥土核心
				elif n > edge_threshold:
					# 介於兩門檻之間 → 泥土邊緣，隨機挑一塊草泥過渡磚銜接
					item = blend_items[rng.randi_range(0, blend_items.size() - 1)]
				elif rng.randf() < grass_variation:
					# 純草區裡，偶爾(機率 grass_variation)點綴一塊過渡磚，打散單調感
					item = blend_items[rng.randi_range(0, blend_items.size() - 1)]

			# 朝向：開啟時隨機選一個 90° 朝向打散重複感；關閉時固定 0(避免和法線貼圖打架)。
			var orient: int = 0
			if random_orientation:
				orient = Y_ORIENT[rng.randi_range(0, Y_ORIENT.size() - 1)]
			# 真正把這一格放上去：座標(高度用 cell_y,河床格比地表低一層)、磚 item、朝向 orient。
			set_cell_item(Vector3i(x, cell_y, z), item, orient)
