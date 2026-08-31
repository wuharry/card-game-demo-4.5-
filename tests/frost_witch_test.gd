## frost_witch_test.gd — 冰霜女巫專用卡圖/Sprite/戰吼驗收(headless SceneTree 腳本)
## 跑法:Godot --headless --path <專案> -s tests/frost_witch_test.gd
extends SceneTree

var _checks := 0
var _fails := 0


func _initialize() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_run()


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _find_bm(node: Node) -> BattleManager:
	if node is BattleManager:
		return node
	for child in node.get_children():
		var found := _find_bm(child)
		if found != null:
			return found
	return null


func _slots(group: String) -> Array[CardSlot]:
	var out: Array[CardSlot] = []
	for node in get_nodes_in_group(group):
		if node is CardSlot:
			out.append(node)
	out.sort_custom(func(a: CardSlot, b: CardSlot) -> bool:
		return a.global_position.x < b.global_position.x)
	return out


func _nearest_slot(slots: Array[CardSlot], target_x: float) -> CardSlot:
	var nearest: CardSlot = null
	var best := INF
	for slot in slots:
		var distance := absf(slot.global_position.x - target_x)
		if distance < best:
			best = distance
			nearest = slot
	return nearest


func _clear_board() -> void:
	for group in ["player_front", "player_back", "enemy_front", "enemy_back"]:
		for node in get_nodes_in_group(group):
			if node is CardSlot and node.card_in_slot != null:
				var unit: Card = node.card_in_slot
				node.on_unit_died()
				unit.queue_free()


func _hand_has_path(hand: Array[CardData], path: String) -> bool:
	for cd in hand:
		if cd.resource_path == path:
			return true
	return false


