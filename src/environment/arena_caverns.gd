@tool
extends ArenaBase
# arena_caverns.gd — 洞窟牌桌(掛在 scenes/arena_caverns.tscn 的根節點)
#
# 氣氛設定:「暖棕地底」(對齊素材包官方展示圖)。三個核心語彙:
#   ‧ 包圍感:外圈用兩圈交錯的巨型鐘乳石+岩塊搭出「洞壁剪影」,
#     視線盡頭永遠是岩壁與黑暗,不是開闊地平線——這才叫地底。
#   ‧ 暖色光池:一盞大暖光罩住牌桌(像洞頂裂縫漏下的天光),
#     外圈暖橙/螢黃小光池交替,一灘一灘地落在洞裡。
#   ‧ 發光蘑菇:黃綠色螢光點綴,由 glow 暈開。
#   第一版翻車教訓:霧/環境光調成藍青色 → 整個像海底。地底的黑要「帶暖」。
# 素材:Pixel 3D Caverns Package——OBJ 的 UV 都對到 Cavern_Tilesheet_C/N 總表。

const PACK := "res://assets/Pixel 3D Caverns Package"
const OBJECTS := PACK + "/Objects/OBJ"
const FOLIAGE := PACK + "/Foliage Models/OBJ"
const TILES := PACK + "/Landscape Material Tiles"
## 混用素材:借 Frostlands 的冰晶模型當「洞穴藍水晶」(見 _build_crystals)。
const FROST_PACK := "res://assets/Pixel3D Frostlands Package"

@export_group("道具數量")
@export var stalagmite_count: int = 12   # 場內鐘乳石(中景點綴;洞壁另外蓋,見下)
@export var stone_count: int = 14        # 岩塊
@export var deadwood_count: int = 10     # 枯樹 / 樹樁
@export var glowcap_count: int = 18      # 發光蘑菇(黃綠螢光的主要來源)
@export var foliage_count: int = 70      # 地被草叢:展示圖裡草很密,量要給足

@export_group("洞壁")
@export var wall_enabled: bool = true    # 外圈洞壁剪影的開關(想省面數可關)

@export_group("洞穴氣氛")
@export var stalactite_count: int = 14   # 洞頂垂刺(倒吊鐘乳石:黑暗裡的天花板暗示)
@export var crystal_count: int = 7       # 藍水晶(混用 Frostlands 冰晶,冷暖對比)
@export var remains_count: int = 7       # 廢礦遺跡(木板/繩欄:有人來過的說故事小物)
@export var dust_motes: bool = true      # 主光池裡漂浮的塵埃粒子


## ArenaBase 在 _rebuild() 時呼叫,整個洞窟分八步蓋。
func _build(rng: RandomNumberGenerator) -> void:
	_build_environment()
	_build_ground()
	if wall_enabled:
		_build_cave_walls(rng)
	_build_stalactites(rng)
	_build_props(rng)
	_build_crystals(rng)
	_build_mood_lights(rng)
	if dust_motes:
		# 塵埃:主光池裡緩緩「上飄」的微粒——光柱裡有東西在動,空氣才是活的。
		_add_drift_particles(center * Vector3(1, 0, 1) + Vector3(0.0, 3.0, 0.0),
			Vector3(10.0, 2.5, 10.0), 90, 0.035, Color(1.0, 0.85, 0.55, 0.45),
			Vector3(0.0, 0.12, 0.0), 12.0, 0.8)


## ── 環境與主光:暖黑地底 ───────────────────────────────
func _build_environment() -> void:
	var env := _make_base_environment()
	env.background_color = Color(0.015, 0.012, 0.008)   # 近黑,帶一絲暖(不是藍黑!)
	env.ambient_light_color = Color(0.45, 0.38, 0.30)   # 暖棕環境光:暗部像被火光烘過
	env.ambient_light_energy = 0.25
	# 霧用「暖黑」:遠處沉進洞窟深處的黑暗——霧色一旦偏藍,整個場景就變海底。
	env.fog_light_color = Color(0.10, 0.07, 0.045)
	env.fog_density = 0.028                             # 濃:十幾公尺外就該看不清,包圍感
	env.fog_sky_affect = 1.0                            # 霧完全蓋掉背景色,天地融成黑
	env.glow_intensity = 1.1                            # 蘑菇螢光與光池亮部暈開
	env.glow_hdr_threshold = 0.9
	env.adjustment_contrast = 1.12                      # 高對比:光池亮、洞壁沉
	env.adjustment_saturation = 1.08
	_add_environment(env)
	# 主方向光只給一點點(0.8):它負責「讓陰影有方向」,
	# 真正照亮牌桌的是 _build_mood_lights 的主光池。
	_add_sun(Color(1.0, 0.85, 0.65), 0.8, Vector3(-55.0, 30.0, 0.0))


