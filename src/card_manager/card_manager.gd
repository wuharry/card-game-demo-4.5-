extends Node3D

# ==========================================
# 物理碰撞遮罩 (Collision Mask) 常數設定
# ==========================================
# 規則：數值為 2 的 (Layer編號 - 1) 次方，便於引擎進行多層的加法運算不衝突。

const COLLISION_MASK_CARD = 1  # 對應 Layer 1：卡片實體 標識可互動的卡片，供滑鼠拖曳時的射線偵測使用。
const COLLISION_MASK_SLOT = 2  # 對應 Layer 2：桌面卡槽 標識桌面上的被動卡槽，供卡片放下時的射線穿透偵測使用。

# 在 3D 中，我們需要攝像機來把滑鼠的 2D 座標轉換成 3D 射線
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var card_being_dragged: Node3D = null
# 用來記錄拖曳時的平面高度 (Y軸)
var drag_plane_height: float = 0.0
# --- 記錄目前被 Hover 的卡片(全場同時永遠「只有一張」卡片能被放大) ---
var currently_hovered_card: Card = null
# --- 記錄拖曳時，目前懸停在哪個卡槽上 ---
var currently_hovered_slot: CardSlot = null

@onready var player_hand = get_node("../PlayerHand")

func _ready() -> void:
	# 連接 PlayerHand 的中繼信號，讓 CardManager 統一從 PlayerHand 接收 hover 事件
	# 這樣不管手牌有幾張、何時新增，CardManager 都只需要訂閱一個來源
	player_hand.card_hovered.connect(on_card_hovered)
	player_hand.card_unhovered.connect(on_card_unhovered)

# 接收 PlayerHand 中繼過來的 hover 事件（公開命名，無底線前綴）
func on_card_hovered(card: Card) -> void:
	# 防呆 1：如果正在拖曳，直接忽略任何 Hover (底下的牌不會亂放大)
	if card_being_dragged != null:
		return
		
	# 防呆 2：如果已經有其他卡片被放大了，先把它縮小 (解決重疊卡死)
	if currently_hovered_card != null and currently_hovered_card != card:
		currently_hovered_card.animate_unhover()
		
	# 記錄並執行新卡片的放大
	currently_hovered_card = card
	card.animate_hover()
	# 未來你可以在這裡加入：讓這張卡片的 Z 軸往前移 (防穿模)

func on_card_unhovered(card: Card) -> void:
	# 確認離開的是目前記錄的這張卡片
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()

		# --- 防呆補償邏輯 ---
		# 主動射一條射線，看看底下還有沒有卡片被忽略了
		var underneath_card = raycast_check_for_card()
		# 如果有掃到卡片，且我們沒有在拖曳，就主動觸發它的 Hover
		if underneath_card and underneath_card is Card and card_being_dragged == null:
			on_card_hovered(underneath_card) # 改用公開名稱呼叫，與方法定義一致
		# 未來你可以在這裡加入：讓這張卡片的 Z 軸退回原位

