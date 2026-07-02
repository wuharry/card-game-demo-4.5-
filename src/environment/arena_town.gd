@tool
extends ArenaBase
# arena_town.gd — 像素城鎮廣場(掛在 scenes/arena_town.tscn 的根節點)
#
# 用途:主選單的 3D 背景(「不在」牌桌輪替池裡;哪天想拿來當牌桌,
#       去 arena_pool.gd 的 ARENAS 加一行路徑就行)。
# 氣氛設定:「黃昏小鎮」。
#   ‧ 環形房屋面向中央廣場(不是亂撒:城鎮有秩序,和森林的隨機是兩種語彙)
#   ‧ 低角度橘金夕陽 + 暖暮霧
#   ‧ 窗戶會亮:tilesheet 附了現成的自發光圖(_E),黃昏窗光是本場景的記憶點
#   ‧ 廣場上有市集攤位,街燈掛暖色點光
# 素材:Pixel_3D_RPG_Town_2.0——UV 都對到 T_RPGTown_TileSheet_01(D 色/N 法線/E 發光)。

const PACK := "res://assets/Pixel_3D_RPG_Town_2.0"
const SHEET_D := PACK + "/TileSheet/T_RPGTown_TileSheet_01_D.png"
const SHEET_N := PACK + "/TileSheet/T_RPGTown_TileSheet_01_N.png"
const SHEET_E := PACK + "/TileSheet/T_RPGTown_TileSheet_01_E.png"
const TILES := PACK + "/Landscape_Material_Tiles"

@export_group("城鎮")
@export var house_count: int = 9                 # 環形房屋數
@export var house_ring_radius: float = 13.0      # 房屋圈半徑(廣場多大就看它)
@export var house_face_offset_deg: float = 0.0   # 房子若「背對」廣場,把這改成 180
@export var market_count: int = 10               # 市集攤位/木箱/酒桶
@export var object_count: int = 10               # 花圃、鐵砧等雜項
@export var foliage_count: int = 28              # 庭園灌木與草
@export var streetlight_count: int = 5           # 街燈(每盞掛一顆暖光)


func _init() -> void:
	# 城鎮不是牌桌,共同參數的預設值在這裡整組改掉:
	#   ‧ 中央只要留個廣場(5),不用牌桌的 8.5
	#   ‧ 散佈外圈收到房屋圈內(11.5),道具不會長到房子外面
	#   ‧ 不留「相機走廊」:主選單相機會繞著城鎮轉,四面八方都會被看到
	ring_inner = 5.0
	ring_outer = 11.5
	clear_front_z = 999.0   # 走廊條件永遠不成立 = 不留走廊
	rng_seed = 7777


## ArenaBase 在 _rebuild() 時呼叫,城鎮分六步蓋。
func _build(rng: RandomNumberGenerator) -> void:
	_build_environment()
	_build_ground()
	_build_house_ring(rng)
	_build_market(rng)
	_build_streetlights(rng)
	_build_foliage(rng)


## ── 環境與主光:黃昏暮色 ───────────────────────────────
func _build_environment() -> void:
	var env := _make_base_environment()
	env.background_color = Color(0.25, 0.20, 0.30)   # 暖紫暮色天
	env.ambient_light_color = Color(0.55, 0.48, 0.50)
	env.ambient_light_energy = 0.45
	env.fog_light_color = Color(0.30, 0.22, 0.24)    # 暖暮霧:遠景沉進黃昏
	env.fog_density = 0.012
	env.glow_intensity = 1.0
	env.glow_hdr_threshold = 0.9                     # 門檻降一點:窗光與街燈容易暈開
	env.adjustment_saturation = 1.15
	_add_environment(env)
	# 夕陽:低角度(-18°)橘金色,把房子拉出長影、牆面染成金黃。
	_add_sun(Color(1.0, 0.72, 0.45), 1.8, Vector3(-18.0, 55.0, 0.0))


## ── 地板:石板廣場(兩種石紋互為斑塊) ─────────────────
func _build_ground() -> void:
	_add_ground(
		load(TILES + "/T_StoneTile_01_D.png"),
		load(TILES + "/T_StoneTile_02_D.png"),
		load(TILES + "/T_StoneTile_01_N.png"),
		load(TILES + "/T_StoneTile_02_N.png"),
		2.0,     # tile_size:一塊石板鋪 2 公尺
		0.55,    # patch_threshold:兩種石紋大約 6:4
		0.04)    # patch_freq:斑塊偏大片,像分區鋪的石板


## 全場道具共用的兩顆材質(同一張 tilesheet → GPU 可合批)。
func _town_material(with_windows: bool) -> StandardMaterial3D:
	if with_windows:
		# 房屋用:接上 _E 自發光圖,窗戶在暮色裡亮起來(素材包畫好的,不用自己標)。
		return _make_pixel_material(load(SHEET_D), load(SHEET_N), 1.6, load(SHEET_E))
	return _make_pixel_material(load(SHEET_D), load(SHEET_N))


