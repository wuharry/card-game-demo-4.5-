extends SceneTree
## 伏印宿主制+裝備替換 回歸(§7 對齊桌遊 v0.1):
## 埋設綁宿主、整排紅色警戒(含後排:不洩漏宿主)、宿主陣亡伏印隨葬、
## 觸發後警戒熄滅、靈裝一次一件新蓋舊(舊裝入墓、加成不疊、現血夾回)。
## 用法:godot --headless --path . -s tests/ward_equip_test.gd

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


func _alert_of(slot) -> float:
	var v: Variant = slot._tile_mat.get_shader_parameter("ward_alert")
	return float(v) if v != null else 0.0


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var knight := load("res://data/cards/knight.tres") as CardData        # hp 6
	var mithril := load("res://data/cards/equip_mithril_plate.tres") as CardData  # +2
	var ward := load("res://data/cards/ward_blast_sigil.tres") as CardData

	# ── 1) 埋設:宿主綁定+整排(含後排)紅色警戒亮起 ──
	var host = bm.spawn_unit(knight, _first_empty("player_front"))
	await create_timer(0.4).timeout
	bm.set_ward(ward, host)
	_check(bm.ward_count("player") == 1, "伏印進帳(宿主制)")
	_check(bm.host_has_ward(host), "host_has_ward 認得宿主")
	await create_timer(0.7).timeout   # 警戒淡入 0.4s,等收斂
	var back_slot = get_nodes_in_group("player_back")[0]
	_check(_alert_of(back_slot) > 0.9,
		"整排卡槽警戒亮起(後排也亮:視覺不洩漏宿主在哪)")

	# ── 2) 宿主陣亡 → 未觸發的伏印隨葬+警戒熄滅 ──
	var g0: int = bm.grave_count("player")
	bm._deal_damage(host, 99, false)
	bm._check_death(host)
	_check(bm.grave_count("player") == g0 + 2, "宿主+未觸發伏印一起入墓(+2)")
	_check(bm.ward_count("player") == 0, "伏印離帳")
	await create_timer(0.7).timeout
	_check(_alert_of(back_slot) < 0.1, "警戒熄滅")

	# ── 3) 觸發路徑:敵方伏印(帶宿主)→ 我方召喚觸發 → 敵警戒熄 ──
	var e_host = bm.spawn_unit(knight, _first_empty("enemy_back"))
	await create_timer(0.4).timeout
	bm.set_ward(ward, e_host)
	var e_slot = get_nodes_in_group("enemy_front")[0]
	await create_timer(0.7).timeout
	_check(_alert_of(e_slot) > 0.9, "敵方整排警戒亮")
	var victim = bm.spawn_unit(knight, _first_empty("player_front"))
	await create_timer(0.4).timeout
	var msg: String = bm.mark_summoned(victim)
	_check(msg != "", "召喚觸發敵方伏印")
	_check(bm.ward_count("enemy") == 0, "觸發後伏印離帳")
	await create_timer(0.7).timeout
	_check(_alert_of(e_slot) < 0.1, "觸發後敵方警戒熄滅")

	# ── 4) 裝備替換:一次一件、新蓋舊 ──
	var u = bm.spawn_unit(knight, _first_empty("player_front"))
	await create_timer(0.4).timeout
	bm.attach_equip(mithril, u)   # 第一件:6/6 → 8/8
	var g1: int = bm.grave_count("player")
	var replaced: String = bm.attach_equip(mithril, u)   # 第二件:替換
	_check(replaced != "", "回報被替換的舊裝名(%s)" % replaced)
	_check(u.equipped_cards.size() == 1, "同時只有一件靈裝")
	_check(u.max_hp_bonus == 2, "加成不疊(2,不是 4)")
	_check(bm.grave_count("player") == g1 + 1, "舊裝進墓地")
	_check(u.current_hp == 8, "替換後現血:拆舊夾回 6 → 新裝補 2 = 8(實際 %d)" % u.current_hp)

	if fails == 0:
		print("PASS 伏印宿主制+裝備替換 13 斷言全過")
		quit(0)
	else:
		quit(1)
