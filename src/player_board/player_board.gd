## player_board.gd — 一側棋盤(自動生成一整排卡槽)
##
## 掛在 player_board.tscn 的根節點 (Node3D) 上。
## 主場景 main.tscn 會放兩份這個棋盤：一份給玩家、一份給敵人(把 is_enemy 勾起來)。
## 它在遊戲一開始，就用迴圈「程序化」地生成 5 欄 × 2 排 = 10 個卡槽，
## 這樣就不必在編輯器裡手動擺 10 個卡槽。

# @tool  ← (目前是註解掉的) 若把開頭的 # 去掉，這支腳本連在「編輯器裡」也會執行，
#           你打開場景就能直接看到生成的卡槽，而不必按播放。先保持關閉比較單純。

extends Node3D

## @export 會讓變數出現在右側 Inspector 面板，可以用拖拉的方式設定，不必改程式。
## card_slot_scene：要生成的卡槽藍圖。在 Inspector 對應欄位「Card Slot Scene」，
## 需把 card_slot.tscn 拖進去。PackedScene = 一個「打包好的場景檔」。
@export var card_slot_scene: PackedScene
## is_enemy：這份棋盤是不是敵方。對應 Inspector 的「Is Enemy」勾選框。
## main.tscn 裡敵方那份會把它設成 true，用來決定棋盤要擺在遠端還是近端。
@export var is_enemy: bool = false
## 卡槽整體縮放。0.8 是配合較細的立牌像素密度(card.gd 的 standee_pixel_size 0.016)：
## 卡片/卡槽縮小後，「角色 vs 卡片」的比例回到約 1/3，角色在卡上才有份量。
## 卡片入槽時會自動乘上同倍率(見 card_slot.gd 的 _base_scale)，不用另外調。
@export var slot_scale: float = 0.8


func _ready() -> void:
	# 防呆：若忘了在 Inspector 指定卡槽藍圖，就印警告而不是直接崩潰。
	if card_slot_scene:
		generate_board()
	else:
		print("警告：PlayerBoard 的屬性面板 Card Slot Scene 是空的！")


## 用兩層迴圈鋪出一個方格陣列的卡槽。
func generate_board() -> void:
	var cols := 5      # 每排幾個卡槽(欄，左右方向)
	var rows := 2      # 總共幾排(列，前後方向)
	var col_gap := 2.0 * slot_scale # 欄與欄的水平間距(X 方向，跟著卡槽縮放走)
	var row_gap := 2.5 * slot_scale # 排與排的前後間距(Z 方向)

	# 玩家棋盤往近端(Z 正方向)偏，敵人棋盤往遠端(Z 負方向)偏，兩邊才不會重疊。
	var z_offset := 0.7 if not is_enemy else -8.5
	# 棋盤原點：Y 抬高 0.01 避免卡槽和地板「穿模」(疊在同一高度互相閃爍)。
	var board_origin := Vector3(0.0, 0.01, z_offset)

	# 算出最左邊那欄的起點，讓整排卡槽在 X 軸上「置中對齊」棋盤原點。
	# 例如 5 欄、間距 2：總寬 = (5-1)×2 = 8，往左移一半(4)就會置中。
	# 這行只算一次放在迴圈外，比放在迴圈裡重複算更有效率。
	var start_point := board_origin + Vector3(
		-((cols - 1) * col_gap) / 2.0,
		0.0,
		0.0
	)

	# 外層跑「排」(前/後)，內層跑「欄」(左→右)，逐格生成卡槽。
	for row in range(rows):
		for col in range(cols):
			# instantiate() = 依照藍圖「實體化」出一個真正的卡槽節點。
			var slot := card_slot_scene.instantiate()
			# 縮放要在 add_child「之前」設好：卡槽的 _ready 會在 add_child 當下執行，
			# 它要拿「進場時的 scale」當高亮動畫的基準(設晚了就會快照到錯的 1.0)。
			slot.scale = Vector3.ONE * slot_scale
			# add_child() = 把它掛到場景樹底下，這樣它才會真的出現在畫面中。
			add_child(slot)

			# 從起點出發，依目前欄、列往右(X)、往後(Z)偏移，得到這格的位置。
			# position 是「相對父節點」的座標，對應 Inspector 的 Transform → Position。
			slot.position = start_point + Vector3(
				col * col_gap,
				0.0,
				row * row_gap
			)

			# 給每個卡槽取個好認的名字，例如 Slot_R0_C3 (第0排第3欄)。
			# %s 是字串佔位符，會被後面 [ ] 裡的值依序填入。
			slot.name = "Slot_R%s_C%s" % [row, col]

			# 把卡槽加入「群組」(group)，之後 Manager 可以用群組名一次抓出一整類卡槽。
			# 例如 "player_front"(我方前排)、"enemy_back"(敵方後排)。
			var faction_prefix := "enemy" if is_enemy else "player"
			var row_suffix := "front" if row == 0 else "back" # 第0排=前排，第1排=後排
			slot.add_to_group("%s_%s" % [faction_prefix, row_suffix])
