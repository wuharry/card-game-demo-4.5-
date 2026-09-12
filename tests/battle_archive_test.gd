extends SceneTree
## 真實單人入口 → 墓地射線 → 詳情 → 關閉 → 戰報。可加 -- capture 拍圖。

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
	print("PASS " if ok else "FAIL ", message)


func _run() -> void:
	var menu := load("res://scenes/main_menu.tscn").instantiate() as Node
	root.add_child(menu)
	current_scene = menu
	menu._single_player_button.pressed.emit()
	await create_timer(2.0).timeout
	var cm := root.find_child("CardManger", true, false)
	_check(cm != null, "主選單點擊單人遊戲能進入對局")
	if cm == null:
		quit(1)
		return
	var bm: BattleManager = cm.battle_manager
	var archive = cm.battle_ui.archive
	_check(MatchMode.is_vs_ai() and cm._enemy_ai != null, "單人 AI 已初始化")
	await physics_frame
	var pile: GravePile = cm._grave_piles.player
	var point: Vector2 = cm.camera.unproject_position(pile.global_position + Vector3(0, 0.4, 0))
	cm._on_left_pressed_idle_at(point)
	_check(archive.is_open() and archive.mode == "grave", "點擊墓地地標開啟 dialog，包括空墓地")
	var card := load("res://data/cards/swordsman.tres") as CardData
	bm.bury("player", card)
	bm.bury("player", card)
	_check(archive._rows.get_child_count() == 2, "重複卡片分別列出，墓地開啟時即時更新")
	archive._rows.get_child(0).mouse_entered.emit()
	_check(archive._description.text.contains(card.card_name), "hover 顯示卡名與詳情")
	_check(cm.battle_ui.blocks_board_pointer(Vector2.ZERO), "dialog 阻擋整個棋盤點擊")
	var copied := bm.grave_cards("player")
	copied.clear()
	_check(bm.grave_count("player") == 2, "檢視資料不會改動墓地帳")
	if "capture" in OS.get_cmdline_user_args():
		await create_timer(0.8).timeout
		root.get_texture().get_image().save_png("res://docs/grave_dialog_review.png")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	cm._input(escape)
	_check(not archive.is_open() and not cm._leave_pending, "Esc 只關墓地，不開離開選單")
	cm.battle_ui._history_button.pressed.emit()
	_check(archive.is_open() and archive.mode == "history", "戰鬥紀錄入口可開啟")
	bm.record_event("測試觸發")
	_check(archive._rows.get_child(archive._rows.get_child_count() - 1).text.contains("測試觸發"),
		"開啟中的戰報即時更新")
	if "capture" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		root.get_texture().get_image().save_png("res://docs/battle_history_review.png")
	archive.close()
	current_scene.queue_free()
	await process_frame
	quit(1 if fails else 0)
