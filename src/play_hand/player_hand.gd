## player_hand.gd — 玩家手牌(把卡片排成爐石風格的扇形)
##
## 掛在 main.tscn 的 PlayerHand (Node3D) 節點上。
## 負責：① 一開始發 N 張起手牌 ② 把手牌排成圓弧扇形 ③ 出牌後重新靠攏。
## 它也是 hover 信號的「中繼站」：每張卡的 hover 信號先傳到這裡，再統一往上轉給 CardManager。

@tool  # 讓這支腳本在「編輯器裡」也會跑，方便你不用按播放就能預覽扇形排列。

extends Node3D
class_name PlayerHand

## ── 可在 Inspector 調整的參數(@export)──────────────
## @export 變數會出現在右側 Inspector 面板，可直接拖拉數值即時調整，不必改程式。
## card_scene：手牌要生成的卡片藍圖。preload() = 在遊戲啟動前就先把這個場景檔載入備用。
@export var card_scene: PackedScene = preload("res://src/card/card.tscn")

@export var hand_size: int = 5                   # 起手牌張數(對應 Inspector「Hand Size」)
@export var fan_radius: float = 7.0              # 扇形圓弧半徑，越大弧線越平緩
@export var max_fan_spread_degrees: float = 32.0 # 手牌滿時允許的「最大」總張開角度(上限)
@export var card_angle_gap: float = 8.0          # 相鄰兩張牌之間的固定角度間距(爐石風格核心)
@export var card_tilt_x: float = 55.0            # 卡片往攝影機方向傾斜的角度
@export var card_uniform_scale: float = 0.6      # 手牌統一縮放比例(手牌看起來多大)

## 用一個陣列記住目前手上有哪些卡。出牌時會從這個陣列移除。
var cards: Array[Node3D] = []

## 卡池:data/cards/ 底下所有 .tres 載進來的 CardData(第一次發牌時才載,見下)。
var _card_pool: Array[CardData] = []

## ── 中繼信號 ──────────────────────────────────
## 為什麼要中繼？因為手牌數量會一直變(抽牌/出牌)，
## 若 CardManager 要直接連接每一張卡會很麻煩。改成：每張卡 → PlayerHand → CardManager，
## CardManager 只要訂閱 PlayerHand 這「一個」來源就好。
signal card_hovered(card: Card)
signal card_unhovered(card: Card)


func _ready() -> void:
	# 遊戲一開始就發起手牌。
	draw_starting_hand(hand_size)


## 發 count 張牌到手上。
func draw_starting_hand(count: int) -> void:
	# 卡池是「懶載入」:第一次要發牌才去載,而不是 _ready 就載
	# (這支是 @tool 腳本,編輯器裡也會跑;懶載入讓載入失敗的影響縮到最小)。
	if _card_pool.is_empty():
		_load_card_pool()
	for i in range(count):
		# 依藍圖實體化一張卡。
		var card: Card = card_scene.instantiate()
		# 先把卡縮到手牌大小。Vector3.ONE × 0.6 = (0.6, 0.6, 0.6)。
		card.scale = Vector3.ONE * card_uniform_scale
		add_child(card)        # 掛進場景樹才會顯示
		cards.append(card)     # 記進手牌陣列
		# 從卡池隨機抽一份資料餵給這張卡:名字/費用/攻血/卡圖立刻換成該卡的。
		# (正式的「牌堆抽牌不重複」之後做在 Deck;現在先隨機,驗證資料流打通。)
		if not _card_pool.is_empty():
			card.setup(_card_pool.pick_random())

		# 把每張卡的 hover 信號「轉發」成 PlayerHand 自己的信號。
		# func(c): ... 是「匿名函式(lambda)」：收到卡的信號時，立刻用自己的名義再發一次。
		card.card_hovered.connect(func(c: Card) -> void: card_hovered.emit(c))
		card.card_unhovered.connect(func(c: Card) -> void: card_unhovered.emit(c))
	# 全部發完後排成扇形。
	_arrange_fan()


