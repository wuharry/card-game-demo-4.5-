## enemy_ai.gd — 單人模式的規則型 AI。
##
## AI 不直接改帳：所有出牌仍走 CardManager 的既有結算入口。這裡只做三件事：
## 產生合法候選、替候選評分、依序下令。評分不追求完美搜尋，但會考慮斬殺、
## 換怪、受傷治療、裝備替換、伏印宿主與「棄牌回魔後能否解鎖高價值行動」。
class_name EnemyAI
extends Node

@export var step_delay: float = 0.7
@export var think_delay: float = 0.9

const MAX_PLAY_ACTIONS := 16
const DISCARD_PLAN_MARGIN := 2.0

var cm: Node = null
var bm: BattleManager = null


func setup(manager: Node) -> void:
	cm = manager
	bm = manager.battle_manager


func take_turn() -> void:
	await _wait(think_delay)
	if _stopped():
		return
	# 舊單位先判斷技能，避免把所有魔力都花在鋪場後永遠不用主動技。
	await _skill_phase()
	if _stopped():
		return
	await _play_phase()
	if _stopped():
		return
	# 新召喚單位的非攻擊技能可在登場回合使用；已用過的單位會被規則層擋掉。
	await _skill_phase()
	if _stopped():
		return
	await _attack_phase()
	if _stopped():
		return
	await _wait(0.5)
	if not _stopped():
		cm._net_end_turn()


func _stopped() -> bool:
	return bm == null or bm.game_ended or bm.active_side != "enemy"


func _wait(sec: float) -> void:
	if sec <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(sec).timeout


## ── 手牌規劃 ─────────────────────────────────────
func _play_phase() -> void:
	for _guard in MAX_PLAY_ACTIONS:
		if _stopped():
			return
		var action := _best_hand_action(bm.active_mana())
		var discard_plan := _best_discard_plan()
		if not discard_plan.is_empty() and (action.is_empty() \
				or float(discard_plan.score) > float(action.score) + DISCARD_PLAN_MARGIN):
			var discard_cd: CardData = discard_plan.card
			cm._net_discard(int(discard_plan.index), discard_cd.resource_path)
			await _wait(step_delay)
			continue
		if action.is_empty():
			return
		if not await _execute_hand_action(action):
			return
		await _wait(step_delay)


func _best_hand_action(mana: int, excluded_index: int = -1) -> Dictionary:
	var best: Dictionary = {}
	var hand := bm.hand_of("enemy")
	for i in range(hand.size()):
		if i == excluded_index:
			continue
		var cd: CardData = hand[i]
		if cd == null or cd.cost > mana:
			continue
		var candidate := _hand_candidate(i, cd)
		if candidate.is_empty():
			continue
		if best.is_empty() or float(candidate.score) > float(best.score):
			best = candidate
	return best


func _hand_candidate(index: int, cd: CardData) -> Dictionary:
	match cd.card_type:
		CardData.CardType.MINION:
			var slot := _pick_summon_slot()
			if slot != null:
				return {"index": index, "card": cd, "kind": &"summon", "slot": slot,
					"score": _minion_value(cd) - float(cd.cost) * 0.25}
		CardData.CardType.ARCANA:
			var spell := _arcana_candidate(cd)
			if not spell.is_empty():
				spell.index = index
				spell.card = cd
				spell.kind = &"arcana"
				return spell
		CardData.CardType.EQUIP:
			var target := _pick_equip_target(cd)
			if target != null:
				return {"index": index, "card": cd, "kind": &"equip", "target": target,
					"score": _equipment_value(cd) + _unit_value(target) * 0.12}
		CardData.CardType.WARD:
			var host := _pick_ward_host()
			if host != null:
				return {"index": index, "card": cd, "kind": &"ward", "target": host,
					"score": 5.0 + float(cd.cost) * 0.35 + _unit_value(host) * 0.08}
		_:
			pass # 瞬咒保留在手上，交給 BattleManager 的反制窗口自動使用。
	return {}


