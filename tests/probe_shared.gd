extends SceneTree
## 第 1 關探針:兩次 load 同一個 .tres,拿到的是兩份還是一份?

func _initialize() -> void:
	var a := load("res://data/cards/knight.tres") as CardData
	var b := load("res://data/cards/knight.tres") as CardData

	print("A 的 hp = ", a.hp, " / B 的 hp = ", b.hp)

	# ① 這兩個變數指的是同一個東西嗎?
	print("① a == b  → ", a == b)

	# ② 只動 a,不碰 b。然後問 b 的血。
	a.hp = 999
	print("② 把 a.hp 改成 999 之後,b.hp = ", b.hp)

	# ③ 換個問法:它們的記憶體位址(instance id)一樣嗎?
	print("③ a 的 id = ", a.get_instance_id(), " / b 的 id = ", b.get_instance_id())

	quit()
