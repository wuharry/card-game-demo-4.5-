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
		var normal_attack := card.get_anim_sheet("Attack01")
		if normal_attack == null:
			failures.append("%s 缺少普通攻擊動畫 Attack01" % id)
		elif normal_attack.get_width() != 300 or normal_attack.get_height() != 100:
			failures.append("%s Attack01 尺寸錯誤：%dx%d" % [id,
				normal_attack.get_width(), normal_attack.get_height()])
		else:
			_check_three_frame_sheet(normal_attack, "%s Attack01" % id, failures)
		if card.active_skill == null:
			failures.append("%s 缺少主動技能" % id)
			continue
		if card.active_skill.anim == "Attack01":
			failures.append("%s 的技能不可共用普通攻擊 Attack01" % id)
		elif card.active_skill.anim != "Attack02":
			failures.append("%s 的技能動畫應為 Attack02，目前為 %s" % [id, card.active_skill.anim])
		var action := card.get_anim_sheet(card.active_skill.anim)
		if action == null:
			failures.append("%s 找不到技能動畫 %s" % [id, card.active_skill.anim])
		elif action.get_width() != 300 or action.get_height() != 100:
			failures.append("%s 技能動畫尺寸錯誤：%dx%d" % [id, action.get_width(), action.get_height()])
		else:
			_check_three_frame_sheet(action, "%s %s" % [id, card.active_skill.anim], failures)

	print("新從者驗證：%d 張，%d 個唯一卡名" % [IDS.size(), names.size()])
	if failures.is_empty():
		print("PASS：專用卡圖、Idle、普通攻擊 Attack01 與技能 Attack02 全部可載入")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FAIL：%d 項" % failures.size())
	quit(1)


func _check_three_frame_sheet(texture: Texture2D, label: String, failures: Array[String]) -> void:
	var image := texture.get_image()
	if image == null or image.is_empty():
		failures.append("%s 無法讀取像素" % label)
		return
	for frame in 3:
		var cell := image.get_region(Rect2i(frame * 100, 0, 100, 100))
		if cell.get_used_rect().size == Vector2i.ZERO:
			failures.append("%s 第 %d 幀是空白" % [label, frame + 1])
		if cell.get_pixel(0, 0).a > 0.01 or cell.get_pixel(99, 99).a > 0.01:
			failures.append("%s 第 %d 幀背景不透明" % [label, frame + 1])
