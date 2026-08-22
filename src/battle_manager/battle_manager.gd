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
signal state_changed(turn: int, side: String, mana: int, mana_max: int, temp_mana: int)
## 有單位死亡(CardManager 靠這條清掉指向死者的參考)。
signal unit_died(unit: Card)
## 有牌入土(CardManager 靠這條刷新墓地視覺)。
signal card_buried(side: String, cd: CardData)
## 伏印帳有變(CardManager 靠這條開關整排卡槽的紅色警戒)。
signal wards_changed(side: String, count: int)
## 規則層要求抽牌(巫師/邪眼魔的戰吼)。為什麼不直接抽:
## draw_cards() 只動「帳」,手牌「視圖」的 stash 對帳與飛入動畫在 CardManager 那邊
## (§28 帳/視圖分離)。帳房不該知道視圖怎麼演,所以喊一聲、讓 CardManager 走它既有的
## _apply_draw 單一入口——連線重放與熱座也就自動沿用同一條路。
signal draw_requested(n: int)
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
	## 丟牌回魔的暫時魔力(§1.1):mana 裡有幾點是「自己下回合開始就蒸發」的錢。
	## 顯示用的帳中帳(HUD 畫黃◆):增減永遠跟著 mana 走,不變量 temp_mana ≤ mana。
	var temp_mana: int = 0
	var deck: Array[CardData] = []
	var hand: Array[CardData] = []
	## 蓋放的伏印(§7 宿主制,對齊桌遊):每筆 {"cd": CardData, "host": Card}——
	## 伏印必須埋在「我方場上從者」底下,宿主離場時未觸發的伏印隨葬。
	## 不佔卡槽;順序=蓋放順序(先蓋先發);「敵方召喚時觸發」見 mark_summoned。
	var wards: Array[Dictionary] = []
	## 墓地:所有離場的牌統一收這裡(死亡從者+隨葬靈裝、用畢的秘術/瞬咒、
	## 觸發過的伏印、爆牌、丟牌回魔)——入口只有一個 bury()。
	var grave: Array[CardData] = []
	## 丟牌回魔冷卻(§1.1):0=可用;使用設 2、自己回合開始 -1 → 隔回合一次。
	var discard_cd: int = 0

var turn: int = 1
var active_side: String = "player"   # 現在輪到誰行動(回合歸屬)
var sides: Dictionary = {}           # "player"/"enemy" → SideState

## 單位節點的掛點(CardManager 在 _ready 注入 player_hand):
## place_card 的「躺平」靠它的 -90°X 旋轉;召喚技與連線重放生單位都掛這裡。
var hand_node: PlayerHand = null

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
	st.temp_mana = 0   # 暫時魔力被「回滿」洗掉:帳中帳跟著歸零(§1.1)
	st.discard_cd = maxi(0, st.discard_cd - 1)   # 丟牌回魔冷卻:自己回合開始 -1(§1.1)


## 行動方目前的魔力(給 UI 顯示用;帳本身是私有的,外部走這個口)。
func active_mana() -> int:
	return _active().mana


func can_afford(cost: int) -> bool:
	return _active().mana >= cost


## 召喚費由 CardManager 在出牌時呼叫;技能費在 on_action_performed 內扣。
func spend(cost: int) -> void:
	_pay(_active(), cost)
	_emit_state()


## 扣費的唯一出口:暫時魔力先被吃掉,順手維持不變量 temp_mana ≤ mana。
## 機制上先扣誰都一樣(下回合全洗掉),挑「暫時的先走」是讓視覺語意成立:
## 黃◆疊在魔力列最右,花費從右邊扣 → 黃色=最先消失的錢。
func _pay(st: SideState, cost: int) -> void:
	st.mana = maxi(0, st.mana - cost)
	st.temp_mana = clampi(st.temp_mana - cost, 0, st.mana)


## 換邊前,把手牌「視圖」的現況存回行動方的帳(視圖是顯示,帳才是真相)。
func stash_hand(hand_data: Array[CardData]) -> void:
	_active().hand = hand_data


## 目前行動方的手牌資料(CardManager 拿去重建視圖)。
func active_hand() -> Array[CardData]:
	return _active().hand


## 指定側的手牌資料(連線視角鎖定用:各機只看自己那側的手牌)。
func hand_of(side: String) -> Array[CardData]:
	return (sides[side] as SideState).hand