## ── 地板:暖泥土為底、枯草當斑塊 ───────────────────────
## 第一版用「藍灰岩」當斑塊,在冷光下整片花掉;
## 展示圖的地是暖棕泥土 + 成片枯草,同色系、只添質感不跳色。
func _build_ground() -> void:
	_add_ground(
		load(TILES + "/Caverns_Dirt_Tile_01.png"),        # 底:洞窟泥土
		load(TILES + "/Caverns_Dead_Grass_Tile_01.png"),  # 斑塊:枯草地
		load(TILES + "/Caverns_Dirt_Tile_N_01.png"),
		load(TILES + "/Caverns_Dead_Grass_Tile_N_01.png"),
		2.0,     # tile_size:一塊貼圖鋪 2 公尺
		0.52,    # patch_threshold:枯草佔比偏多,地才不單調
		0.03)    # patch_freq:比預設(0.05)低 → 斑塊更大片,不是細碎胡椒鹽


## ── 洞壁:兩圈交錯的巨型鐘乳石+岩塊,把戰場「包」進洞裡 ──
## 走「剪影」策略:壁件只求輪廓對,細節交給黑暗與濃霧(反正照不到光)。
## 不用 _scatter_meshes(那是成簇亂撒),牆要「沿著圓周站滿」:
## 等弧長分圓 + 抖動;第二圈半步錯位,補在第一圈的縫上。
func _build_cave_walls(rng: RandomNumberGenerator) -> void:
	var pieces := _load_meshes(OBJECTS, ["Cavern_Stalagmite_01", "Cavern_Stalagmite_02",
		"Cavern_Stalagmite_03", "Cavern_Stalagmite_04", "Cavern_Stalagmite_05",
		"Cavern_Stone_01", "Cavern_Stone_02", "Cavern_Stone_03"])
	if pieces.is_empty():
		return
	var sheet: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_C.png")
	var sheet_n: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_N.png")
	var mat := _make_pixel_material(sheet, sheet_n)

	var root := Node3D.new()
	root.name = "CaveWalls"
	add_child(root)
	for ring in range(2):
		var radius: float = ring_outer - 1.0 + float(ring) * 2.5   # 內圈 19、外圈 21.5
		var step := 2.6 / radius             # 弧長 2.6 公尺 ÷ 半徑 = 每件之間的弧角
		var ang := step * 0.5 * float(ring)  # 第二圈整體偏移半步 → 與第一圈交錯
		while ang < TAU:
			var a := ang + rng.randf_range(-0.02, 0.02)
			var rad := radius + rng.randf_range(-0.6, 0.6)
			var p := Vector2(sin(a) * rad, cos(a) * rad)
			ang += step
			# 相機正後方(+Z)留一道窄口:鏡頭本來就看不到,純省面數。
			if p.y > clear_front_z + 4.0 and absf(p.x) < ring_inner:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = pieces[rng.randi_range(0, pieces.size() - 1)]
			mi.material_override = mat
			root.add_child(mi)
			mi.position = center * Vector3(1, 0, 1) + Vector3(p.x, 0.0, p.y)
			mi.rotation.y = rng.randf() * TAU
			# 高度用另一個抖動:牆頂天際線才會參差,不是等高的柵欄。
			var s := rng.randf_range(3.0, 5.5) * prop_scale
			mi.scale = Vector3(s, s * rng.randf_range(1.0, 1.6), s)
			_placed.append(p)   # 登記:場內散佈的道具別長進牆裡


