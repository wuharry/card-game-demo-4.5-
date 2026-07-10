## battle_manager.gd — 戰鬥狀態的「帳房」:魔力、回合、真結算(HP 增減與死亡)
##
## 由 CardManager 在 _ready 程式生成掛在自己底下(main.tscn 零改動,同 BattleUI)。
## 分工:CardManager 管「互動」(點了誰、選了什麼),這裡管「規則」(付不付得起、
## 掉多少血、誰死了)。「演出與規則分離」的另一半:訂閱 action_performed 做真結算
## ——動畫照播,數值在這裡落地。
##
## 尚未實作(戰鬥系統下一階段):狀態效果(灼燒/凍結/中毒…)、打法修飾
## (橫掃/貫穿/連擊/吸血)、召喚系效果、不滅復活。
extends Node
class_name BattleManager

## 魔力 / 回合 / 行動方有變動(HUD 靠這條刷新)。
signal state_changed(turn: int, side: String, mana: int, mana_max: int)
## 有單位死亡(CardManager 靠這條清掉指向死者的參考)。
signal unit_died(unit: Card)
## 勝負已分("player" = 玩家贏)。
signal game_over(winner: String)

const MANA_CAP := 10
## 卡槽群組(player_board 生成卡槽時分好的):查單位在哪個槽、站哪邊都靠它。
const SLOT_GROUPS: Array[String] = [
	"player_front", "player_back", "enemy_front", "enemy_back"]
## 召喚系技能(死靈法師)要生新卡用的藍圖。
const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
## 「相鄰路線」的 x 距離上限:卡槽寬 1.28 + 間距,一路 ≈ 1.5;2.2 = 自己 + 左右各一路。
## 嘲諷守護與橫掃共用這把尺;改棋盤間距時記得回來對。
const LANE_ADJACENT_X := 2.2

## 手牌上限(§1):滿手時抽到的牌直接燒掉(爆牌制)。
const MAX_HAND := 8

## 一側玩家的帳(魔力/牌堆/手牌「資料」)。熱座與連線共用這個形狀:
## 熱座 = 一台電腦輪流看兩份帳;連線 = host 持有兩份、client 只看自己那份。
class SideState:
	var mana: int = 0
	var mana_max: int = 0   # 規格§1:起始 0,每次輪到自己回合開始才 +1 回滿
	var deck: Array[CardData] = []
	var hand: Array[CardData] = []

var turn: int = 1
var active_side: String = "player"   # 現在輪到誰行動(回合歸屬)
var sides: Dictionary = {}           # "player"/"enemy" → SideState

## 雙方本體(CardManager 生成後註冊進來);打倒對方本體 = 勝利(§1)。
var player_hero: Hero = null
var enemy_hero: Hero = null
var game_ended: bool = false


func _ready() -> void:
	# 開局建帳:雙方各一副洗好的牌堆 + 起手 5 張(資料層;視圖由 CardManager 同步)。
	for side in ["player", "enemy"]:
		var st := SideState.new()
		st.deck = Deck.build_shuffled()
		for i in range(5):
			if not st.deck.is_empty():
				st.hand.append(st.deck.pop_back())
		sides[side] = st
	_begin_side_turn(_active())   # 玩家的第 1 回合:魔力 0→1 回滿
	_emit_state()


## ── 每側的帳 ───────────────────────────────────────
func _active() -> SideState:
	return sides[active_side]


## 輪到某一側的回合開始:魔力上限 +1(封頂)並回滿(未用不保留,§1)。
func _begin_side_turn(st: SideState) -> void:
	st.mana_max = mini(MANA_CAP, st.mana_max + 1)
	st.mana = st.mana_max


## 行動方目前的魔力(給 UI 顯示用;帳本身是私有的,外部走這個口)。
func active_mana() -> int:
	return _active().mana


func can_afford(cost: int) -> bool:
	return _active().mana >= cost


## 召喚費由 CardManager 在出牌時呼叫;技能費在 on_action_performed 內扣。
func spend(cost: int) -> void:
	_active().mana = maxi(0, _active().mana - cost)
	_emit_state()


## 換邊前,把手牌「視圖」的現況存回行動方的帳(視圖是顯示,帳才是真相)。
func stash_hand(hand_data: Array[CardData]) -> void:
	_active().hand = hand_data


## 目前行動方的手牌資料(CardManager 拿去重建視圖)。
func active_hand() -> Array[CardData]:
	return _active().hand


func deck_count(side: String) -> int:
	return (sides[side] as SideState).deck.size() if sides.has(side) else 0