func _execute_hand_action(action: Dictionary) -> bool:
	var cd: CardData = action.card
	var idx := _current_hand_index(cd, int(action.index))
	if idx < 0:
		return false
	match StringName(action.kind):
		&"summon":
			var slot: CardSlot = action.slot
			cm._net_summon(idx, cd.resource_path, cm.get_path_to(slot))
		&"equip":
			var equip_target: Card = action.target
			var equip_slot := bm.find_slot_of(equip_target)
			if equip_slot == null:
				return false
			cm._net_equip(idx, cd.resource_path, cm.get_path_to(equip_slot))
		&"ward":
			var ward_host: Card = action.target
			var host_slot := bm.find_slot_of(ward_host)
			if host_slot == null:
				return false
			cm._net_ward(idx, cd.resource_path, cm.get_path_to(host_slot))
		&"arcana":
			return await cm.ai_play_arcana(idx, action.get("target"),
				int(action.get("scry_pick", 0)), str(action.get("swap_discard_path", "")))
		_:
			return false
	return true


func _current_hand_index(cd: CardData, fallback: int) -> int:
	var hand := bm.hand_of("enemy")
	if fallback >= 0 and fallback < hand.size() and hand[fallback] == cd:
		return fallback
	return hand.find(cd)


## 只有在「棄完立刻能做更強的事」時才回魔；不為了清手牌無腦丟牌。
func _best_discard_plan() -> Dictionary:
	if not bm.can_discard_for_mana("enemy"):
		return {}
	var hand := bm.hand_of("enemy")
	var best: Dictionary = {}
	for i in range(hand.size()):
		var cd: CardData = hand[i]
		var gained := floori(cd.cost / 2.0)
		if gained <= 0:
			continue
		var unlocked := _best_hand_action(bm.active_mana() + gained, i)
		if unlocked.is_empty() or int((unlocked.card as CardData).cost) <= bm.active_mana():
			continue
		var plan_score := float(unlocked.score) + float(gained) * 1.5 - _hold_value(cd) * 0.45
		if best.is_empty() or plan_score > float(best.score):
			best = {"index": i, "card": cd, "score": plan_score, "unlocks": unlocked.card}
	return best


## ── 秘術 ─────────────────────────────────────────
func _arcana_candidate(cd: CardData) -> Dictionary:
	if cd.active_skill == null:
		return {}
	var sk := cd.active_skill
	if sk.effect_target == SkillData.Target.SELF:
		var score := _self_arcana_score(cd)
		if score <= 0.0:
			return {}
		var out := {"score": score - float(cd.cost) * 0.2, "target": null}
		if sk.effect == SkillData.Effect.SCRY:
			out.scry_pick = _best_scry_index(sk.amount)
		elif sk.effect == SkillData.Effect.DISCARD_DRAW:
			out.swap_discard_path = _worst_hand_card_path(cd)
		return out
	var target := _pick_arcana_target(cd)
	if target == null:
		return {}
	return {"score": _targeted_arcana_score(cd, target) - float(cd.cost) * 0.2,
		"target": target}


func _self_arcana_score(cd: CardData) -> float:
	var sk := cd.active_skill
	if cd.special_id != &"":
		return _special_arcana_score(cd)
	match sk.effect:
		SkillData.Effect.DRAW:
			if bm.deck_count("enemy") == 0:
				return 0.0
			var room := maxi(1, BattleManager.MAX_HAND - bm.hand_of("enemy").size() + 1)
			return float(mini(room, sk.amount)) * 3.0
		SkillData.Effect.SCRY:
			return 4.5 if bm.deck_count("enemy") > 0 else 0.0
		SkillData.Effect.DISCARD_DRAW:
			return 3.5 + float(sk.amount) if bm.deck_count("enemy") > 0 else 0.0
		SkillData.Effect.SUMMON:
			return 7.0 if _pick_summon_slot() != null else 0.0
	return 0.0


func _special_arcana_score(cd: CardData) -> float:
	var allies := _units_of("enemy")
	var foes := _units_of("player")
	match cd.special_id:
		&"arcana_skyfire_fall", &"arcana_eternal_winter", &"arcana_soul_harvest":
			return float(foes.size()) * 7.0
		&"arcana_allforge":
			return float(allies.size()) * 5.0
		&"arcana_dead_army_gate":
			return float(_empty_slot_count("enemy_front")) * 6.0
		&"arcana_starsea_rewind":
			return float(mini(5, bm.grave_count("enemy"))) * 2.0 \
				+ (5.0 if bm.deck_count("enemy") > 0 else 0.0)
		&"arcana_end_ritual":
			var ally_value := _board_value(allies)
			var foe_value := _board_value(foes)
			var heal_need := 20 - bm.enemy_hero.hp
			return foe_value - ally_value + float(heal_need) * 0.7 if foe_value > ally_value else 0.0
	return 0.0


