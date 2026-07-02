@tool
extends Node3D
class_name ForestScatter
# 程序化在戰場四周散佈樹木與灌木，框出 HD-2D 森林背景。
# 採「成簇」分布（先放叢集中心，再在中心附近高斯散佈），看起來像自然樹叢而非整齊排列。
# 內圈（牌桌 + 邊距）與前方（玩家/相機側）保持淨空，不擋視線、不擋桌。
#
# PSX 樹是「交叉平面 + alpha 鏤空」模型，fbx 匯入不會自動接上外部 png，
# 所以這裡在生成時程序化套上正確貼圖（alpha 裁切 + 雙面），避免變成白色硬紙板。
#
# 調整 export 後勾 regenerate 即可即時重新散佈。樹太大/浮空先調 tree_scale / y_offset。

@export var regenerate: bool = false:
	set(value):
		regenerate = false
		if is_inside_tree():
			_scatter()

@export_group("範圍")
@export var center: Vector3 = Vector3(0, 0, 0.3)   # 戰場中心
@export var ring_inner: float = 8.5                # 內圈淨空半徑（牌桌外緣 + 邊距，別小於 8）
@export var ring_outer: float = 20.0               # 外圈半徑
@export var clear_front_z: float = 6.0             # 保留 +Z（玩家側）這段不長樹

@export_group("數量與成簇")
@export var count: int = 72                         # 樹/灌木總數
@export var clusters: int = 16                      # 樹叢數量（叢集中心）
@export var cluster_radius: float = 2.6             # 每叢散開半徑（越大越鬆散）
@export var rng_seed: int = 1337

@export_group("外觀")
@export var y_offset: float = 0.0                  # 樹根貼地微調（樹浮空就調這個）
@export var tree_scale: float = 0.12               # 整體縮放（fbx 原生很大，預設已調小）
@export var scale_jitter: float = 0.35             # 大小隨機幅度
@export var bush_ratio: float = 0.25               # 灌木佔比

@export_group("自然化")
# 這組參數專門打散「程式生成感」。共同原則：真實森林裡沒有兩棵樹是一樣的，
# 但也沒有兩棵樹會長在同一個點上。
@export var min_spacing: float = 1.2               # 任兩棵的最小距離：擋掉樹幹互相穿插的「連體樹」
@export var tilt_max_deg: float = 3.0              # 隨機微傾角度：真樹很少長得筆直（別超過 5°，會像倒了）
@export var outer_bias: float = 0.65               # 半徑分布偏壓：<1 樹偏向外圈 → 遠景密成樹牆、近景稀疏有縱深
@export var far_scale_boost: float = 0.3           # 越遠的樹越大(最多 +30%)：補償透視縮小，背景牆更厚實
@export var edge_bush_bias: float = 1.8            # 叢緣灌木倍率：灌木偏好長在樹叢邊緣(林下植被的真實分布)
@export var stream_z: float = 0.35                 # 溪流中心的世界 Z（對齊場景 Stream 節點）
@export var stream_half_width: float = 1.7         # 溪流兩側各留這麼寬不長樹：樹不該站在水裡

const TREES: Array[PackedScene] = [
	preload("res://assets/environment/psx_trees/models/tree01.fbx"),
	preload("res://assets/environment/psx_trees/models/tree02.fbx"),
	preload("res://assets/environment/psx_trees/models/tree03.fbx"),
	preload("res://assets/environment/psx_trees/models/tree04.fbx"),
	preload("res://assets/environment/psx_trees/models/tree05.fbx"),
	preload("res://assets/environment/psx_trees/models/tree06.fbx"),
	preload("res://assets/environment/psx_trees/models/tree07.fbx"),
	preload("res://assets/environment/psx_trees/models/tree08.fbx"),
]
const TREE_TEX: Array[Texture2D] = [
	preload("res://assets/environment/psx_trees/textures/tree01.png"),
	preload("res://assets/environment/psx_trees/textures/tree02.png"),
	preload("res://assets/environment/psx_trees/textures/tree03.png"),
	preload("res://assets/environment/psx_trees/textures/tree04.png"),
	preload("res://assets/environment/psx_trees/textures/tree05.png"),
	preload("res://assets/environment/psx_trees/textures/tree06.png"),
	preload("res://assets/environment/psx_trees/textures/tree07.png"),
	preload("res://assets/environment/psx_trees/textures/tree08.png"),
]
const BUSHES: Array[PackedScene] = [
	preload("res://assets/environment/psx_trees/models/bush01.fbx"),
	preload("res://assets/environment/psx_trees/models/bush02.fbx"),
	preload("res://assets/environment/psx_trees/models/bush03.fbx"),
	preload("res://assets/environment/psx_trees/models/bush04.fbx"),
]
const BUSH_TEX: Array[Texture2D] = [
	preload("res://assets/environment/psx_trees/textures/bush01.png"),
	preload("res://assets/environment/psx_trees/textures/bush02.png"),
	preload("res://assets/environment/psx_trees/textures/bush03.png"),
	preload("res://assets/environment/psx_trees/textures/bush04.png"),
]