## Debug 離線測卡:把指定卡移進手牌並補足它的費用。
## 這裡只改「帳」;CardManager 呼叫前會先 stash 視圖、呼叫後再 rebuild。
## 線上禁用:client 本地塞牌會和權威帳分家,也等同作弊。
func debug_prepare_card(side: String, card_path: String) -> Dictionary:
	var result := {
		"ok": false, "reason": "", "added": false,
		"replaced": "", "replacement_note": "", "card": null,
	}
	if not OS.is_debug_build():
		result.reason = "僅 Debug 版本可使用測卡功能"
		return result
	if NetMatch.is_online or NetMatch.is_dedicated_server:
		result.reason = "連線對局停用測卡功能,避免雙方帳目不同步"
		return result
	if not sides.has(side):
		result.reason = "找不到測試側別:%s" % side
		return result
	if not ResourceLoader.exists(card_path):
		result.reason = "找不到測試卡:%s" % card_path
		return result
	var cd := load(card_path) as CardData
	if cd == null:
		result.reason = "測試資源不是 CardData:%s" % card_path
		return result

	var st := sides[side] as SideState
	var already_held := false
	for held in st.hand:
		if held.resource_path == cd.resource_path:
			cd = held
			already_held = true
			break
	if not already_held:
		# 優先把牌堆裡原有的那一份搬進手牌;沒有時移除一張牌堆底卡來維持總張數。
		var deck_index := -1
		for i in range(st.deck.size()):
			if st.deck[i].resource_path == cd.resource_path:
				deck_index = i
				break
		if deck_index >= 0:
			cd = st.deck[deck_index]
			st.deck.remove_at(deck_index)
		elif not st.deck.is_empty():
			st.deck.pop_front()
		elif not st.hand.is_empty():
			# 牌堆已空時改成原位替換一張手牌;不憑空增加這局的總牌數。
			var displaced: CardData = st.hand.pop_back()
			result.replaced = displaced.card_name
			result.replacement_note = "(牌堆已空,以【%s】替換)" % displaced.card_name
		else:
			result.reason = "牌堆與手牌都已空,沒有可替換的測試牌位置"
			return result
		# 滿手時把最右一張放回牌堆底,測卡不直接燒掉玩家原本的牌。
		if st.hand.size() >= MAX_HAND:
			var returned: CardData = st.hand.pop_back()
			result.replaced = returned.card_name
			result.replacement_note = "(滿手,已把【%s】放回牌堆底)" % returned.card_name
			st.deck.push_front(returned)
		st.hand.append(cd)
		result.added = true

	var needed := clampi(cd.cost, 0, MANA_CAP)
	st.mana_max = maxi(st.mana_max, needed)
	st.mana = maxi(st.mana, needed)
	st.temp_mana = mini(st.temp_mana, st.mana)
	result.ok = true
	result.card = cd
	if side == active_side:
		_emit_state()
	return result


func deck_count(side: String) -> int:
	return (sides[side] as SideState).deck.size() if sides.has(side) else 0


## ── 墓地(§7 收尾/§1 爆牌/§1.1 棄牌的共同去處)──────────────
## 所有「離場的牌」統一從這裡入土。埋點全都在兩台會重放的函式裡
## (死亡結算/consume_quick/mark_summoned/end_turn/丟牌 RPC),
## 所以連線不需要任何新的同步——資料一致+操作一致=墓地一致。
func bury(side: String, cd: CardData) -> void:
	if cd == null or not sides.has(side):
		return
	(sides[side] as SideState).grave.append(cd)
	card_buried.emit(side, cd)


func grave_count(side: String) -> int:
	return (sides[side] as SideState).grave.size() if sides.has(side) else 0


## 最後入土的那張(墓地視覺讓它躺在最上面;空墓回 null)。
func grave_top(side: String) -> CardData:
	var g: Array[CardData] = (sides[side] as SideState).grave
	return g.back() if not g.is_empty() else null


## ── 丟牌回魔(§1.1)───────────────────────────────
func can_discard_for_mana(side: String) -> bool:
	return (sides[side] as SideState).discard_cd == 0


## 帳面結算:回魔 = Cost÷2 無條件捨去;冷卻設 2(自己回合開始 -1 →
## 下一個自己的回合仍是 1 被擋、再下一回合歸 0 = 規格「最多隔回合一次」)。
## 手牌的「移除」不在這裡:出牌端走視圖、重放端走 remove_from_hand,
## 和召喚同一套不對稱(見 card_manager._consume_played)。
func apply_discard_for_mana(side: String, cd: CardData) -> int:
	var st: SideState = sides[side]
	var gained := floori(cd.cost / 2.0)
	st.mana += gained        # 暫時魔力:下回合開始會被「回滿至上限」洗掉,天生不留存(§1)
	st.temp_mana += gained   # 帳中帳:讓 HUD 知道這幾點是黃色的(顯示用,不另立規則)
	st.discard_cd = 2
	bury(side, cd)
	_emit_state()
	return gained


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
	# 抽牌階段(§5):走 draw_cards 單一入口——爆牌規則只寫一份,法術抽牌同款。
	var d := draw_cards(active_side, 1)
	var result := {"drawn": null, "burned": d.burned > 0}
	if not d.drawn.is_empty():
		result.drawn = d.drawn[0]
	_emit_state()
	return result