func _pick_arcana_target(cd: CardData) -> Card:
	var wants_ally := cd.active_skill.effect_target == SkillData.Target.ALLY
	var pool := _units_of("enemy" if wants_ally else "player")
	var best: Card = null
	var best_score := -INF
	for unit in pool:
		if unit.has_keyword(&"潛行"):
			continue
		var score := _targeted_arcana_score(cd, unit)
		if score > best_score:
			best_score = score
			best = unit
	return best if best_score > 0.0 else null


func _targeted_arcana_score(cd: CardData, target: Card) -> float:
	var sk := cd.active_skill
	if sk.effect_target == SkillData.Target.ALLY:
		match sk.effect:
			SkillData.Effect.HEAL:
				var missing := target.data.hp + target.max_hp_bonus - target.current_hp
				return float(mini(sk.amount, missing)) * 2.5 + _unit_value(target) * 0.08
			SkillData.Effect.SHIELD:
				return float(sk.amount) * 1.5 + _unit_value(target) * 0.1
			SkillData.Effect.APPLY_STATUS:
				return 0.0 if target.has_status(sk.status) else 4.0 + _unit_value(target) * 0.12
		return 0.0
	var damage := maxi(sk.power, 0)
	var dealt := mini(damage, target.current_hp + target.shield)
	var score := float(dealt) * 2.4 + float(target.atk_total()) * 0.45
	if damage >= target.current_hp + target.shield:
		score += 9.0
	if sk.effect == SkillData.Effect.APPLY_STATUS and not target.has_status(sk.status):
		score += 4.0
	return score


func _best_scry_index(look_n: int) -> int:
	var options := bm.peek_deck_top("enemy", look_n)
	var best_i := 0
	var best_score := -INF
	for i in range(options.size()):
		var score := _hold_value(options[i])
		if score > best_score:
			best_score = score
			best_i = i
	return best_i


func _worst_hand_card_path(excluded: CardData) -> String:
	var worst: CardData = null
	var worst_score := INF
	for cd in bm.hand_of("enemy"):
		if cd == excluded:
			continue
		var score := _hold_value(cd)
		if score < worst_score:
			worst_score = score
			worst = cd
	return worst.resource_path if worst != null else ""


## ── 主動技能 ─────────────────────────────────────
func _skill_phase() -> void:
	# 不依場景樹順序一隻隻用：每次都把全場還可用的技能一起評分。
	# 否則一個低價值的自我上盾可能先把魔力花掉，讓牧師無法救重傷友軍。
	for _guard in 12:
		if _stopped():
			return
		var best: Dictionary = {}
		for unit in _units_of("enemy"):
			if not is_instance_valid(unit) or bm.skill_block_reason(unit) != "":
				continue
			var target := _pick_skill_target(unit)
			if target == null:
				continue
			var score := _skill_action_score(unit, target)
			if best.is_empty() or score > float(best.score):
				best = {"caster": unit, "target": target, "score": score}
		if best.is_empty():
			return
		var caster: Card = best.caster
		var target: Node3D = best.target
		var slot := bm.find_slot_of(caster)
		if slot == null:
			return
		var is_hero := target is Hero
		var target_ref := (target as Hero).side if is_hero \
			else str(cm.get_path_to(bm.find_slot_of(target as Card)))
		cm._net_action(cm.get_path_to(slot), true, is_hero, target_ref)
		await _wait(step_delay)


func _skill_action_score(caster: Card, target: Node3D) -> float:
	var sk := caster.data.active_skill
	if sk.kind != SkillData.Kind.NON_ATTACK:
		var damage := caster.atk_total() + sk.power \
			if sk.kind == SkillData.Kind.ENHANCED_ATTACK else sk.power
		if target is Hero:
			return 100.0 if damage >= (target as Hero).hp else float(damage) * 1.6
		var foe := target as Card
		var effective_hp := foe.current_hp + foe.shield
		return float(mini(damage, effective_hp)) * 2.0 \
			+ float(foe.atk_total()) * 0.7 + (8.0 if damage >= effective_hp else 0.0)
	match sk.effect:
		SkillData.Effect.HEAL:
			var missing := 0
			if target is Hero:
				missing = (target as Hero).max_hp - (target as Hero).hp
			elif target is Card:
				var ally := target as Card
				missing = ally.data.hp + ally.max_hp_bonus - ally.current_hp
			return float(mini(sk.amount, missing)) * 3.0
		SkillData.Effect.SHIELD:
			return float(sk.amount) * 1.6 \
				+ (_unit_value(target as Card) * 0.1 if target is Card else 0.0)
		SkillData.Effect.APPLY_STATUS:
			return 5.0 + (_unit_value(target as Card) * 0.12 if target is Card else 0.0)
		SkillData.Effect.SUMMON:
			return 7.0
	return 0.0


