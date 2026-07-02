@tool
extends ArenaBase
# arena_frostlands.gd — 冰原牌桌(掛在 scenes/arena_frostlands.tscn 的根節點)
#
# 氣氛設定:「月夜冰湖」(參考歧路旅人的雪夜場景)。
#   ‧ 戰鬥發生在一面「圓形冰湖」上,湖緣立一圈冰晶,四周是雪地與雪松林。
#   ‧ 光影走高對比:深藍的夜色底 + 一道亮冷的月光;霧是「深藍」的——
#     遠景沉入夜色而不是被白霧洗掉(第一版整片白牆、卡槽隱形,就是霧調亮的錯)。
#   ‧ 體積霧讓月光切出可見的光柱(god rays),是參考圖裡最有記憶點的元素。
# 素材:Pixel3D Frostlands Package——OBJ 的 UV 都對到 frostland_tilesheet 總表。

const PACK := "res://assets/Pixel3D Frostlands Package"
const MODELS := PACK + "/Models"
const TILES := PACK + "/Landscape Material Tiles"

@export_group("道具數量")
@export var tree_count: int = 52         # 雪松 + 枯樹(外圈樹牆,密一點才有森林包圍感)
@export var ice_count: int = 8           # 雪地上的冰晶簇(微發光的藍色亮點)
@export var object_count: int = 12       # 倒木 / 雪堆 / 雪人等雜項
@export var foliage_count: int = 24      # 灌木 / 草 / 小石頭

@export_group("冰湖")
@export var lake_radius: float = 11.0    # 冰湖半徑(比 ring_inner 大:牌桌整個在湖上)
@export var rim_spike_count: int = 18    # 湖緣冰晶數(玩家側走廊會自動留空)
@export var god_rays: bool = true        # 體積霧光柱(太吃效能或太霧就關掉)


## ArenaBase 在 _rebuild() 時呼叫,整個冰原分五步蓋。
func _build(rng: RandomNumberGenerator) -> void:
	_build_environment()
	_build_ground()
	_build_frozen_lake()
	_build_lake_rim(rng)
	_build_props(rng)


## ── 環境與主光:深藍月夜,高對比 ───────────────────────
func _build_environment() -> void:
	var env := _make_base_environment()
	env.background_color = Color(0.05, 0.08, 0.14)     # 深藍夜空
	env.ambient_light_color = Color(0.35, 0.45, 0.65)  # 月夜藍環境光:暗部全帶藍調
	env.ambient_light_energy = 0.35
	# 霧改成「深藍」:霧色比場景亮 → 白牆;霧色比場景暗 → 遠景沉入夜色。
	# 這是第一版翻車的核心教訓:霧的顏色決定畫面是「有深度」還是「被洗白」。
	env.fog_light_color = Color(0.10, 0.16, 0.28)
	env.fog_density = 0.01
	env.fog_sky_affect = 0.8
	env.glow_intensity = 1.0                           # 亮部(月光反光、冰晶)暈開一點
	env.adjustment_contrast = 1.12                     # 對比拉高:亮更亮、暗更沉
	env.adjustment_saturation = 1.05
	if god_rays:
		# 體積霧:讓空氣本身「接得住光」,月光被樹影切開就成了光柱。
		# anisotropy(各向異性)> 0 = 光偏向「順著光線方向」散射,光柱更明顯。
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015             # 淡淡的就好,濃了又變白牆
		env.volumetric_fog_albedo = Color(0.5, 0.65, 0.9)
		env.volumetric_fog_anisotropy = 0.6
	_add_environment(env)
	# 月光:亮而冷。能量給到 2.4——底這麼暗,主光不夠力牌面會看不清;
	# 仰角壓低(-38°)讓樹拉出長影,長影切體積霧才有光柱。
	_add_sun(Color(0.75, 0.85, 1.0), 2.4, Vector3(-38.0, 35.0, 0.0))


