extends "res://tests/screenshot.gd"
## 固定滿手牌，拍攝左／中／右卡 hover 與歸位，驗證整張卡不被鄰卡遮擋。
## godot --path . --rendering-method forward_plus --resolution 1280x720 \
##   -s tests/screenshot_hover.gd -- /tmp/card-hover

var _capture_failed := false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "/tmp/card-hover"
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		push_error("無法建立截圖目錄：" + out)
		quit(1)
		return
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 90:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var ph: PlayerHand = cm.player_hand
	# 拍攝由下面直接切換 hover，避免桌面滑鼠位置干擾固定情境。
	root.physics_object_picking = false
	cm.set_process_input(false)
	var cards: Array[CardData] = []
	for card_name in ["knight", "ward_blast_sigil", "soldier", "ward_soulburn_sigil",
			"arcana_fireblast", "knight", "ward_thorn_sigil", "soldier"]:
		cards.append(load("res://data/cards/%s.tres" % card_name))
	ph.rebuild_from(cards, false)
	for card in ph.cards:
		card.get_node("Area3D").collision_layer = 0
	await create_timer(0.3).timeout
	await _save_frame(out.path_join("hand.png"))
	for i in [0, 3, 7]:
		var card: Card = ph.cards[i]
		cm.on_card_hovered(card)
		await create_timer(0.3).timeout
		await _save_frame(out.path_join("hover_%d.png" % i))
		cm.on_card_unhovered(card)
		await create_timer(0.3).timeout
	await _save_frame(out.path_join("restored.png"))
	if not _capture_failed:
		print("saved hover captures: ", out)
	quit(1 if _capture_failed else 0)


func _save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		_capture_failed = true
		push_error("截圖儲存失敗：" + path)
