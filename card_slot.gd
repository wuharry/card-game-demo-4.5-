extends Area3D

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
	# 建立 Tween 動畫，set_parallel(true) 讓位移和旋轉「同時」發生
	var tw = create_tween().set_parallel(true)
	
	# 1. 吸附到卡槽中心，並稍微浮起一點點(避免跟底圖穿模閃爍)
	var target_pos = global_position + Vector3(0, 0.01, 0)
	tw.tween_property(card, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_SINE)
	
	# 2. 讓卡片「躺平」！ (X 軸旋轉 -90 度)
	tw.tween_property(card, "rotation_degrees", Vector3(-90, 0, 0), 0.2).set_trans(Tween.TRANS_SINE)
	
# 準備讓 Manager 呼叫的函式：當卡片被拿走時
func remove_card() -> void:
	is_empty = true # 卡片狀態清空
	card_in_slot = null # 剪斷記憶體牽繩
