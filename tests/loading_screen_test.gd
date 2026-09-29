extends SceneTree
## -- <capture.png> [en] [large] [battle]；使用預設 Forward+，headless 只驗行為。
const LOADING = preload("res://src/loading/loading_screen.gd")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Loading test timed out")
		quit(1))
	var args := OS.get_cmdline_user_args()
	var settings := root.get_node("AppSettings")
	settings.language = "en" if "en" in args else "zh_TW"
	settings.reduce_motion = false
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.5 if "large" in args else 1.0
	var overlay := LOADING.new()
	root.add_child(overlay)
	await process_frame
	var sigil: Control = overlay._status.get_parent().get_child(0)
	var initial_age: float = sigil.age
	await create_timer(0.3).timeout
	_check(sigil.age > initial_age, "卡牌動畫必須隨時間更新")
	sigil.reduced = true
	initial_age = sigil.age
	await process_frame
	_check(sigil.age == initial_age, "減少動態必須停止卡牌浮動")
	root.content_scale_factor = 1.5 if "large" in args else 1.0
	await process_frame
	await process_frame
	_check(root.get_visible_rect().encloses(overlay._status.get_global_rect()), "載入文字不得超出視窗")
	if DisplayServer.get_name() != "headless" and not args.is_empty():
		overlay._progress.value = 42.0
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
	overlay.queue_free()
	await process_frame

	# 失敗必須留在原場景，返回按鈕釋放遮罩並通知選單。
	var original := Node.new()
	root.add_child(original)
	current_scene = original
	var failed_overlay := LOADING.new()
	root.add_child(failed_overlay)
	var failure_seen: Array[bool] = [false]
	failed_overlay.failed.connect(func() -> void: failure_seen[0] = true)
	failed_overlay.start("res://scenes/does_not_exist_loading_test.tscn")
	while not failed_overlay._retry.visible:
		await process_frame
	_check(current_scene == original, "載入失敗不得卸載原場景")
	_check(not failed_overlay._busy, "失敗後應允許返回")
	failed_overlay._retry.pressed.emit()
	await process_frame
	_check(failure_seen[0] and not is_instance_valid(failed_overlay), "返回必須通知選單並清除遮罩")

	if "battle" in args:
		var battle_script := load("res://src/card_manager/card_manager.gd") as GDScript
		_check(battle_script != null and battle_script.can_instantiate(), "牌桌腳本必須可編譯")
		if _failures > 0:
			quit(1)
			return
		original.free()
		var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		current_scene = menu
		menu._on_single_player_pressed()
		menu._enter_game() # 重複呼叫不能建立第二個載入畫面。
		var count := 0
		for node in root.get_children():
			if node.get_script() == LOADING:
				count += 1
		_check(count == 1, "連點進場只能建立一個載入畫面")
		await scene_changed
		_check(current_scene.scene_file_path == "res://scenes/main.tscn", "選單應進入真實牌桌")
		var manager := root.find_child("CardManger", true, false)
		_check(manager != null and is_instance_valid(manager.battle_ui._desc),
			"真實牌桌指令面板必須完成初始化")
		await create_timer(0.5).timeout
		for node in root.get_children():
			_check(node.get_script() != LOADING, "牌桌就緒後必須清除載入遮罩")
	else:
		# 真正透過背景載入和 SceneTree 切換，驗證跨場景生命週期。
		var target := Node.new()
		target.name = "LoadedTarget"
		var packed := PackedScene.new()
		packed.pack(target)
		target.free()
		var path := "user://loading_screen_test_target.tscn"
		_check(ResourceSaver.save(packed, path) == OK, "測試場景需可儲存")
		settings.reduce_motion = true
		var success_overlay := LOADING.new()
		root.add_child(success_overlay)
		success_overlay.start(path)
		await scene_changed
		_check(current_scene.name == "LoadedTarget", "背景載入後需切換至目標場景")
		while is_instance_valid(success_overlay):
			await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Loading screen: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	quit(0 if _failures == 0 else 1)
