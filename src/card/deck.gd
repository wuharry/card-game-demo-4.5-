## deck.gd — 牌堆工具:載入卡池、洗出一副牌
##
## 牌堆本體就是 Array[CardData](頂 = 陣尾,抽牌 = pop_back),不需要自己的節點;
## 帳(誰的牌堆剩幾張)在 BattleManager 的 SideState 上。
## 連線後(ADR-001)這裡的亂數只會在 host 跑:抽牌的「結果」廣播給雙方,
## 不做「同步亂數種子」那種脆弱同步。
class_name Deck
extends RefCounted

const DECK_SIZE := 60   # 一副牌的張數(規則帳在 README Gameplay Spec §1)
const MAX_COPIES := 3   # 同名卡上限(暗影詩章式:隨機組成但不會抽到一堆同名卡)


## 把 data/cards/ 底下所有 .tres 載成卡池(和 PlayerHand 的編輯器預覽共用)。
## .remap 剝皮:匯出成正式版後檔名清單會變 xxx.tres.remap(Godot 匯出重映射)。
static func load_pool() -> Array[CardData]:
	var out: Array[CardData] = []
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		push_warning("找不到卡池資料夾 res://data/cards")
		return out
	for f in dir.get_files():
		var file_name := f.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			out.append(load("res://data/cards/" + file_name))
	return out


## 洗好的一副牌:60 張、同名卡最多 3 份。
## 做法:先把「每種卡 ×3」攤成一疊大池(24 種 → 72 張),洗亂後砍到 60 張——
## 取出來的自然不會超過上限,不必邊抽邊查份數(想過才不做:拒絕重抽法)。
static func build_shuffled() -> Array[CardData]:
	var pile: Array[CardData] = []
	for card in load_pool():
		for i in range(MAX_COPIES):
			pile.append(card)
	pile.shuffle()
	if pile.size() > DECK_SIZE:
		pile.resize(DECK_SIZE)   # resize 保留型別;slice() 部分版本回未定型 Array(§19 教訓)
	return pile
