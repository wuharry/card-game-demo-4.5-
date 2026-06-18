## card_slot.gd — 桌面上一個「卡槽」
##
## 掛在 card_slot.tscn 的根節點上，而那個根節點型別是 Area3D
## (Area3D = 一塊只負責「偵測」不負責物理碰撞的感應區)。
## 卡槽是被動的：它自己不主動做事，而是等 CardManager 來呼叫它的方法。
##
## 場景結構：
##   CardSlot (Area3D, 掛這支腳本)
##   ├─ Sprite3D            ← 卡槽外框圖
##   └─ CollisionShape3D    ← 讓射線能打到卡槽的形狀
##
## 它記住自己是空的還是被佔用、被誰佔用，並提供放入/取出/高亮的動畫。

extends Area3D
## 註冊成全域型別 CardSlot，CardManager 才能寫 var slot: CardSlot。
class_name CardSlot


## ── 狀態變數 ──────────────────────────────────
## 這個卡槽現在是不是空的。CardManager 放牌前會先檢查它。
var is_empty: bool = true
## 目前放在這個卡槽裡的是哪一張卡 (沒有就是 null)。
## 存的是「參考」(指向那張卡的記憶體位置)，不是複製一份。
var card_in_slot: Card = null


## ── 私有變數 ──────────────────────────────────
## 開頭的底線 _ 是命名慣例，表示「這是內部用的，外面不要碰」。
## 記住目前正在播放的高亮動畫，方便在新的動畫開始前先把舊的停掉，
## 否則滑鼠快速進進出出時，多個動畫會打架造成大小抖動。
var _highlight_tween: Tween = null


func _ready() -> void:
	# pass = 「這裡什麼都不做」。卡槽在準備階段不需要初始化任何東西。
	pass


## ── 公開方法：放入一張卡 ───────────────────────
## 由 CardManager 在玩家把卡拖到這個空卡槽上、放開滑鼠時呼叫。
func place_card(card: Card) -> void:
	is_empty = false       # 更新狀態：這個槽現在有人了
	card_in_slot = card    # 記住是哪一張卡

	# 卡片入槽了，把高亮(放大提示)收掉，視覺回到正常。
	unhighlight()

	# set_parallel(true)：底下幾個 tween_property 會「同時」播放，而不是排隊。
	var tw := create_tween().set_parallel(true)

	# 目標位置 = 卡槽位置再往上抬 0.09，讓卡片疊在卡槽上方一點點、不會穿插。
	# global_position 是「世界座標」(整個場景的絕對位置)。
	var target_position := global_position + Vector3(0, 0.09, 0)
	tw.tween_property(card, "global_position", target_position, 0.15)  # 0.15 秒滑到定位
	tw.tween_property(card, "rotation_degrees", Vector3(0, 0, 0), 0.15) # 同時把卡片轉正
	# scale 設成 1.0 倍：卡片入槽後大小正好等於卡槽 (兩者原生都是 1.6×2.4)。
	tw.tween_property(card, "scale", Vector3.ONE * 1.0, 0.15)

	# 鎖死這張卡 (停用它的碰撞)，玩家就不能再把它從卡槽拖走。
	card.lock_interaction()


## ── 公開方法：把卡片取出 ───────────────────────
func remove_card() -> void:
	if card_in_slot:
		# 解鎖，讓這張卡重新可以被滑鼠抓取。
		card_in_slot.unlock_interaction()

		var tw := create_tween().set_parallel(true)
		tw.tween_property(card_in_slot, "rotation_degrees", Vector3(0, 0, 0), 0.15)
		# 縮回卡片自己記住的「原始大小」(在 card.gd 的 original_scale)。
		tw.tween_property(card_in_slot, "scale", card_in_slot.original_scale, 0.15)

	# 清空狀態：這個槽又變回空的了。
	is_empty = true
	card_in_slot = null


## ── 高亮：玩家拖著卡片懸停在這個空槽上方時 ──────────
func highlight() -> void:
	# 已經有卡的槽不需要提示，直接 return 結束。
	if not is_empty:
		return

	# 若上一個高亮動畫還在跑，先 kill() 砍掉，避免兩個動畫疊在一起讓 scale 抖動。
	if _highlight_tween:
		_highlight_tween.kill()

	# 把整個卡槽稍微放大到 1.1 倍，產生「即將吸附」的視覺提示。
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)


## ── 取消高亮：滑鼠離開、或卡片已放入後 ─────────────
func unhighlight() -> void:
	if _highlight_tween:
		_highlight_tween.kill()

	# 縮回原本大小 (Vector3.ONE = 1 倍)。
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", Vector3.ONE, 0.1)
