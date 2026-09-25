extends SceneTree
## 真實戰鬥：規則結算、視覺停頓、無障礙、HUD；Forward+ 可輸出驗收畫面。
const SETTINGS = preload("res://src/settings/app_settings.gd")
const CAMERA_FX = preload("res://src/fx/camera_impulse.gd")
var _checks := 0
var _fails := 0
var _args: PackedStringArray


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		push_error(message)
	print("PASS: " if ok else "FAIL: ", message)


func _capture(suffix: String) -> void:
	if DisplayServer.get_name() == "headless" or _args.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_args[0] + suffix + ".png") == OK,
		"capture " + suffix)


func _run() -> void:
	_args = OS.get_cmdline_user_args()
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	var app := SETTINGS.current()
	app.reduce_motion = false
	app.language = "en" if "en" in _args else "zh_TW"
	app.quality = 2
	app.apply_quality()
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.5 if "large" in _args else 1.0
	var cm := root.find_child("CardManger", true, false)
	var bm: BattleManager = cm.battle_manager
	var ui: BattleUI = cm.battle_ui
	for side in ["player", "enemy"]:
		bm.hand_of(side).clear()
	cm.player_hand.rebuild_from(bm.hand_of("player"), false)
	var attacker := bm.spawn_unit(load("res://data/cards/swordsman.tres"), get_nodes_in_group("player_front")[2])
	var target := bm.spawn_unit(load("res://data/cards/knight.tres"), get_nodes_in_group("enemy_front")[2])
	var rear := bm.spawn_unit(load("res://data/cards/knight.tres"), get_nodes_in_group("enemy_back")[2])
	attacker.max_hp_bonus = 20
	attacker.heal(20)
	target.max_hp_bonus = 20
	target.heal(20)
	await create_timer(1.4).timeout
	var initial_position: Vector3 = attacker._standee.position
	var target_hp := target.current_hp
	bm.on_action_performed(attacker, null, target)
	_check(attacker.attacked_this_turn, "攻擊機會立即記帳，不能因演出延遲重複出手")
	await create_timer(0.15).timeout
	_check(target.current_hp == target_hp, "起手尚未命中，不提前扣血")
	_check(not attacker._standee.position.is_equal_approx(initial_position), "劍士的立牌有起手位移")
	await create_timer(0.23).timeout
	_check(target.current_hp == target_hp - 2, "命中仍遵守騎士鐵壁減傷")
	_check(not get_nodes_in_group("slash_visuals").is_empty(), "真正命中才出現刀光")
	await _capture("_slash")
	await create_timer(0.9).timeout
	_check(attacker._standee.position.is_equal_approx(initial_position), "攻擊後回到基準，不累積漂移")
	_check(get_nodes_in_group("slash_visuals").is_empty(), "刀光自行清除")

	# 新 Hurt Tween 取代舊 Idle 時仍會短暫停住，期間 HUD／規則計時照常運作。
	target.impact_feedback(3)
	target.play_one_shot_anim("Hurt")
	await process_frame
	await process_frame
	_check(not target._standee_anim.is_running(), "Hit-stop 追蹤同幀換掉的受擊動畫")
	_check(Engine.time_scale == 1.0 and not paused, "Hit-stop 不暫停規則或 SceneTree")
	await create_timer(0.16).timeout
	_check(target._standee_anim.is_running(), "Hit-stop 結束會恢復目前動畫")

	target.add_shield(6)
	await create_timer(1.1).timeout
	target_hp = target.current_hp
	bm._deal_damage(target, 3, false)
	_check(target.current_hp == target_hp and target.shield == 3, "格擋回饋不改變護盾吸收")
	_check(not get_nodes_in_group("transient_spatial_fx").is_empty(), "全額格擋仍有可見回饋")
	await _capture("_block")
	await create_timer(1.1).timeout

	ui.update_hud(2, NetMatch.my_side, 8, 10, 2)
	ui.update_hud(2, NetMatch.my_side, 6, 10, 0)
	_check(ui._hud_mana_value.text == "6 / 10" and ui._hud_mana_delta.text.contains("2"),
		"魔力總量即時更新，並顯示本次消耗")
	ui.update_hud(2, NetMatch.my_side, 13, 10, 5)
	_check(ui._hud_mana_value.text == "13 / 10" and ui._hud_mana_bonus.text == " +3",
		"溢出魔力保留實際數字，晶體列寬度有上限")
	target.add_status(SkillData.Status.FREEZE, 2)
	ui.open(target, "blocked", "blocked")
	_check(ui._unit_status.text.contains(app.status_name(SkillData.Status.FREEZE))
		and ui._unit_status.text.contains(app.text("status_shield") % 3), "指令面板顯示護盾和狀態剩餘回合")
	_check(ui._cancel_btn.has_focus(), "無可用行動時焦點停在取消")
	await process_frame
	await process_frame
	_check(not ui._hud_panel.get_global_rect().intersects(ui._hud_turn_panel.get_global_rect()),
		"資源面板與回合條不重疊")
	_check(not ui._hud_panel.get_global_rect().intersects(ui._end_turn_btn.get_global_rect()),
		"資源面板與結束回合不重疊")
	_check(ui.blocks_board_pointer(ui._hud_panel.get_global_rect().get_center()), "HUD 點擊不穿透牌桌")
	_check(not ui._panel.get_global_rect().intersects(ui._history_button.get_global_rect())
		and not ui._panel.get_global_rect().intersects(ui._leave_btn.get_global_rect()),
		"放大後的指令面板不被常駐工具列遮住")
	await _capture("_hud")
	ui.close()
	MatchMode.mode = MatchMode.Mode.VS_AI
	ui.update_hud(3, "enemy", 3, 3, 0)
	_check(ui._end_turn_btn.disabled and ui._hud_mana_delta.text.is_empty(), "換到對方回合會禁用按鈕，清除上次魔力變化")
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	ui.update_hud(4, "player", 10, 10, 0)

	target.shield = 0
	target.remove_status(SkillData.Status.FREEZE)
	var thunder := load("res://data/cards/arcana_thunder_pierce.tres") as CardData
	target_hp = target.current_hp
	bm.cast_arcana(thunder, target)
	_check(target.current_hp == target_hp - thunder.active_skill.power, "落雷保持同步扣血")
	await create_timer(0.15).timeout
	await _capture("_thunder")
	await create_timer(1.25).timeout
	_check(get_nodes_in_group("spell_visuals").is_empty(), "雷電回閃與餘光會全部清除")
	_check(target.current_hp == target_hp - thunder.active_skill.power, "雷電回閃不重複扣血")

	# 取消攻擊不前衝、不生成刀光；消耗行動仍遵守既有規則。
	bm.set_ward(load("res://data/cards/ward_mirror_prison.tres"), target)
	target_hp = target.current_hp
	bm.on_action_performed(attacker, attacker.data.active_skill, target)
	await create_timer(0.5).timeout
	_check(target.current_hp == target_hp and get_nodes_in_group("slash_visuals").is_empty(),
		"伏印取消攻擊技能時，不扣血或播放成功刀光")
	_check(attacker._standee.position.is_equal_approx(initial_position), "被取消行動不留下位移")
	await create_timer(1.1).timeout # 等伏印本身的既有演出結束，再獨立檢查新生成的無障礙提示。

	# 震動可疊加請求但不疊加位移；無障礙在演出中途切換也須歸位。
	var camera := root.get_camera_3d()
	var camera_base := Vector2(camera.h_offset, camera.v_offset)
	for i in 20:
		CAMERA_FX.play(attacker, 0.06)
	await create_timer(0.035).timeout
	app.reduce_motion = true
	await process_frame
	await process_frame
	_check(Vector2(camera.h_offset, camera.v_offset).is_equal_approx(camera_base), "減少動態立即停止鏡頭震動並歸位")
	attacker.take_damage(1)
	await create_timer(0.2).timeout
	_check(not get_nodes_in_group("combat_numbers").is_empty(), "減少動態仍有足夠時間讀傷害數字")
	for effect in get_nodes_in_group("transient_spatial_fx"):
		_check(effect.find_children("*", "GPUParticles3D", true, false).is_empty()
			and effect.find_children("*", "OmniLight3D", true, false).is_empty(), "減少動態不生成爆閃燈光或粒子")
	await create_timer(1.0).timeout
	app.reduce_motion = false

	seed(1993)
	var expected := randi()
	seed(1993)
	for i in 80:
		Sfx.play(Sfx.HIT)
	_check(randi() == expected, "音效變調不消耗遊戲全域 RNG")
	var hit_voices := 0
	for voice in get_nodes_in_group("sfx_voices"):
		if voice.stream == Sfx.HIT:
			hit_voices += 1
	_check(hit_voices == 1, "同幀大量命中只播放一次相同音源")
	await create_timer(1.5).timeout
	_check(get_nodes_in_group("sfx_voices").is_empty(), "音效播完會清除節點")
	var label := preload("res://src/fx/combat_number.gd").show_at(rear, "-5", Color.WHITE)
	rear.queue_free()
	await process_frame
	_check(is_instance_valid(label), "目標離場後仍能讀完傷害數字")
	await create_timer(1.0).timeout
	_check(not is_instance_valid(label), "失去目標的飄字也會自行回收")
	current_scene = null
	scene.queue_free()
	await process_frame
	print("Combat feedback review: ", "PASS" if _fails == 0 else "FAIL", " checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
