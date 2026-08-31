extends SceneTree
## 卡池資料驗證:data/cards/ 全部載得起來、卡型分佈正確、秘術的目標設定沒填錯。
##   godot --headless -s tests/card_pool_verify.gd
##
## 為什麼要有這支:.tres 是手寫文字檔,填錯(load_steps 數錯、enum 值填錯、
## effect_target 漏填)不會有人報錯——**只會在遊戲跑到那張卡時才炸或行為怪**。
## 資料層要有自己的守門員,不能靠玩到才發現(§16「bad=0 才算接完」)。

const CARD_DATA := preload("res://src/card/card_data.gd")
const SKILL_DATA := preload("res://src/card/skill_data.gd")

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: " + label)


func _type_name(t: int) -> String:
	return ["從者", "靈裝", "秘術", "瞬咒", "伏印", "領域"][t] if t >= 0 and t < 6 else "?"


func _run() -> void:
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		print("FAIL: 打不開 res://data/cards")
		quit(1)
		return

	var counts := {}
	var bad := 0
	var total := 0
	var arcana: Array = []
	var art_paths := {}

	for f in dir.get_files():
		var fn: String = f.trim_suffix(".remap")
		if not fn.ends_with(".tres"):
			continue
		total += 1
		var cd = load("res://data/cards/" + fn)
		if cd == null:
			print("FAIL: 載不起來 " + fn)
			bad += 1
			continue
		var t: int = cd.card_type
		counts[t] = counts.get(t, 0) + 1
		_check(cd.use_dedicated_art and cd.art != null, "%s 缺少專用卡圖" % fn)
		if cd.use_dedicated_art and cd.art != null:
			var art_path: String = cd.art.resource_path
			_check(not art_paths.has(art_path), "%s 與 %s 共用卡圖 %s" % [
				fn, art_paths.get(art_path, "?"), art_path])
			art_paths[art_path] = fn
		if t == CARD_DATA.CardType.ARCANA:
			arcana.append([fn, cd])

	_check(bad == 0, "有 %d 張載入失敗" % bad)
	_check(total == 120, "卡池應為 120 張，目前 %d" % total)
	var expected_counts := {
		CARD_DATA.CardType.MINION: 66,
		CARD_DATA.CardType.EQUIP: 5,
		CARD_DATA.CardType.ARCANA: 33,
		CARD_DATA.CardType.QUICK: 8,
		CARD_DATA.CardType.WARD: 8,
		CARD_DATA.CardType.DOMAIN: 0,
	}
	for type in expected_counts:
		_check(counts.get(type, 0) == expected_counts[type], "%s應為 %d 張，目前 %d" % [
			_type_name(type), expected_counts[type], counts.get(type, 0)])
	print("卡池總數:%d(載入失敗 %d)" % [total, bad])
	for t in [0, 1, 2, 3, 4, 5]:
		if counts.has(t):
			print("  %s:%d" % [_type_name(t), counts[t]])

	# ── 秘術逐張體檢:目標設定是這次改動的核心,填錯會靜默走錯流程 ──
	print("\n秘術逐張:")
	for entry in arcana:
		var fn: String = entry[0]
		var cd = entry[1]
		var sk = cd.active_skill
		if sk == null:
			print("FAIL: %s 沒有 active_skill" % fn)
			_fail += 1
			continue
		var needs_target: bool = sk.effect_target != SKILL_DATA.Target.SELF
		var eff: int = sk.effect
		# HEAL / APPLY_STATUS 一定要有目標;DRAW / SCRY / DISCARD_DRAW / SUMMON 一定不能有。
		if eff in [SKILL_DATA.Effect.HEAL, SKILL_DATA.Effect.APPLY_STATUS]:
			_check(needs_target, "%s:effect=%d 需要目標,但 effect_target=SELF" % [fn, eff])
		elif eff in [SKILL_DATA.Effect.DRAW, SKILL_DATA.Effect.SCRY,
				SKILL_DATA.Effect.DISCARD_DRAW, SKILL_DATA.Effect.SUMMON]:
			_check(not needs_target, "%s:effect=%d 不該選目標,但 effect_target≠SELF" % [fn, eff])
		elif cd.special_id != &"":
			# 複合高階秘術由 special_id 結算；它們是無目標卡，不要求 power。
			_check(not needs_target, "%s:複合秘術應為 SELF 無目標" % fn)
		else:
			# Effect.NONE = 純傷害,一定要有目標而且 power > 0
			_check(needs_target, "%s:純傷害秘術卻不用選目標" % fn)
			_check(sk.power > 0, "%s:純傷害秘術的 power 是 0" % fn)
		# SUMMON 要指得到一張真的卡
		if eff == SKILL_DATA.Effect.SUMMON:
			var p := "res://data/cards/%s.tres" % sk.summon_card
			_check(ResourceLoader.exists(p), "%s:summon_card 指向不存在的 %s" % [fn, p])
		print("  %-28s ◆%d  effect=%d target=%d power=%d amount=%d status=%d mod=%d" % [
			cd.card_name, cd.cost, eff, sk.effect_target, sk.power,
			sk.amount, sk.status, sk.modifier])

	print("\n%s %d 項檢查,%d 失敗" % ["PASS" if _fail == 0 else "FAIL", _pass + _fail, _fail])
	quit(0 if _fail == 0 else 1)
