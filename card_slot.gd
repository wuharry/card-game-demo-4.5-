extends Area3D
class_name CardSlot # 賦予身分證，讓 Manager 知道這是一個卡槽

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
	
# 準備讓 Manager 呼叫的函式：當卡片被拿走時
func remove_card() -> void:
	is_empty = true # 卡片狀態清空
	card_in_slot = null # 剪斷記憶體牽繩
