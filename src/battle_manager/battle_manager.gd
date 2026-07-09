## battle_manager.gd — 戰鬥狀態的「帳房」:魔力、回合、真結算(HP 增減與死亡)
##
## 由 CardManager 在 _ready 程式生成掛在自己底下(main.tscn 零改動,同 BattleUI)。
## 分工:CardManager 管「互動」(點了誰、選了什麼),這裡管「規則」(付不付得起、
## 掉多少血、誰死了)。「演出與規則分離」的另一半:訂閱 action_performed 做真結算
## ——動畫照播,數值在這裡落地。
##
## 尚未實作(戰鬥系統下一階段):狀態效果(灼燒/凍結/中毒…)、打法修飾
## (橫掃/貫穿/連擊/吸血)、召喚系效果、不滅復活、玩家本體 HP 與勝負判定。
extends Node
class_name BattleManager

## 魔力 / 回合有變動(HUD 靠這條刷新)。
signal state_changed(turn: int, mana: int, mana_max: int)
## 有單位死亡(CardManager 靠這條清掉指向死者的參考)。
signal unit_died(unit: Card)

const MANA_CAP := 10
## 卡槽群組(player_board 生成卡槽時分好的):查單位在哪個槽、站哪邊都靠它。
const SLOT_GROUPS: Array[String] = [
	"player_front", "player_back", "enemy_front", "enemy_back"]

var turn: int = 1
var mana_max: int = 1   # 規格§1:起始 0、回合開始 +1 → 第 1 回合開打時正是 1
var mana: int = 1


func _ready() -> void:
	_emit_state()   # 開場先把 HUD 刷成第 1 回合的狀態


## ── 魔力 ──────────────────────────────────────────
func can_afford(cost: int) -> bool:
	return mana >= cost


## 召喚費由 CardManager 在出牌時呼叫;技能費在 on_action_performed 內扣。
func spend(cost: int) -> void:
	mana = maxi(0, mana - cost)
	_emit_state()


## ── 回合 ──────────────────────────────────────────
## 結束回合:回合 +1、魔力上限 +1(封頂 10)並回滿(未用魔力不保留,§1)、
## 全場單位的行動旗標歸零。敵方 AI 動工前,這顆按鈕就等於「下一回合」。
func end_turn() -> void:
	turn += 1
	mana_max = mini(MANA_CAP, mana_max + 1)
	mana = mana_max
	for slot in _all_slots():
		if slot.card_in_slot != null:
			slot.card_in_slot.attacked_this_turn = false
			slot.card_in_slot.skill_used_this_turn = false
			slot.card_in_slot.summoned_this_turn = false
	_emit_state()


## 召喚落地時標記(召喚暈眩:當回合不能攻擊,§3)。
func mark_summoned(unit: Card) -> void:
	unit.summoned_this_turn = true


## ── 行動合法性(回傳「被擋的理由」;空字串 = 可以做)────────
## UI 拿理由灰化按鈕並顯示給玩家;規則只寫在這裡一份,按鈕永遠只是轉述。
func attack_block_reason(unit: Card) -> String:
	if unit.attacked_this_turn:
		return "本回合已攻擊過。"
	if unit.summoned_this_turn and not unit.data.keywords.has(&"衝鋒"):
		return "召喚暈眩:剛上場,下回合才能攻擊。"
	return ""


func skill_block_reason(unit: Card) -> String:
	var skill := unit.data.active_skill
	if skill == null:
		return "沒有主動技能。"
	if unit.skill_used_this_turn:
		return "本回合已發動過技能。"
	# §6 行動經濟:強化攻擊要用掉「本回合的攻擊」;獨立攻擊視同攻擊,吃召喚暈眩。
	if skill.kind == SkillData.Kind.ENHANCED_ATTACK and unit.attacked_this_turn:
		return "強化攻擊需要本回合的攻擊(已用掉)。"
	if skill.kind == SkillData.Kind.INDEPENDENT_ATTACK \
			and unit.summoned_this_turn and not unit.data.keywords.has(&"衝鋒"):
		return "召喚暈眩:獨立攻擊視同攻擊,下回合才能用。"
	if mana < skill.cost:
		return "魔力不足(需要 ◆%d,現有 %d)。" % [skill.cost, mana]
	return ""


## ── 真結算(訂閱 CardManager.action_performed)─────────
func on_action_performed(caster: Card, skill: SkillData, target: Card) -> void:
	# 1) 行動經濟與費用先落帳(演出還在播,帳要先記,玩家馬上開選單也不會重複用)。
	if skill == null:
		caster.attacked_this_turn = true
	else:
		caster.skill_used_this_turn = true
		if skill.kind == SkillData.Kind.ENHANCED_ATTACK:
			caster.attacked_this_turn = true   # 強化攻擊 = 用掉本回合的攻擊(§6)
		mana = maxi(0, mana - skill.cost)
	_emit_state()
	# 2) 等攻擊動畫揮到一半再扣血,數字跟拳頭一起落地。
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(caster):
		return
	if skill == null:
		_resolve_attack(caster, target, caster.data.atk, true)
	elif skill.kind == SkillData.Kind.ENHANCED_ATTACK:
		_resolve_attack(caster, target, caster.data.atk + skill.power, true)
	elif skill.kind == SkillData.Kind.INDEPENDENT_ATTACK:
		_resolve_attack(caster, target, skill.power, false)   # 額外攻擊:不觸發反擊
	elif skill.effect == SkillData.Effect.HEAL:
		if is_instance_valid(target):
			target.heal(skill.amount)
	# 其餘效果(上狀態/召喚/打法修飾)留給戰鬥系統下一階段:目前只有演出。


## §4.2 雙向傷害交換:「同時結算」——反擊值用交戰前的數值先記下、再一起扣,
## 誰先歸零都不影響對方吃到的傷害(順序扣血會讓先死的一方打不出反擊,規則就錯了)。
func _resolve_attack(attacker: Card, defender: Card, dmg: int, retaliate: bool) -> void:
	if not is_instance_valid(defender):
		return
	var counter := defender.data.atk if retaliate else 0
	defender.take_damage(dmg)
	if retaliate and is_instance_valid(attacker):
		attacker.take_damage(counter)
	_check_death(defender)
	if attacker != defender:
		_check_death(attacker)


func _check_death(unit: Card) -> void:
	if not is_instance_valid(unit) or unit.current_hp > 0:
		return
	var slot := _find_slot(unit)
	if slot != null:
		slot.on_unit_died()   # 先清位:死亡演出期間這格就能再放牌
	unit_died.emit(unit)
	unit.die()


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
	state_changed.emit(turn, mana, mana_max)