## ── 道具:中景點綴,由大到小四批散佈 ───────────────────
func _build_props(rng: RandomNumberGenerator) -> void:
	var sheet: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_C.png")
	var sheet_n: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_N.png")
	var solid := _make_pixel_material(sheet, sheet_n)        # 一般道具
	var glow := _make_pixel_material(sheet, sheet_n, 2.2)    # 發光蘑菇:色圖當自發光

	# 場內鐘乳石:縮小、變少(1.2~2.2 倍)——巨型的都站在洞壁上了,
	# 場內只要中景點綴,太多會跟牆搶戲。
	var stalagmites := _load_meshes(OBJECTS, ["Cavern_Stalagmite_01",
		"Cavern_Stalagmite_02", "Cavern_Stalagmite_03",
		"Cavern_Stalagmite_04", "Cavern_Stalagmite_05"])
	_scatter_meshes(rng, stalagmites, solid, stalagmite_count,
		8, 2.6, 1.2, 2.2, 1.8, 2.0, "Stalagmites")

	# 岩塊:中景填充。
	var stones := _load_meshes(OBJECTS,
		["Cavern_Stone_01", "Cavern_Stone_02", "Cavern_Stone_03"])
	_scatter_meshes(rng, stones, solid, stone_count,
		10, 2.6, 1.0, 2.0, 1.5, 3.0, "Stones")

	# 枯樹與樹樁:地底的死寂感。
	var deadwood := _load_meshes(OBJECTS,
		["Cavern_Dead_Tree_01", "Cavern_Dead_Tree_02", "Cavern_Stump_01"])
	_scatter_meshes(rng, deadwood, solid, deadwood_count,
		8, 2.4, 1.2, 1.8, 1.6, 3.0, "Deadwood")

	# 發光蘑菇:glow 材質,間距縮小讓它們一小簇一小簇地聚,像真菌。
	var glowcaps := _load_meshes(OBJECTS, ["Cavern_Glow_Cap_01",
		"Cavern_Glow_Cap_02", "Cavern_Glow_Cap_03",
		"Cavern_Glow_Cap_04", "Cavern_Mushroom_01"])
	_scatter_meshes(rng, glowcaps, glow, glowcap_count,
		9, 1.6, 0.9, 1.6, 1.0, 4.0, "GlowCaps")

	# 地被草叢:最小、最密(展示圖的地被幾乎是鋪滿的)。
	var grass := _load_meshes(FOLIAGE, ["Cavern_Grass_Foliage_01",
		"Cavern_Grass_Foliage_02", "Cavern_Grass_Foliage_03",
		"Cavern_Grass_Foliage_04", "Cavern_Grass_Foliage_05",
		"Cavern_Grass_Foliage_06", "Cavern_Grass_Foliage_07"])
	grass.append_array(_load_meshes(OBJECTS, ["Cavern_Shrub_01"]))
	_scatter_meshes(rng, grass, solid, foliage_count,
		16, 2.4, 0.8, 1.4, 0.5, 5.0, "Foliage")

	# 廢礦遺跡:木板、繩欄——「曾有人在這裡採掘」的說故事小物。
	# 傾斜給大一點(6°):廢棄的東西就該歪歪斜斜,太正像剛蓋好的。
	var remains := _load_meshes(OBJECTS, ["Cavern_Plank_01", "Cavern_Plank_02",
		"Cavern_Plank_03", "Cavern_Plank_04", "Cavern_Plank_05",
		"Cavern_Rope_Fence_01", "Cavern_Rope_Fence_02", "Cavern_Rope_Fence_03",
		"Cavern_Rope_Fence_04", "Cavern_Rope_Fence_05"])
	_scatter_meshes(rng, remains, solid, remains_count,
		5, 2.2, 0.9, 1.3, 1.6, 6.0, "MineRemains")