## ── 抽牌/濾牌(§抽濾;法術與回合抽共用的單一入口)──────────


## 抽 n 張:滿手燒牌(§1 爆牌:牌照樣從牌堆消失,雙方可見)、
## 牌堆空了就抽不到(本作無疲勞傷害)。
## 回傳 {"drawn": Array[CardData] 實際入手, "burned": int 燒掉幾張}。
func draw_cards(side: String, n: int) -> Dictionary:
	var st := sides[side] as SideState
	var drawn: Array[CardData] = []
	var burned := 0
	for i in range(n):
		if st.deck.is_empty():
			break
		if st.hand.size() >= MAX_HAND:
			bury(side, st.deck.pop_back())
			burned += 1
		else:
			var cd: CardData = st.deck.pop_back()
			st.hand.append(cd)
			drawn.append(cd)
	_emit_state()
	return {"drawn": drawn, "burned": burned}


## 看牌堆頂 n 張(不動帳,只讀;回傳 [0] = 最頂)。
func peek_deck_top(side: String, n: int) -> Array[CardData]:
	var deck: Array[CardData] = (sides[side] as SideState).deck
	var out: Array[CardData] = []
	for i in range(mini(n, deck.size())):
		out.append(deck[deck.size() - 1 - i])
	return out


## 濾牌結算(命運窺視):頂 look_n 張取第 pick_i 張入手,其餘放回牌堆底。
## pick_i 對齊 peek_deck_top 的順序([0]=最頂)。兩台各自重放同款參數,結果一致。
func scry_pick(side: String, look_n: int, pick_i: int) -> Dictionary:
	var st := sides[side] as SideState
	var popped: Array[CardData] = []
	for i in range(mini(look_n, st.deck.size())):
		popped.append(st.deck.pop_back())
	if popped.is_empty():
		return {"picked": null, "burned": false}
	pick_i = clampi(pick_i, 0, popped.size() - 1)
	var picked: CardData = popped[pick_i]
	popped.remove_at(pick_i)
	for cd in popped:
		st.deck.insert(0, cd)   # 其餘放牌堆底(對手只知道張數沒變,不知內容)
	var burned := false
	if st.hand.size() >= MAX_HAND:   # 防呆:施法後手牌 ≤7,正常流程到不了這
		bury(side, picked)
		burned = true
	else:
		st.hand.append(picked)
	_emit_state()
	return {"picked": picked, "burned": burned}


## 棄掉手牌第 idx 張入墓(以血換識的「換」;不觸發丟牌回魔、不吃冷卻)。
func discard_from_hand(side: String, idx: int) -> CardData:
	var st := sides[side] as SideState
	if idx < 0 or idx >= st.hand.size():
		return null
	var cd: CardData = st.hand[idx]
	st.hand.remove_at(idx)
	bury(side, cd)
	_emit_state()
	return cd


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
## 召喚落地:記召喚暈眩,並結算「對方蓋放的伏印」(§7 爆裂符印:敵方召喚時觸發)。
## 回傳觸發訊息(空字串 = 沒有伏印),CardManager 拿去 flash 給玩家看。
func mark_summoned(unit: Card) -> String:
	unit.summoned_this_turn = true
	# 戰吼先於伏印結算。順序有實質差別,不是隨便排的:
	# 黑騎士 A 的【暗影護甲】(登場 +2 護盾)必須先掛上,才擋得住緊接著引爆的伏印傷害。
	# 反過來排,「登場就有盾」這句話在最需要它的那一刻剛好沒作用。
	var msg := _resolve_battlecry(unit)
	var owner_side := "enemy" if active_side == "player" else "player"
	var traps: Array[Dictionary] = (sides[owner_side] as SideState).wards
	if traps.is_empty():
		return msg
	# §5.1 簡化原則:一次觸發一張(先蓋的先發)。
	var entry: Dictionary = traps.pop_front()
	var trap: CardData = entry.cd
	bury(owner_side, trap)   # 伏印用掉即入土(§7)
	wards_changed.emit(owner_side, traps.size())
	var dmg := trap.active_skill.power if trap.active_skill != null else 0
	_deal_damage(unit, dmg, false)
	_check_death(unit)
	var trap_msg := "伏印【%s】觸發:對召喚的【%s】造成 %d 點傷害!" % [
		trap.card_name, unit.data.card_name, dmg]
	return trap_msg if msg.is_empty() else msg + "\n" + trap_msg