## 把 data/cards/ 底下所有 .tres 載進卡池。
## 用 DirAccess 掃資料夾而不是寫死 24 個 preload:之後加新卡 = 丟一個新 .tres
## 進資料夾就完事,這支程式一行都不用動(資料變、程式不變)。
func _load_card_pool() -> void:
	_card_pool.clear()
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		push_warning("找不到卡池資料夾 res://data/cards,手牌會是空白佔位卡")
		return
	for f in dir.get_files():
		# 匯出成正式版時,檔名清單裡可能是 xxx.tres.remap(Godot 的匯出重映射),
		# 把 .remap 後綴剝掉再載入,編輯器/正式版兩邊都通。
		var file_name := f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			_card_pool.append(load("res://data/cards/" + file_name))


## 供 CardManager 在出牌後呼叫，讓剩下的手牌平滑靠攏重排。
func organize_hand() -> void:
	_arrange_fan()


## 出牌：把這張牌移出手牌並重新靠攏。由 CardManager 在成功入槽後呼叫，
## 讓「移除 + 重排」封裝在手牌自己身上，外部不必直接操作 cards 陣列。
func play_card(card: Node3D) -> void:
	cards.erase(card)
	_arrange_fan()


## ── 核心：把 cards 陣列裡的牌排成圓弧扇形 ──────────
## 開頭底線 _ 代表這是內部函式。
func _arrange_fan() -> void:
	var count := cards.size()
	# 沒有牌就不用排，直接結束。
	if count == 0:
		return

	# 「中心索引」：用來讓整排牌對稱於正中央。
	# 例如 5 張(索引0~4)，center_i = 2.0，索引2正好是中間。
	var center_i := (count - 1) / 2.0

	# ── 動態總張角：牌多就撐開、牌少就靠攏，但不超過上限 ──
	var actual_spread_degrees: float
	if count == 1:
		actual_spread_degrees = 0.0   # 只有一張就放正中間，不展開
	else:
		# 相鄰間距 × 間隙數 = 需要的總角度；min() 確保不超過設定上限。
		actual_spread_degrees = min(card_angle_gap * (count - 1), max_fan_spread_degrees)

	# 三角函數要用「弧度」，所以把(總角度的一半)從度數轉成弧度。
	var half_rad := deg_to_rad(actual_spread_degrees / 2.0)

	for i in range(count):
		# t：這張牌在扇形中的相對位置比例。最左 = -1、正中 = 0、最右 = +1。
		# count==1 時 center_i=0 會除以零，所以單獨給 0.0。
		var t: float = (i - center_i) / center_i if count > 1 else 0.0

		# 比例 × 半角 = 這張牌實際的角度偏移(弧度)。
		var angle_rad := t * half_rad

		# 用 sin / cos 把「角度」換算成圓弧上的「座標」(PlayerHand 的本地座標)。
		#   sin(角度) → 左右分量：讓牌左右對稱展開
		#   cos(角度)-1 → 上下分量：讓兩側的牌自然往下垂，形成弧度
		var target_pos := Vector3(
			fan_radius * sin(angle_rad),
			fan_radius * (cos(angle_rad) - 1.0),
			0.0
		)

		# 讓牌沿著圓弧切線方向稍微歪頭：Z 軸轉角 = 角度偏移的負值。
		# X 軸固定傾斜 card_tilt_x 度(讓牌面朝向攝影機)。
		var target_rot := Vector3(card_tilt_x, 0.0, -rad_to_deg(angle_rad))

		# 用 Tween 平滑移動到新位置，所以出牌後重排會有流暢的滑動動畫。
		# set_parallel(true) 讓位置、旋轉、縮放三個動畫「同時」進行。
		var tw := cards[i].create_tween().set_parallel(true)
		tw.tween_property(cards[i], "position", target_pos, 0.2)                      # 0.2 秒移到定位
		tw.tween_property(cards[i], "rotation_degrees", target_rot, 0.2)              # 同步轉到目標角度
		tw.tween_property(cards[i], "scale", Vector3.ONE * card_uniform_scale, 0.2)   # 確保回到手牌標準大小
