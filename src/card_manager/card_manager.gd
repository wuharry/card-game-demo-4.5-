## card_manager.gd — 全場的「大腦」：負責滑鼠拖放、hover、出牌判定
##
## 掛在 main.tscn 的 CardManger (Node3D) 節點上。
## 它是整個互動的中樞，每一幀檢查滑鼠、處理點擊放開，
## 並協調 Card(卡片)、CardSlot(卡槽)、PlayerHand(手牌)三方。
##
## 核心觀念「射線偵測 (raycast)」：
##   螢幕是平的(2D)，但場景是立體的(3D)。要知道滑鼠點到哪個 3D 物件，
##   就從攝影機往滑鼠方向「射一條看不見的線」，看它打中什麼。

extends Node3D

# ==========================================
# 物理碰撞遮罩 (Collision Mask) 常數
# ==========================================
# Godot 用「層 (Layer)」來分類物件。我們把卡片放在第 1 層、卡槽放在第 2 層。
# 射線可以指定「只想打中哪一層」，這樣找卡片時不會誤抓到卡槽，反之亦然。
# 數值規則：第 N 層 = 2 的 (N-1) 次方。第1層=1、第2層=2、第3層=4…(用加法可組合多層)。
# (這些層的對應，也可在 Inspector 的 CollisionObject3D → Collision → Layer/Mask 勾選框設定)

const COLLISION_MASK_CARD = 1  # 第 1 層：卡片實體(拖曳時要找的對象)
const COLLISION_MASK_SLOT = 2  # 第 2 層：桌面卡槽(放牌時要找的對象)

## @onready：等節點都準備好後，才執行右邊的取值並存進變數(太早拿可能還是 null)。
## camera：場景目前啟用中的攝影機。把滑鼠的 2D 座標換成 3D 射線時一定要用到它。
@onready var camera: Camera3D = get_viewport().get_camera_3d()

## 目前「被滑鼠抓著拖曳」的卡片。沒有在拖任何卡時是 null。
var card_being_dragged: Node3D = null
## 拖曳時把卡片鎖在這個高度(Y 軸)，避免它忽高忽低或穿進地板。
var drag_plane_height: float = 0.0
## 目前被滑鼠 hover(放大)的卡片。全場同時「只能有一張」被放大，避免畫面混亂。
var currently_hovered_card: Card = null
## 拖曳時，目前懸停在哪個卡槽上方(用來控制卡槽的高亮提示)。
var currently_hovered_slot: CardSlot = null

## 取得手牌節點。"../PlayerHand" 是相對路徑：".." 先回到父節點，再往下找 PlayerHand。
@onready var player_hand = get_node("../PlayerHand")


func _ready() -> void:
	# 訂閱 PlayerHand 的中繼信號。之後任何一張手牌被 hover，事件都會流到這兩個函式。
	# connect(函式) = 「當信號發出時，請幫我呼叫這個函式」。
	player_hand.card_hovered.connect(on_card_hovered)
	player_hand.card_unhovered.connect(on_card_unhovered)


## ── 收到「滑鼠移到某張卡上」事件 ──────────────────
func on_card_hovered(card: Card) -> void:
	# 防呆 1：正在拖牌時，不要去放大底下其他的牌。
	if card_being_dragged != null:
		return

	# 防呆 2：若已經有「別張」卡被放大，先把它縮回去，確保同時只有一張放大。
	if currently_hovered_card != null and currently_hovered_card != card:
		currently_hovered_card.animate_unhover()

	# 記住目前放大的是這張，並播放它的放大動畫。
	currently_hovered_card = card
	card.animate_hover()
	# (未來可在這裡讓卡片往前移一點，避免被旁邊的牌擋住)


## ── 收到「滑鼠離開某張卡」事件 ──────────────────
func on_card_unhovered(card: Card) -> void:
	# 確認離開的就是目前記錄的那張，才把它縮回去。
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()

		# 補償邏輯：扇形手牌彼此重疊，滑鼠從上面那張移開時，
		# 其實可能正停在下面另一張牌上 → 主動再射一條線確認。
		var underneath_card = raycast_check_for_card()
		# 若底下真的還有牌、而且沒有在拖曳，就主動幫它觸發 hover(放大)。
		if underneath_card and underneath_card is Card and card_being_dragged == null:
			on_card_hovered(underneath_card)