## 戰吼:召喚落地時自動結算一次 data.battlecry(null = 沒有戰吼)。
## 回傳給 UI 的訊息(空字串 = 沒觸發)。
##
## 為什麼掛在 mark_summoned 而不是出牌按鈕那邊:這裡是**所有召喚的必經之路**——
## 手動出牌、從者的召喚技(_resolve_summon)、召喚系秘術(summon_for_side)、
## 連線重放端生單位,四條路最後都會經過它。接一個點,四種情境一起生效;
## 接在出牌按鈕上,則「死靈法師召出來的骷髏」永遠不會觸發自己的戰吼。
## (和伏印觸發挑同一個點是同一個理由,不是巧合。)
func _resolve_battlecry(unit: Card) -> String:
	if unit.data == null or unit.data.battlecry == null:
		return ""
	var bc: SkillData = unit.data.battlecry
	match bc.effect:
		SkillData.Effect.SUMMON:
			_resolve_summon(unit, bc)
		SkillData.Effect.DRAW:
			draw_requested.emit(bc.amount)   # 視圖那半交給 CardManager(見信號註解)
		_:
			_apply_skill_effect(unit, bc, null)
	var label := bc.description if bc.description != "" else bc.skill_name
	return "【%s】的戰吼:%s" % [unit.data.card_name, label]


## 正對面那一路的敵方前排單位(戰吼指定 LANE_ENEMY 時用;沒有就回 null)。
## 路線對位一律用 x 座標找最近的對面格,不寫死欄號——和 _lane_blocked 同一把尺。
func _lane_opposite(unit: Card) -> Card:
	var my_slot := _find_slot(unit)
	if my_slot == null:
		return null
	var opposing := "enemy_front" if side_of(unit) == "player" else "player_front"
	var nearest: CardSlot = null
	var best := INF
	for slot in get_tree().get_nodes_in_group(opposing):
		if slot is CardSlot:
			var dx: float = absf(
				(slot as CardSlot).global_position.x - my_slot.global_position.x)
			if dx < best:
				best = dx
				nearest = slot
	return nearest.card_in_slot if nearest != null else null


## ── 法術結算(§7 非從者卡;由 CardManager 的出牌流程呼叫)──────────
## 規則只寫這一份:UI 負責選目標和問反制,數值在這裡落地。


## 秘術結算(有目標的那一類):效果由 skill.effect 決定,不再只有傷害一種。
## 回傳給 UI 顯示的訊息字串——訊息的措辭跟著效果走,所以由這裡組(同 mark_summoned)。
##
## 為什麼傷害要走 _resolve_attack 而不是直接 _deal_damage?
## 因為橫掃/貫穿/連擊/吸血的展開只寫在那一份裡(§20 choke point)。
## 秘術傳 attacker = null + retaliate = false:秘術不吃反擊、也沒有施法單位可回血。
func cast_arcana(card: CardData, target: Card) -> String:
	if not is_instance_valid(target) or card.active_skill == null:
		return ""
	var sk: SkillData = card.active_skill
	match sk.effect:
		SkillData.Effect.HEAL:
			target.heal(sk.amount)
			return "【%s】治療【%s】%d 點" % [card.card_name, target.data.card_name, sk.amount]
		SkillData.Effect.APPLY_STATUS:
			# 複合秘術:power > 0 就先打傷害再上狀態(順序同從者的攻擊技——
			# 傷害落地、目標還活著才上狀態,不然是替屍體掛 debuff)。
			var msg := "【%s】對【%s】" % [card.card_name, target.data.card_name]
			if sk.power > 0:
				_resolve_attack(null, target, sk.power, false, sk.modifier, false)
				msg += "造成 %d 點傷害並" % sk.power
			if is_instance_valid(target):
				_apply_timed_status(target, sk.status, sk.status_turns)
			return msg + "施加【%s】%d 回合" % [
				Card.STATUS_NAMES.get(sk.status, "狀態"), sk.status_turns]
		_:
			# Effect.NONE = 純傷害秘術(火焰爆裂那一類)。
			# ⚠ 不要在這裡再補一次 _check_death:_resolve_attack 內部已經做過,
			# 重複呼叫會讓死亡流程跑兩次——第二次 side_of() 查不到卡槽(第一次已清位)
			# 回空字串,sides[""] 直接炸。回歸測試抓到的就是這個。
			var name_before := target.data.card_name   # 目標可能在結算中死亡被清掉
			_resolve_attack(null, target, sk.power, false, sk.modifier, false)
			return "【%s】對【%s】造成 %d 點傷害" % [
				card.card_name, name_before, sk.power]


