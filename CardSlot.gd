extends Area3D
class_name CardSlot# 賦予身分證，讓 Manager 知道這是一個卡槽
# --- 狀態變數 ---
# 記錄這個卡槽目前是否為空
var is_empty: bool = true
# 記錄目前放在這個卡槽裡的具體是哪一張卡片 (一開始是 null)
var card_in_slot: Card = null

func _ready() -> void:
	pass



# --- 公開方法 (Public Methods) ---
# 準備讓 Manager 呼叫的函式：當卡片被放進來時
func place_card(card: Card) -> void:
	is_empty = false # 更新卡槽的狀態
	card_in_slot = card # 把這張卡片的「記憶體參考」存進卡槽裡

	# 視覺升級：平滑吸附到卡槽中心，並且「同時躺平」
	var tw = create_tween().set_parallel(true) # 關鍵：設定為平行執行
	
	# 1. 計算目標高度 (稍微浮起避免穿模)
	var target_position = global_position + Vector3(0, 0.06, 0)
	
	# 2. 執行位移動畫
	tw.tween_property(card, "global_position", target_position, 0.15)
	
	# 3. 執行旋轉動畫 (X軸轉 -90 度，讓卡片躺平)
	tw.tween_property(card, "rotation_degrees", Vector3(-90, 0, 0), 0.15)

	# 物理：鎖死這張卡片
	card.lock_interaction()

# 當玩家拖曳卡片懸停在上方時呼叫
func highlight() -> void:
	if is_empty:
		# 稍微放大，產生「吸附預備」的視覺感
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)

# 當玩家拖曳卡片離開，或是把卡片放進去後呼叫
func unhighlight() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.1)
