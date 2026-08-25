extends SceneTree

const IDS := [
	"alchemist",
	"adventurer",
	"lizard_warrior",
	"kobold_miner",
	"halfling_scout",
	"dwarf_smith",
	"goblin_bomber",
	"catfolk_rogue",
	"ratfolk_plague_doctor",
	"frog_shaman",
	"harpy_hunter",
	"treant_guardian",
	"mushroom_mage",
	"gargoyle_sentinel",
	"desert_nomad",
	"pirate_captain",
	"wandering_bard",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var names := {}
	for id: String in IDS:
		var path := "res://data/cards/%s.tres" % id
		var card := load(path) as CardData
		if card == null:
			failures.append("%s 無法載入" % path)
			continue
		if card.card_type != CardData.CardType.MINION:
			failures.append("%s 不是從者" % id)
		if card.card_name in names:
			failures.append("卡名重複：%s" % card.card_name)
		names[card.card_name] = true
		if not card.use_dedicated_art or card.art == null:
			failures.append("%s 缺少專用卡圖" % id)
		elif card.art.get_width() <= card.art.get_height():
			failures.append("%s 卡圖不是橫幅：%dx%d" % [id, card.art.get_width(), card.art.get_height()])
		if card.standee == null:
			failures.append("%s 缺少 Idle standee" % id)
		elif card.standee.get_width() != 300 or card.standee.get_height() != 100:
			failures.append("%s Idle 尺寸錯誤：%dx%d" % [id, card.standee.get_width(), card.standee.get_height()])
		if card.active_skill == null:
			failures.append("%s 缺少主動技能" % id)
			continue
		var action := card.get_anim_sheet(card.active_skill.anim)
		if action == null:
			failures.append("%s 找不到技能動畫 %s" % [id, card.active_skill.anim])
		elif action.get_width() != 300 or action.get_height() != 100:
			failures.append("%s 技能動畫尺寸錯誤：%dx%d" % [id, action.get_width(), action.get_height()])

	print("新從者驗證：%d 張，%d 個唯一卡名" % [IDS.size(), names.size()])
	if failures.is_empty():
		print("PASS：專用卡圖、Idle 與技能動畫全部可載入")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FAIL：%d 項" % failures.size())
	quit(1)
