extends SceneTree
## 9–13 費高階卡結算回歸：丟牌跨越 7 魔力上限、事件型瞬咒、複合秘術、
## 新靈裝欄位、死亡替代伏印與不滅指定復活血量。

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
	for slot in get_nodes_in_group(group):
		if slot.is_empty:
			return slot
	return null


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var player = bm.sides["player"]
	var enemy = bm.sides["enemy"]
	player.hand.clear()
	enemy.hand.clear()

	# 1) 自然魔力固定封頂 7；棄 12 費牌得到 6 點暫時魔力，剛好能支付 13 費。
	player.mana_max = 7
	player.mana = 7
	var discard_12 := load("res://data/cards/quick_soul_substitution.tres") as CardData
	var gained: int = bm.apply_discard_for_mana("player", discard_12)
	_check(gained == 6 and player.mana == 13 and player.temp_mana == 6,
		"7 魔力 + 棄 12 費 = 13（其中 6 點為暫時魔力）")
	_check(bm.can_afford(13), "13 費終結卡可由丟牌回魔支付")
	bm._begin_side_turn(player)
	_check(player.mana_max == 7 and player.mana == 7 and player.temp_mana == 0,
		"換回合後自然魔力仍封頂 7，暫時魔力歸零")

	# 2) 瞬咒只回應自己支援的事件；絕對否決則涵蓋所有高階事件。
	var time_gap := load("res://data/cards/quick_time_gap_barrier.tres") as CardData
	var absolute := load("res://data/cards/quick_absolute_denial.tres") as CardData
	enemy.mana = 13
	enemy.hand.append(time_gap)
	_check(bm.quick_candidate("enemy", &"normal_attack") == time_gap,
		"時隙屏障只進普通攻擊反應窗")
	_check(bm.quick_candidate("enemy", &"arcana") == null,
		"時隙屏障不會誤反制秘術")
	enemy.hand.clear()
	enemy.hand.append(absolute)
	_check(bm.quick_candidate("enemy", &"summon") == absolute
		and bm.quick_candidate("enemy", &"ward") == absolute,
		"絕對否決支援召喚與伏印事件")
	enemy.hand.clear()

	# 3) 新靈裝改的是單位實例：攻血、關鍵字與吸血皆會隨替換正確收回。
	var soldier := load("res://data/cards/soldier.tres") as CardData
	var host = bm.spawn_unit(soldier, _first_empty("player_front"))
	await create_timer(0.4).timeout
	var warplate := load("res://data/cards/equip_giant_warplate.tres") as CardData
	var bloodblade := load("res://data/cards/equip_blood_pact_greatblade.tres") as CardData
	bm.attach_equip(warplate, host)
	_check(host.current_hp == soldier.hp + 8 and host.has_keyword(&"鐵壁"),
		"巨神戰鎧提供 +8 生命與鐵壁")
	bm.attach_equip(bloodblade, host)
	_check(host.atk_total() == soldier.atk + 5 and host.current_hp == soldier.hp + 2,
		"血契巨刃替換舊裝後只保留 +5/+2")
	_check(host.has_equipped_lifesteal() and not host.has_keyword(&"鐵壁"),
		"替換後取得普攻吸血，舊裝鐵壁已收回")

	# 4) 複合秘術走 special_id 結算，會實際改動全場單位。
	# 用能撐過 4 傷的目標，才能同時驗證傷害後追加的灼燒。
	var sturdy_foe := load("res://data/cards/knight.tres") as CardData
	var foe = bm.spawn_unit(sturdy_foe, _first_empty("enemy_front"))
	await create_timer(0.4).timeout
	var allforge := load("res://data/cards/arcana_allforge.tres") as CardData
	var skyfire := load("res://data/cards/arcana_skyfire_fall.tres") as CardData
	bm.resolve_special_arcana(allforge, "player")
	_check(host.has_status(SkillData.Status.FORGE) and host.shield == 2,
		"萬象鍛成給我方全體鍛強 2 與護盾 2")
	var foe_hp: int = foe.current_hp
	bm.resolve_special_arcana(skyfire, "player")
	_check(foe.current_hp == foe_hp - 4 and foe.has_status(SkillData.Status.BURN),
		"天火墜落對敵方全體造成 4 傷並施加灼燒")

	# 5) 死亡替代：輪迴伏印優先救回宿主；墓海巨像依資料以 5 HP 不滅復活。
	var reincarnation := load("res://data/cards/ward_reincarnation_sigil.tres") as CardData
	bm.set_ward(reincarnation, host)
	host.current_hp = 0
	bm._check_death(host)
	_check(host.current_hp == soldier.hp + 2 and host.shield == 7,
		"輪迴伏印完全恢復並在原有 2 盾上再加 5 盾")
	_check(not bm.host_has_ward(host), "輪迴伏印觸發後離帳")

	var colossus_cd := load("res://data/cards/tombsea_colossus.tres") as CardData
	var colossus = bm.spawn_unit(colossus_cd, _first_empty("player_back"))
	await create_timer(0.4).timeout
	colossus.current_hp = 0
	bm._check_death(colossus)
	_check(colossus.current_hp == 5 and colossus.revived,
		"墓海巨像首次陣亡依 revive_hp=5 復活")

	if fails == 0:
		print("PASS 高階卡結算 14 斷言全過")
		quit(0)
	else:
		quit(1)
