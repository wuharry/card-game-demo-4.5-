extends SceneTree
## 使用真實牌桌驗證 UI 與特效生命週期；非 headless 同時輸出截圖。
const FX = preload("res://src/fx/pixel_effect.gd")
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error(message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var app := root.get_node("AppSettings")
	app.reduce_motion = false
	app.language = "en" if "en" in args else "zh_TW"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.5 if "large" in args else 1.0
	MatchMode.mode = MatchMode.Mode.VS_AI
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.5 if "large" in args else 1.0
	await process_frame
	var cm := root.find_child("CardManger", true, false)
	var ui: BattleUI = cm.battle_ui
	ui.update_hud(2, NetMatch.my_side, 8, 10, 2)
	ui.flash_message(app.text("battle_attack_desc"))
	ui._history_button.button_pressed = true
	_check(ui._recent_messages.size() > 0, "訊息須保留供重讀")
	_check(ui.blocks_board_pointer(ui._history_button.get_global_rect().get_center()),
		"最近訊息按鈕不能穿透到牌桌")
	ui.update_arrow(Vector2(420, 400), Vector2(700, 260), true)
	var host := Node3D.new()
	scene.add_child(host)
	host.position = Vector3(0, 1, -1)
	for family in ["impact", "heal", "holy", "fire", "ice", "smoke", "darkness"]:
		FX.play_at(host, family)
		_check(FX._frames.has(family + "1"), "動畫素材缺失：" + family)
	await create_timer(2.0).timeout
	_check(get_nodes_in_group("transient_pixel_fx").is_empty(),
		"正常播放結束必須清除特效")
	app.reduce_motion = true
	FX.play_at(host, "heal")
	await create_timer(0.4).timeout
	_check(get_nodes_in_group("transient_pixel_fx").is_empty(),
		"減少動態模式也必須清除特效")
	app.reduce_motion = false
	FX.play_at(host, "heal")
	await create_timer(0.2).timeout
	_check(not ui._hud_panel.get_global_rect().intersects(ui._hud_turn_panel.get_global_rect()),
		"資源列不能蓋住回合條")
	_check(not ui._history_panel.get_global_rect().intersects(ui._toast.get_global_rect()),
		"最近訊息不能蓋住即時提示")
	if DisplayServer.get_name() != "headless" and not args.is_empty():
		await RenderingServer.frame_post_draw
		print("capture size=", root.get_texture().get_size(), " UI scale=", root.content_scale_factor)
		root.get_texture().get_image().save_png(args[0])
	ui.update_hud(2, "enemy", 3, 3, 0)
	_check(ui._end_turn_btn.disabled, "AI 回合不可結束回合")
	ui.update_hud(3, NetMatch.my_side, 3, 3, 0)
	_check(not ui._end_turn_btn.disabled, "我方回合必須恢復操作")
	var unit: Card = cm.battle_manager.spawn_unit(load("res://data/cards/knight.tres"),
		get_nodes_in_group("player_front")[0])
	unit.equip_atk_bonus = 2
	unit.max_hp_bonus = 3
	ui.open(unit, "blocked", "blocked")
	_check(not ui._toast.visible and not ui._arrow_line.visible,
		"新指令不能被上一個提示與瞄準線遮住")
	_check(ui._stats.text == "ATK %d ／ HP %d／%d" % [
		unit.atk_total(), unit.current_hp, unit.data.hp + unit.max_hp_bonus],
		"指令面板必須顯示含裝備與生命加成的數值")
	_check(ui._cancel_btn.has_focus(), "沒有可用指令時鍵盤焦點必須落在取消")
	ui.show_card_preview(unit)
	await process_frame
	_check(not ui._prev_panel.get_global_rect().intersects(ui._end_turn_btn.get_global_rect()),
		"卡片預覽不能蓋住結束回合")
	if "commands" in args and DisplayServer.get_name() != "headless":
		ui.open(unit)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0].get_basename() + "_commands.png")
	print("UI/FX review: ", "PASS" if _fails == 0 else "FAIL", " failures=", _fails)
	quit(0 if _fails == 0 else 1)
