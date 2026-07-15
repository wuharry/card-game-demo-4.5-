extends SceneTree
## 回歸測試:瘋狂 hover 不得累積漂移(Harvey 實測回報的 bug)。
## 兩張手牌交錯快打 hover/unhover 30 輪(間隔比補間 0.15s 短),
## 收手後等動畫收斂,斷言每張卡都回到扇形基準位;
## 另驗「判定與演出分離」:抬升期間碰撞箱世界座標釘在扇形原位。

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var ph = cm.get("player_hand")
	if ph.cards.size() < 2:
		print("FAIL: 手牌不足兩張")
		quit(1)
		return
	var a: Card = ph.cards[0]
	var b: Card = ph.cards[1]
	var base_a: Vector3 = a.hand_base_pos
	var base_b: Vector3 = b.hand_base_pos
	var area_a: Node3D = a.get_node("Area3D")
	var area_gpos0: Vector3 = area_a.global_position

	# ── 不變量:hover 抬升期間,碰撞箱的「世界位置」必須釘在扇形原位 ──
	# (判定與演出分離:判定幾何跟著演出跑,就是 enter/exit 閃爍迴圈的根源)
	cm.on_card_hovered(a)
	await create_timer(0.3).timeout   # 等抬升補間走完
	var lifted_visual: float = (a.position - base_a).length()
	var pinned_drift: float = (area_a.global_position - area_gpos0).length()
	if lifted_visual < 1.0:
		print("FAIL: hover 後視覺未抬升(位移 %.2f)" % lifted_visual)
		quit(1)
		return
	if pinned_drift > 0.15:
		print("FAIL: hover 抬升時碰撞箱漂離扇形原位 %.3f" % pinned_drift)
		quit(1)
		return
	cm.on_card_unhovered(a)
	await create_timer(0.3).timeout
	if (area_a.global_position - area_gpos0).length() > 0.05:
		print("FAIL: 歸位後碰撞箱未回原位")
		quit(1)
		return
	print("  ok: 抬升 %.2f 期間碰撞箱釘住(漂移 %.3f)" % [lifted_visual, pinned_drift])

	# 瘋狂交錯:enter(B) 常在 exit(A) 之前——模擬扇形重疊的真實事件序
	for i in 30:
		cm.on_card_hovered(a)
		await create_timer(0.03).timeout
		cm.on_card_hovered(b)      # 先 enter B
		cm.on_card_unhovered(a)    # 再 exit A
		await create_timer(0.03).timeout
		cm.on_card_unhovered(b)

	await create_timer(0.5).timeout   # 等最後一輪補間收斂

	var fails := 0
	for pair in [[a, base_a, "A"], [b, base_b, "B"]]:
		var card: Card = pair[0]
		var base: Vector3 = pair[1]
		var drift: float = (card.position - base).length()
		if drift > 0.01:
			fails += 1
			print("FAIL: 卡 %s 未歸位,漂移 %.3f(pos=%s base=%s)" % [
				pair[2], drift, card.position, base])
	# 基準位本身也不准被動畫污染
	if a.hand_base_pos != base_a or b.hand_base_pos != base_b:
		fails += 1
		print("FAIL: 扇形基準位被改寫")

	if fails == 0:
		print("PASS 瘋狂 hover 30 輪後全數歸位,零漂移")
		quit(0)
	else:
		quit(1)
