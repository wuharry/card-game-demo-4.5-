

extends Area3D

# 賦予身分證，讓 Manager 知道這是一個卡槽
class_name CardSlot

# --- 狀態變數 ---
# 記錄這個卡槽目前是否為空
var is_empty: bool = true
# 記錄目前放在這個卡槽裡的具體是哪一張卡片 (一開始是 null)
var card_in_slot: Card = null

# --- 私有變數 ---
# 追蹤 highlight 動畫的 Tween，防止快速移入移出時動畫衝突
var _highlight_tween: Tween = null

func _ready() -> void:
	pass

# --- 公開方法 (Public Methods) ---

# 準備讓 Manager 呼叫的函式：當卡片被放進來時
func place_card(card: Card) -> void:
	is_empty = false # 更新卡槽的狀態
	card_in_slot = card # 把這張卡片的「記憶體參考」存進卡槽裡

	# 放入後立刻取消 highlight 狀態（卡槽已滿，視覺回到正常）
	unhighlight()

	# 視覺升級：平滑吸附到卡槽中心，並且「同時躺平」
	# set_parallel(true)：讓位移與旋轉同時執行，而不是依序執行
	var tw = create_tween().set_parallel(true)

	# 1. 計算目標高度 (稍微浮起避免穿模)
	var target_position = global_position + Vector3(0, 0.09, 0)


	# 2. 執行位移動畫
	tw.tween_property(card, "global_position", target_position, 0.15)

	# 3. 執行旋轉動畫 (X軸轉 -90 度，讓卡片躺平)
	tw.tween_property(card, "rotation_degrees", Vector3(-90, 0, 0), 0.15)

	# 物理：鎖死這張卡片，防止玩家再次拖曳
	card.lock_interaction()

# 準備讓 Manager 呼叫的函式：當卡片被拿走時
func remove_card() -> void:
	if card_in_slot:
		# 解除物理鎖定，讓卡片可以再次被拖曳
		card_in_slot.unlock_interaction()

		# 對稱還原：讓卡片立起來（與 place_card 的躺平動畫對稱）
		var tw = create_tween()
		tw.tween_property(card_in_slot, "rotation_degrees", Vector3(0, 0, 0), 0.15)

	# 清空卡槽狀態
	is_empty = true
	card_in_slot = null

# 當玩家拖曳卡片懸停在上方時呼叫
func highlight() -> void:
	# 只有空卡槽才需要發光，已有卡片的槽不給提示
	if not is_empty:
		return

	# Kill 舊動畫，防止快速進出時 scale 抖動
	if _highlight_tween:
		_highlight_tween.kill()

	# 稍微放大，產生「吸附預備」的視覺感
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)

# 當玩家拖曳卡片離開，或是把卡片放進去後呼叫
func unhighlight() -> void:
	# Kill 舊動畫，確保縮小動畫不會被中斷卡住
	if _highlight_tween:
		_highlight_tween.kill()

	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", Vector3.ONE, 0.1)
