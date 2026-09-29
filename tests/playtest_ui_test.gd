extends SceneTree
## 真實牌桌 + 座標輸入 + RichTextLabel GUI 命中；帶 --capture=/tmp/xxx 可保存畫面。
## godot --headless --path . --script res://tests/playtest_ui_test.gd

var _fails := 0
var _checks := 0
var _cm
var _ui: BattleUI
var _bm: BattleManager
var _capture_dir := ""


func _initialize() -> void:
	create_timer(90).timeout.connect(func() -> void:
		push_error("playtest UI timeout")
		quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		push_error(message)
	else:
		print("  ok: ", message)


func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = point
	_cm._input(event)


func _motion(point: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _screen(card: Card) -> Vector2:
	return _cm.camera.unproject_position(card.get_node("Area3D/CollisionShape3D").global_position)


func _settle() -> void:
	await process_frame
	await process_frame
	await physics_frame


## 掃過文字的真實 GUI 區域，不能手動 emit meta_hover_started 冒充滑鼠驗收。
func _hover_link(label: RichTextLabel) -> bool:
	_ui.hide_related_preview()
	var rect := label.get_global_rect()
	var name_start := label.text.find("[u]") + 3
	var name := label.text.substr(name_start, label.text.find("[/u]") - name_start)
	var char_start := label.get_parsed_text().find(name)
	var first_line := label.get_character_line(char_start)
	var last_line := label.get_character_line(char_start + name.length() - 1)
	for line in range(first_line, last_line + 1):
		var y := rect.position.y + label.get_line_offset(line) + 10
		for x in range(int(rect.position.x) + 4, int(rect.end.x), 8):
			_motion(Vector2(x, y))
			if DisplayServer.get_name() != "headless":
				await process_frame
			if _ui._related_panel != null and _ui._related_panel.visible:
				await _settle()
				return true
	return false


func _capture(name: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	_check(root.get_texture().get_image().save_png(_capture_dir.path_join(name + ".png")) == OK,
		"capture " + name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			_capture_dir = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(_capture_dir)
	var settings := root.get_node("AppSettings")
	settings.language = "en" if "en" in args else "zh_TW"
	settings.reduce_motion = true
	settings.ui_scale = 1.5 if "large" in args else 1.0
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = settings.ui_scale
	await create_timer(0.8).timeout
	_cm = root.find_child("CardManger", true, false)
	_cm.set_process_input(false)
	_cm.set_process(false)
	root.physics_object_picking = false
	_ui = _cm.battle_ui
	_bm = _cm.battle_manager
	_bm.sides["player"].mana = 7
	_bm.hand_of("enemy").clear()
	var necro := load("res://data/cards/necromancer.tres") as CardData
	var skeleton := load("res://data/cards/skeleton.tres") as CardData
	var fixed_hand: Array[CardData] = [necro]
	_cm.player_hand.rebuild_from(fixed_hand, false)
	var a := _bm.spawn_unit(necro, get_nodes_in_group("player_front")[0])
	var b := _bm.spawn_unit(necro, get_nodes_in_group("player_front")[2])
	await create_timer(0.5).timeout
	await _settle()
	var blank := Vector2(8, root.get_visible_rect().size.y * 0.55)
	var mana := _bm.active_mana()
	_click(_screen(a))
	await _settle()
	_check(_ui.command_menu_is_open() and _cm.active_unit == a, "點場上單位開啟指令")
	_click(_ui._panel.get_global_rect().position + Vector2(10, 10))
	_check(_cm.active_unit == a, "點指令面板內不會取消或穿透到牌桌")
	_click(blank)
	_check(_cm.ui_state == _cm.UiState.IDLE and _cm.active_unit == null
		and _cm.pending_skill == null and not _ui.command_menu_is_open(), "點空白收起並清除選取")
	_check(_bm.active_mana() == mana, "取消不支付魔力")
	_click(_screen(a))
	_click(_ui._history_button.get_global_rect().get_center())
	_ui._history_button.pressed.emit()
	_check(_cm.ui_state == _cm.UiState.IDLE and _ui.archive.is_open(),
		"點戰鬥紀錄可直接收起指令並查看，不必先按取消")
	_ui.archive.close()
	_click(_screen(a))
	_click(_screen(b))
	_check(_cm.active_unit == b and _ui.command_menu_is_open(), "點另一張場上卡直接切換")
	_click(_screen(b))
	_check(_cm.ui_state == _cm.UiState.IDLE, "再次點選同卡可收起")
	_click(_screen(a))
	await _settle()
	var attack_point := _ui._attack_btn.get_global_rect().get_center()
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = root.get_final_transform() * attack_point
		Input.parse_input_event(button)
		Input.flush_buffered_events()
	_check(_cm.ui_state == _cm.UiState.TARGETING,
		"指令按鈕收到 GUI 點擊後仍進入選目標，不被點外取消攔截")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_cm._input(escape)
	_check(_cm.ui_state == _cm.UiState.IDLE and _cm.pending_skill == null,
		"Esc 仍可取消瞄準")
	_click(_screen(a))
	var hand_card: Card = _cm.player_hand.cards[0]
	_click(_screen(hand_card))
	_check(_cm.card_being_dragged == hand_card and not _ui.command_menu_is_open(),
		"指令開啟時點手牌直接開始拖曳")
	_click(blank, MOUSE_BUTTON_RIGHT)
	await _settle()
	_check(_cm.card_being_dragged == null, "右鍵仍能取消拖曳")

	# 用真正的反制 coroutine 驗證外部點擊不能偷解鎖；玩家選擇後才能結束。
	var quick := load("res://data/cards/quick_void_rebuke.tres") as CardData
	_bm.hand_of("enemy").append(quick)
	_bm.sides["enemy"].mana = quick.cost
	_cm._ask_counter_hotseat("UI 驗收")
	await _settle()
	_click(blank)
	_click(_screen(a))
	_click(blank, MOUSE_BUTTON_RIGHT)
	_check(_ui.has_modal_choice() and _cm.ui_state == _cm.UiState.MENU_OPEN
		and _cm.active_unit == null, "反制窗口外部點擊與右鍵不解鎖牌桌")
	_ui._answer_reaction(false)
	await _settle()
	_check(not _ui.has_modal_choice() and _cm.ui_state == _cm.UiState.IDLE,
		"反制按略過才恢復操作")
	_cm._picking = true
	_cm.ui_state = _cm.UiState.MENU_OPEN
	_ui.show_card_picker("選牌驗收", "必須選擇", [necro])
	_click(blank)
	_check(_cm.ui_state == _cm.UiState.MENU_OPEN and _ui.has_modal_choice(),
		"已付費選牌不得點空白取消")
	_ui._pick_panel.hide()
	_ui._pick_dim.hide()
	_cm._picking = false
	_cm.ui_state = _cm.UiState.MENU_OPEN
	_click(blank)
	_click(blank, MOUSE_BUTTON_RIGHT)
	_check(_cm.ui_state == _cm.UiState.MENU_OPEN, "連線等待沒有指令選單時不得自行取消")
	_cm._cancel_command()

	# 中文／英文名稱均從效果資料產生連結；特殊 token 與別稱也要可查。
	for slug in ["necromancer", "arcana_raise_dead", "demon_d", "slime", "lava_slime",
			"skeleton_archer", "arcana_hellhound_call", "arcana_bloodwing_pact",
			"arcana_skeletal_reinforcements", "arcana_gate_of_dead_army",
			"ward_decoy_puppet", "ward_royal_tomb_trap"]:
		var data := load("res://data/cards/%s.tres" % slug) as CardData
		var expected := CardDetailPanel.summoned_data(data, data.active_skill)
		_check(expected != null, slug + " 存在真實召喚物資料")
		a.data = data
		_ui.show_card_preview(a)
		await _settle()
		var hit := await _hover_link(_ui._prev_panel.body)
		_check(hit, slug + " 名稱可被真實 hover 命中")
		if not hit:
			await _capture("failed_hover")
			quit(1)
			return
		_check(_ui._related_panel != null and _ui._related_panel.data == expected,
			slug + " 預覽資料與效果引用一致")
	_check(not _ui._related_panel.interactive, "相關卡片保持一層，分裂不遞迴開窗")
	await _capture("token")
	a.data = necro
	_ui.show_card_preview(a)
	await _settle()
	_ui.release_card_preview(a)
	_motion(_ui._prev_panel.get_global_rect().position + Vector2(25, 25))
	await create_timer(1.0).timeout
	_check(_ui._prev_panel.visible, "離開卡片後游標進入詳情，超過延遲仍保持開啟")
	_check(await _hover_link(_ui._prev_panel.body), "詳情中骷髏兵名稱可懸停")
	_check(_ui._related_panel.data == skeleton and _ui._related_panel._stats.text.contains(str(skeleton.hp)),
		"召喚物顯示模板數值")
	_check(_bm.active_mana() == mana, "查看所有召喚物不扣費")
	_check(_ui.blocks_board_pointer(_ui._prev_panel.get_global_rect().get_center())
		and _ui.blocks_board_pointer(_ui._related_panel.get_global_rect().get_center()),
		"兩層詳情都阻擋背後卡片點擊")
	await _capture("summon_preview")
	_check(root.get_visible_rect().encloses(_ui._prev_panel.get_global_rect())
		and root.get_visible_rect().encloses(_ui._related_panel.get_global_rect()),
		"兩層詳情都留在目前解析度與 UI 比例內")
	_check(not _ui._prev_panel.get_global_rect().intersects(_ui._related_panel.get_global_rect()),
		"召喚物預覽不蓋住來源詳情")
	_motion(blank)
	await _settle()
	_motion(blank)
	await create_timer(1.0).timeout
	_check(not _ui._prev_panel.visible and not _ui._related_panel.visible, "游標離開後兩層詳情一起收起")
	_click(_screen(a))
	_ui._show_skill_desc()
	await _settle()
	_check(await _hover_link(_ui._desc), "左下技能說明也能 hover 召喚物")
	await _capture("command_reference")
	_click(blank)
	_check(not _ui._related_panel.visible, "取消指令同時關閉召喚物預覽")
	# 故意超出小視窗高度的卡文，驗證捲動真的能操作而非只把底部截掉。
	var long_card := necro.duplicate(true) as CardData
	long_card.active_skill.description = "召喚一個骷髏兵。\n".repeat(35)
	var language_before: String = settings.language
	settings.language = "zh_TW"
	a.data = long_card
	_ui.show_card_preview(a)
	await _settle()
	_check(root.get_visible_rect().encloses(_ui._prev_panel.get_global_rect()),
		"超長卡文仍限制在視窗內")
	var text_point := _ui._prev_panel.body.get_global_rect().position + Vector2(30, 20)
	_motion(text_point)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = root.get_final_transform() * text_point
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _settle()
	_check(_ui._prev_panel._scroll.scroll_vertical > 0, "游標在長說明上可用滾輪查看底部")
	settings.language = language_before
	a.data = necro
	_ui.show_card_preview(a)
	await _settle()
	await _hover_link(_ui._prev_panel.body)
	a.queue_free()
	await _settle()
	_check(not _ui._prev_panel.visible and not _ui._related_panel.visible, "來源卡釋放後不殘留詳情")
	print("Playtest UI: ", "PASS" if _fails == 0 else "FAIL", " checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