func _pick_skill_target(caster: Card) -> Node3D:
	var sk := caster.data.active_skill
	if sk == null:
		return null
	if sk.kind != SkillData.Kind.NON_ATTACK:
		return _pick_combat_target(caster, sk)
	match sk.effect:
		SkillData.Effect.SUMMON:
			return caster if _pick_summon_slot() != null else null
		SkillData.Effect.HEAL:
			if sk.effect_target == SkillData.Target.ALLY_HERO:
				return bm.enemy_hero if bm.enemy_hero.hp < bm.enemy_hero.max_hp else null
			if sk.effect_target == SkillData.Target.SELF:
				return caster if caster.current_hp < caster.data.hp + caster.max_hp_bonus else null
			return _most_damaged_ally()
		SkillData.Effect.SHIELD:
			if sk.effect_target == SkillData.Target.SELF:
				return caster if caster.shield < sk.amount else null
			return _best_ally_target(sk.status)
		SkillData.Effect.APPLY_STATUS:
			if sk.effect_target == SkillData.Target.LANE_ENEMY:
				return _best_status_target("player", sk.status)
			if sk.effect_target == SkillData.Target.SELF:
				return caster if not caster.has_status(sk.status) else null
			return _best_ally_target(sk.status)
	return null


## ── 攻擊 ─────────────────────────────────────────
func _attack_phase() -> void:
	for unit in _units_of("enemy"):
		if _stopped():
			return
		if not is_instance_valid(unit) or bm.attack_block_reason(unit) != "":
			continue
		var target := _pick_combat_target(unit, null)
		if target == null:
			continue
		var slot := bm.find_slot_of(unit)
		if slot == null:
			continue
		var is_hero := target is Hero
		var target_ref := (target as Hero).side if is_hero \
			else str(cm.get_path_to(bm.find_slot_of(target as Card)))
		cm._net_action(cm.get_path_to(slot), false, is_hero, target_ref)
		await _wait(step_delay)


func _pick_combat_target(attacker: Card, skill: SkillData) -> Node3D:
	var damage := attacker.atk_total()
	var retaliates := true
	if skill != null:
		if skill.kind == SkillData.Kind.ENHANCED_ATTACK:
			damage += skill.power
		else:
			damage = skill.power
			retaliates = false
	# 有斬殺永遠先打本體。
	if bm.face_block_reason(attacker, bm.player_hero, skill) == "" \
			and damage >= bm.player_hero.hp:
		return bm.player_hero
	var best: Node3D = null
	var best_score := -INF
	for target in _units_of("player"):
		var effective_hp := target.current_hp + target.shield
		var score := float(mini(damage, effective_hp)) * 2.0 \
			+ float(target.atk_total()) * 0.7
		if damage >= effective_hp:
			score += 8.0
		if retaliates and target.atk_total() >= attacker.current_hp + attacker.shield \
				and damage < effective_hp:
			score -= 6.0
		if skill != null and skill.modifier != SkillData.Modifier.NONE:
			score += 3.0
		if score > best_score:
			best_score = score
			best = target
	if bm.face_block_reason(attacker, bm.player_hero, skill) == "":
		var face_score := float(damage) * 1.6
		if face_score > best_score:
			best = bm.player_hero
	return best


## ── 棋盤與價值函式 ───────────────────────────────
func _pick_summon_slot() -> CardSlot:
	var front: Array[CardSlot] = []
	for node in get_tree().get_nodes_in_group("enemy_front"):
		if node is CardSlot and (node as CardSlot).is_empty:
			front.append(node)
	if not front.is_empty():
		var threats := _units_of("player")
		if threats.is_empty():
			return _closest_to_center(front)
		var threat := threats[0]
		for unit in threats:
			if _unit_value(unit) > _unit_value(threat):
				threat = unit
		var threat_slot := bm.find_slot_of(threat)
		return _closest_x(front, threat_slot.global_position.x) if threat_slot != null \
			else _closest_to_center(front)
	return _first_empty("enemy_back")


