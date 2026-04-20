extends Node3D

const COLLISION_MASK_CARD = 1

# 在 3D 中，我們需要攝像機來把滑鼠的 2D 座標轉換成 3D 射線
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var card_being_dragged: Node3D = null
# 用來記錄拖曳時的平面高度 (Y軸)
var drag_plane_height: float = 0.0

func _ready() -> void:
	# 1. 遊戲開始時，先綁定所有卡片的信號
	connect_card_signals()
	# 3D 不需要像 2D 那樣限制 screen_size，因為世界座標跟螢幕像素不同
	pass

# --- 新增：綁定信號的邏輯 ---
func connect_card_signals() -> void:
	for child in get_children():
		if child is Card:
			# 將卡片的信號，連接到 Manager 底下的 _on_card_hovered 函式
			# 因為卡片有傳遞 self 出來，所以接收端也要預留參數位置
			child.card_hovered.connect(_on_card_hovered)
			child.card_unhovered.connect(_on_card_unhovered)

# --- 新增：接收廣播後的處理函式 ---
func _on_card_hovered(card: Card) -> void:
	# 防呆檢查：如果現在沒有在拖拽任何卡片，才允許卡片放大
	if card_being_dragged == null:
		card.animate_hover()
		# 未來你可以在這裡加入：讓這張卡片的 Z 軸往前移 (防穿模)

func _on_card_unhovered(card: Card) -> void:
	if card_being_dragged == null:
		card.animate_unhover()
		# 未來你可以在這裡加入：讓這張卡片的 Z 軸退回原位
			
			
func _process(delta: float) -> void:
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("左鍵點擊 (3D)")
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
				# 記錄卡片當前的高度，這樣拖曳時不會突然飛高或穿地板
				drag_plane_height = card.global_position.y
		else:
			print('左鍵釋放 (3D)')
			card_being_dragged = null

# 用來檢測點擊下去的地方是否有卡片 (3D 版本)
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