## 召喚系秘術:沒有施法單位,所以空位要用「行動方」來找(對照 _resolve_summon 用 caster)。
## 回傳訊息字串;場滿時召喚落空(和爐石同規,也和 _resolve_summon 一致)。
func summon_for_side(side: String, skill: SkillData) -> String:
	if skill == null or skill.summon_card == "":
		return ""
	var res_path := "res://data/cards/%s.tres" % skill.summon_card
	if not ResourceLoader.exists(res_path):
		push_warning("[秘術召喚] 找不到 %s" % res_path)
		return ""
	var slot := _first_empty_slot(side)
	if slot == null:
		return "場上沒有空位,召喚落空了"
	var unit := spawn_unit(load(res_path), slot)
	if unit == null:
		return ""
	mark_summoned(unit)   # 召喚暈眩 + 對方伏印觸發(§7),和一般召喚同一條路
	return "召喚了【%s】" % unit.data.card_name


## 靈裝(秘銀胸鎧):我方從者生命上限 +amount 並補等量現血;
## 加成記在「單位節點」上(max_hp_bonus)——宿主離場,裝備自然隨節點一起消失(§7)。
## 一次一件(桌遊試玩回饋):新裝蓋舊裝——舊裝的加成收回、卡進墓地。
## 回傳被替換的舊裝名("" = 本來沒穿),CardManager 拿去組提示訊息。
func attach_equip(card: CardData, target: Card) -> String:
	if not is_instance_valid(target) or card.active_skill == null:
		return ""
	var replaced := ""
	for old in target.equipped_cards:
		if old.active_skill != null:
			target.max_hp_bonus -= old.active_skill.amount
		bury(side_of(target), old)
		replaced = old.card_name
	target.equipped_cards.clear()
	target.clamp_hp()   # 舊裝拆了上限縮水,現血夾回上限(6/6+2 拆裝 → 4/4)
	target.max_hp_bonus += card.active_skill.amount
	target.heal(card.active_skill.amount)
	target.equipped_cards.append(card)   # 記在宿主身上:宿主陣亡時靈裝隨葬(§7)
	return replaced


## 伏印(§7 宿主制):埋設在「我方場上從者」底下,等對方召喚時觸發(mark_summoned)。
## 側別由宿主推,不看 active_side——帳跟著宿主走,呼叫端不用想現在輪到誰。
func set_ward(card: CardData, host: Card) -> void:
	var side := side_of(host)
	(sides[side] as SideState).wards.append({"cd": card, "host": host})
	wards_changed.emit(side, ward_count(side))


func ward_count(side: String) -> int:
	return (sides[side] as SideState).wards.size() if sides.has(side) else 0


## 這隻從者底下有沒有埋著伏印(一格一張,§7 擺放規則)。
func host_has_ward(unit: Card) -> bool:
	for entry in (sides[side_of(unit)] as SideState).wards:
		if entry.host == unit:
			return true
	return false


## 守方手上第一張「付得起」的瞬咒(§5.1 反制窗口用;沒有就回 null)。
## 守方用的是帳上的手牌(熱座時他的牌已 stash 回帳)與帳上的剩餘魔力。
func quick_candidate(defender: String) -> CardData:
	var st: SideState = sides[defender]
	for cd in st.hand:
		if cd.card_type == CardData.CardType.QUICK and st.mana >= cd.cost:
			return cd
	return null


## 守方發動瞬咒:扣魔力、離手(§5.1;抵銷的效果由呼叫端決定「不結算」來實現)。
func consume_quick(defender: String, quick: CardData) -> void:
	var st: SideState = sides[defender]
	_pay(st, quick.cost)   # 瞬咒在「對方回合」付費:自己上回合剩的暫時魔力也花得到
	st.hand.erase(quick)
	bury(defender, quick)   # 瞬咒用掉即入土(§7);熱座/連線都經過這裡,埋一次就好
	_emit_state()


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
		_pay(_active(), skill.cost)
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
		# 非攻擊技:治療 / 護盾 / 上狀態 / 召喚(§6【非攻擊】)。
		if skill.effect == SkillData.Effect.SUMMON:
			_resolve_summon(caster, skill)
		else:
			_apply_skill_effect(caster, skill, target)
		return
	if target is Hero:
		(target as Hero).take_damage(dmg)   # 打臉不吃反擊(§4.2)
		return
	var mod := SkillData.Modifier.NONE if skill == null else skill.modifier
	_resolve_attack(caster, target as Card, dmg, retaliate, mod)
	# 攻擊技的附帶效果(火球術的灼燒、戰騎突擊的自身護盾、狂暴衝鋒的自身鍛強):
	# 一律等傷害落地才結算——打敵方的 debuff 要目標還活著才上,不然是替屍體掛狀態。
	if skill != null and skill.effect != SkillData.Effect.NONE:
		_apply_skill_effect(caster, skill, target)


