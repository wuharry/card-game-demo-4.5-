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

## 高亮膜著色器(圓角雙框+呼吸脈動,見 slot_tile.gdshader)。
## _ready 時以程式掛上,card_slot.tscn 零改動;每個卡槽一份材質,發光才能各自獨立。
const SLOT_SHADER: Shader = preload("res://src/card_slot/slot_tile.gdshader")
var _tile_mat: ShaderMaterial = null


func _ready() -> void:
	# 把「進場時的縮放」拍下來當基準(PlayerBoard 在 add_child 前就把 scale 設好了)。
	_base_scale = scale
	# 用著色器膜換掉場景裡的平板材質(執行期替換,場景檔不動)。
	_tile_mat = ShaderMaterial.new()
	_tile_mat.shader = SLOT_SHADER
	var tile: MeshInstance3D = $SlotTile
	# 圓角要等比:把平面實際的「寬/深」比例告訴 shader(非等比縮放會把圓角拉成橢圓)。
	_tile_mat.set_shader_parameter("aspect", tile.scale.x / tile.scale.z)
	_tile_mat.set_shader_parameter("glow", 0.0)
	tile.set_surface_override_material(0, _tile_mat)


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
	# 「躺平」= 世界座標繞 X 轉 -90°(卡面朝上、卡頂朝敵方，遊戲王式擺法)。
	# 卡片上桌後仍掛在 PlayerHand 底下，而 PlayerHand 為了讓手牌面向玩家帶了傾角
	# (構圖改版後是 +108°X，不再是當初的 -90°X)。所以 local 目標**不能寫死 (0,0,0)**：
	# 那會連父傾角一起繼承、卡片上桌就歪成近乎立起(這正是舊 bug 的成因——兩個角度
	# 手動對齊卻沒連動)。改成**反解父旋轉**：local = 父旋轉的逆 × 目標世界旋轉，
	# PlayerHand 之後再怎麼調角度都自動壓平，不會再壞。用 quaternion 而非 euler：
	# 避開 108° 在 YXZ 分解下被拆成怪值，且 Tween 對 quaternion 走最短弧、轉正不翻滾。
	var flat_world := Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0))
	var parent_basis: Basis = card.get_parent().global_transform.basis
	var flat_local := (parent_basis.inverse() * flat_world).get_rotation_quaternion()
	tw.tween_property(card, "quaternion", flat_local, 0.15)
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


## ── 單位死亡:只清狀態,不播「取回」動畫(死亡演出由卡片自己負責)──
## 由 BattleManager 在 HP 歸零時呼叫。
func on_unit_died() -> void:
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

	# 主角是發光:shader 的 glow 推到 1(變亮+呼吸脈動);
	# 縮放只留 1.06 的輕微「湊上前」,別跟發光搶戲。
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.tween_property(self, "scale", _base_scale * 1.06, 0.12)
	_highlight_tween.tween_method(_set_glow, _current_glow(), 1.0, 0.12)


## ── 取消高亮：滑鼠離開、或卡片已放入後 ─────────────
func unhighlight() -> void:
	if _highlight_tween:
		_highlight_tween.kill()

	# 縮回「基準大小」(不是 Vector3.ONE——卡槽可能被 PlayerBoard 整體縮放過)、熄燈。
	_highlight_tween = create_tween().set_parallel(true)
	_highlight_tween.tween_property(self, "scale", _base_scale, 0.1)
	_highlight_tween.tween_method(_set_glow, _current_glow(), 0.0, 0.1)


## ── glow 參數的 tween 介面 ─────────────────────────
## 不用 tween_property("shader_parameter/glow"):那是 shader 解析後才存在的動態屬性,
## 用 tween_method 直接呼叫 set_shader_parameter,不依賴算繪器狀態(headless 驗證也過)。
func _set_glow(value: float) -> void:
	_tile_mat.set_shader_parameter("glow", value)


## 從「當下值」起跑而不是寫死 0/1:高亮動畫做到一半被反向 kill 時才不會跳變。
func _current_glow() -> float:
	var v: Variant = _tile_mat.get_shader_parameter("glow")
	return float(v) if v != null else 0.0
