## spell_smoke.gd — 法術結算煙霧測試(headless SceneTree 腳本)
## 跑法:Godot --headless --path <專案> -s <本檔>
## 驗證:伏印觸發 / 秘術傷害與致死 / 靈裝加成 / 蓋放進帳 / 瞬咒候選。
extends SceneTree

var _checks := 0
var _fails := 0


func _initialize() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var ps: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = ps.instantiate()
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
	for c in node.get_children():
		var r := _find_bm(c)
		if r != null:
			return r
	return null


func _first_empty_in(group: String) -> CardSlot:
	for s in get_nodes_in_group(group):
		if s is CardSlot and s.is_empty:
			return s
	return null


func _run() -> void:
	for i in range(20):
		await process_frame

	var bm := _find_bm(root)
	if bm == null:
		print("FAIL: 找不到 BattleManager 節點")
		quit(1)
		return

	# ── 開局帳 sanity ──
	_check(bm.active_side == "player", "開局行動方是 player")
	_check(bm.hand_of("player").size() == 5, "玩家起手 5 張(實際 %d)" % bm.hand_of("player").size())
	_check(bm.deck_count("player") == 55, "玩家牌堆 60-5=55(實際 %d)" % bm.deck_count("player"))

	var knight_cd: CardData = load("res://data/cards/knight.tres")       # hp 6, 鐵壁
	var fireblast_cd: CardData = load("res://data/cards/arcana_fireblast.tres")  # power 3
	var mithril_cd: CardData = load("res://data/cards/equip_mithril_plate.tres") # amount 2
	var ward_cd: CardData = load("res://data/cards/ward_blast_sigil.tres")       # power 2
	var quick_cd: CardData = load("res://data/cards/quick_void_rebuke.tres")

	# ── (a) spawn_unit + mark_summoned:對面(敵方)有伏印 → 觸發傷害 ──
	# active_side = "player" → mark_summoned 會去掏 enemy 側的 wards。
	bm.sides["enemy"].wards.append(ward_cd)
	var slot1 := _first_empty_in("player_front")
	if slot1 == null:
		print("FAIL: 找不到空的 player_front 卡槽")
		quit(1)
		return
	var unit1: Card = bm.spawn_unit(knight_cd, slot1)
	_check(unit1 != null, "(a) spawn_unit 生出單位")
	if unit1 == null:
		quit(1)
		return
	var msg: String = bm.mark_summoned(unit1)
	_check(unit1.summoned_this_turn, "(a) 召喚暈眩旗標已立")
	_check(msg != "", "(a) 伏印觸發訊息非空")
	# 伏印走 _deal_damage(minion_attack=false):鐵壁不擋 → 6-2=4。
	_check(unit1.current_hp == 4, "(a) 伏印傷害落地 6-2=4(實際 %d)" % unit1.current_hp)
	_check(bm.sides["enemy"].wards.is_empty(), "(a) 伏印用掉即離帳")

	# ── (b) cast_arcana 火焰爆裂:對單位造成 power=3 傷害 ──
	var slot2 := _first_empty_in("enemy_front")
	if slot2 == null:
		print("FAIL: 找不到空的 enemy_front 卡槽")
		quit(1)
		return
	var unit2: Card = bm.spawn_unit(knight_cd, slot2)
	bm.cast_arcana(fireblast_cd, unit2)
	_check(unit2.current_hp == 3, "(b) 火焰爆裂 6-3=3(實際 %d)" % unit2.current_hp)
	# 連丟兩發打死:cast_arcana 內建 _check_death → 卡槽應立即清位。
	bm.cast_arcana(fireblast_cd, unit2)
	bm.cast_arcana(fireblast_cd, unit2)
	_check(slot2.is_empty, "(b) 秘術致死後卡槽立即清位")

	# ── (c) attach_equip 秘銀胸鎧:max_hp_bonus +2 並補等量現血 ──
	bm.attach_equip(mithril_cd, unit1)
	_check(unit1.max_hp_bonus == 2, "(c) max_hp_bonus == 2(實際 %d)" % unit1.max_hp_bonus)
	_check(unit1.current_hp == 6, "(c) 現血 4+2=6(實際 %d)" % unit1.current_hp)

	# ── (d) set_ward:蓋放進「行動方」的伏印帳 ──
	bm.set_ward(ward_cd)
	_check(bm.sides["player"].wards.size() == 1, "(d) set_ward 進玩家伏印帳")

	# ── 加碼:quick_candidate(守方手上第一張付得起的瞬咒)──
	bm.sides["enemy"].hand.append(quick_cd)
	bm.sides["enemy"].mana = 10
	_check(bm.quick_candidate("enemy") == quick_cd, "(+) quick_candidate 找到守方瞬咒")

	if _fails > 0:
		print("FAIL: %d/%d 斷言未過" % [_fails, _checks])
		quit(1)
	else:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