## 技能效果的統一結算:**做什麼**由 skill.effect 決定、**對誰做**由 skill.effect_target 決定。
## 非攻擊技的主體效果、攻擊技的附帶效果、戰吼,三條路都走這一份——
## 分開寫的話,每加一種 Effect 就得記得改三個地方(這次加護盾就是被這件事逼出來的)。
func _apply_skill_effect(caster: Card, skill: SkillData, target: Node3D) -> void:
	for who in _effect_recipients(caster, skill, target):
		if not is_instance_valid(who):
			continue
		match skill.effect:
			SkillData.Effect.HEAL:
				if who is Card:
					(who as Card).heal(skill.amount)
				elif who is Hero:
					(who as Hero).heal(skill.amount)
			SkillData.Effect.SHIELD:
				if who is Card:
					(who as Card).add_shield(skill.amount)
			SkillData.Effect.APPLY_STATUS:
				if who is Card:
					_apply_timed_status(who as Card, skill.status, skill.status_turns)


## 凍結 1 回合若施加在「下一個才要行動」的敵人身上,不能在它緊接著的開始階段
## 立刻 -1 消失。用一次性旗標跳過那次遞減,資料與狀態列仍能如實保持「1」。
func _apply_timed_status(target: Card, status: SkillData.Status, turns: int) -> void:
	var target_side := side_of(target)
	var defer_first_decay := status == SkillData.Status.FREEZE \
		and not target_side.is_empty() and target_side != active_side
	target.add_status(status, turns, defer_first_decay)