## 這個卡槽屬於哪一側(出牌只能放自己這側,熱座的側別檢查用)。
func slot_side(slot: CardSlot) -> String:
	var group := _row_group_of(slot)
	if group == "":
		return ""
	return "player" if group.begins_with("player") else "enemy"


## ── 回合 ──────────────────────────────────────────
## 結束回合:回合 +1、魔力上限 +1(封頂 10)並回滿(未用魔力不保留,§1)、
## 全場單位的行動旗標歸零。敵方 AI 動工前,這顆按鈕就等於「下一回合」。
## 結束回合 = 換邊(熱座):行動方的結束階段 → 換邊 → 新行動方的開始階段+抽牌。
## 回傳 {"drawn": CardData|null, "burned": bool} 給 CardManager 做提示。
func end_turn() -> Dictionary:
	_tick_dot_side(active_side, false)   # 行動方的結束階段:灼燒+中毒(§5/§9)
	active_side = "enemy" if active_side == "player" else "player"
	turn += 1
	var st := _active()
	_begin_side_turn(st)   # 新行動方:魔力 +1 回滿
	# 新行動方的開始階段:先 tick 再遞減——1 回合的灼燒才咬得到「結束+開始」共 2 點。
	_tick_dot_side(active_side, true)
	for slot in _all_slots():
		var u := slot.card_in_slot
		if u != null and side_of(u) == active_side:
			u.attacked_this_turn = false
			u.skill_used_this_turn = false
			u.summoned_this_turn = false
			u.iron_wall_used_this_turn = false
			u.decay_statuses()
	# 抽牌階段(§5,資料層):滿手燒牌(§1 爆牌:牌照樣從牌堆消失,雙方可見)。
	var result := {"drawn": null, "burned": false}
	if st.hand.size() >= MAX_HAND:
		if not st.deck.is_empty():
			st.deck.pop_back()
			result.burned = true
	elif not st.deck.is_empty():
		var drawn: CardData = st.deck.pop_back()
		st.hand.append(drawn)
		result.drawn = drawn
	_emit_state()
	return result


## 持續傷害 tick(§9):只 tick「該側」的單位——狀態是在持有者自己的
## 回合階段結算的(對手回合不會咬你);灼燒開始與結束各 1 點、中毒只在結束。
func _tick_dot_side(side: String, phase_start: bool) -> void:
	for slot in _all_slots():
		var u := slot.card_in_slot
		if u == null or side_of(u) != side:
			continue
		var dmg := 0
		if u.has_status(SkillData.Status.BURN):
			dmg += 1
		if not phase_start and u.has_status(SkillData.Status.POISON):
			dmg += 1
		if dmg > 0:
			u.take_damage(dmg)
			u.play_one_shot_anim("Hurt")
			_check_death(u)


## 召喚落地時標記(召喚暈眩:當回合不能攻擊,§3)。
func mark_summoned(unit: Card) -> void:
	unit.summoned_this_turn = true


## ── 本體與勝負 ─────────────────────────────────────
func register_heroes(p_hero: Hero, e_hero: Hero) -> void:
	player_hero = p_hero
	enemy_hero = e_hero
	p_hero.died.connect(_on_hero_died)
	e_hero.died.connect(_on_hero_died)


func _on_hero_died(hero: Hero) -> void:
	if game_ended:
		return
	game_ended = true
	game_over.emit("player" if hero.side == "enemy" else "enemy")


## 打臉合法性(§4.1):路線正前方沒有敵方阻擋,才能直取本體。
func face_block_reason(attacker: Card, hero: Hero, skill: SkillData) -> String:
	if game_ended:
		return "勝負已分。"
	if skill != null and skill.effect_target == SkillData.Target.ALLY:
		return "友軍技能不能指定本體。"
	if skill != null and skill.kind == SkillData.Kind.NON_ATTACK:
		return "非攻擊技能不能指定本體。"
	if hero.side == side_of(attacker):
		return "不能指定自己的本體。"
	# 【飛行】無視路線阻擋與守護,直擊本體(§8;守護是阻擋的一種,一併無視)。
	if attacker.data.keywords.has(&"飛行"):
		return ""
	# §8.1 守護型嘲諷:嘲諷單位守自己+左右相鄰路線,先打它才能打臉。
	var guard := _taunt_guarding(attacker)
	if guard != null:
		return "本體受【嘲諷】守護(%s):必須先攻擊守護者。" % guard.data.card_name
	if _lane_blocked(attacker):
		return "路線正前方有敵方單位阻擋,無法直取本體。"
	return ""


