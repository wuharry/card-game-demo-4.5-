extends SceneTree
## 截圖工具(帶召喚):跑 main.tscn → 等發牌 → 把第一張從者卡打到我方前排空槽 →
## 等入槽/躺平/立牌動畫收斂 → 存 PNG。用來人眼驗「卡片上桌是不是躺平」。
## 用法:godot --path . -s tests/screenshot_summon.gd -- /絕對路徑/out.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/summon.png"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		out = ua[0]
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 90:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var ph = cm.get("player_hand")
	# 找第一張從者卡(card_type 0 = MINION)
	var card = null
	for c in ph.cards:
		if c.data != null and c.data.card_type == 0:
			card = c
			break
	if card == null:
		print("FAIL: 手上沒有從者卡")
		quit(1)
		return
	# 找第一個空的我方前排槽
	var slot = null
	for s in get_nodes_in_group("player_front"):
		if s.is_empty:
			slot = s
			break
	cm._pending_play_card = card
	cm._net_summon(ph.cards.find(card), card.data.resource_path, cm.get_path_to(slot))
	# 等入槽 0.15 + 立牌彈出動畫收斂
	await create_timer(1.5).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: " + out)
	quit(0)
