extends SceneTree
## 單人 vs AI 驗收:玩家結束回合 → AI 自動召喚+攻擊+還回合;
## 視圖鎖玩家(AI 回合手牌不換頁)、卡背扇形張數對帳。

var fails := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		fails += 1
		print("FAIL: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _first_empty(group: String):
	for s in get_nodes_in_group(group):
		if s.is_empty:
			return s
	return null


func _units_in(groups: Array) -> int:
	var n := 0
	for g in groups:
		for s in get_nodes_in_group(g):
			if s.card_in_slot != null:
				n += 1
	return n


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	MatchMode.mode = MatchMode.Mode.VS_AI
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 25:
		await process_frame

	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var ph = cm.get("player_hand")

	# 預置:AI 帳裡塞一張便宜從者(保證有牌可出);雙方各一隻場上單位(驗攻擊,
	# spawn_unit 不 mark_summoned → 沒有召喚暈眩,AI 的劍士當回合就能動)
	bm.sides["enemy"].hand.append(load("res://data/cards/skeleton.tres"))
	var e_unit = bm.spawn_unit(load("res://data/cards/swordsman.tres"), _first_empty("enemy_front"))
	var p_unit = bm.spawn_unit(load("res://data/cards/knight.tres"), _first_empty("player_front"))
	var p_hp0: int = p_unit.current_hp
	var e_board0 := _units_in(["enemy_front", "enemy_back"])
	var view0: int = ph.cards.size()

	_check(cm.get("_enemy_ai") != null, "VS_AI 模式有生出 EnemyAI")
	_check(cm.get("_opp_hand") != null, "有生出對手卡背扇形")

	# 玩家結束回合 → AI 上工
	cm._on_end_turn()
	await create_timer(0.5).timeout
	_check(bm.active_side == "enemy", "回合已交給 enemy(AI)")
	_check(ph.cards.size() == view0, "AI 回合開始:玩家手牌視圖沒被換頁(不攤 AI 的牌)")

	# 等 AI 打完整個回合(輪回 player 為止,上限 15 秒)
	var waited := 0.0
	while bm.active_side != "player" and waited < 15.0:
		await create_timer(0.25).timeout
		waited += 0.25
	_check(bm.active_side == "player", "AI 自己結束了回合(耗時 %.1fs)" % waited)
	# 別數「場上總數」(預置劍士可能吃反擊陣亡),也別認卡名(起手隨機,AI 可能
	# 先挑到別張便宜從者)——認「召喚暈眩標記」:AI 回合結束只重置玩家側旗標,
	# 這回合被 AI 召喚的單位 summoned_this_turn 會留著。
	var summoned := 0
	for g in ["enemy_front", "enemy_back"]:
		for s in get_nodes_in_group(g):
			if s.card_in_slot != null and s.card_in_slot.summoned_this_turn:
				summoned += 1
	_check(summoned >= 1, "AI 有召喚新單位上場(帶暈眩標記 %d 隻,e_board0=%d)" % [summoned, e_board0])
	var attacked: bool = (not is_instance_valid(p_unit)) or p_unit.current_hp < p_hp0 \
		or bm.player_hero.hp < 20
	_check(attacked, "AI 有發動攻擊(玩家單位受傷/陣亡或本體被打)")
	var opp_n: int = cm.get("_opp_hand")._backs.filter(func(b): return b.visible).size()
	_check(opp_n == bm.hand_of("enemy").size() or bm.hand_of("enemy").size() > 8,
		"卡背扇形張數與 AI 帳一致(%d)" % opp_n)
	_check(ph.cards.size() == view0 + 1, "輪回玩家:視圖只多了新抽那張(%d→%d)" % [view0, ph.cards.size()])

	if fails == 0:
		print("PASS 單人 vs AI 全數通過")
		quit(0)
	else:
		quit(1)