func _pick_equip_target(cd: CardData) -> Card:
	var best: Card = null
	var best_score := -INF
	for unit in _units_of("enemy"):
		var old_value := _equipment_value(unit.equipped_cards[0]) \
			if not unit.equipped_cards.is_empty() else 0.0
		var upgrade := _equipment_value(cd) - old_value
		if upgrade <= 0.0:
			continue
		var score := upgrade + _unit_value(unit) * 0.15
		if score > best_score:
			best_score = score
			best = unit
	return best


func _pick_ward_host() -> Card:
	var best: Card = null
	var best_score := -INF
	for unit in _units_of("enemy"):
		if bm.host_has_ward(unit):
			continue
		var score := _unit_value(unit)
		if score > best_score:
			best_score = score
			best = unit
	return best


func _most_damaged_ally() -> Card:
	var best: Card = null
	var best_score := 0.0
	for unit in _units_of("enemy"):
		var missing := unit.data.hp + unit.max_hp_bonus - unit.current_hp
		var score := float(missing) * 3.0 + _unit_value(unit) * 0.1
		if missing > 0 and score > best_score:
			best_score = score
			best = unit
	return best


func _best_ally_target(status: SkillData.Status) -> Card:
	var best: Card = null
	var best_score := -INF
	for unit in _units_of("enemy"):
		if status != SkillData.Status.NONE and unit.has_status(status):
			continue
		var score := _unit_value(unit)
		if score > best_score:
			best_score = score
			best = unit
	return best


func _best_status_target(side: String, status: SkillData.Status) -> Card:
	var best: Card = null
	var best_score := -INF
	for unit in _units_of(side):
		if unit.has_status(status):
			continue
		var score := _unit_value(unit)
		if score > best_score:
			best_score = score
			best = unit
	return best


func _units_of(side: String) -> Array[Card]:
	var out: Array[Card] = []
	for group in [side + "_front", side + "_back"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is CardSlot and (node as CardSlot).card_in_slot != null:
				out.append((node as CardSlot).card_in_slot)
	return out


func _first_empty(group: String) -> CardSlot:
	for node in get_tree().get_nodes_in_group(group):
		if node is CardSlot and (node as CardSlot).is_empty:
			return node
	return null


func _closest_to_center(slots: Array[CardSlot]) -> CardSlot:
	return _closest_x(slots, 0.0)


func _closest_x(slots: Array[CardSlot], x: float) -> CardSlot:
	var best: CardSlot = null
	var best_distance := INF
	for slot in slots:
		var distance := absf(slot.global_position.x - x)
		if distance < best_distance:
			best_distance = distance
			best = slot
	return best


func _empty_slot_count(group: String) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(group):
		if node is CardSlot and (node as CardSlot).is_empty:
			count += 1
	return count


func _minion_value(cd: CardData) -> float:
	var value := float(cd.atk * 2 + cd.hp)
	value += float(cd.keywords.size()) * 1.5
	if cd.active_skill != null:
		value += 2.0
	if cd.battlecry != null:
		value += 2.0
	return value


func _equipment_value(cd: CardData) -> float:
	if cd == null:
		return 0.0
	var hp_bonus := cd.equip_hp_bonus
	if hp_bonus == 0 and cd.special_id == &"" and cd.active_skill != null:
		hp_bonus = cd.active_skill.amount
	return float(cd.equip_atk_bonus * 2 + hp_bonus) \
		+ float(cd.equip_keywords.size()) * 2.0 + (3.0 if cd.equip_lifesteal else 0.0)


func _unit_value(unit: Card) -> float:
	return float(unit.atk_total() * 2 + unit.current_hp + unit.shield) \
		+ float(unit.data.keywords.size()) * 1.5


func _board_value(units: Array[Card]) -> float:
	var total := 0.0
	for unit in units:
		total += _unit_value(unit)
	return total


func _hold_value(cd: CardData) -> float:
	match cd.card_type:
		CardData.CardType.MINION:
			return _minion_value(cd)
		CardData.CardType.QUICK:
			return 9.0 + float(cd.cost)
		CardData.CardType.EQUIP:
			return 4.0 + _equipment_value(cd)
		CardData.CardType.WARD:
			return 5.0 + float(cd.cost)
		CardData.CardType.ARCANA:
			return 6.0 + float(cd.cost) * 0.6
	return float(cd.cost)
