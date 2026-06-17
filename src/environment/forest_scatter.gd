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
	_scatter()

func _scatter() -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 1) 先在環狀區域放「樹叢中心」（避開內圈與前方）
	var centers: Array[Vector2] = []
	var c_attempts := 0
	while centers.size() < clusters and c_attempts < clusters * 24:
		c_attempts += 1
		var ang := rng.randf() * TAU
		var rad: float = lerpf(ring_inner + 1.0, ring_outer, rng.randf())
		var p := Vector2(sin(ang) * rad, cos(ang) * rad)
		if _in_clear_zone(p):
			continue
		centers.append(p)
	if centers.is_empty():
		return

	# 2) 在每個樹叢中心附近高斯散佈樹/灌木
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 16:
		attempts += 1
		var c: Vector2 = centers[rng.randi_range(0, centers.size() - 1)]
		var off := Vector2(rng.randfn(0.0, cluster_radius * 0.5), rng.randfn(0.0, cluster_radius * 0.5))
		var p := c + off
		if _in_clear_zone(p):
			continue

		var src: PackedScene
		var tex: Texture2D
		if rng.randf() < bush_ratio:
			var bi := rng.randi_range(0, BUSHES.size() - 1)
			src = BUSHES[bi]
			tex = BUSH_TEX[bi]
		else:
			var ti := rng.randi_range(0, TREES.size() - 1)
			src = TREES[ti]
			tex = TREE_TEX[ti]

		var inst := src.instantiate()
		add_child(inst)
		inst.position = center + Vector3(p.x, y_offset, p.y)
		inst.rotation.y = rng.randf() * TAU
		var s: float = tree_scale * (1.0 + rng.randf_range(-scale_jitter, scale_jitter))
		inst.scale = Vector3(s, s, s)
		_apply_foliage_material(inst, tex)
		placed += 1

# 內圈（牌桌）與前方（玩家側）視為淨空區，回傳 true 表示該位置要跳過
# p 為相對 center 的 XZ 偏移
func _in_clear_zone(p: Vector2) -> bool:
	if p.length() < ring_inner:
		return true
	if p.y > clear_front_z and absf(p.x) < ring_inner:
		return true
	return false

# 套上 alpha 鏤空 + 雙面材質，把貼圖接回去（修白色硬紙板問題）
func _apply_foliage_material(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _get_material(tex)
	for child in node.get_children():
		_apply_foliage_material(child, tex)

func _get_material(tex: Texture2D) -> StandardMaterial3D:
	if _mat_cache.has(tex):
		return _mat_cache[tex]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mat_cache[tex] = m
	return m
