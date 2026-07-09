@tool
extends Node3D
class_name ArenaBase
# arena_base.gd — 程式生成牌桌場景的「共用底盤」(Caverns / Frostlands 都繼承它)
#
# 職責:提供地板、道具散佈、燈光、環境的共用工具函式與共同參數;
# 每個場景自己的長相(用哪些模型、什麼顏色的霧)由子類別在 _build() 裡決定。
#
# 為什麼用「繼承」而不是每個場景各寫一份?
#   兩個場景 80% 的邏輯相同(清場、散佈數學、材質快取、淨空區),
#   複製兩份之後修 bug 要修兩處,遲早漏一處。共用的放這裡,個性放子類。
#
# ⚠ 生成的節點「不會」存進 .tscn:add_child 時沒設 owner,編輯器存檔就不落盤。
#   跟 forest_scatter 同一套哲學——場景檔保持極薄,內容每次由 code 重建。

# Inspector 裡的「重新生成」按鈕:勾下去立刻打回 false 並重蓋整個場景。
@export var regenerate: bool = false:
	set(value):
		regenerate = false
		if is_inside_tree():
			_rebuild()

@export_group("範圍")
@export var center: Vector3 = Vector3(0, 0, 0.3)   # 戰場中心(對齊牌桌,與 forest 相同)
@export var ring_inner: float = 8.5                # 內圈淨空半徑(牌桌 + 邊距)
@export var ring_outer: float = 20.0               # 道具散佈的外圈半徑
@export var clear_front_z: float = 6.0             # +Z(玩家/相機側)走廊保持淨空
@export var rng_seed: int = 9000                   # 亂數種子(同種子 = 同一張場景)
@export var prop_scale: float = 1.0               # 所有道具的整體縮放(模型天生太大/小就調這)

# 共用的地板混合 shader(雙貼圖 + 噪聲斑塊,詳見該檔註解)。
const GROUND_SHADER: Shader = preload("res://assets/environment/arena_ground.gdshader")

# 材質快取:同一組貼圖只建一次材質。幾百個 MeshInstance 共用同幾顆材質,
# GPU 也能合批(同材質的物件可以一起畫),省效能。
var _mat_cache: Dictionary = {}
# 本輪已放置的道具位置(XZ)。跨「多次」_scatter_meshes 呼叫共用,
# 讓「石頭別疊在蘑菇上」這種跨批次的間距也成立。
var _placed: PackedVector2Array = []
# 環境粒子共用的小圓點貼圖(懶生成,見 _make_dot_texture)。
var _dot_tex: GradientTexture2D = null


func _ready() -> void:
	_rebuild()


## 清掉上次生成的所有子節點,從零重蓋一次整個場景。
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()   # queue_free = 幀尾安全刪除
	_mat_cache.clear()
	_placed.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_build(rng)


## 【子類別必須覆寫】場景的實際內容(環境、燈、地板、道具)在這裡蓋。
func _build(_rng: RandomNumberGenerator) -> void:
	push_warning("ArenaBase._build() 沒有被覆寫:這個場景不會有任何內容")


# ══════════════════════════════════════════════════════
#  環境與燈光
# ══════════════════════════════════════════════════════

## 造一份「共同底子」的 Environment:ACES 色調映射 + SSAO + SSR + 霧 + glow,
## 規格對齊 arena_forest.tscn 的 WorldEnvironment,
## 子類別拿到後再調成自己的氣氛(背景色、霧色、glow 強度…)。
func _make_base_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR           # 用純色當天空(有霧遮著看不出來)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES      # 電影感的色調映射,亮部不易死白
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ssao_enabled = true                              # 縫隙處環境光遮蔽:接縫更「咬」得住地面
	env.ssao_intensity = 1.5
	env.ssao_power = 1.5
	env.ssr_enabled = true                               # 螢幕空間反射:水面/冰面會映出場景
	env.ssr_max_steps = 48
	env.fog_enabled = true                               # 霧:把遠景收掉,框出舞台感
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.5
	env.glow_enabled = true                              # 泛光:超過門檻的亮部往外暈
	env.glow_normalized = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true                        # 最後的調色:對比與飽和微加
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	return env