## ── 地板:雪為底、青灰岩當斑塊 ─────────────────────────
## 斑塊從第一版的「棕色凍土」換成「青灰石板」:夜景是藍調的,
## 突然冒出暖棕色斑塊會跳色;同色系的岩板只添質感、不搶戲。
func _build_ground() -> void:
	_add_ground(
		load(TILES + "/SnowTile_01_C.png"),     # 底:積雪
		load(TILES + "/StoneTile_01_C.png"),    # 斑塊:雪薄處露出的青灰岩
		load(TILES + "/SnowTile_01_N.png"),
		load(TILES + "/StoneTile_01_N.png"),
		2.0,    # tile_size:一塊貼圖鋪 2 公尺
		0.66)   # patch_threshold:調高 → 岩斑更少,雪原為主

## ── 冰湖:戰鬥舞台本體 ─────────────────────────────────
## 一面圓形冰湖蓋在牌桌正下方(lake_radius > ring_inner,整張牌桌都在湖上)。
## 低粗糙度讓 WorldEnvironment 的 SSR 把樹影、月光映在冰面上;
## 深色的冰也讓青色卡槽有足夠對比(第一版白底上疊青色 → 隱形)。
func _build_frozen_lake() -> void:
	# 用「壓扁的圓柱」當圓形湖面:CylinderMesh 頂面是圓,radial_segments 開高就夠圓。
	var disc := CylinderMesh.new()
	disc.top_radius = lake_radius
	disc.bottom_radius = lake_radius
	disc.height = 0.04
	disc.radial_segments = 64

	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TILES + "/IceTile_01_C.png")
	m.albedo_color = Color(0.62, 0.74, 0.88)   # 乘上冷藍把亮青色冰磚壓暗:夜裡的冰不該亮
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.normal_enabled = true
	m.normal_texture = load(TILES + "/IceTile_01_N.png")
	m.roughness = 0.07   # 接近鏡面 → SSR 反射清晰,月光在冰面拉出亮帶
	m.metallic = 0.0
	# 圓柱頂面的 UV 是「radial(放射狀)」的,直接貼方形冰磚會扭成同心圓;
	# 改用 triplanar(三平面投影):忽略 mesh 自帶 UV,按「世界座標」貼圖 → 冰磚方正不變形。
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)   # triplanar 密度:0.5 = 一塊冰磚鋪 2 公尺

	var lake := MeshInstance3D.new()
	lake.name = "FrozenLake"
	lake.mesh = disc
	lake.material_override = m
	# 圓柱以「中心」定位,高 0.04 → 抬 0.021 讓頂面浮出地板 1 公分,避免 Z-fighting。
	lake.position = Vector3(center.x, 0.001, center.z)
	add_child(lake)


## ── 湖緣冰晶:沿湖邊立一圈冰刺(參考圖裡冰湖平台的邊界語彙) ──
## 不用 _scatter_meshes(那是「成簇亂撒」),這裡要的是「沿著圓周站一圈」:
## 等角分圓 + 半徑/角度抖動 → 有秩序但不機械。
func _build_lake_rim(rng: RandomNumberGenerator) -> void:
	var spikes := _load_meshes(MODELS + "/Objects",
		["SM_IceCluster_01", "SM_IceCluster_02"])
	if spikes.is_empty():
		return
	var sheet: Texture2D = load(PACK + "/Tilesheet/frostland_tilesheet.png")
	var sheet_n: Texture2D = load(PACK + "/Tilesheet/frostland_N.png")
	var ice := _make_pixel_material(sheet, sheet_n, 1.4)   # 微發光:夜裡的藍色亮點

	var root := Node3D.new()
	root.name = "LakeRim"
	add_child(root)
	for i in range(rim_spike_count):
		# 等角分圓再加抖動:純等角像鐘面刻度,抖一點才像自然凍出來的。
		var ang := TAU * float(i) / float(rim_spike_count) + rng.randf_range(-0.08, 0.08)
		var rad := lake_radius - 0.6 + rng.randf_range(-0.5, 0.5)
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)
		if p.y > clear_front_z and absf(p.x) < ring_inner:
			continue   # 玩家/相機側留空:冰晶不擋牌桌視線
		var mi := MeshInstance3D.new()
		mi.mesh = spikes[rng.randi_range(0, spikes.size() - 1)]
		mi.material_override = ice
		root.add_child(mi)
		mi.position = center * Vector3(1, 0, 1) + Vector3(p.x, 0.0, p.y)
		mi.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.8, 1.8) * prop_scale
		mi.scale = Vector3(s, s, s)
		_placed.append(p)   # 登記位置:後續散佈的樹/道具會避開冰晶