## 找出守著攻擊者這條路線的敵方嘲諷單位(§8.1;沒有就回 null)。
func _taunt_guarding(attacker: Card) -> Card:
	var my_slot := _find_slot(attacker)
	if my_slot == null:
		return null
	var opposing := "enemy_front" if side_of(attacker) == "player" else "player_front"
	for slot in get_tree().get_nodes_in_group(opposing):
		if slot is CardSlot and slot.card_in_slot != null \
				and slot.card_in_slot.data.keywords.has(&"嘲諷"):
			var dx: float = absf(slot.global_position.x - my_slot.global_position.x)
			if dx < LANE_ADJACENT_X:
				return slot.card_in_slot
	return null


## 攻擊者同一直行(路線)上,對面「前排」最近的那格有人 = 被擋(§4.1 LANE_ONLY;
## 後排是伏印區,不當阻擋)。路線對位用 x 座標找最近的對面前排格,不寫死欄號。
func _lane_blocked(attacker: Card) -> bool:
	var my_slot := _find_slot(attacker)
	if my_slot == null:
		return true   # 不在場上(不該發生):一律當被擋,安全邊
	var opposing := "enemy_front" if side_of(attacker) == "player" else "player_front"
	var nearest: CardSlot = null
	var best := INF
	for slot in get_tree().get_nodes_in_group(opposing):
		if slot is CardSlot:
			var dx: float = absf(
				(slot as CardSlot).global_position.x - my_slot.global_position.x)
			if dx < best:
				best = dx
				nearest = slot
	return nearest != null and nearest.card_in_slot != null


## ── 行動合法性(回傳「被擋的理由」;空字串 = 可以做)────────
## UI 拿理由灰化按鈕並顯示給玩家;規則只寫在這裡一份,按鈕永遠只是轉述。
func attack_block_reason(unit: Card) -> String:
	if side_of(unit) != active_side:
		return "還沒輪到這一方行動。"
	if unit.has_status(SkillData.Status.FREEZE):
		return "凍結中:無法攻擊(§9)。"
	if unit.attacked_this_turn:
		return "本回合已攻擊過。"
	if unit.summoned_this_turn and not unit.data.keywords.has(&"衝鋒"):
		return "召喚暈眩:剛上場,下回合才能攻擊。"
	return ""


func skill_block_reason(unit: Card) -> String:
	var skill := unit.data.active_skill
	if skill == null:
		return "沒有主動技能。"
	if side_of(unit) != active_side:
		return "還沒輪到這一方行動。"
	if unit.has_status(SkillData.Status.FREEZE):
		return "凍結中:無法發動技能(§9)。"
	if unit.skill_used_this_turn:
		return "本回合已發動過技能。"
	# §6 行動經濟:強化攻擊要用掉「本回合的攻擊」;獨立攻擊視同攻擊,吃召喚暈眩。
	if skill.kind == SkillData.Kind.ENHANCED_ATTACK and unit.attacked_this_turn:
		return "強化攻擊需要本回合的攻擊(已用掉)。"
	if skill.kind == SkillData.Kind.INDEPENDENT_ATTACK \
			and unit.summoned_this_turn and not unit.data.keywords.has(&"衝鋒"):
		return "召喚暈眩:獨立攻擊視同攻擊,下回合才能用。"
	if _active().mana < skill.cost:
		return "魔力不足(需要 ◆%d,現有 %d)。" % [skill.cost, _active().mana]
	return ""


