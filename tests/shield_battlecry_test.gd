## shield_battlecry_test.gd — 護盾 / 戰吼 / 全體技 / 衰弱的驗收(headless SceneTree 腳本)
## 跑法:Godot --headless --path <專案> -s <本檔>
##
## 這輪(2026-08-10 卡池對齊 Pack01/02)新加的四樣機制,既有七支回歸一樣都碰不到,
## 所以另立這一支。重點不是「有沒有效果」,而是**順序**——護盾插錯位置不會報錯,
## 只會讓數值默默少擋幾點,是最不容易被人眼抓到的那種錯。
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


## 清空整排卡槽(每段情境開始前歸零,免得前一段的殘兵被全體技掃到、算式對不上)。
func _clear(groups: Array) -> void:
	for g in groups:
		for s in get_nodes_in_group(g):
			if s is CardSlot and s.card_in_slot != null:
				var u: Card = s.card_in_slot
				s.on_unit_died()
				u.queue_free()


func _run() -> void:
	for i in range(20):
		await process_frame

	var bm := _find_bm(root)
	if bm == null:
		print("FAIL: 找不到 BattleManager 節點")
		quit(1)
		return

	var knight: CardData = load("res://data/cards/knight.tres")            # 鐵壁 + 守護戰吼
	var soldier: CardData = load("res://data/cards/soldier.tres")          # 防禦姿態:自身 2 盾
	var templar: CardData = load("res://data/cards/knight_templar.tres")   # 戰吼:英雄 +3
	var bk_a: CardData = load("res://data/cards/black_knight_a.tres")      # 戰吼:自身 +2 盾
	var axeman: CardData = load("res://data/cards/armored_axeman.tres")    # 旋風斬:SPREAD_ALL
	var ward_cd: CardData = load("res://data/cards/ward_blast_sigil.tres")

	# ── (a) 護盾的吸收順序:夜幕減半 → 鐵壁 −1 → 護盾 → 扣血 ──────────
	# 這是整輪最容易寫錯的一行。10 點打在「3 盾 + 夜幕 + 鐵壁」的騎士身上:
	#   ‧ 盾排在減免「之前」→ 10−3=7 → 減半 4 → 鐵壁 3 → 掉 3 血
	#   ‧ 盾排在減免「之後」→ 10 → 減半 5 → 鐵壁 4 → 盾吸 3 → 掉 1 血  ← 正確
	# 兩種寫法都不會報錯,差別只在這個數字。
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	var u_a: Card = bm.spawn_unit(knight, _first_empty_in("player_front"))
	u_a.add_shield(3)
	u_a.add_status(SkillData.Status.NIGHT_VEIL, 1)
	_check(u_a.shield == 3, "(a) add_shield 記在節點上(實際 %d)" % u_a.shield)
	var hp_before: int = u_a.current_hp
	bm._deal_damage(u_a, 10, true)
	_check(u_a.current_hp == hp_before - 1,
		"(a) 減免先做、護盾後吸:10 傷只掉 1 血(實際掉 %d)" % (hp_before - u_a.current_hp))
	_check(u_a.shield == 0, "(a) 3 點盾被吃光(實際剩 %d)" % u_a.shield)

	# ── (b) 護盾擋不住的部分才算「實際傷害」(吸血拿的是這個數)──────
	# 5 點打 3 盾的滿血目標 → 盾吸 3、掉 2 血 → 回傳 2,不是 5 也不是 3。
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	var u_b: Card = bm.spawn_unit(knight, _first_empty_in("enemy_front"))
	u_b.add_shield(3)
	var dealt: int = bm._deal_damage(u_b, 5, false)
	_check(dealt == 2, "(b) _deal_damage 回傳穿透護盾的 2(實際 %d)" % dealt)
	_check(u_b.current_hp == knight.hp - 2,
		"(b) 現血 %d-2(實際 %d)" % [knight.hp, u_b.current_hp])

	# ── (c) 戰吼:騎士【守護】給左右相鄰友軍各 2 點護盾 ────────────
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	var slots: Array = []
	for s in get_nodes_in_group("player_front"):
		if s is CardSlot:
			slots.append(s)
	slots.sort_custom(func(x, y): return x.global_position.x < y.global_position.x)
	var mate: Card = bm.spawn_unit(soldier, slots[0])
	var far: Card = bm.spawn_unit(soldier, slots[slots.size() - 1])
	_check(mate.shield == 0 and far.shield == 0, "(c) 起始都沒有盾")
	bm.spawn_unit(knight, slots[1])          # 騎士站在 mate 隔壁
	bm.mark_summoned(slots[1].card_in_slot)  # 戰吼在這裡跑
	_check(mate.shield == 2, "(c) 相鄰友軍拿到 2 點盾(實際 %d)" % mate.shield)
	_check(far.shield == 0, "(c) 隔了好幾路的友軍沒拿到(實際 %d)" % far.shield)

	# ── (d) 戰吼:聖殿騎士回己方英雄 3 點 ────────────────────
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	bm.player_hero.take_damage(8)
	var hero_hp: int = bm.player_hero.hp
	var t_slot := _first_empty_in("player_front")
	bm.spawn_unit(templar, t_slot)
	bm.mark_summoned(t_slot.card_in_slot)
	_check(bm.player_hero.hp == hero_hp + 3,
		"(d) 己方英雄 +3(%d→%d,實際 %d)" % [hero_hp, hero_hp + 3, bm.player_hero.hp])

	# ── (e) 戰吼先於伏印:暗影護甲擋得住緊接著引爆的伏印傷害 ────────
	# 倒過來排的話,「登場就有盾」在最需要它的那一刻剛好還沒生效。
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	bm.sides["enemy"].wards.append({"cd": ward_cd, "host": null})
	var k_slot := _first_empty_in("player_front")
	bm.spawn_unit(bk_a, k_slot)
	var bk: Card = k_slot.card_in_slot
	bm.mark_summoned(bk)
	var ward_dmg: int = ward_cd.active_skill.power
	_check(bk.current_hp == bk_a.hp,
		"(e) 戰吼的盾先掛上,伏印 %d 傷全被吸掉、沒掉血(實際 %d/%d)" % [
			ward_dmg, bk.current_hp, bk_a.hp])
	_check(bk.shield == 2 - ward_dmg,
		"(e) 盾剩 2-%d=%d(實際 %d)" % [ward_dmg, 2 - ward_dmg, bk.shield])

	# ── (f) SPREAD_ALL:全體技打到守方場上每一隻,不只相鄰路 ─────────
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	var e_slots: Array = []
	for s in get_nodes_in_group("enemy_front"):
		if s is CardSlot:
			e_slots.append(s)
	e_slots.sort_custom(func(x, y): return x.global_position.x < y.global_position.x)
	# 靶要挑「沒有鐵壁」的:騎士的鐵壁會把首次從者傷害 −1,算式就不是純 SPREAD_ALL 了
	# (第一版拿騎士當靶,兩條斷言都紅——夾具帶了自己的減免進來,不是機制壞掉)。
	var orc: CardData = load("res://data/cards/orc.tres")   # 3/3/3,無關鍵字
	var v0: Card = bm.spawn_unit(orc, e_slots[0])
	var v_far: Card = bm.spawn_unit(orc, e_slots[e_slots.size() - 1])
	var attacker: Card = bm.spawn_unit(axeman, _first_empty_in("player_front"))
	bm._resolve_attack(attacker, v0, 2, false, SkillData.Modifier.SPREAD_ALL)
	_check(v0.current_hp == orc.hp - 2, "(f) 主目標吃 2(實際 %d)" % v0.current_hp)
	_check(v_far.current_hp == orc.hp - 2,
		"(f) 最遠那一路也吃 2 —— 這是 SPREAD_ALL 與 SPREAD_3 的差別(實際 %d)" % v_far.current_hp)

	# ── (g) 衰弱:ATK −1,且夾在 0 以上(負攻擊力會讓反擊變成補血)──────
	_clear(["player_front", "player_back", "enemy_front", "enemy_back"])
	var u_g: Card = bm.spawn_unit(knight, _first_empty_in("player_front"))
	var atk0: int = u_g.atk_total()
	u_g.add_status(SkillData.Status.WEAKEN, 1)
	_check(u_g.atk_total() == atk0 - 1, "(g) 衰弱後 ATK −1(%d→%d)" % [atk0, u_g.atk_total()])
	u_g.add_status(SkillData.Status.FORGE, 2)
	_check(u_g.atk_total() == atk0 + 1,
		"(g) 鍛強與衰弱不互斥,同時在身上淨 +1(實際 %d)" % u_g.atk_total())
	var bat: CardData = load("res://data/cards/bat.tres")   # 1/1/1:攻擊力只有 1
	var weak: Card = bm.spawn_unit(bat, _first_empty_in("player_back"))
	weak.add_status(SkillData.Status.WEAKEN, 1)
	_check(weak.atk_total() == 0, "(g) 1 點攻擊吃衰弱夾在 0,不會變負(實際 %d)" % weak.atk_total())

	print("")
	if _fails == 0:
		print("PASS 護盾+戰吼 %d 斷言全過" % _checks)
	else:
		print("FAIL %d/%d 斷言未過" % [_fails, _checks])
	quit(1 if _fails > 0 else 0)
