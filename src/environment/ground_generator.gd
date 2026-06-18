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
@export var min_x: int = -26
@export var max_x: int = 23
@export var min_z: int = -21
@export var max_z: int = 16
@export var y_level: int = -1

@export_group("地貌")
@export var grass_item: int = 13                       # 純草
@export var dirt_item: int = 3                          # 純泥
@export var blend_items: Array[int] = [0, 4, 5]         # 草泥過渡磚（斑塊邊緣）
@export var dirt_threshold: float = 0.30                # 噪聲高於此 → 泥土核心（越大泥越少）
@export var edge_threshold: float = 0.16               # 噪聲高於此 → 過渡帶
@export var grass_variation: float = 0.05              # 草地中混入少量過渡磚的機率
@export var patch_scale: float = 0.11                   # 噪聲頻率（越小斑塊越大）
@export var rng_seed: int = 20240617
@export var random_orientation: bool = false           # 隨機 Y 朝向會與法線貼圖打架，造成同種磚明暗斑駁，預設關閉

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

	# 另開一個亂數器，專門做「機率性的小變化」(過渡磚挑選、草地點綴)。
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 兩層迴圈掃過範圍內每一格 (x, z)。
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var n := noise.get_noise_2d(float(x), float(z))   # 這格的雜訊值，約 [-1, 1]
			var item := grass_item                            # 預設先當成草地
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
			var orient: int = Y_ORIENT[rng.randi_range(0, Y_ORIENT.size() - 1)] if random_orientation else 0
			# 真正把這一格放上去：座標(含高度 y_level)、要放的磚 item、朝向 orient。
			set_cell_item(Vector3i(x, y_level, z), item, orient)