## ── 真結算(訂閱 CardManager.action_performed)─────────
## target 是 Card(從者:走雙向交換)或 Hero(本體:打臉不吃反擊)。
func on_action_performed(caster: Card, skill: SkillData, target: Node3D) -> void:
	# 1) 行動經濟與費用先落帳(演出還在播,帳要先記,玩家馬上開選單也不會重複用)。
	if skill == null:
		caster.attacked_this_turn = true
	else:
		caster.skill_used_this_turn = true
		if skill.kind == SkillData.Kind.ENHANCED_ATTACK:
			caster.attacked_this_turn = true   # 強化攻擊 = 用掉本回合的攻擊(§6)
		_active().mana = maxi(0, _active().mana - skill.cost)
	_emit_state()
	# 2) 等攻擊動畫揮到一半再扣血,數字跟拳頭一起落地。
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	# 先算出這次行動的「傷害輪廓」:多少傷害、會不會吃反擊。
	var dmg := 0
	var retaliate := false
	if skill == null:
		dmg = caster.atk_total()   # 含鍛強加值,別直接讀 data.atk
		retaliate = true
	elif skill.kind == SkillData.Kind.ENHANCED_ATTACK:
		dmg = caster.atk_total() + skill.power
		retaliate = true
	elif skill.kind == SkillData.Kind.INDEPENDENT_ATTACK:
		dmg = skill.power   # 額外攻擊:不觸發反擊
	else:
		# 非攻擊技:治療 / 上狀態 / 召喚(§6【非攻擊】)。
		match skill.effect:
			SkillData.Effect.HEAL:
				if target is Card:
					(target as Card).heal(skill.amount)
			SkillData.Effect.APPLY_STATUS:
				if target is Card:
					(target as Card).add_status(skill.status, skill.status_turns)
			SkillData.Effect.SUMMON:
				_resolve_summon(caster, skill)
		return
	if target is Hero:
		(target as Hero).take_damage(dmg)   # 打臉不吃反擊(§4.2)
		return
	var mod := SkillData.Modifier.NONE if skill == null else skill.modifier
	_resolve_attack(caster, target as Card, dmg, retaliate, mod)
	# 攻擊技的附帶狀態(火球術的灼燒):傷害落地後、目標還活著才上。
	if skill != null and skill.effect == SkillData.Effect.APPLY_STATUS \
			and is_instance_valid(target) and target is Card:
		(target as Card).add_status(skill.status, skill.status_turns)


## §4.2 雙向傷害交換:「同時結算」——反擊值用交戰前的數值先記下、再一起扣,
## 誰先歸零都不影響對方吃到的傷害(順序扣血會讓先死的一方打不出反擊,規則就錯了)。
## mod = 打法修飾(§6):連擊/吸血/橫掃/貫穿都在這裡展開;副目標一律不反擊。
func _resolve_attack(attacker: Card, defender: Card, dmg: int, retaliate: bool,
		mod: SkillData.Modifier) -> void:
	if not is_instance_valid(defender):
		return
	var counter := defender.atk_total() if retaliate else 0
	var hits := 2 if mod == SkillData.Modifier.DOUBLE else 1   # 連擊:結算兩次
	var dealt := 0
	for hit in range(hits):
		if is_instance_valid(defender):
			dealt += _deal_damage(defender, dmg, true)
	if retaliate and counter > 0 and is_instance_valid(attacker):
		_deal_damage(attacker, counter, true)
	# 吸血:回復「實際造成」的傷害——夜幕/鐵壁減免後的數字,不是帳面值。
	if mod == SkillData.Modifier.LIFESTEAL and dealt > 0 and is_instance_valid(attacker):
		attacker.heal(dealt)
	# 橫掃:同一排、左右相鄰路線的單位各吃一份。
	if mod == SkillData.Modifier.SPREAD_3:
		for u in _adjacent_lane_units(defender):
			_deal_damage(u, dmg, true)
			_check_death(u)
	# 貫穿:同路線的後排也吃一份。
	if mod == SkillData.Modifier.PIERCE:
		var back := _unit_behind(defender)
		if back != null:
			_deal_damage(back, dmg, true)
			_check_death(back)
	_check_death(defender)
	if attacker != defender:
		_check_death(attacker)


## 傷害管線:夜幕減半(§9)→ 鐵壁首傷 -1(§8,播 Block)→ 扣血+受擊演出。
## 回傳「實際傷害」給吸血用。minion_attack = 這是從者攻擊(鐵壁只擋這種)。
func _deal_damage(unit: Card, amount: int, minion_attack: bool) -> int:
	if not is_instance_valid(unit):
		return 0
	var dmg := amount
	if unit.has_status(SkillData.Status.NIGHT_VEIL):
		dmg = int(ceil(dmg / 2.0))   # 夜幕:首次受傷減半(進位),用掉即消
		unit.remove_status(SkillData.Status.NIGHT_VEIL)
	var blocked := false
	if minion_attack and unit.data.keywords.has(&"鐵壁") \
			and not unit.iron_wall_used_this_turn:
		unit.iron_wall_used_this_turn = true
		dmg = maxi(0, dmg - 1)
		blocked = true
	unit.take_damage(dmg)
	# 演出:格擋播 Block(沒有該表就退回 Hurt);其餘吃到傷害才縮。
	if blocked:
		if not unit.play_one_shot_anim("Block"):
			unit.play_one_shot_anim("Hurt")
	elif dmg > 0:
		unit.play_one_shot_anim("Hurt")
	return dmg