## ── 洞頂垂刺:鐘乳石倒過來吊在高處 ─────────────────────────
## 洞窟沒有真的天花板 mesh(蓋一整片洞頂太貴也看不清);
## 在 8.5~11 公尺高吊一圈倒刺,鏡頭上緣看到「有東西垂下來」,
## 大腦自己補完「上面是洞頂」——剪影策略,和洞壁同一招。
func _build_stalactites(rng: RandomNumberGenerator) -> void:
	if stalactite_count <= 0:
		return
	var pieces := _load_meshes(OBJECTS, ["Cavern_Stalagmite_01", "Cavern_Stalagmite_02",
		"Cavern_Stalagmite_03", "Cavern_Stalagmite_04", "Cavern_Stalagmite_05"])
	if pieces.is_empty():
		return
	var sheet: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_C.png")
	var sheet_n: Texture2D = load(PACK + "/Tilesheet/Cavern_Tilesheet_N.png")
	var mat := _make_pixel_material(sheet, sheet_n)
	var root := Node3D.new()
	root.name = "Stalactites"
	add_child(root)
	for i in range(stalactite_count):
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(9.0, ring_outer)
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)
		var mi := MeshInstance3D.new()
		mi.mesh = pieces[rng.randi_range(0, pieces.size() - 1)]
		mi.material_override = mat
		root.add_child(mi)
		# 倒吊:繞 X 轉 180°,模型的「往上長」變成「往下垂」。
		mi.rotation_degrees = Vector3(180.0, rng.randf() * 360.0, 0.0)
		var s := rng.randf_range(2.0, 3.8) * prop_scale
		mi.scale = Vector3(s, s * rng.randf_range(1.1, 1.7), s)   # 拉長:垂刺比立刺細長
		# 吊在半空,不登記 _placed:地面道具跟天上的東西不搶位置。
		mi.position = center * Vector3(1, 0, 1) + Vector3(
			p.x, rng.randf_range(8.5, 11.0), p.y)


## ── 藍水晶:混用 Frostlands 的冰晶模型(這就是跨包混搭的示範)──
## 全場都是暖橙與螢綠,缺一個「冷」的顏色收畫面;冰晶接 frostland 總表
## + 自發光 2.0,glow 一暈就是洞穴藍水晶——模型不知道自己換了個世界。
func _build_crystals(rng: RandomNumberGenerator) -> void:
	if crystal_count <= 0:
		return
	var crystals := _load_meshes(FROST_PACK + "/Models/Objects",
		["SM_IceCluster_01", "SM_IceCluster_02"])
	if crystals.is_empty():
		return
	var sheet: Texture2D = load(FROST_PACK + "/Tilesheet/frostland_tilesheet.png")
	var sheet_n: Texture2D = load(FROST_PACK + "/Tilesheet/frostland_N.png")
	var mat := _make_pixel_material(sheet, sheet_n, 2.0)
	_scatter_meshes(rng, crystals, mat, crystal_count,
		5, 2.0, 1.0, 1.9, 2.2, 2.0, "Crystals")


## ── 光池:展示圖的靈魂——暖光一灘一灘地落在洞裡 ────────
func _build_mood_lights(rng: RandomNumberGenerator) -> void:
	# 1) 主光池:大範圍暖光罩住整個牌桌區,像洞頂裂縫漏下的天光。
	#    牌面的可讀性主要靠它(方向光只有 0.8,故意不夠)。
	_add_omni(center * Vector3(1, 0, 1) + Vector3(0.0, 6.5, 0.0),
		Color(1.0, 0.78, 0.50), 2.6, 20.0)
	# 2) 外圈小光池:暖橙(火光)與螢光黃綠(菌光)交替,
	#    對應展示圖裡一灘橙、一灘綠的光斑節奏。
	var light_count := 6
	for i in range(light_count):
		# (i + 0.5) / n:等角分布偏移半格,避免第一顆正好落在玩家正前方。
		var ang := TAU * (float(i) + 0.5) / float(light_count)
		var rad := 11.0 + rng.randf_range(-1.0, 2.0)
		var pos := Vector2(sin(ang), cos(ang)) * rad
		if _in_clear_zone(pos):   # 落在淨空區(正前方走廊)的直接跳過
			continue
		var col := Color(1.0, 0.62, 0.30) if i % 2 == 0 else Color(0.80, 0.90, 0.40)
		_add_omni(Vector3(pos.x, 1.2, pos.y) + center * Vector3(1, 0, 1), col, 1.3, 7.0)
