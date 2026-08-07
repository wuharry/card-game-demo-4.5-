extends SceneTree
## 秘術分派器補完驗收:HEAL / APPLY_STATUS / SUMMON / Modifier 四條新路。
##   godot --headless -s tests/arcana_effects_test.gd
##
## 為什麼卡是在這裡「用 code 捏」而不是先寫 .tres?
## 這支驗的是**分派器接得對不對**(系統合約),不是某張卡的數值。
## 捏在測試裡,才不會為了測試往 data/cards 塞一堆假卡汙染牌池與圖鑑。

const CARD_DATA := preload("res://src/card/card_data.gd")
const SKILL_DATA := preload("res://src/card/skill_data.gd")

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok: " + label)
	else:
		_fail += 1
		print("FAIL: " + label)


## 捏一張秘術卡:type=ARCANA,技能參數由呼叫端指定。
func _make_arcana(nm: String, effect: int, target: int, power: int, amount: int,
		status: int = 0, turns: int = 1, modifier: int = 0,
		summon: String = "") -> Resource:
	var sk: Resource = SKILL_DATA.new()
	sk.skill_name = nm
	sk.kind = SKILL_DATA.Kind.NON_ATTACK
	sk.effect = effect
	sk.effect_target = target
	sk.power = power
	sk.amount = amount
	sk.status = status
	sk.status_turns = turns
	sk.modifier = modifier
	sk.summon_card = summon
	var cd: Resource = CARD_DATA.new()
	cd.card_type = CARD_DATA.CardType.ARCANA
	cd.card_name = nm
	cd.cost = 1
	cd.active_skill = sk
	return cd


func _first_empty(group: String):
	for s in get_nodes_in_group(group):
		if s.is_empty:
			return s
	return null


func _run() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var knight: Resource = load("res://data/cards/knight.tres")

	# ── 1. 「要不要選目標」由 effect_target 決定,不由 effect 種類 ──
	var heal_card := _make_arcana("聖光", SKILL_DATA.Effect.HEAL,
		SKILL_DATA.Target.ALLY, 0, 3)
	var draw_card := _make_arcana("靈感", SKILL_DATA.Effect.DRAW,
		SKILL_DATA.Target.SELF, 0, 2)
	var dmg_card := _make_arcana("火球", SKILL_DATA.Effect.NONE,
		SKILL_DATA.Target.LANE_ENEMY, 3, 0)
	_check(cm._spell_needs_target(heal_card), "HEAL(ALLY)要選目標")
	_check(not cm._spell_needs_target(draw_card), "DRAW(SELF)不用選目標")
	_check(cm._spell_needs_target(dmg_card), "傷害(LANE_ENEMY)要選目標")
	# 舊的白名單寫法會把 HEAL 判成「無目標」——這條就是那個 bug 的守門員。
	_check(not cm._is_effect_spell(heal_card), "HEAL 不會被誤判成無目標秘術")

	# ── 2. HEAL:治療我方單位 ──
	var slot_p = _first_empty("player_front")
	var ally: Card = bm.spawn_unit(knight, slot_p)
	var full: int = ally.current_hp
	ally.current_hp = maxi(1, full - 4)
	var before: int = ally.current_hp
	var msg: String = bm.cast_arcana(heal_card, ally)
	_check(ally.current_hp == mini(full, before + 3),
		"HEAL:%d → %d(+3,不超過上限 %d)" % [before, ally.current_hp, full])
	_check(msg.contains("治療"), "HEAL 的訊息講的是治療不是傷害(實際:%s)" % msg)

	# ── 3. APPLY_STATUS:傷害 + 上狀態的複合秘術 ──
	var slot_e = _first_empty("enemy_front")
	var foe: Card = bm.spawn_unit(knight, slot_e)
	var foe_hp: int = foe.current_hp
	var burn_card := _make_arcana("烈焰", SKILL_DATA.Effect.APPLY_STATUS,
		SKILL_DATA.Target.LANE_ENEMY, 2, 0, SKILL_DATA.Status.BURN, 2)
	msg = bm.cast_arcana(burn_card, foe)
	_check(foe.current_hp == foe_hp - 2,
		"APPLY_STATUS:傷害有落地 %d → %d" % [foe_hp, foe.current_hp])
	_check(foe.has_status(SKILL_DATA.Status.BURN), "APPLY_STATUS:灼燒有掛上")

	# ── 4. Modifier:秘術也能橫掃(以前只有從者攻擊讀得到 modifier)──
	var e_slots := get_nodes_in_group("enemy_front")
	var victims: Array = []
	for s in e_slots:
		if s.is_empty:
			var u: Card = bm.spawn_unit(knight, s)
			if u != null:
				victims.append(u)
	if victims.size() >= 2:
		var hp_before: Array = []
		for u in victims:
			hp_before.append(u.current_hp)
		var sweep := _make_arcana("烈風", SKILL_DATA.Effect.NONE,
			SKILL_DATA.Target.LANE_ENEMY, 1, 0, 0, 1,
			SKILL_DATA.Modifier.SPREAD_3)
		bm.cast_arcana(sweep, victims[0])
		var hit := 0
		for i in victims.size():
			if victims[i].current_hp < hp_before[i]:
				hit += 1
		_check(hit >= 2, "SPREAD_3:秘術打到 %d 隻(不只主目標)" % hit)
	else:
		print("  skip: 敵方前排空位不足,跳過橫掃驗證")

	# ── 5. SUMMON:無施法單位的召喚秘術 ──
	var before_units := get_nodes_in_group("player_front").size() \
		+ get_nodes_in_group("player_back").size()
	var filled_before := 0
	for g in ["player_front", "player_back"]:
		for s in get_nodes_in_group(g):
			if not s.is_empty:
				filled_before += 1
	var summon_card := _make_arcana("亡者甦醒", SKILL_DATA.Effect.SUMMON,
		SKILL_DATA.Target.SELF, 0, 0, 0, 1, 0, "skeleton")
	msg = bm.summon_for_side("player", summon_card.active_skill)
	var filled_after := 0
	for g in ["player_front", "player_back"]:
		for s in get_nodes_in_group(g):
			if not s.is_empty:
				filled_after += 1
	_check(filled_after == filled_before + 1,
		"SUMMON:我方場上單位 %d → %d" % [filled_before, filled_after])
	_check(msg != "", "SUMMON 有回傳訊息(實際:%s)" % msg)

	# ── 6. 鐵壁不吃秘術傷害(§8:只減免「從者攻擊」)──
	var slot_e2 = _first_empty("enemy_back")
	if slot_e2 != null:
		var tank: Card = bm.spawn_unit(knight, slot_e2)
		tank.data = tank.data.duplicate()          # 別汙染共享的 Resource(主帳 §7)
		var kw: Array[StringName] = [&"鐵壁"]      # keywords 是 Array[StringName],不是 PackedStringArray
		tank.data.keywords = kw
		tank.iron_wall_used_this_turn = false
		var thp: int = tank.current_hp
		bm.cast_arcana(dmg_card, tank)
		_check(tank.current_hp == thp - 3,
			"鐵壁不減免秘術傷害:%d → %d(該扣滿 3)" % [thp, tank.current_hp])

	print("%s %d/%d" % ["PASS" if _fail == 0 else "FAIL", _pass, _pass + _fail])
	quit(0 if _fail == 0 else 1)
