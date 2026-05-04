# @tool # 關鍵字：讓這個腳本在編輯器內直接執行

extends Node3D

# 場景建築藍圖
@export var card_slot_scene: PackedScene
# 參數：讓這個組件知道自己是玩家還是對手的棋盤
@export var is_enemy: bool = false

func _ready() -> void:
	if card_slot_scene:
		generate_board()
	else:
		print("警告：PlayerBoard 的屬性面板 Card Slot Scene 是空的！")

func generate_board() -> void:
	var cols := 5   # 每排幾個卡槽
	var rows := 2   # 總共幾排
	var col_gap := 2.0  # 欄（水平）間距
	var row_gap := 2.5  # 列（前後）間距

	# 玩家在近端（Z 正方向），敵人在遠端（Z 負方向）
	var z_offset := 0.7 if not is_enemy else -8.5
	# 棋盤原點：Y 軸微微抬高防止穿模,Z 軸根據敵我不同有不同的偏移
	var board_origin := Vector3(0.0, 0.01, z_offset)

	# 計算起始點，使整排卡槽在 X 軸上完美置中
	# 只算一次，不放在迴圈裡重複計算
	var start_point := board_origin + Vector3(
		-((cols - 1) * col_gap) / 2.0,
		0.0,
		0.0
	)

	for row in range(rows):
		for col in range(cols):
			var slot = card_slot_scene.instantiate()
			add_child(slot)

			# 從起始點出發，依欄列偏移計算每個卡槽的最終位置
			slot.position = start_point + Vector3(
				col * col_gap,
				0.0,
				row * row_gap
			)

			slot.name = "Slot_R%s_C%s" % [row, col]

			# 自動加入群組標籤，方便 Manager 之後用群組查詢卡槽
			var faction_prefix := "enemy" if is_enemy else "player"
			var row_suffix := "front" if row == 0 else "back" # 第一排是前排，第二排是後排
			slot.add_to_group("%s_%s" % [faction_prefix, row_suffix])
