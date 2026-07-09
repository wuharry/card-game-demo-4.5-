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

## 卡槽的「基準縮放」:PlayerBoard 生成時會整體縮放卡槽(slot_scale,配合立牌像素密度)。
## 高亮動畫要以它為基準去乘;若寫死 Vector3.ONE,一次高亮就把縮放洗掉了。
## (基準值要快照、即時值才即時讀——和 card.gd 的 original_scale 是同一條原則。)
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	# 把「進場時的縮放」拍下來當基準(PlayerBoard 在 add_child 前就把 scale 設好了)。
	_base_scale = scale


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
	# 「轉正」= local (0,0,0)。注意這是「相對 PlayerHand」的旋轉：卡片上桌後仍掛在
	# PlayerHand 底下，而 PlayerHand 自己就轉了 -90°X —— 所以 local (0,0,0) 疊上
	# 父節點的旋轉，世界結果正是「躺平、卡面朝上、卡頂朝敵方」(遊戲王式擺法)。
	# ⚠ 別在這裡再補 -90°：兩個旋轉會疊加，卡片就立起來了(local vs world，同 §B)。
	tw.tween_property(card, "rotation_degrees", Vector3(0, 0, 0), 0.15)
	# 卡片大小「跟著卡槽走」:兩者原生同為 1.6×2.4;卡槽被 PlayerBoard 縮放過,
	# 卡片就乘上同一個倍率,入槽後才會剛好蓋住卡槽。
	tw.tween_property(card, "scale", Vector3.ONE * _base_scale.x, 0.15)
	# chain()：從「同時播放」切回「排隊」——等上面的躺平動畫都走完，
	# 才呼叫 show_standee() 讓角色現身，時序上就是「卡落地 → 怪獸登場」。
	tw.chain().tween_callback(card.show_standee)

	# 標記上桌:不能再拖曳,但碰撞留著——點擊會改開指令選單(分流在 CardManager)。
	card.enter_board_mode()


## ── 公開方法：把卡片取出 ───────────────────────
func remove_card() -> void:
	if card_in_slot:
		# 先收掉站在卡上的立牌(卡要離開桌面了，怪獸跟著退場)。
		card_in_slot.hide_standee()
		# 回手:恢復可拖曳狀態。
		card_in_slot.exit_board_mode()

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

	# 把整個卡槽稍微放大到「基準的 1.1 倍」，產生「即將吸附」的視覺提示。
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", _base_scale * 1.1, 0.1)


## ── 取消高亮：滑鼠離開、或卡片已放入後 ─────────────
func unhighlight() -> void:
	if _highlight_tween:
		_highlight_tween.kill()

	# 縮回「基準大小」(不是 Vector3.ONE——卡槽可能被 PlayerBoard 整體縮放過)。
	_highlight_tween = create_tween()
	_highlight_tween.tween_property(self, "scale", _base_scale, 0.1)