## 效果的收受者清單。回傳陣列而不是單一節點,是因為 ADJACENT_ALLIES 一次打到好幾個;
## 其餘型別就是「只有一個元素的陣列」——呼叫端不必為多目標另開一條路。
func _effect_recipients(caster: Card, skill: SkillData, target: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	match skill.effect_target:
		SkillData.Target.SELF:
			if is_instance_valid(caster):
				out.append(caster)
		SkillData.Target.ADJACENT_ALLIES:
			# 騎士【守護】:左右相鄰路線的友軍。_adjacent_lane_units 掃的是「同一排」,
			# 從我方單位出發掃到的自然是友軍,不必另寫一套敵我判斷。
			if is_instance_valid(caster):
				for u in _adjacent_lane_units(caster):
					out.append(u)
		SkillData.Target.ALLY_HERO:
			var hero := _hero_of(side_of(caster))
			if hero != null:
				out.append(hero)
		SkillData.Target.LANE_ENEMY:
			# 主動技:玩家(或 AI)在宣告階段指定的那一個目標。
			# 戰吼沒有宣告階段(target 傳 null)→ 退回「正對面那一路的敵人」。
			# 設計稿原文是「敵方**隨機**一個單位」,這裡刻意去隨機:連線對戰要兩台
			# 同步 RNG seed 才不會讓帳分岔,成本遠大於隨機買到的那點刺激(同【不滅】的取捨)。
			if is_instance_valid(target):
				out.append(target)
			elif is_instance_valid(caster):
				var opp := _lane_opposite(caster)
				if opp != null:
					out.append(opp)
		_:
			# ALLY:玩家指定的友軍(治療系)。
			if is_instance_valid(target):
				out.append(target)
	return out


## 某一側的本體節點(戰吼「恢復己方英雄」用)。
func _hero_of(side: String) -> Hero:
	if side == "player":
		return player_hero
	if side == "enemy":
		return enemy_hero
	return null


## §4.2 雙向傷害交換:「同時結算」——反擊值用交戰前的數值先記下、再一起扣,
## 誰先歸零都不影響對方吃到的傷害(順序扣血會讓先死的一方打不出反擊,規則就錯了)。
## mod = 打法修飾(§6):連擊/吸血/橫掃/貫穿都在這裡展開;副目標一律不反擊。
## minion_attack:這是不是「從者攻擊」——只有從者攻擊會吃鐵壁減免(§8)。
## 秘術傳 false:§8 寫的是「每回合首次受到的**從者攻擊**傷害 −1」,秘術不在其中。
## 給預設值 true,既有的攻擊呼叫點一行都不用改(§24 的「預設參數擴充 API」)。
func _resolve_attack(attacker: Card, defender: Card, dmg: int, retaliate: bool,
		mod: SkillData.Modifier, minion_attack: bool = true) -> void:
	if not is_instance_valid(defender):
		return
	var counter := defender.atk_total() if retaliate else 0
	var hits := 2 if mod == SkillData.Modifier.DOUBLE else 1   # 連擊:結算兩次
	var dealt := 0
	for hit in range(hits):
		if is_instance_valid(defender):
			dealt += _deal_damage(defender, dmg, minion_attack)
	if retaliate and counter > 0 and is_instance_valid(attacker):
		_deal_damage(attacker, counter, true)
	# 吸血:回復「實際造成」的傷害——夜幕/鐵壁減免後的數字,不是帳面值。
	if mod == SkillData.Modifier.LIFESTEAL and dealt > 0 and is_instance_valid(attacker):
		attacker.heal(dealt)
	# 橫掃:同一排、左右相鄰路線的單位各吃一份。
	if mod == SkillData.Modifier.SPREAD_3:
		for u in _adjacent_lane_units(defender):
			_deal_damage(u, dmg, minion_attack)
			_check_death(u)
	# 全體:守方場上所有其他單位各吃一份(前後排都算)。
	# 和橫掃共用「副目標不反擊、不吃附帶狀態」的規矩——差別只在取目標的範圍。
	if mod == SkillData.Modifier.SPREAD_ALL:
		for u in _other_units_of_side(defender):
			_deal_damage(u, dmg, minion_attack)
			_check_death(u)
	# 貫穿:同路線的後排也吃一份。
	if mod == SkillData.Modifier.PIERCE:
		var back := _unit_behind(defender)
		if back != null:
			_deal_damage(back, dmg, minion_attack)
			_check_death(back)
	_check_death(defender)
	if attacker != defender:
		_check_death(attacker)


## 傷害管線:夜幕減半(§9)→ 鐵壁首傷 -1(§8,播 Block)→ 護盾吸收 → 扣血+受擊演出。
## 回傳「實際扣掉的血」給吸血用。minion_attack = 這是從者攻擊(鐵壁只擋這種)。
##
## ⚠ 護盾為什麼排在減免「之後」而不是之前——這個順序不會報錯,只會讓數值默默不對:
##   10 點傷害打在「3 盾 + 夜幕 + 鐵壁」的目標上
##   ‧ 盾先吸:10 −3(盾)=7 → 夜幕減半 4 → 鐵壁 −1 → 掉 3 血,盾全空
##   ‧ 盾後吸:10 → 夜幕減半 5 → 鐵壁 −1 = 4 → 盾吸 3 → 掉 1 血,盾也全空
##   同樣一面盾,擺錯位置就少擋 2 點。通則:**減免先做、吸收後做**,
##   每一層減免才會作用在「還沒被盾墊掉」的完整數字上,兩層都拿到最大價值。
##
## ⚠ 回傳值的語意:吸血回的是「HP 真的少了多少」,不含被盾吃掉的部分——
##   盾不是血,砍在盾上沒有血可吸。5 點吸血打 3 盾的滿血目標 → 掉 2 血、攻擊者回 2。
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
	# 護盾在最後一道:減免完的數字先砍盾,穿透的部分才進 HP。
	# 盾擋掉全部時 dmg 會是 0 → take_damage 不播爆點也不掉血,但盾的消耗有自己的飄字。
	var shielded := unit.shield > 0
	dmg = unit.absorb_with_shield(dmg)
	unit.take_damage(dmg)
	# 演出:格擋播 Block(沒有該表就退回 Hurt);其餘吃到傷害才縮。
	# 盾擋下全部也算「擋住了」——有 Block 表就播,讓玩家看得出盾有作用。
	if blocked or (shielded and dmg == 0):
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
	var side := side_of(unit)   # 要在清位「前」問:side_of 靠所在卡槽的群組反查
	if side.is_empty():
		# 查不到卡槽 = 這隻已經離場(死亡流程跑過、位子清掉了),節點只是還沒 free。
		# 沒有這道門,重複結算會走到 sides[""] 直接炸。
		# 實戰進不來(_is_valid_spell_target 擋掉不在場上的目標),但測試與
		# 連線重放端會打到,而且錯誤訊息('Dictionary' 上用 String 存取)完全看不出根因。
		return
	var slot := _find_slot(unit)
	if slot != null:
		slot.on_unit_died()   # 先清位:死亡演出期間這格就能再放牌
	bury(side, unit.data)
	for eq in unit.equipped_cards:
		bury(side, eq)   # 宿主離場,靈裝一併離場(§7):隨葬進同一座墓
	# 宿主底下未觸發的伏印一併進墓地(§7 FAQ);拆完廣播讓紅色警戒跟著熄。
	var side_wards: Array[Dictionary] = (sides[side] as SideState).wards
	var ward_removed := false
	for i in range(side_wards.size() - 1, -1, -1):
		if side_wards[i].host == unit:
			bury(side, side_wards[i].cd)
			side_wards.remove_at(i)
			ward_removed = true
	if ward_removed:
		wards_changed.emit(side, side_wards.size())
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
	var unit := spawn_unit(load(res_path), slot)
	if unit != null:
		mark_summoned(unit)


## 生一個單位節點進指定卡槽(召喚技與連線重放共用)。
## 掛在 hand_node(PlayerHand)底下:place_card 的「躺平」靠它的 -90°X 旋轉,
## 掛錯父節點卡會立起來(local vs world,見 card_slot 的說明)。
func spawn_unit(cd: CardData, slot: CardSlot) -> Card:
	if cd == null or slot == null or hand_node == null:
		return null
	var card: Card = CARD_SCENE.instantiate()
	hand_node.add_child(card)
	card.setup(cd)
	# hover 信號接回中繼站,生出來的單位才能被指定成目標時亮起。
	card.card_hovered.connect(hand_node.card_hovered.emit)
	card.card_unhovered.connect(hand_node.card_unhovered.emit)
	card.global_position = slot.global_position + Vector3(0.0, 1.5, 0.0)
	slot.place_card(card)
	return card


## ── 連線同步(2c):帳的序列化/重建與手牌帳操作 ──────────────
## host 開局把「雙方牌堆+起手」打包給 client,兩台的帳從此一致;
## 之後每個行動走 RPC 重放,牌堆抽牌(pop_back)自然同步——資料一致+操作一致=狀態一致。


func export_accounts() -> Dictionary:
	return {
		"p_deck": _paths_of(sides["player"].deck),
		"e_deck": _paths_of(sides["enemy"].deck),
		"p_hand": _paths_of(sides["player"].hand),
		"e_hand": _paths_of(sides["enemy"].hand),
		"p_grave": _paths_of(sides["player"].grave),
		"e_grave": _paths_of(sides["enemy"].grave),
		"p_dcd": sides["player"].discard_cd,
		"e_dcd": sides["enemy"].discard_cd,
	}


func import_accounts(data: Dictionary) -> void:
	sides["player"].deck = _cards_of(data["p_deck"])
	sides["enemy"].deck = _cards_of(data["e_deck"])
	sides["player"].hand = _cards_of(data["p_hand"])
	sides["enemy"].hand = _cards_of(data["e_hand"])
	# .get 給預設:開局同步都在空墓時發生,但帳的形狀要完整(中途重連也對得上)
	sides["player"].grave = _cards_of(data.get("p_grave", PackedStringArray()))
	sides["enemy"].grave = _cards_of(data.get("e_grave", PackedStringArray()))
	sides["player"].discard_cd = int(data.get("p_dcd", 0))
	sides["enemy"].discard_cd = int(data.get("e_dcd", 0))


static func _paths_of(list: Array[CardData]) -> PackedStringArray:
	var out := PackedStringArray()
	for cd in list:
		out.append(cd.resource_path)
	return out


static func _cards_of(paths: PackedStringArray) -> Array[CardData]:
	var out: Array[CardData] = []
	for p in paths:
		var cd := load(p) as CardData
		if cd != null:
			out.append(cd)
	return out


## 行動方從手上打出第 idx 張(連線重放端的帳面扣牌;出牌端的視圖自己會扣)。
func remove_from_hand(side: String, idx: int) -> void:
	var hand: Array[CardData] = (sides[side] as SideState).hand
	if idx >= 0 and idx < hand.size():
		hand.remove_at(idx)


## 單位所在的卡槽(連線用它當單位的「跨機器身分證」:兩台場景樹路徑一致)。
func find_slot_of(unit: Card) -> CardSlot:
	return _find_slot(unit)


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


## 和 target 同一側、但不是 target 本人的所有場上單位(全體技的副目標)。
## 前後排都掃 —— 後排站得了從者(前排滿了 AI 就往後放),只有伏印是住側帳不佔槽。
func _other_units_of_side(target: Card) -> Array[Card]:
	var out: Array[Card] = []
	var side := side_of(target)
	if side.is_empty():
		return out
	for group in [side + "_front", side + "_back"]:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot and slot.card_in_slot != null \
					and slot.card_in_slot != target:
				out.append(slot.card_in_slot)
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
	state_changed.emit(turn, active_side,
		_active().mana, _active().mana_max, _active().temp_mana)
