extends SceneTree
## 真實牌桌驗證：演出不改同步傷害，反制不誤播，貫穿位置在致死清槽前保存。
## godot --headless --path . --script res://tests/spell_visual_integration_test.gd

var _checks := 0
var _fails := 0
var _events: Array[Dictionary] = []
var _reaction_was_visible := false


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: ", message)
	else:
		_fails += 1
		push_error(message)


func _record_visual(card: CardData, positions: Array[Vector3]) -> void:
	_events.append({"card": card, "positions": positions.duplicate()})


func _accept_reaction(ui: BattleUI) -> void:
	await process_frame
	var panel := ui.get("_react_panel") as PanelContainer
	_reaction_was_visible = panel != null and panel.visible
	ui._answer_reaction(true)


func _run() -> void:
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 25:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	if cm == null:
		_check(false, "真實牌桌須能建立 CardManager")
		quit(1)
		return
	var bm: BattleManager = cm.battle_manager
	bm.arcana_visual_requested.connect(_record_visual)
	for side in ["player", "enemy"]:
		bm.hand_of(side).clear() # 不讓隨機起手牌替測試目標自動擋傷或取消伏印。
	cm.player_hand.rebuild_from(bm.hand_of("player"), false)
	var knight := load("res://data/cards/knight.tres") as CardData
	var fire := load("res://data/cards/arcana_fireblast.tres") as CardData
	var frost := load("res://data/cards/arcana_frozen_pulse.tres") as CardData
	var thunder := load("res://data/cards/arcana_thunder_pierce.tres") as CardData
	var mirror := load("res://data/cards/ward_mirror_prison.tres") as CardData
	var quick := load("res://data/cards/quick_void_rebuke.tres") as CardData
	var front_slot := get_nodes_in_group("enemy_front")[0] as CardSlot
	var back_slot: CardSlot = null
	for slot in get_nodes_in_group("enemy_back"):
		if absf(slot.global_position.x - front_slot.global_position.x) < 0.1:
			back_slot = slot as CardSlot
			break
	if back_slot == null:
		_check(false, "測試棋盤須有同路線前後排")
		quit(1)
		return
	var front := bm.spawn_unit(knight, front_slot)
	var back := bm.spawn_unit(knight, back_slot)
	var center := front.global_position + Vector3(0, 0.65, 0)
	var back_center := back.global_position + Vector3(0, 0.65, 0)

	# 不 await：回傳訊息時就必須已經扣血，視覺 signal 同時保存世界位置。
	var hp_before := front.current_hp
	var message := bm.cast_arcana(fire, front)
	_check(front.current_hp == hp_before - fire.active_skill.power,
		"成功火焰秘術仍同步扣血")
	_check(not message.is_empty() and _events.size() == 1,
		"成功秘術只發出一次視覺請求並回傳戰報")
	if not _events.is_empty():
		_check(_events[-1].card == fire and _events[-1].positions == [center],
			"視覺請求使用真實卡資料與目標世界命中中心")

	front.current_hp = knight.hp
	bm.cast_arcana(frost, front)
	_check(front.current_hp == knight.hp - frost.active_skill.power
		and front.has_status(SkillData.Status.FREEZE),
		"冰系秘術的傷害與凍結仍在返回前完成")

	# 伏印在 cast_arcana 內才判定，不能在 CardManager 宣告時先播成功命中。
	var events_before := _events.size()
	hp_before = front.current_hp
	bm.set_ward(mirror, front)
	message = bm.cast_arcana(fire, front)
	_check(_events.size() == events_before and front.current_hp == hp_before,
		"鏡牢伏印取消指定後，不扣血也不發出成功演出")
	_check(message.contains("取消") and not bm.host_has_ward(front),
		"伏印仍依原規則消耗並回報取消")

	# 致死時卡槽會立刻清空；兩個命中中心必須先保存下來。
	front.current_hp = 1
	back.current_hp = 1
	bm.cast_arcana(thunder, front)
	_check(front_slot.is_empty and back_slot.is_empty,
		"雷霆貫穿同步擊殺同路線前後排")
	_check(_events.size() == events_before + 1,
		"貫穿只發一次請求，由同一請求帶出全部命中位置")
	if not _events.is_empty():
		_check(_events[-1].positions == [center, back_center],
			"貫穿位置快照在前後排致死清槽後仍完整")
	back = bm.spawn_unit(knight, back_slot)
	bm.cast_arcana(thunder, back)
	if not _events.is_empty():
		_check(_events[-1].positions == [back_center],
			"直接指定後排時不憑空增加貫穿目標")

	# 走真正的熱座出牌與反制面板：被瞬咒取消仍付費入墓，但不請求演出。
	back.current_hp = knight.hp
	bm.hand_of("player").append(fire)
	bm.sides["player"].mana = fire.cost
	bm.sides["player"].temp_mana = 0
	cm.player_hand.rebuild_from(bm.hand_of("player"), false)
	bm.hand_of("enemy").append(quick)
	bm.sides["enemy"].mana = quick.cost
	bm.sides["enemy"].temp_mana = 0
	events_before = _events.size()
	_accept_reaction(cm.battle_ui)
	await cm._resolve_arcana(cm.player_hand.cards[0], back)
	_check(_reaction_was_visible, "熱座反制確實由玩家面板決定")
	_check(_events.size() == events_before and back.current_hp == knight.hp,
		"瞬咒抵銷後不扣血，也不發出成功演出")
	_check(bm.sides["player"].mana == 0 and bm.sides["enemy"].mana == 0
		and cm.player_hand.cards.is_empty(), "抵銷仍支付雙方費用並消耗秘術手牌")

	# AI 與連線重放都走同一 signal，不需要為各種入口維護三套特效觸發。
	MatchMode.mode = MatchMode.Mode.VS_AI
	bm.active_side = "enemy"
	bm.hand_of("player").clear()
	bm.hand_of("enemy").append(fire)
	bm.sides["enemy"].mana = fire.cost
	var ally_slot := get_nodes_in_group("player_front")[0] as CardSlot
	var ally := bm.spawn_unit(knight, ally_slot)
	events_before = _events.size()
	var cast_ok: bool = await cm.ai_play_arcana(0, ally)
	_check(cast_ok and ally.current_hp == knight.hp - fire.active_skill.power
		and _events.size() == events_before + 1, "AI 秘術同樣只觸發一次成功演出")
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	bm.active_side = "player"
	back.current_hp = knight.hp
	cm.set("_pending_arcana_path", fire.resource_path)
	cm.set("_pending_arcana_target", cm.get_path_to(back_slot))
	events_before = _events.size()
	cm._net_arcana_resolve(false)
	_check(back.current_hp == knight.hp - fire.active_skill.power
		and _events.size() == events_before + 1,
		"連線結算的本地重放同步扣血並發出一次演出")

	# 專用伺服器收到視覺 signal 也不建立節點；不啟動網路或改動傷害規則。
	var children_before := scene.get_child_count()
	NetMatch.is_dedicated_server = true
	var positions: Array[Vector3] = [back_center]
	cm._on_arcana_visual_requested(fire, positions)
	NetMatch.is_dedicated_server = false
	_check(scene.get_child_count() == children_before,
		"專用伺服器的視覺消費端不生成特效節點")
	await create_timer(1.8).timeout
	print("Spell visual integration: ", "PASS" if _fails == 0 else "FAIL",
		" checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
