## enemy_ai.gd — 敵方 AI:「另一個會按按鈕的玩家」
##
## 職責:單人模式下,輪到 enemy 時自動行動——
##   召喚付得起的從者(前排優先)→ 場上能動的單位普攻(有目標打目標、無阻擋打臉)→ 結束回合。
## 原則:不開後門、不碰 UI;規則一律問 BattleManager(attack_block_reason 等),
##   結算走「和連線重放同一條路」(_net_summon / _net_action 的重放端分支)——
##   帳的一致性靠所有人走同一條結算路保證,AI 只是另一個發令者。
## 掛法:VS_AI 模式時由 CardManager 在 _ready 生成、掛在自己底下。
class_name EnemyAI
extends Node

const STEP_DELAY := 0.7    # 每個動作之間停一拍,人眼才跟得上 AI 在做什麼
const THINK_DELAY := 0.9   # 回合開頭「想一下」,換頁訊息先落地

var cm: Node = null              # CardManager(中樞;鴨子型別,避免循環參考)
var bm: BattleManager = null


func setup(manager: Node) -> void:
	cm = manager
	bm = manager.battle_manager


## 回合主流程。每個 await 醒來都先問「還輪得到我嗎」——
## 玩家的伏印/反擊可能在中途分出勝負,勝負已分就立刻收手。
func take_turn() -> void:
	await _wait(THINK_DELAY)
	if _stopped():
		return
	await _summon_phase()
	if _stopped():
		return
	await _attack_phase()
	if _stopped():
		return
	await _wait(0.5)
	if _stopped():
		return
	cm._net_end_turn()   # 離線直呼,和玩家按「結束回合」走同一條換頁路


func _stopped() -> bool:
	return bm.game_ended or bm.active_side != "enemy"


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## ── 出牌階段:付得起就召喚,前排優先(前排才有阻擋/嘲諷的規則地位)──
## 只出從者:法術牌 v1 先握著不用(AI 施法是之後的擴充,見 README 待辦)。
func _summon_phase() -> void:
	for _guard in 10:   # 安全上限:手牌最多 8,10 次絕對夠;防呆勝過防意外
		var pick: CardData = null
		for cd in bm.hand_of("enemy"):
			if cd.card_type == CardData.CardType.MINION and bm.can_afford(cd.cost):
				pick = cd
				break
		if pick == null:
			return
		var slot := _first_empty("enemy_front")
		if slot == null:
			slot = _first_empty("enemy_back")
		if slot == null:
			return
		var idx: int = bm.hand_of("enemy").find(pick)
		# 走連線重放同一條函式:VS_AI 時 _acting_locally() 為 false → 帳面路徑
		cm._net_summon(idx, pick.resource_path, cm.get_path_to(slot))
		await _wait(STEP_DELAY)
		if _stopped():
			return


## ── 攻擊階段:每隻能動的單位打一次(先清場上目標,沒目標且路線無阻就打臉)──
func _attack_phase() -> void:
	var slots: Array[Node] = []
	slots.append_array(get_tree().get_nodes_in_group("enemy_front"))
	slots.append_array(get_tree().get_nodes_in_group("enemy_back"))
	for slot in slots:
		if _stopped():
			return
		var unit: Card = (slot as CardSlot).card_in_slot
		if unit == null or bm.attack_block_reason(unit) != "":
			continue
		var target := _pick_target(unit)
		if target == null:
			continue
		var tgt_is_hero := target is Hero
		var tgt_ref: String = "player" if tgt_is_hero \
			else str(cm.get_path_to(bm.find_slot_of(target)))
		cm._net_action(cm.get_path_to(slot), false, tgt_is_hero, tgt_ref)
		await _wait(STEP_DELAY)


## 目標優先序:玩家前排 → 玩家後排 → 本體(打臉合法性問規則,不自己判)。
func _pick_target(attacker: Card) -> Node3D:
	for group in ["player_front", "player_back"]:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot and (slot as CardSlot).card_in_slot != null:
				return (slot as CardSlot).card_in_slot
	if bm.face_block_reason(attacker, bm.player_hero, null) == "":
		return bm.player_hero
	return null


func _first_empty(group: String) -> CardSlot:
	for slot in get_tree().get_nodes_in_group(group):
		if slot is CardSlot and (slot as CardSlot).is_empty:
			return slot
	return null