## 湖面上不長樹不擺道具(覆寫 ArenaBase 的擴充淨空判斷)。
## p 是相對 center 的 XZ 偏移,湖心就是 center → 直接比距離就好。
func _extra_clear(p: Vector2) -> bool:
	return p.length() < lake_radius + 0.5


## ── 道具:樹牆、冰晶、雜項、地被,四批散佈 ──────────────
func _build_props(rng: RandomNumberGenerator) -> void:
	var sheet: Texture2D = load(PACK + "/Tilesheet/frostland_tilesheet.png")
	var sheet_n: Texture2D = load(PACK + "/Tilesheet/frostland_N.png")
	var solid := _make_pixel_material(sheet, sheet_n)      # 一般道具
	# 冰晶用 1.4 的自發光,跟湖緣冰晶同參數 → 命中材質快取,全場冰晶共用一顆材質。
	var ice := _make_pixel_material(sheet, sheet_n, 1.4)

	# 雪松為主、枯樹點綴(枯樹名字放兩次 = 抽中機率仍低於八種雪松)。
	var trees := _load_meshes(MODELS + "/Trees", ["SM_Tree_01", "SM_Tree_01_var",
		"SM_Tree_02", "SM_Tree_02_var", "SM_Tree_03", "SM_Tree_03_var",
		"SM_Tree_04", "SM_Tree_04_var", "SM_DeadTree_01", "SM_DeadTree_01_var"])
	_scatter_meshes(rng, trees, solid, tree_count,
		14, 2.8, 0.9, 1.6, 1.3, 3.0, "Trees")

	# 冰晶簇:數量少、微發光,是雪地裡的藍色亮點。
	var ice_clusters := _load_meshes(MODELS + "/Objects",
		["SM_IceCluster_01", "SM_IceCluster_02"])
	_scatter_meshes(rng, ice_clusters, ice, ice_count,
		6, 2.0, 0.9, 1.5, 1.4, 3.0, "IceClusters")

	# 雜項:倒木、枯幹、雪堆…(雪人只放一種,抽中就是彩蛋)。
	var objects := _load_meshes(MODELS + "/Objects", ["SM_FallenTree_01",
		"SM_FallenTree_02", "SM_Trunk_01", "SM_Trunk_02", "SM_Trunk_03",
		"SM_SnowPile_01", "SM_SnowPile_02", "SM_SnowPile_03", "SM_Snowman"])
	_scatter_meshes(rng, objects, solid, object_count,
		9, 2.4, 0.9, 1.4, 1.4, 4.0, "Objects")

	# 地被:灌木、草、小石頭,最小最密,鋪滿腳邊。
	var foliage := _load_meshes(MODELS + "/Foliage", ["SM_Bush_01", "SM_Bush_02",
		"SM_Bush_03", "SM_Grass_01", "SM_Grass_02", "SM_Grass_03",
		"SM_Stone_01", "SM_Stone_02"])
	_scatter_meshes(rng, foliage, solid, foliage_count,
		14, 2.2, 0.8, 1.3, 0.6, 5.0, "Foliage")
