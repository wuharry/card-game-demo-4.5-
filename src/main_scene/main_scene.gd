extends Node3D
# main_scene.gd — 掛在 main.tscn 根節點(MainScene)上的「牌桌環境切換器」
#
# main.tscn 裡烤死的環境是森林(編輯時看得到、開發時最常用);
# 遊戲執行時如果 ArenaPool 抽到的不是森林,就把烤死的那份換成抽到的環境。
#
# 為什麼不乾脆做三份 main.tscn(森林版/洞窟版/冰原版)?
#   牌桌玩法(手牌、棋盤、牌堆、相機、CardManager)三個場景完全一樣,
#   複製三份之後改一個玩法 bug 要改三處,一定漏。
#   「一份玩法 + 可抽換的環境」才是對的切法。

func _ready() -> void:
	# 專用伺服器(ADR-002)只算帳不畫畫面:換戰場是純視覺決定,規則完全無關。
	# 早退省下的是森林散佈幾百棵樹 + 換 WorldEnvironment——每間房都省一次。
	if NetMatch.is_dedicated_server:
		return
	var path := ArenaPool.next_arena_path
	if path.is_empty():
		# 沒經過主選單(開發時直接 F6 跑 main.tscn)→ 自己抽一次,順便測隨機。
		path = ArenaPool.pick_random()
	if path == ArenaPool.DEFAULT_ARENA:
		return   # 抽到森林:場景裡烤好的就是它,什麼都不用做

	# 換環境:用 free()「立刻」移除,而不是 queue_free()。
	# queue_free 要到幀尾才真的刪,會有一瞬間同時存在兩個 WorldEnvironment
	# (森林的一個 + 新環境的一個),Godot 會抱怨且行為未定義。
	$Arena_Forest.free()
	var arena: Node3D = load(path).instantiate()
	arena.name = "Arena"
	add_child(arena)
