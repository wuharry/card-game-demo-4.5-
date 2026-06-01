@tool

extends Node3D
class_name PlayerHand

@export var card_scene: PackedScene = preload("res://src/card/card.tscn")

@export var hand_size: int = 5
@export var fan_radius: float = 7.0             # 扇形圓弧半徑，數值越大弧線越平緩
@export var max_fan_spread_degrees: float = 25.0 # 手牌滿時允許的最大總張開角度（上限）
@export var card_angle_gap: float = 6.0          # 相鄰兩張牌之間的固定角度間距（爐石風格核心）
@export var card_tilt_x: float = 55.0            # 卡片向攝影機傾斜的角度
@export var card_uniform_scale: float = 0.3      # 手牌的統一縮放比例

var cards: Array[Node3D] = []

# PlayerHand 自己的中繼信號：當任何一張手牌被 hover/unhover，就向外廣播
# 這樣 CardManager 只需要訂閱 PlayerHand，不用讓 PlayerHand 直接戳 CardManager 的內部方法
signal card_hovered(card: Card)
signal card_unhovered(card: Card)

func _ready() -> void:
	draw_starting_hand(hand_size)

func draw_starting_hand(count: int) -> void:
	for i in range(count):
		var card: Card = card_scene.instantiate()
		card.scale = Vector3.ONE * card_uniform_scale
		add_child(card)
		cards.append(card)
		# 用 lambda（匿名函式）把單張牌的信號，轉發給 PlayerHand 自己的中繼信號
		# 這樣外部（CardManager）只需要連接 PlayerHand，不需要知道每張牌的存在
		card.card_hovered.connect(func(c: Card) -> void: card_hovered.emit(c))
		card.card_unhovered.connect(func(c: Card) -> void: card_unhovered.emit(c))
	_arrange_fan()

# 供 CardManager 呼叫，讓手牌平滑地重新排列
func organize_hand() -> void:
	_arrange_fan()

func _arrange_fan() -> void:
	var count := cards.size()
	if count == 0:
		return

	# 手牌的「中心索引」，用來讓整排牌對稱於中央
	# 例如 5 張牌：center_i = 2.0，索引 0~4 對稱於索引 2
	var center_i := (count - 1) / 2.0

	# ── 爐石風格：動態計算本次實際使用的總張角 ──────────────────────
	# 牌多 → 間距累計大 → 撐開；牌少 → 間距累計小 → 自動往中央靠攏
	# min() 確保就算牌很多，總角度也不會超過設定的上限
	var actual_spread_degrees: float
	if count == 1:
		actual_spread_degrees = 0.0   # 只剩一張牌時放正中央，不需要展開
	else:
		# 相鄰固定間距 × 牌間隙數 = 本次所需總角度，但不超過最大上限
		actual_spread_degrees = min(card_angle_gap * (count - 1), max_fan_spread_degrees)

	# 將總角度的一半轉成弧度，後面三角函數需要弧度單位
	var half_rad := deg_to_rad(actual_spread_degrees / 2.0)

	for i in range(count):
		# t：代表這張牌在扇形中的「相對位置比例」
		# 最左邊的牌 t = -1.0，正中央 t = 0.0，最右邊 t = +1.0
		# 用 center_i 當分母（而非 max(center_i,1)），確保最外側牌永遠精確落在 ±half_rad
		# count==1 時 center_i=0 會除以零，所以單獨給 0.0
		var t: float = (i - center_i) / center_i if count > 1 else 0.0

		# 將比例 t 乘以半角弧度，得到這張牌實際的角度偏移
		var angle_rad := t * half_rad

		# 根據角度計算圓弧上的目標位置（PlayerHand Local Space）
		# sin(angle) → 水平（左右）分量，讓牌左右對稱展開
		# cos(angle) - 1 → 垂直分量，讓兩側牌自然往下彎，形成弧形手感
		var target_pos := Vector3(
			fan_radius * sin(angle_rad),
			fan_radius * (cos(angle_rad) - 1.0),
			0.0
		)

		# Z 軸旋轉角度等於弧度偏移的負值，讓牌沿著圓弧切線方向傾斜
		var target_rot := Vector3(card_tilt_x, 0.0, -rad_to_deg(angle_rad))

		# 用 Tween 平滑地將牌移到新位置，出牌後重排會有流暢的動畫
		# set_parallel(true) 讓位置、旋轉、縮放三個動畫同時播放
		var tw := cards[i].create_tween().set_parallel(true)
		tw.tween_property(cards[i], "position", target_pos, 0.2)                      # 0.2 秒移到新位置
		tw.tween_property(cards[i], "rotation_degrees", target_rot, 0.2)              # 同步旋轉到新角度
		tw.tween_property(cards[i], "scale", Vector3.ONE * card_uniform_scale, 0.2)   # 確保縮放回到標準值