func _process(_delta: float) -> void:
	if card_being_dragged:
		# 1. 建立一個數學平面 (Plane)。
		# Vector3.UP 代表平面朝上 (正常的桌子表面)，drag_plane_height 是高度
		var drop_plane = Plane(Vector3.UP, drag_plane_height)
		
		# 2. 獲取滑鼠在螢幕上的位置
		var mouse_position = get_viewport().get_mouse_position()
		
		# 3. 從攝像機發射射線
		var ray_origin = camera.project_ray_origin(mouse_position)
		var ray_normal = camera.project_ray_normal(mouse_position)
		
		# 4. 計算射線與平面的交點
		# 這會告訴我們：滑鼠指在那個高度的哪個 3D 位置
		var intersect_pos = drop_plane.intersects_ray(ray_origin, ray_normal)
		
		if intersect_pos:
			# 更新卡片位置 (你可以選擇是否要平滑移動，這裡先直接賦值)
			card_being_dragged.global_position = intersect_pos
			# ================= 拖曳時的卡槽預覽邏輯 =================
			var found_slot = raycast_check_for_card_slot()
			# 如果掃描到的卡槽，跟「上一個記錄的卡槽」不一樣 (代表滑鼠移動到新卡槽，或離開了卡槽)
			if found_slot != currently_hovered_slot:
				# 1. 先把舊的卡槽恢復原狀 (如果有記錄的話)
				if currently_hovered_slot != null:
					currently_hovered_slot.unhighlight()
				
				# 2. 如果新掃到的是一個「空卡槽」，就讓它亮起來！
				if found_slot != null and found_slot.is_empty:
					found_slot.highlight()
				
				# 3. 更新大腦的記錄
				currently_hovered_slot = found_slot

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("左鍵點擊 (3D)")
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
				# 記錄卡片當前的高度，這樣拖曳時不會突然飛高或穿地板
				drag_plane_height = card.global_position.y
				# --- 卡片被抓起來時，強制取消它的放大狀態 ---
				if currently_hovered_card == card:
					currently_hovered_card = null
					card.animate_unhover()
		
		else:  # 當滑鼠左鍵鬆開時
			print('左鍵釋放 (3D)')
			
			# 1. 先確認手上是不是真的有抓著卡片
			if card_being_dragged:
				
				# 2. 往下射一條射線，看看底下有沒有卡槽
				var found_slot = raycast_check_for_card_slot()
				
				# 3. 如果有找到卡槽，而且這個卡槽是空的！
				if found_slot and found_slot.is_empty:
					# 呼叫我們剛才在 CardSlot 寫好的完美封裝函式！
					found_slot.place_card(card_being_dragged)
					player_hand.cards.erase(card_being_dragged) # 從手牌陣列移除已出的牌
					organize_hand() # 出牌後立刻重排剩餘手牌，觸發靠攏動畫
					print("成功把卡片放進卡槽！")
				else:
					# 如果底下沒有卡槽，或卡槽已經滿了，退回原本的手牌區
					organize_hand() 
					
				# 4. 邏輯全部結算完畢後，這時才能「清空手上的卡片」
				card_being_dragged = null

# 用來檢測點擊下去的地方是否有卡片 (3D 版本),找碰撞遮罩1的
func raycast_check_for_card():
	# 獲取滑鼠位置
	var mouse_pos = get_viewport().get_mouse_position()
	
	# --- 3D 射線核心邏輯 ---
	# 射線起點：攝像機的位置
	var from = camera.project_ray_origin(mouse_pos)
	# 射線終點：從攝像機往滑鼠指向的方向延伸 1000 單位長
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	# 獲取 3D 物理空間
	var space_state = get_world_3d().direct_space_state
	
	# 創建 3D 射線查詢參數
	# 注意：2D 是 intersect_point (點查詢)，3D 必須是 intersect_ray (射線查詢)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# 設定是否檢測 Area3D
	query.collide_with_areas = true
	query.collide_with_bodies = true # 通常 3D 卡片可能是 StaticBody 或 Area
	
	# 設定碰撞遮罩
	query.collision_mask = COLLISION_MASK_CARD
	
	# 執行射線檢測
	var result = space_state.intersect_ray(query)
	
	if result:
		# result 是一個 Dictionary，包含 collider, position, normal 等
		print('點擊在卡片上', result.collider.get_parent())
		return result.collider.get_parent()
	else:
		print('點擊在卡片外面')
		return null

# --- 專門用來尋找卡槽的射線 ---
func raycast_check_for_card_slot() -> CardSlot:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# 關鍵 1：雷達切換！這次我們只掃描 Layer 2 (卡槽)
	query.collision_mask = COLLISION_MASK_SLOT 
	
	# 關鍵 2：因為我們的 CardSlot 是 Area3D，不是一般的靜態剛體，所以這個必須設為 true
	query.collide_with_areas = true 
	
	var result = space_state.intersect_ray(query)
	if result:
		# 確定掃到東西，回傳這個 CardSlot 節點
		return result.collider as CardSlot
		
	return null

func organize_hand() -> void:
	if player_hand:
		player_hand.organize_hand()
