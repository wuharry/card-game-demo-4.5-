@tool
extends GridMap
# 用噪聲程序化鋪設地板：以純草為底，泥土依噪聲「成簇」分布、邊緣用草泥過渡磚銜接，
# 取代原本胡椒鹽式的隨機泥塊，看起來更自然。每格隨機 Y 朝向以打散重複感。
#
# 調整 export 後勾 regenerate 即可即時重鋪。泥土太多/太少調 dirt_threshold，
# 斑塊大小調 patch_scale（越小斑塊越大）。

@export var regenerate: bool = false:
	set(value):
		regenerate = false
		if is_inside_tree():
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

const Y_ORIENT: Array[int] = [0, 22, 10, 16]           # 四個 Y 軸 90° 正交朝向

func _ready() -> void:
	_generate()

func _generate() -> void:
	clear()

	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = patch_scale
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var n := noise.get_noise_2d(float(x), float(z))   # 約 [-1, 1]
			var item := grass_item
			if n > dirt_threshold:
				item = dirt_item
			elif n > edge_threshold:
				item = blend_items[rng.randi_range(0, blend_items.size() - 1)]
			elif rng.randf() < grass_variation:
				item = blend_items[rng.randi_range(0, blend_items.size() - 1)]

			var orient: int = Y_ORIENT[rng.randi_range(0, Y_ORIENT.size() - 1)]
			set_cell_item(Vector3i(x, y_level, z), item, orient)
