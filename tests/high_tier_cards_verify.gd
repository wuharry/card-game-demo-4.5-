extends SceneTree

const EXPECTED := {
	9: 7,
	10: 6,
	11: 6,
	12: 6,
	13: 3,
}
const SKILLED := ["abyss_devourer", "thunderhorn_behemoth", "red_obsidian_ancient_dragon"]
const SKILLESS := ["steel_forge_titan", "tombsea_colossus", "sky_leviathan"]

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cost_counts := {}
	var new_count := 0
	var dir := DirAccess.open("res://data/cards")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var cd := load("res://data/cards/" + file) as CardData
		if cd == null:
			failures.append("無法載入 %s" % file)
			continue
		if cd.cost >= 9:
			new_count += 1
			cost_counts[cd.cost] = cost_counts.get(cd.cost, 0) + 1
			if not cd.use_dedicated_art or cd.art == null:
				failures.append("%s 缺專用卡圖" % file)
			elif cd.art.get_width() <= cd.art.get_height():
				failures.append("%s 卡圖不是橫幅" % file)
	if new_count != 28:
		failures.append("9–13 費應有 28 張，目前 %d" % new_count)
	for cost in EXPECTED:
		if cost_counts.get(cost, 0) != EXPECTED[cost]:
			failures.append("%d 費應有 %d 張，目前 %d" % [cost, EXPECTED[cost], cost_counts.get(cost, 0)])

	for id in SKILLED:
		_check_minion(id, true)
	for id in SKILLESS:
		_check_minion(id, false)

	if failures.is_empty():
		print("PASS：28 張高階卡、費用曲線、專用卡圖與從者雙動畫契約正確")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FAIL：%d 項" % failures.size())
	quit(1)


func _check_minion(id: String, skilled: bool) -> void:
	var cd := load("res://data/cards/%s.tres" % id) as CardData
	if cd == null:
		failures.append("%s 無法載入" % id)
		return
	for suffix in ["Idle", "Attack01"]:
		var tex := cd.standee if suffix == "Idle" else cd.get_anim_sheet(suffix)
		if tex == null or tex.get_width() != 300 or tex.get_height() != 100:
			failures.append("%s 的 %s 缺少或尺寸不是 300x100" % [id, suffix])
	if skilled:
		if cd.active_skill == null or cd.active_skill.anim != "Attack02":
			failures.append("%s 應有 Attack02 主動技" % id)
		elif cd.get_anim_sheet("Attack02") == null:
			failures.append("%s 缺 Attack02 圖" % id)
	else:
		if cd.active_skill != null:
			failures.append("%s 應為無主動技從者" % id)
		if cd.get_anim_sheet("Attack02") != null:
			failures.append("%s 不應有 Attack02" % id)
