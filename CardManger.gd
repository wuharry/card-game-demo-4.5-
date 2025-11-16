extends Node2D



var card_being_dreeged

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("左鍵點擊")
			var card=raycast_check_for_card()
		else:
			print('左鍵釋放')
	
#	用來檢測點擊下去的地方是否有卡片?
func raycast_check_for_card():
	# 獲取 2D 物理世界的狀態 (用於進行物理查詢)
	var space_state = get_world_2d().direct_space_state
	
	# 創建一個點查詢參數物件 (用於檢測某個點是否碰到物體)
	var parameters = PhysicsPointQueryParameters2D.new()
	
	# 設定查詢位置為滑鼠的全域座標
	parameters.position = get_global_mouse_position()
	
	# 設定是否檢測 Area2D 節點 (true = 會檢測 Area2D)
	parameters.collide_with_areas = true
	
	# 設定碰撞遮罩層 (只檢測第 1 層的物體)
	parameters.collision_mask = 1
	
	# 執行點查詢,返回所有在該點的物體陣列
	var result = space_state.intersect_point(parameters)
	
	# 印出結果
	
	if result.size()>0:
		print('點擊在卡片上', result[0].collider.get_parent())
		return result[0].collider.get_parent()
	else:
		print('點擊在卡片外面', result)
		return null
	
