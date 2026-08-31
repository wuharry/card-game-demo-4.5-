extends SceneTree
## AI 策略驗收：固定手牌與棋盤，確認 AI 會用秘術、靈裝、伏印、
## 主動技能，並且只在能立即解鎖高價值行動時棄牌回魔。

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
	for slot in get_nodes_in_group(group):
		if slot.is_empty:
			return slot
	return null


func _grave_has(bm, side: String, card_name: String) -> bool:
	for cd in bm.sides[side].grave:
		if cd.card_name == card_name:
			return true
	return false


func _decline_next_reaction(ui) -> void:
	# ai_play_arcana() 會在反制面板的 signal 上 await；延後一幀模擬玩家
	# 按「不發動」，也順便驗證 VS AI 沒有替玩家自動做決定。
	await process_frame
	ui.reaction_decided.emit(false)


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	MatchMode.mode = MatchMode.Mode.VS_AI
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 25:
		await process_frame

	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var ai = cm.get("_enemy_ai")
	var enemy = bm.sides["enemy"]
	var player = bm.sides["player"]
	ai.step_delay = 0.45 # 戰鬥結算動畫在 0.35s 落帳，測試仍要等它完成。
	ai.think_delay = 0.0
	bm.active_side = "enemy"
	player.hand.clear() # 不讓隨機起手的瞬咒彈出人工反制面板。
	cm.get("player_hand").rebuild_from(player.hand, false)

	# 1) 同一回合中，秘術先解掉威脅，再把靈裝與伏印用在己方單位。
	var ally = bm.spawn_unit(load("res://data/cards/soldier.tres"), _first_empty("enemy_front"))
	var foe = bm.spawn_unit(load("res://data/cards/soldier.tres"), _first_empty("player_front"))
	enemy.hand.clear()
	enemy.hand.append(load("res://data/cards/arcana_fireblast.tres"))
	enemy.hand.append(load("res://data/cards/equip_mithril_plate.tres"))
	enemy.hand.append(load("res://data/cards/ward_blast_sigil.tres"))
	enemy.mana_max = 7
	enemy.mana = 7
	enemy.temp_mana = 0
	enemy.discard_cd = 0
	await ai._play_phase()
	_check(not is_instance_valid(foe) or foe.current_hp <= 0,
		"AI 會施放傷害秘術擊殺敌方單位")
	_check(ally.equipped_cards.size() == 1
		and ally.equipped_cards[0].card_name == "秘銀胸鎧",
		"AI 會把靈裝裝到有價值的己方單位")
	_check(bm.ward_count("enemy") == 1 and bm.host_has_ward(ally),
		"AI 會選擇伏印宿主並埋設伏印")
	_check(enemy.hand.is_empty() and enemy.mana == 0,
		"AI 出牌後手牌與魔力帳正確")
	_check(_grave_has(bm, "enemy", "火焰爆裂"), "AI 用過的秘術會進墓地")

	# 2) 主動技能：只有 2 魔力時先讓牧師救人，而不是依節點順序
	#    先花 1 魔力上盾；再補 1 魔力時，士兵也會使用自我增益。
	var priest = bm.spawn_unit(load("res://data/cards/priest.tres"), _first_empty("enemy_back"))
	ally.take_damage(3)
	var hp_before: int = ally.current_hp
	enemy.mana = 2
	await ai._skill_phase()
	_check(ally.current_hp > hp_before and priest.skill_used_this_turn,
		"AI 會優先把治療技能用在受傷友軍")
	_check(not ally.skill_used_this_turn and enemy.mana == 0,
		"AI 不會讓低價值技能擠掉緊急治療的魔力")
	enemy.mana = 1
	await ai._skill_phase()
	_check(ally.shield >= 2 and ally.skill_used_this_turn,
		"AI 會使用剩餘可用的自身增益主動技能")
	_check(enemy.mana == 0, "AI 技能會正確支付魔力")

	# 3) 7 魔力無法打出 9 費萬象鍛成；棄掉 4 費箭雨正好回 2，
	#    而場上已無合法箭雨目標。這是「回魔能立即解鎖強行動」的確定場景。
	enemy.hand.clear()
	enemy.hand.append(load("res://data/cards/arcana_allforge.tres"))
	enemy.hand.append(load("res://data/cards/arcana_arrow_rain.tres"))
	enemy.mana_max = 7
	enemy.mana = 7
	enemy.temp_mana = 0
	enemy.discard_cd = 0
	var shield_before: int = ally.shield
	await ai._play_phase()
	_check(enemy.discard_cd == 2, "AI 會棄掉死牌回魔")
	_check(_grave_has(bm, "enemy", "箭雨") and _grave_has(bm, "enemy", "萬象鍛成"),
		"回魔牌與後續施放的秘術都正確進墓")
	_check(ally.has_status(SkillData.Status.FORGE) and ally.shield >= shield_before + 2,
		"AI 回魔後會立即施放被解鎖的高價值秘術")
	_check(enemy.hand.is_empty() and enemy.mana == 0 and enemy.temp_mana == 0,
		"棄牌回魔與施法後的最終帳正確")

	# 4) AI 回合中的事件型瞬咒由規則層自動觸發。除了帳面離手，
	#    玩家仍看得到的手牌節點也必須同步，不能在下回合被 stash 復活。
	var quick: CardData = load("res://data/cards/quick_time_gap_barrier.tres")
	player.hand.clear()
	player.hand.append(quick)
	player.mana = quick.cost
	cm.get("player_hand").rebuild_from(player.hand, false)
	var reaction_target = bm.spawn_unit(load("res://data/cards/soldier.tres"),
		_first_empty("player_front"))
	var target_hp: int = reaction_target.current_hp
	var ally_slot = bm.find_slot_of(ally)
	cm._net_action(cm.get_path_to(ally_slot), false, false,
		str(cm.get_path_to(bm.find_slot_of(reaction_target))))
	await create_timer(0.45).timeout
	_check(player.hand.is_empty() and cm.get("player_hand").cards.is_empty(),
		"AI 行動觸發玩家瞬咒後，帳面與可見手牌同步離手")
	_check(reaction_target.current_hp == target_hp and _grave_has(bm, "player", "時隙屏障"),
		"玩家事件型瞬咒會正確反應 AI 攻擊並進墓")

	# 5) 秘術的瞬咒是互動式決策：AI 施法時不得替玩家自動打出反制。
	var decree: CardData = load("res://data/cards/quick_royal_decree.tres")
	player.hand.clear()
	player.hand.append(decree)
	player.mana = decree.cost
	cm.get("player_hand").rebuild_from(player.hand, false)
	enemy.hand.clear()
	enemy.hand.append(load("res://data/cards/arcana_fireblast.tres"))
	enemy.mana = 3
	_decline_next_reaction(cm.get("battle_ui"))
	var cast_ok: bool = await cm.ai_play_arcana(0, reaction_target)
	_check(cast_ok and (not is_instance_valid(reaction_target)
		or reaction_target.current_hp <= 0),
		"玩家拒絕反制後，AI 秘術才正常結算")
	_check(player.hand.size() == 1 and player.hand[0] == decree
		and cm.get("player_hand").cards.size() == 1,
		"AI 施法時的玩家瞬咒不會被自動消耗")

	if fails == 0:
		print("PASS AI 策略行為全數通過")
		quit(0)
	else:
		quit(1)