## ── 每一幀都會執行：負責「拖曳中」的即時跟手 ──────────
## _process(delta) 是 Godot 的逐幀回呼。delta 是距離上一幀的秒數(這裡用不到，故加底線)。
func _process(_delta: float) -> void:
	# 只有真的抓著卡時才需要處理。
	if card_being_dragged:
		# 1. 想像桌面是一個「數學平面」：法線朝上(Vector3.UP)、高度為 drag_plane_height。
		#    卡片只會在這個水平面上滑動，不會亂飛。
		var drop_plane = Plane(Vector3.UP, drag_plane_height)

		# 2. 取得滑鼠在螢幕上的像素位置。
		var mouse_position = get_viewport().get_mouse_position()

		# 3. 從攝影機朝滑鼠方向射線：origin = 起點、normal = 方向。
		var ray_origin = camera.project_ray_origin(mouse_position)
		var ray_normal = camera.project_ray_normal(mouse_position)

		# 4. 算出這條射線和桌面平面的交點 = 滑鼠在桌面上對應的 3D 位置。
		var intersect_pos = drop_plane.intersects_ray(ray_origin, ray_normal)

		if intersect_pos:
			# 把卡片直接移到該位置(跟著滑鼠走)。
			card_being_dragged.global_position = intersect_pos

			# ── 拖曳時的卡槽高亮預覽 ──
			# 順便往下看現在懸停在哪個卡槽上。
			var found_slot = raycast_check_for_card_slot()
			# 只有當「懸停的卡槽改變了」才更新，避免每幀重複觸發動畫。
			if found_slot != currently_hovered_slot:
				# 先把上一個卡槽的高亮收掉。
				if currently_hovered_slot != null:
					currently_hovered_slot.unhighlight()
				# 若新的是空卡槽，就讓它亮起來。
				if found_slot != null and found_slot.is_empty:
					found_slot.highlight()
				# 更新記錄。
				currently_hovered_slot = found_slot


## ── 處理滑鼠輸入：按下=抓牌、放開=出牌 ──────────────
## _input(event) 在每次有輸入(滑鼠/鍵盤)時被呼叫，event 帶有這次事件的資訊。
func _input(event: InputEvent) -> void:
	# 只關心「滑鼠左鍵」事件。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# ── 左鍵按下 = 嘗試抓牌 ──
			print("左鍵點擊 (3D)")
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
				# 記住卡片當下的高度，拖曳時就維持在這個高度水平移動。
				drag_plane_height = card.global_position.y
				# 抓起來的瞬間取消它的放大狀態，避免邊拖邊放大的怪畫面。
				if currently_hovered_card == card:
					currently_hovered_card = null
					card.animate_unhover()

		else:
			# ── 左鍵放開 = 嘗試出牌 ──
			print('左鍵釋放 (3D)')

			# 1. 先確認手上真的有抓著卡。
			if card_being_dragged:
				# 2. 往下射線，看看放開的位置下面有沒有卡槽。
				var found_slot = raycast_check_for_card_slot()

				# 3. 找到卡槽、而且是空的 → 成功出牌。
				if found_slot and found_slot.is_empty:
					found_slot.place_card(card_being_dragged)         # 交給卡槽處理入槽動畫+鎖定
					player_hand.cards.erase(card_being_dragged)       # 從手牌陣列移除這張牌
					organize_hand()                                   # 剩下的手牌重新靠攏
					print("成功把卡片放進卡槽！")
				else:
					# 沒對準卡槽 / 卡槽已滿 → 讓它回到手牌扇形原位。
					organize_hand()

				# 4. 結算完畢，鬆手 → 清空「正在拖曳」的記錄。
				card_being_dragged = null


## ── 射線：找滑鼠下方的「卡片」(第 1 層)──────────────
func raycast_check_for_card():
	var mouse_pos = get_viewport().get_mouse_position()

	# 射線起點 = 攝影機；終點 = 往滑鼠方向延伸 1000 單位(夠長即可)。
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	# 取得 3D 物理世界，準備做查詢。
	var space_state = get_world_3d().direct_space_state

	# 建立射線查詢參數(3D 用 intersect_ray；2D 才是 intersect_point)。
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true   # 卡片用的是 Area3D，必須打開才掃得到
	query.collide_with_bodies = true
	query.collision_mask = COLLISION_MASK_CARD  # 只掃第 1 層(卡片)

	# 執行射線。打中東西時 result 是一個字典，沒打中是空的。
	var result = space_state.intersect_ray(query)

	if result:
		# result.collider 是被打中的 Area3D，它的父節點才是 Card 本體。
		print('點擊在卡片上', result.collider.get_parent())
		return result.collider.get_parent()
	else:
		print('點擊在卡片外面')
		return null


## ── 射線：找滑鼠下方的「卡槽」(第 2 層)──────────────
## 回傳型別寫成 -> CardSlot，代表這個函式保證回傳一個卡槽(或 null)。
func raycast_check_for_card_slot() -> CardSlot:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# 關鍵：這次只掃第 2 層(卡槽)，所以不會誤打到卡片。
	query.collision_mask = COLLISION_MASK_SLOT
	# CardSlot 本身就是 Area3D，必須打開這個才掃得到。
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)
	if result:
		# as CardSlot：把打中的東西「當作」CardSlot 型別回傳(方便後續取用它的方法)。
		return result.collider as CardSlot

	return null


## 轉呼叫手牌的重排，讓出牌後剩下的牌靠攏。
func organize_hand() -> void:
	if player_hand:
		player_hand.organize_hand()