## ── 房屋圈:環形排列、正面朝向廣場 ─────────────────────
## 不用 _scatter_meshes(那是自然物的「成簇亂撒」):城鎮是人蓋的,
## 房子沿著圓周站、門面朝廣場,只在半徑/角度上留一點抖動當「手工感」。
func _build_house_ring(rng: RandomNumberGenerator) -> void:
	var houses := _load_meshes(PACK + "/Houses", ["SM_House_01", "SM_House_02",
		"SM_House_03", "SM_House_04", "SM_House_05", "SM_House_06",
		"SM_House_07", "SM_Market_01"])
	if houses.is_empty():
		return
	var mat := _town_material(true)
	var root := Node3D.new()
	root.name = "Houses"
	add_child(root)
	var plaza := center * Vector3(1, 0, 1)   # 廣場中心(貼地)
	for i in range(house_count):
		var ang := TAU * float(i) / float(house_count) + rng.randf_range(-0.06, 0.06)
		var rad := house_ring_radius + rng.randf_range(-0.8, 0.8)
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)
		var mi := MeshInstance3D.new()
		mi.mesh = houses[rng.randi_range(0, houses.size() - 1)]
		mi.material_override = mat
		root.add_child(mi)
		mi.position = plaza + Vector3(p.x, 0.0, p.y)
		# look_at:把節點的 -Z 轉向目標(這裡是廣場中心)。
		# 模型正面若不是 -Z,房子會背對廣場 → 調 house_face_offset_deg = 180 補轉。
		mi.look_at(plaza, Vector3.UP)
		mi.rotate_y(deg_to_rad(house_face_offset_deg + rng.randf_range(-6.0, 6.0)))
		mi.scale = Vector3.ONE * prop_scale
		_placed.append(p)   # 登記:廣場道具不要長進房子裡


## ── 市集:攤位、貨箱、酒桶散佈在廣場邊緣 ────────────────
func _build_market(rng: RandomNumberGenerator) -> void:
	var mat := _town_material(false)
	var stalls := _load_meshes(PACK + "/Objects", ["SM_Market_Fruitbox_01",
		"SM_Market_Fruitbox_02", "SM_Market_FishDisplay_01", "SM_Market_FishDisplay_02",
		"SM_Market_Armour_01", "SM_Market_Weapon_01", "SM_Barrel_01", "SM_Crate_01"])
	# 攤位是擺在平地上的家具:傾斜給 0(tilt 是給自然物的,歪掉的攤位像地震)。
	_scatter_meshes(rng, stalls, mat, market_count,
		6, 2.0, 0.95, 1.05, 1.4, 0.0, "Market")

	var objects := _load_meshes(PACK + "/Objects", ["SM_Garden_01", "SM_Garden_02",
		"SM_Garden_03", "SM_Anvil_01", "SM_Blacksmith_WeaponRack_01"])
	_scatter_meshes(rng, objects, mat, object_count,
		6, 2.2, 0.95, 1.05, 1.4, 0.0, "Objects")


## ── 街燈:繞廣場等角一圈,每盞掛一顆暖色點光 ────────────
func _build_streetlights(rng: RandomNumberGenerator) -> void:
	var lamps := _load_meshes(PACK + "/Objects", ["SM_StreetLight_01"])
	if lamps.is_empty():
		return
	var mat := _town_material(false)
	var root := Node3D.new()
	root.name = "StreetLights"
	add_child(root)
	var plaza := center * Vector3(1, 0, 1)
	for i in range(streetlight_count):
		var ang := TAU * (float(i) + 0.5) / float(streetlight_count)
		var p := Vector2(sin(ang), cos(ang)) * 6.3   # 站在廣場邊緣
		var mi := MeshInstance3D.new()
		mi.mesh = lamps[0]
		mi.material_override = mat
		root.add_child(mi)
		mi.position = plaza + Vector3(p.x, 0.0, p.y)
		mi.look_at(plaza, Vector3.UP)   # 燈臂朝廣場伸
		mi.rotate_y(deg_to_rad(rng.randf_range(-4.0, 4.0)))
		mi.scale = Vector3.ONE * prop_scale
		# 燈頭掛暖光:高度抓 2.6(約模型燈頭處;燈光浮空/埋地就是這個數字不對)。
		_add_omni(plaza + Vector3(p.x, 2.6, p.y), Color(1.0, 0.75, 0.45), 1.6, 6.0)
		_placed.append(p)


## ── 庭園植被:房前屋後的灌木與草 ───────────────────────
func _build_foliage(rng: RandomNumberGenerator) -> void:
	var mat := _town_material(false)
	var foliage := _load_meshes(PACK + "/Foliage", ["SM_Garden_Bush_01",
		"SM_Garden_Bush_02", "SM_Garden_Bush_03", "SM_Garden_Bush_04",
		"SM_Garden_Grass_01", "SM_Garden_Grass_02", "SM_Garden_Grass_03",
		"SM_Garden_Grass_04", "SM_Garden_Grass_05", "SM_Garden_Grass_06"])
	_scatter_meshes(rng, foliage, mat, foliage_count,
		12, 2.0, 0.9, 1.3, 0.6, 4.0, "Foliage")