## 把 Environment 掛上場(WorldEnvironment 節點)。
func _add_environment(env: Environment) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


## 主光:一盞帶陰影的 DirectionalLight3D(規格對齊 forest 的暖陽,顏色角度由子類決定)。
func _add_sun(color: Color, energy: float, rot_deg: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = color
	sun.light_energy = energy
	sun.rotation_degrees = rot_deg
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.9
	sun.light_angular_distance = 1.5   # 給光源一點角直徑 → 陰影邊緣自然變軟
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)


## 氣氛點光(蘑菇螢光、火把光暈…)。
func _add_omni(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	# 氣氛光不開陰影:一顆有陰影的點光 ≈ 多六次深度繪製,氣氛光用不著這成本。
	light.shadow_enabled = false
	add_child(light)


# ══════════════════════════════════════════════════════
#  環境粒子(雪花、塵埃、孢子)
# ══════════════════════════════════════════════════════

## 粒子用的小圓點貼圖:程式生一張「中心白、邊緣透明」的放射漸層。
## 雪花/塵埃在畫面上只有幾個像素,一顆漸層圓就夠,不必進美術資源。
func _make_dot_texture() -> GradientTexture2D:
	if _dot_tex != null:
		return _dot_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_dot_tex = GradientTexture2D.new()
	_dot_tex.gradient = grad
	_dot_tex.fill = GradientTexture2D.FILL_RADIAL
	_dot_tex.fill_from = Vector2(0.5, 0.5)
	_dot_tex.fill_to = Vector2(0.5, 0.0)
	_dot_tex.width = 32
	_dot_tex.height = 32
	return _dot_tex


## 環境粒子:在盒形區域內持續飄動的小點(雪花往下、塵埃上飄,方向由 velocity 給)。
## GPUParticles3D 在 GPU 上模擬,幾百顆對效能無感;preprocess = lifetime 讓粒子
## 「開場就已經飄滿」,不會出現前十幾秒空場等雪下的空窗。velocity 不可為零向量。
func _add_drift_particles(pos: Vector3, extents: Vector3, amount: int, size: float,
		color: Color, velocity: Vector3, lifetime: float, turbulence: float = 0.0) -> void:
	var p := GPUParticles3D.new()
	p.name = "DriftParticles"
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = velocity.normalized()
	pm.spread = 12.0                                   # 方向帶一點發散,不是列隊直落
	pm.initial_velocity_min = velocity.length() * 0.7  # 快慢不一:自然的雪不等速
	pm.initial_velocity_max = velocity.length() * 1.3
	pm.gravity = Vector3.ZERO   # 速度自己給、不吃重力(塵埃甚至要往上飄)
	if turbulence > 0.0:
		pm.turbulence_enabled = true                   # 亂流:路徑蛇行,不是直線
		pm.turbulence_noise_strength = turbulence
		pm.turbulence_influence_min = 0.04
		pm.turbulence_influence_max = 0.12
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 不受光:自帶亮度的小點
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES   # 每顆粒子面向鏡頭
	m.albedo_color = color
	m.albedo_texture = _make_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	p.position = pos
	# 可視包圍盒要涵蓋「生成盒 + 整段飄行距離」:
	# 太小的話鏡頭一轉,引擎以為粒子不在視野內,整批剔除、雪憑空消失。
	var travel := velocity * lifetime
	var lo := -extents - Vector3(2, 2, 2)
	lo += Vector3(minf(travel.x, 0.0), minf(travel.y, 0.0), minf(travel.z, 0.0))
	var hi := extents + Vector3(2, 2, 2)
	hi += Vector3(maxf(travel.x, 0.0), maxf(travel.y, 0.0), maxf(travel.z, 0.0))
	p.visibility_aabb = AABB(lo, hi - lo)
	add_child(p)


# ══════════════════════════════════════════════════════
#  地板
# ══════════════════════════════════════════════════════

## 地板:一大片 PlaneMesh + 雙貼圖斑塊混合 shader。
## 預設尺寸與位置對齊 arena_forest 的 GridMap 覆蓋範圍,三個場景舞台大小一致;
## 要在更遠處擺遠景物(雪丘 landmass)的場景可傳更大的 size,別讓遠景踩出地板外。
func _add_ground(tex_base: Texture2D, tex_patch: Texture2D,
		normal_base: Texture2D, normal_patch: Texture2D,
		tile_size: float, patch_threshold: float,
		patch_freq: float = 0.05, size: Vector2 = Vector2(52.0, 40.0)) -> void:
	var plane := PlaneMesh.new()
	plane.size = size

	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("tex_base", tex_base)
	mat.set_shader_parameter("tex_patch", tex_patch)
	mat.set_shader_parameter("normal_base", normal_base)
	mat.set_shader_parameter("normal_patch", normal_patch)
	mat.set_shader_parameter("tile_size", tile_size)
	mat.set_shader_parameter("patch_threshold", patch_threshold)
	mat.set_shader_parameter("patch_scale", patch_freq)   # 斑塊噪聲頻率(越小斑塊越大片)
	# 斑塊遮罩:程式生一張無縫噪聲圖餵給 shader
	# (角色等同 ground_generator 裡決定草/泥分布的 FastNoiseLite)。
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = 0.05
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true   # 無縫:平鋪時接縫處不會出現一條線
	noise_tex.noise = noise
	mat.set_shader_parameter("mask_noise", noise_tex)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	ground.position = Vector3(-1.0, 0.0, -2.0)   # 平移到與 forest GridMap 相同的覆蓋中心
	add_child(ground)


# ══════════════════════════════════════════════════════
#  模型載入與材質
# ══════════════════════════════════════════════════════

## 批次載入 OBJ 模型。.obj 匯入 Godot 後是「Mesh 資源」(不是場景),
## 所以之後用 MeshInstance3D 來擺,而不是 instantiate()。
## 用 load() 而非 preload():preload 在「解析腳本時」就要檔案存在,素材一缺整支腳本
## 掛掉;load() 在執行期才找,缺了只警告、其他道具照常生。
func _load_meshes(dir: String, names: Array[String]) -> Array[Mesh]:
	var out: Array[Mesh] = []
	for n in names:
		var path := dir.path_join(n + ".obj")
		if not ResourceLoader.exists(path):
			push_warning("找不到模型:" + path)
			continue
		out.append(load(path))
	return out


## 造像素風材質:albedo 接素材包的 tilesheet 總表。
## 這些 OBJ 的 MTL 檔裡「沒有」貼圖引用(素材包就這樣出的),匯進來是灰白色;
## 但模型的 UV 都對好 tilesheet 了,所以只要把總表接上 albedo 就會顯色——
## 和 forest_scatter 幫 PSX 樹補材質是同一招。
## emission_boost > 0:啟用自發光——
##   ‧ 有給 emission_tex(素材包附的 _E 自發光圖,例:城鎮的窗戶)就用它,
##     只有圖上標亮的部位會發光;
##   ‧ 沒給就拿色圖充當(顏色亮的部位發光,給發光蘑菇/冰晶這種「整朵亮」的用)。
## 夠亮的部分會超過 glow_hdr_threshold,被 WorldEnvironment 的 glow 暈開。
func _make_pixel_material(albedo: Texture2D, normal: Texture2D = null,
		emission_boost: float = 0.0, emission_tex: Texture2D = null) -> StandardMaterial3D:
	var normal_key := normal.resource_path if normal != null else "-"
	var emission_key := emission_tex.resource_path if emission_tex != null else "-"
	var key := "%s|%s|%.2f|%s" % [albedo.resource_path, normal_key,
		emission_boost, emission_key]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	# NEAREST 取樣:保住像素風的銳利格子;帶 mipmap 避免遠處摩爾紋。
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
	if emission_boost > 0.0:
		m.emission_enabled = true
		m.emission_texture = emission_tex if emission_tex != null else albedo
		m.emission_energy_multiplier = emission_boost
	_mat_cache[key] = m
	return m


# ══════════════════════════════════════════════════════
#  道具散佈
# ══════════════════════════════════════════════════════

## 核心:把一組 Mesh「成簇」散佈在戰場外圈。
## 數學與 forest_scatter.gd 的 _scatter() 同源(叢心 + 高斯散佈 + 淨空區 + 最小間距),
## 詳細推導請看那支檔案的註解;差異只有兩點:
##   ① 擺的是 MeshInstance3D(OBJ 是 Mesh 資源,FBX 才是場景)
##   ② _placed 名單跨批次共用(石頭、蘑菇、樹彼此也保持距離)
func _scatter_meshes(rng: RandomNumberGenerator, meshes: Array[Mesh], mat: Material,
		count: int, clusters: int, cluster_radius: float,
		scale_min: float, scale_max: float, min_spacing: float = 1.2,
		tilt_deg: float = 3.0, group_label: String = "Props") -> void:
	if meshes.is_empty():
		return
	var root := Node3D.new()   # 一批道具一個容器節點,執行時的場景樹裡好辨認
	root.name = group_label
	add_child(root)

	# 1) 叢心:一直抽到湊滿為止,上限是防呆保險絲(淨空條件太嚴時不無限迴圈)。
	var centers: Array[Vector2] = []
	var c_attempts := 0
	while centers.size() < clusters and c_attempts < clusters * 24:
		c_attempts += 1
		var ang := rng.randf() * TAU
		var rad := lerpf(ring_inner + 1.0, ring_outer, rng.randf())
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)
		if _in_clear_zone(p):
			continue
		centers.append(p)
	if centers.is_empty():
		return

	# 2) 沿叢心高斯散佈,通過「淨空 + 間距」檢查才真的放。
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 24:
		attempts += 1
		var c: Vector2 = centers[rng.randi_range(0, centers.size() - 1)]
		var off := Vector2(rng.randfn(0.0, cluster_radius * 0.5),
			rng.randfn(0.0, cluster_radius * 0.5))
		var p := c + off
		if _in_clear_zone(p) or not _far_enough(p, min_spacing):
			continue

		var mi := MeshInstance3D.new()
		mi.mesh = meshes[rng.randi_range(0, meshes.size() - 1)]
		mi.material_override = mat   # 蓋掉 OBJ 自帶的灰白材質(MTL 沒接貼圖)
		root.add_child(mi)
		# center 只取 XZ(乘 (1,0,1) 把 Y 歸零):道具的腳要貼地,不跟牌桌抬高。
		mi.position = center * Vector3(1, 0, 1) + Vector3(p.x, 0.0, p.y)
		mi.rotation.y = rng.randf() * TAU                                # 隨機朝向
		mi.rotation.x = deg_to_rad(rng.randf_range(-tilt_deg, tilt_deg)) # 微傾,破機械感
		mi.rotation.z = deg_to_rad(rng.randf_range(-tilt_deg, tilt_deg))
		var s := rng.randf_range(scale_min, scale_max) * prop_scale
		mi.scale = Vector3(s, s, s)
		_placed.append(p)
		placed += 1


## 淨空區:牌桌圓 + 玩家側走廊 + 子類別的加碼區。p 為相對 center 的 XZ 偏移。
func _in_clear_zone(p: Vector2) -> bool:
	if p.length() < ring_inner:                          # 牌桌範圍內
		return true
	if p.y > clear_front_z and absf(p.x) < ring_inner:   # 相機正前方的走廊
		return true
	return _extra_clear(p)


## 【子類別可覆寫】額外的淨空判斷(例:冰原的結冰河帶)。預設沒有。
func _extra_clear(_p: Vector2) -> bool:
	return false


## 最小間距檢查(量級估算見 forest_scatter.gd 的 _far_enough 註解:
## 每次重生成最壞也才幾萬次比較,不值得上空間網格)。
func _far_enough(p: Vector2, min_spacing: float) -> bool:
	var min_sq := min_spacing * min_spacing
	for q in _placed:
		if p.distance_squared_to(q) < min_sq:
			return false
	return true