func _run() -> void:
	for i in range(20):
		await process_frame
	var bm := _find_bm(root)
	var cm := root.find_child("CardManger", true, false)
	if bm == null or cm == null:
		print("FAIL:找不到 BattleManager 或 CardManger")
		quit(1)
		return

	var frost_path := "res://data/cards/frost_witch.tres"
	var frost := load(frost_path) as CardData
	var soldier := load("res://data/cards/soldier.tres") as CardData
	_check(frost != null, "冰霜女巫 CardData 可載入")
	_check(soldier != null, "測試靶 Soldier CardData 可載入")
	if frost == null or soldier == null:
		quit(1)
		return
	_check(frost.use_dedicated_art and frost.art != null, "卡面使用獨立靜態卡圖")
	_check(frost.standee != null, "Idle Sprite 可載入")
	_check(frost.battlecry != null and frost.battlecry.status_turns == 1,
		"卡面與資料都定義為凍結 1 回合")
	var summon := frost.get_anim_sheet("Summon")
	_check(summon != null, "Summon 兄弟動畫表可載入")
	if summon != null:
		_check(summon.get_width() == 600 and summon.get_height() == 100,
			"Summon 是 6×100×100 橫排")

	var hand := cm.get("player_hand") as PlayerHand
	var battle_ui := cm.get("battle_ui") as BattleUI
	_check(hand != null and battle_ui != null, "找到玩家手牌視圖與測卡 UI")
	if hand == null or battle_ui == null:
		quit(1)
		return

	# 走使用者真正會按到的入口:signal → CardManager → 指定卡/魔力/自動對位靶。
	_clear_board()
	var player_slots := _slots("player_front")
	var enemy_slots := _slots("enemy_front")
	_check(player_slots.size() >= 3 and enemy_slots.size() >= 3, "雙方前排至少三路")
	if player_slots.size() < 3 or enemy_slots.size() < 3:
		quit(1)
		return
	var total_before := bm.hand_of("player").size() + bm.deck_count("player")
	battle_ui.debug_test_pressed.emit()
	_check(_hand_has_path(bm.hand_of("player"), frost_path), "按鈕固定把冰霜女巫放進玩家手牌")
	_check(bm.active_mana() >= frost.cost, "按鈕補足可召喚冰霜女巫的魔力")
	_check(bm.hand_of("player").size() + bm.deck_count("player") == total_before,
		"準備測試前後牌堆+手牌總張數不變")

	var target_slot: CardSlot = null
	for slot in enemy_slots:
		if slot.card_in_slot != null:
			target_slot = slot
			break
	_check(target_slot != null, "按鈕自動在敵方前排建立測試靶")
	if target_slot == null:
		quit(1)
		return
	var target: Card = target_slot.card_in_slot
	var summon_slot := _nearest_slot(player_slots, target_slot.global_position.x)
	_check(summon_slot != null and summon_slot.is_empty, "測試靶正對面保留可召喚空位")
	if summon_slot == null or not summon_slot.is_empty:
		quit(1)
		return

	# 再放一隻旁路靶,證明戰吼只命中正對面而非全場。
	var off_slot: CardSlot = null
	for slot in enemy_slots:
		if slot != target_slot and slot.is_empty:
			off_slot = slot
			break
	var off_lane := bm.spawn_unit(soldier, off_slot)
	_check(off_lane != null, "建立旁路對照靶")
	if off_lane == null:
		quit(1)
		return
	_check(not target.has_status(SkillData.Status.FREEZE), "結算前正對面測試靶未凍結")

	var witch_in_hand: Card = null
	for node in hand.cards:
		var card := node as Card
		if card == null:
			continue
		if card.data != null and card.data.resource_path == frost_path:
			witch_in_hand = card
			break
	_check(witch_in_hand != null, "手牌視圖中找到冰霜女巫")
	if witch_in_hand == null:
		quit(1)
		return
	var hand_index := hand.cards.find(witch_in_hand)
	cm.set("_pending_play_card", witch_in_hand)
	cm.call("_net_summon", hand_index, frost_path, cm.get_path_to(summon_slot))
	_check(summon_slot.card_in_slot == witch_in_hand, "正式召喚流程把女巫放進對位卡槽")
	_check(target.has_status(SkillData.Status.FREEZE), "戰吼凍結正對面的測試靶")
	_check(not off_lane.has_status(SkillData.Status.FREEZE), "旁路靶不受凍結")
	var status_label := target.get_node_or_null("StatusLabel") as Label3D
	_check(status_label != null and status_label.text.contains("凍結1"),
		"狀態列顯示凍結1,與卡面敘述一致")
	_check(not hand.cards.has(witch_in_hand), "召喚後冰霜女巫已離開手牌視圖")

	# 入槽補間 0.15 秒後 show_standee:應先播 Summon,六格播完才回 Idle。
	await create_timer(0.25).timeout
	var standee := witch_in_hand.get("_standee") as Sprite3D
	_check(standee != null and standee.texture == summon, "上桌時實際播放 Summon Sprite")
	await create_timer(0.7).timeout
	_check(standee != null and standee.texture == frost.standee, "Summon 播完自動切回 Idle")

	# 走正式換回合入口:它會先 stash 視圖再換邊,同時驗證帳與視圖不會分家。
	# 受害者緊接著的第一次開始階段會略過遞減,第二次開始才解除。
	cm.call("_net_end_turn")
	_check(not _hand_has_path(bm.hand_of("player"), frost_path), "換回合後帳上也已扣除冰霜女巫")
	_check(bm.active_side == "enemy", "換到敵方第一回合")
	_check(target.has_status(SkillData.Status.FREEZE), "敵方第一回合開始後仍處於凍結")
	_check(bm.attack_block_reason(target).contains("凍結"), "凍結會實際阻止該回合攻擊")
	cm.call("_net_end_turn")   # 回玩家;敵方狀態不在別人的開始階段遞減
	cm.call("_net_end_turn")   # 再回敵方;第二次敵方開始才解除
	_check(not target.has_status(SkillData.Status.FREEZE), "封鎖一個敵方回合後凍結解除")

	print("")
	if _fails == 0:
		print("PASS 冰霜女巫 %d 斷言全過" % _checks)
	else:
		print("FAIL %d/%d 斷言未過" % [_fails, _checks])
	quit(1 if _fails > 0 else 0)
