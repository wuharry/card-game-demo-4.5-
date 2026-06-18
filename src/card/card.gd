## card.gd — 一張「卡片」的大腦
##
## 這支腳本掛在 card.tscn 的根節點 (Node3D) 上。
## 一張卡片在場景樹大概長這樣：
##   Card (Node3D, 掛這支腳本)
##   ├─ CardImage (Sprite3D)         ← 卡面圖
##   └─ Area3D                       ← 偵測滑鼠的感應區
##      └─ CollisionShape3D          ← 感應區的實際形狀(方塊)
##
## 它負責三件事：
##   1. 滑鼠移到卡片上 / 離開時，對外發出「信號」(signal) 通知別人。
##   2. 提供放大 / 縮小的動畫方法，讓 CardManager 決定何時播放。
##   3. 提供「鎖定 / 解鎖」方法，控制這張卡能不能被滑鼠抓取。

extends Node3D
## class_name 會把 Card 註冊成一個「全域型別」。
## 好處：其他腳本可以寫 var c: Card，並享有自動補全與型別檢查。
class_name Card


## ── 信號 (signal) ──────────────────────────────
## 信號就像「廣播」：這張卡不直接去呼叫別人，而是大喊一聲，
## 有訂閱的人 (這裡是 PlayerHand → CardManager) 自然會收到。
## 括號裡的 card: Card 代表廣播時會「附帶」自己這張卡，方便接收方知道是誰。
signal card_hovered(card: Card)
signal card_unhovered(card: Card)

## 記住卡片「原本的大小」。因為放大動畫是以原始大小為基準去乘倍數，
## 若不記住、每次都拿當下大小再放大，多播幾次就會越變越大而失真。
var original_scale: Vector3 = Vector3.ONE


## _ready() 是 Godot 的生命週期函式：節點一進入場景、準備好時自動執行一次。
func _ready() -> void:
	# 把「進場時的縮放」存起來當基準。
	# scale 是每個 3D 節點都有的內建屬性，對應 Inspector 的 Transform → Scale。
	original_scale = scale


## ── 滑鼠事件 → 轉成信號對外廣播 ──────────────────
## 這兩個函式是被 Area3D 的 mouse_entered / mouse_exited 信號呼叫的。
## (連接設定在 card.tscn 的 [connection] 區段，等同 Inspector 的 Node→Signals 面板手動連線)
func _on_area_3d_mouse_entered() -> void:
	# emit() = 把信號發射出去；self 代表「這張卡自己」。
	card_hovered.emit(self)

func _on_area_3d_mouse_exited() -> void:
	card_unhovered.emit(self)


## ── 動畫方法(由 CardManager 決定何時呼叫)──────────
## 把「要不要放大」的決策權交給 Manager，卡片只負責「怎麼放大」。
func animate_hover() -> void:
	# create_tween() 會建立一個補間動畫器：在一段時間內把某個屬性平滑地變化。
	var tw = create_tween()
	# 把 scale 在 0.15 秒內，從現在平滑變到「原始大小 × 1.2」(放大兩成)。
	tw.tween_property(self, "scale", original_scale * 1.2, 0.15)

func animate_unhover() -> void:
	var tw = create_tween()
	# 0.15 秒內縮回原始大小。
	tw.tween_property(self, "scale", original_scale, 0.15)


## ── 公開方法：鎖定 / 解鎖互動 ─────────────────────
## 卡片能不能被滑鼠射線「打到」，取決於它的 CollisionShape3D 有沒有被停用。
func lock_interaction() -> void:
	# $Area3D/CollisionShape3D 是「節點路徑」寫法：從自己往下找這個子節點。
	var col_shape = $Area3D/CollisionShape3D
	if col_shape:
		# disabled = true 等同在 Inspector 勾選 CollisionShape3D 的「Disabled」。
		# 停用後射線打不到它 → 卡片放進卡槽後就抓不動了。
		col_shape.disabled = true
		print("[狀態] 卡片已鎖定，滑鼠無法拖曳")

func unlock_interaction() -> void:
	var col_shape = $Area3D/CollisionShape3D
	if col_shape:
		# 重新啟用碰撞形狀，卡片又可以被滑鼠抓取(例如從卡槽拿回手牌時)。
		col_shape.disabled = false
		print("[狀態] 卡片已解鎖，恢復互動能力")
