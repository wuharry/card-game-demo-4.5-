extends SceneTree
## 墓地+丟牌回魔(§1.1)回歸:
## 死亡入土(含隨葬靈裝)、伏印觸發入土、秘術/瞬咒用畢入土(走連線重放函式)、
## 丟牌回魔(回魔量=Cost÷2 捨去/冷卻隔回合/離手/入土)、墓地視覺與帳對齊。
## 用法:godot --headless --path . -s tests/grave_test.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		fails += 1
		print("FAIL: " + msg)


func _first_empty(group: String):
	for s in get_nodes_in_group(group):
		if s.is_empty:
			return s
	return null


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")

	# ── 1) 死亡入土 + 靈裝隨葬 ──
	var soldier := load("res://data/cards/soldier.tres") as CardData
	var equipcd := load("res://data/cards/equip_mithril_plate.tres") as CardData
	var unit = bm.spawn_unit(soldier, _first_empty("player_front"))
	await create_timer(0.4).timeout   # 等入槽補間收斂
	bm.attach_equip(equipcd, unit)
	var base_p: int = bm.grave_count("player")
	bm._deal_damage(unit, 99, false)
	bm._check_death(unit)
	_check(bm.grave_count("player") == base_p + 2, "陣亡入土+靈裝隨葬(我墓 +2)")
	_check(bm.grave_top("player") == equipcd, "隨葬的靈裝躺最上面")

	# ── 2) 伏印觸發入土(敵方的伏印,埋進敵方的墓)──
	var ward := load("res://data/cards/ward_blast_sigil.tres") as CardData
	bm.sides["enemy"].wards.append({"cd": ward, "host": null})   # 宿主制的帳形
	var unit2 = bm.spawn_unit(soldier, _first_empty("player_front"))
	await create_timer(0.4).timeout
	var base_e: int = bm.grave_count("enemy")
	bm.mark_summoned(unit2)
	_check(bm.grave_count("enemy") == base_e + 1, "伏印觸發後入土(敵墓 +1)")
	_check(bm.grave_top("enemy") == ward, "觸發的伏印躺敵墓最上面")

	# ── 3) 秘術+瞬咒入土(走 _net_arcana_resolve:連線/AI 同一條路)──
	var arcana := load("res://data/cards/arcana_fireblast.tres") as CardData
	var quick := load("res://data/cards/quick_void_rebuke.tres") as CardData
	bm.sides["enemy"].hand.clear()
	bm.sides["enemy"].hand.append(quick)
	bm.sides["enemy"].mana = 9
	cm._pending_arcana_path = arcana.resource_path
	cm._pending_arcana_target = NodePath("")
	var pb: int = bm.grave_count("player")
	var eb: int = bm.grave_count("enemy")
	cm._net_arcana_resolve(true)   # 守方反制成功
	_check(bm.grave_count("player") == pb + 1, "秘術被抵銷仍入土(我墓 +1)")
	_check(bm.grave_count("enemy") == eb + 1, "反制用的瞬咒入土(敵墓 +1)")

	# ── 4) 丟牌回魔:回魔量/離手/入土/冷卻節奏 ──
	var ph = cm.get("player_hand")
	var hand_n: int = ph.cards.size()
	# 挑手上費用最高的牌來棄:cost 1 的牌回魔 0,驗不出「有沒有真的加魔」。
	var card0 = ph.cards[0]
	for c in ph.cards:
		if c.data.cost > card0.data.cost:
			card0 = c
	var expect: int = floori(card0.data.cost / 2.0)
	var mana0: int = bm.active_mana()
	var pg: int = bm.grave_count("player")
	cm._pending_play_card = card0
	cm._net_discard(ph.cards.find(card0), card0.data.resource_path)
	_check(bm.active_mana() == mana0 + expect, "回魔 = Cost÷2 捨去(◆%d→◆%d)" % [mana0, bm.active_mana()])
	_check(ph.cards.size() == hand_n - 1, "棄的牌離開手牌視圖")
	_check(bm.grave_count("player") == pg + 1, "棄的牌入土")
	_check(not bm.can_discard_for_mana("player"), "同回合不能再棄(冷卻中)")
	bm._begin_side_turn(bm.sides["player"])
	_check(not bm.can_discard_for_mana("player"), "下一個自己回合:仍在冷卻(隔回合一次)")
	bm._begin_side_turn(bm.sides["player"])
	_check(bm.can_discard_for_mana("player"), "再下一回合:冷卻結束")

	# ── 5) 墓地視覺對帳(GravePile 顯示的張數 = 帳上的張數)──
	await create_timer(0.3).timeout
	var piles: Dictionary = cm.get("_grave_piles")
	_check(piles["player"].shown_count == bm.grave_count("player"), "玩家墓視覺張數=帳")
	_check(piles["enemy"].shown_count == bm.grave_count("enemy"), "敵方墓視覺張數=帳")

	if fails == 0:
		print("PASS 墓地+丟牌回魔 14 斷言全過")
		quit(0)
	else:
		quit(1)