var _mat_cache: Dictionary = {}

func _ready() -> void:
	_scatter()   # 一啟動就散佈一次

## ── 核心：把樹和灌木「成簇」地散佈在戰場四周 ──
func _scatter() -> void:
	# 先清掉上一次生成的所有子節點，避免按重生成時越疊越多。
	# queue_free() = 「等這一幀結束後安全地刪除」這個節點。
	for child in get_children():
		child.queue_free()

	# 亂數器；種子固定 → 每次散佈位置都一樣(方便重現同一片森林)。
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 1) 先決定幾個「樹叢中心」。樹不是均勻撒滿，而是先選叢心、再在叢心附近群聚，
	#    這樣才像自然的樹叢，而不是整齊的行道樹。
	var centers: Array[Vector2] = []
	var radii: Array[float] = []   # 每叢自己的散開半徑：有的叢緊密、有的鬆散，比全叢同尺寸自然
	var c_attempts := 0
	# 一直嘗試直到湊滿 clusters 個叢心；c_attempts 上限是「保險絲」，避免淨空條件太嚴時無限迴圈。
	while centers.size() < clusters and c_attempts < clusters * 24:
		c_attempts += 1
		var ang := rng.randf() * TAU                                  # 隨機角度(TAU = 2π = 一整圈)
		# pow(隨機值, outer_bias)：outer_bias < 1 會把均勻分布「推向 1」→ 半徑偏外圈。
		# 效果：遠景樹密成一道牆、近景稀疏 → 有縱深，而不是整圈均勻的甜甜圈。
		var t := pow(rng.randf(), outer_bias)
		var rad: float = lerpf(ring_inner + 1.0, ring_outer, t)
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)              # 角度+半徑 → 環狀區域上的一點
		if _in_clear_zone(p):                                         # 落在淨空區(牌桌/前方/溪流)就重抽
			continue
		centers.append(p)
		radii.append(cluster_radius * rng.randf_range(0.6, 1.5))      # 這一叢專屬的鬆緊度
	if centers.is_empty():   # 一個叢心都放不下(參數設太嚴)就直接結束，不報錯
		return

	# 2) 在每個樹叢中心附近用高斯分布散出一棵棵樹/灌木。
	var placed := 0
	var attempts := 0
	var placed_pts: PackedVector2Array = []   # 已放位置，供最小間距檢查
	# 放滿 count 棵為止；attempts 上限同樣是防無限迴圈的保險絲。
	# (加了間距退件後重抽變多，上限從 16 倍放寬到 24 倍。)
	while placed < count and attempts < count * 24:
		attempts += 1
		var ci := rng.randi_range(0, centers.size() - 1)                  # 隨機挑一個叢
		var c: Vector2 = centers[ci]
		var r: float = radii[ci]                                          # 用這一叢自己的鬆緊度
		# randfn = 常態(高斯)分布：越靠近叢心機率越高、越遠越稀疏 → 自然的群聚感。
		var off := Vector2(rng.randfn(0.0, r * 0.5), rng.randfn(0.0, r * 0.5))
		var p := c + off                                                  # 叢心 + 偏移 = 這棵的最終 XZ
		if _in_clear_zone(p):                                             # 一樣避開淨空區
			continue
		if not _far_enough(p, placed_pts):                                # 跟已放的太擠 → 退件重抽
			continue

		# 決定這棵是灌木還是樹。灌木機率隨「離叢心多遠」提高：
		# 真實林相是喬木佔核心、灌木擠在林緣撿漏光——直接把這條生態規則寫進機率。
		var edge_t := clampf(off.length() / maxf(r, 0.01), 0.0, 1.0)      # 0=叢心, 1=叢緣
		var p_bush := bush_ratio * lerpf(0.5, edge_bush_bias, edge_t)
		var src: PackedScene
		var tex: Texture2D
		if rng.randf() < p_bush:
			var bi := rng.randi_range(0, BUSHES.size() - 1)
			src = BUSHES[bi]
			tex = BUSH_TEX[bi]
		else:
			var ti := rng.randi_range(0, TREES.size() - 1)
			src = TREES[ti]
			tex = TREE_TEX[ti]

		var inst := src.instantiate()                                     # 依模型藍圖實體化一棵
		add_child(inst)                                                   # 掛進場景樹才會顯示
		inst.position = center + Vector3(p.x, y_offset, p.y)              # 擺到算好的位置(y_offset 微調貼地)
		inst.rotation.y = rng.randf() * TAU                               # 隨機轉向，打散重複感
		# 隨機微傾：繞 X/Z 各歪一點點。人眼對「全部筆直」非常敏感，2~3 度就足以破掉人工感。
		inst.rotation.x = deg_to_rad(rng.randf_range(-tilt_max_deg, tilt_max_deg))
		inst.rotation.z = deg_to_rad(rng.randf_range(-tilt_max_deg, tilt_max_deg))
		# 大小在 tree_scale 上下用 scale_jitter 隨機浮動，避免每棵一模一樣。
		var s: float = tree_scale * (1.0 + rng.randf_range(-scale_jitter, scale_jitter))
		# 縱深補償：離戰場越遠加成越多(0 → far_scale_boost)。
		# 透視會把遠樹縮小，稍微放大它們，背景才會密成一道厚實的樹牆。
		var depth_range := maxf(ring_outer - ring_inner, 0.01)
		var depth_t := clampf((p.length() - ring_inner) / depth_range, 0.0, 1.0)
		s *= 1.0 + far_scale_boost * depth_t
		inst.scale = Vector3(s, s, s)
		_apply_foliage_material(inst, tex)                                # 補上正確的鏤空材質(見下方)
		placed_pts.append(p)                                              # 登記位置，給後續間距檢查
		placed += 1

