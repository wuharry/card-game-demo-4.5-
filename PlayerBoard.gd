extends Node3D

#場景建築藍圖
@export var card_slot_scene: PackedScene
# --- 參數讓這個組件知道自己是玩家還是對手的棋盤 ---
@export var is_enemy: bool = false 

func _ready() -> void:
	if card_slot_scene:
		generate_board()
	else:
		print("警告： PlayerBoard 的屬性面板Card Slot Scene是空的！")

func generate_board() -> void:
	var cols = 5  # 每排 5 個
	var rows = 2  # 總共 2 排
	var spacing_x = 2.5
	var spacing_z = 4.0 

	for row in range(rows):
		for col in range(cols):
			var slot = card_slot_scene.instantiate()
			add_child(slot)
			
			# 1. 完美置中的數學算法
			var start_x = -((cols - 1) * spacing_x) / 2.0
			var pos_x = start_x + (col * spacing_x)
			# 如果是第一排 (row 0)，Z 軸往前；如果是第二排 (row 1)，Z 軸往後
			var pos_z = row * spacing_z
			
			slot.position = Vector3(pos_x, 0.01, pos_z)
			slot.name = "Slot_R" + str(row) + "_C" + str(col)
			
			# 2. 吸收另一個 AI 的精華：自動加入 Group (群組標籤)
			var faction_prefix = "enemy" if is_enemy else "player"
			var row_suffix = "front" if row == 0 else "back" # 第一排是前排，第二排是後排
			
			var group_name = faction_prefix + "_" + row_suffix
			slot.add_to_group(group_name) # 例如：變成 "player_front" 或是 "enemy_back"
			
			# 可選：印出來確認生成正確
			# print("生成卡槽: ", slot.name, " 屬於群組: ", group_name)
