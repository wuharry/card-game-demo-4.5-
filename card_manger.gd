extends Node3D

# ── 手牌設定 ──────────────────────────
@export var fan_angle: float = 12.0      # 每張牌間隔角度
@export var hand_radius: float = 6.0     # 扇形半徑
@export var hand_y: float = 1.5         # 手牌高度（稍微浮起）
@export var hand_z: float = 10.0          # 手牌距相機距離

# ── 場地設定 ──────────────────────────
@export var grid_spacing: float = 1.6    # 格子間距
@export var left_start: Vector3 = Vector3(-4.0, 0.1, 1.0)
@export var right_start: Vector3 = Vector3(1.5, 0.1, 1.0)
@export var grid_cols: int = 3
@export var grid_rows: int = 4

# ── 動畫設定 ──────────────────────────
@export var tween_duration: float = 0.4

# ── 狀態 ──────────────────────────────
var hand_cards: Array[Node3D] = []       # 手牌列表
var field_cards: Array[Node3D] = []      # 場地卡列表

# ══════════════════════════════════════
func _ready() -> void:
	# 自動收集所有子節點為手牌
	for child in get_children():
		if child is Node3D:
			hand_cards.append(child)
	
	arrange_hand()

# ══════════════════════════════════════
## 手牌扇形排列
func arrange_hand() -> void:
	var count = hand_cards.size()
	if count == 0:
		return
	
	var start_angle = -(count - 1) * fan_angle / 2.0
	
	for i in range(count):
		var card = hand_cards[i]
		var angle_deg = start_angle + i * fan_angle
		var angle_rad = deg_to_rad(angle_deg)
		
		# 扇形位置
		var target_pos = Vector3(
			sin(angle_rad) * hand_radius,
			hand_y,
			hand_z
		)
		# 扇形旋轉（手持傾斜角度）
		var target_rot = Vector3(
			deg_to_rad(45),   # 稍微往玩家傾斜
			angle_rad,          # 扇形展開角
			0.0
		)
		
		_tween_card(card, target_pos, target_rot)

# ══════════════════════════════════════
## 出牌：從手牌移到場地
func play_card(card: Node3D, slot_index: int, is_left_side: bool) -> void:
	if not hand_cards.has(card):
		return
	
	# 計算目標格子位置
	var start = left_start if is_left_side else right_start
	var col = slot_index % grid_cols
	var row = slot_index / grid_cols
	
	var target_pos = start + Vector3(col * grid_spacing, 0.0, row * grid_spacing)
	var target_rot = Vector3(deg_to_rad(-90), 0.0, 0.0)  # 完全躺平
	
	# 從手牌移到場地
	hand_cards.erase(card)
	field_cards.append(card)
	
	# 播放移動動畫
	_tween_card(card, target_pos, target_rot)
	
	# 重新整理剩餘手牌
	await get_tree().create_timer(tween_duration).timeout
	arrange_hand()

# ══════════════════════════════════════
## Tween 動畫移動卡片
func _tween_card(card: Node3D, target_pos: Vector3, target_rot: Vector3) -> void:
	var tw = create_tween()
	tw.set_parallel(true)  # 位置和旋轉同時動
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	
	tw.tween_property(card, "position", target_pos, tween_duration)
	tw.tween_property(card, "rotation", target_rot, tween_duration)