## 判斷某個位置是不是「淨空區」，是的話回傳 true(該位置要跳過、不長樹)。
## p 為相對 center 的 XZ 偏移。
func _in_clear_zone(p: Vector2) -> bool:
	if p.length() < ring_inner:                       # 太靠中心(牌桌範圍內) → 淨空
		return true
	if p.y > clear_front_z and absf(p.x) < ring_inner: # 玩家/相機正前方那條走廊 → 淨空，不擋視線
		return true
	# 溪流帶：p 是「相對 center 的偏移」，加回 center.z 才是世界 Z，再跟溪流中心比。
	# 少了這條，左右兩側的樹會直接站在水裡。
	if absf((p.y + center.z) - stream_z) < stream_half_width:
		return true
	return false

## 檢查位置 p 是否跟所有已放的樹/灌木都保持 min_spacing 以上的距離。
## 用「距離平方」比較，省掉每次開根號。
## 線性掃描是 O(已放數量)：count ≈ 72，整次重生成最壞也才幾萬次比較，
## 是「編輯器按一下」的量級——不值得為它上空間網格(想過才不做)。
func _far_enough(p: Vector2, pts: PackedVector2Array) -> bool:
	var min_sq := min_spacing * min_spacing
	for q in pts:
		if p.distance_squared_to(q) < min_sq:
			return false
	return true

## 把整棵樹(可能由多個 Mesh 子節點組成)都換上鏤空材質。
## PSX 樹是「交叉平面 + alpha 鏤空」模型，fbx 匯入不會自動接外部 png，
## 不處理就會變成白色硬紙板，所以這裡程序化把貼圖接回去。
## 用遞迴(自己呼叫自己)往下走訪每一層子節點。
func _apply_foliage_material(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		# material_override = 強制這個 mesh 改用我們指定的材質(蓋過原本的)。
		(node as MeshInstance3D).material_override = _get_material(tex)
	for child in node.get_children():
		_apply_foliage_material(child, tex)   # 對每個子節點重複同樣處理

## 依貼圖建立(或取用快取的)鏤空雙面材質。
## _mat_cache：同一張貼圖只建立一次材質，重複使用 → 省效能、省記憶體。
func _get_material(tex: Texture2D) -> StandardMaterial3D:
	if _mat_cache.has(tex):           # 這張貼圖之前做過了 → 直接回傳舊的
		return _mat_cache[tex]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex                                        # 套上葉子/樹幹貼圖
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR    # alpha 鏤空：透明處直接「剪掉」不畫
	m.alpha_scissor_threshold = 0.5                              # 透明度低於 0.5 的像素視為鏤空
	m.cull_mode = BaseMaterial3D.CULL_DISABLED                   # 正反兩面都畫(交叉平面才不會缺一面)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS  # 鄰近取樣 → 保留 PSX 像素鋭利感
	_mat_cache[tex] = m               # 存進快取供下次重用
	return m