func _check_death(unit: Card) -> void:
	if not is_instance_valid(unit) or unit.current_hp > 0:
		return
	# 【不滅】:首次陣亡以 1 HP 復活,每場一次(§8;骷髏家族,播 Summon 復活動畫)。
	# 規格寫「以指定 HP 復活」但數值未定案 → 先用 1,要調就改這一行。
	if unit.data.keywords.has(&"不滅") and not unit.revived:
		unit.revived = true
		unit.heal(1)
		if not unit.play_one_shot_anim("Summon"):
			unit.play_one_shot_anim("Summon(With magic effects)")
		return
	var slot := _find_slot(unit)
	if slot != null:
		slot.on_unit_died()   # 先清位:死亡演出期間這格就能再放牌
	unit_died.emit(unit)
	unit.die()


## ── 召喚系技能(§6.1 死靈法師):在施放者那側找空槽生一張新卡 ─────
func _resolve_summon(caster: Card, skill: SkillData) -> void:
	var res_path := "res://data/cards/%s.tres" % skill.summon_card
	if skill.summon_card == "" or not ResourceLoader.exists(res_path):
		return
	var slot := _first_empty_slot(side_of(caster))
	if slot == null:
		return   # 沒空位:演出照播、召喚落空(和爐石場滿同規)
	var card: Card = CARD_SCENE.instantiate()
	# 掛在施放者的父節點(PlayerHand)底下:place_card 的「躺平」靠父節點的
	# -90°X 旋轉,掛錯父節點卡會立起來(local vs world,見 card_slot 的說明)。
	var hand := caster.get_parent()
	hand.add_child(card)
	card.setup(load(res_path))
	# hover 信號接回中繼站,召喚出來的單位才能被指定成目標時亮起。
	if hand is PlayerHand:
		card.card_hovered.connect((hand as PlayerHand).card_hovered.emit)
		card.card_unhovered.connect((hand as PlayerHand).card_unhovered.emit)
	card.global_position = slot.global_position + Vector3(0.0, 1.5, 0.0)
	slot.place_card(card)
	mark_summoned(card)


## ── 路線幾何(橫掃/貫穿/召喚落點用)─────────────────
## 同一排、左右相鄰路線的單位(橫掃的副目標)。
func _adjacent_lane_units(target: Card) -> Array[Card]:
	var out: Array[Card] = []
	var slot := _find_slot(target)
	if slot == null:
		return out
	var row := _row_group_of(slot)
	if row == "":
		return out
	for other in get_tree().get_nodes_in_group(row):
		if other is CardSlot and other != slot and other.card_in_slot != null:
			var dx: float = absf(other.global_position.x - slot.global_position.x)
			if dx < LANE_ADJACENT_X:
				out.append(other.card_in_slot)
	return out


## 同路線的後排單位(貫穿的第二目標);目標已在後排就沒有更後面。
func _unit_behind(target: Card) -> Card:
	var slot := _find_slot(target)
	if slot == null:
		return null
	var back_row := ""
	match _row_group_of(slot):
		"enemy_front":
			back_row = "enemy_back"
		"player_front":
			back_row = "player_back"
		_:
			return null
	var nearest: CardSlot = null
	var best := INF
	for other in get_tree().get_nodes_in_group(back_row):
		if other is CardSlot:
			var dx: float = absf(other.global_position.x - slot.global_position.x)
			if dx < best:
				best = dx
				nearest = other
	if nearest != null and best < 1.2 and nearest.card_in_slot != null:
		return nearest.card_in_slot
	return null


func _row_group_of(slot: CardSlot) -> String:
	for group in SLOT_GROUPS:
		if slot.is_in_group(group):
			return group
	return ""


func _first_empty_slot(side: String) -> CardSlot:
	var rows: Array[String] = ["player_front", "player_back"]
	if side != "player":
		rows = ["enemy_front", "enemy_back"]
	for group in rows:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot and slot.is_empty:
				return slot
	return null


## ── 查詢工具 ───────────────────────────────────────
## 這個單位站在誰的棋盤上?("player" / "enemy" / "" = 不在場上)
func side_of(unit: Card) -> String:
	for group in SLOT_GROUPS:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot and slot.card_in_slot == unit:
				return "player" if group.begins_with("player") else "enemy"
	return ""


func _find_slot(unit: Card) -> CardSlot:
	for slot in _all_slots():
		if slot.card_in_slot == unit:
			return slot
	return null


## 量級:全場最多 20 個槽的線性掃描,只在點擊/結算時查,不用快取。
func _all_slots() -> Array[CardSlot]:
	var out: Array[CardSlot] = []
	for group in SLOT_GROUPS:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot:
				out.append(slot)
	return out


func _emit_state() -> void:
	state_changed.emit(turn, active_side, _active().mana, _active().mana_max)
