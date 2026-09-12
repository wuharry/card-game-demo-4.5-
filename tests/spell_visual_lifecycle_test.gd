extends SceneTree
## 新秘術播放器的節點生命週期與減少動態驗收；不寫入玩家設定。
## godot --headless --path . --script res://tests/spell_visual_lifecycle_test.gd

const FX = preload("res://src/fx/spell_effect.gd")

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: ", message)
	else:
		_fails += 1
		push_error(message)


func _all_freed(nodes: Array[Node]) -> bool:
	for node in nodes:
		if is_instance_valid(node):
			return false
	return true


func _run() -> void:
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var app := root.get_node("AppSettings")
	var original_reduced: bool = app.reduce_motion
	var original_quality: int = app.quality
	app.reduce_motion = false
	app.quality = 1
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 25:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	if cm == null:
		_check(false, "真實牌桌須能建立 CardManager")
		app.reduce_motion = original_reduced
		app.quality = original_quality
		quit(1)
		return
	var cards: Array[CardData] = [
		load("res://data/cards/arcana_fireblast.tres"),
		load("res://data/cards/arcana_thunder_pierce.tres"),
		load("res://data/cards/arcana_frozen_pulse.tres"),
	]
	var host := Node3D.new()
	scene.add_child(host)
	host.scale = Vector3.ONE * 0.2
	host.rotation = Vector3(0.3, 0.7, 0.2)
	var positions: Array[Vector3] = [Vector3(0, 0.8, 3)]

	# 每個真實 profile 都必須建立演出，並且不繼承宿主的縮放與旋轉。
	for card in cards:
		FX.play_arcana(host, card, positions)
	var effects := get_nodes_in_group("spell_visuals")
	_check(effects.size() == cards.size(), "火／雷／冰各建立一個演出")
	for effect in effects:
		var spatial := effect as Node3D
		_check(spatial != null and spatial.get_parent() == scene
			and spatial.global_position.is_equal_approx(positions[0])
			and spatial.global_basis.is_equal_approx(Basis.IDENTITY),
			"演出掛在場景並保持世界位置，不繼承宿主變換")
	await create_timer(1.4).timeout
	_check(_all_freed(effects) and get_nodes_in_group("spell_visuals").is_empty(),
		"三種演出播完後節點與群組都完全清除")

	# 不能靠「完全沒生成演出」通過無障礙驗收：保留靜態提示，但沒有粒子與燈光。
	app.reduce_motion = true
	for card in cards:
		FX.play_arcana(host, card, positions)
	effects = get_nodes_in_group("spell_visuals")
	_check(effects.size() == cards.size(), "減少動態仍保留三種秘術的命中提示")
	for effect in effects:
		_check(not effect.find_children("*", "MeshInstance3D", true, false).is_empty()
			and effect.find_children("*", "GPUParticles3D", true, false).is_empty()
			and effect.find_children("*", "OmniLight3D", true, false).is_empty(),
			"減少動態保留提示網格，不生成 GPU 粒子或瞬間燈光")
	await create_timer(0.6).timeout
	_check(_all_freed(effects) and get_nodes_in_group("spell_visuals").is_empty(),
		"減少動態模式的演出仍會自行清除")

	# 同一個請求帶大量命中位置，也必須受同時演出上限保護。
	app.reduce_motion = false
	var many_positions: Array[Vector3] = []
	for i in FX.MAX_ACTIVE + 4:
		many_positions.append(positions[0] + Vector3(float(i) * 0.1, 0, 0))
	FX.play_arcana(host, cards[1], many_positions)
	_check(get_nodes_in_group("spell_visuals").size() == FX.MAX_ACTIVE,
		"大量命中位置最多生成 MAX_ACTIVE 個演出")
	FX.play_arcana(host, cards[0], positions)
	_check(get_nodes_in_group("spell_visuals").size() == FX.MAX_ACTIVE,
		"額外施法也不能突破同時演出上限")
	await create_timer(1.4).timeout
	_check(get_nodes_in_group("spell_visuals").is_empty(),
		"達到上限的一批演出結束後全部清除")

	# 走真實致死結算，再刻意提早移除屍體；特效不能跟著目標被刪掉。
	var bm: BattleManager = cm.battle_manager
	for side in ["player", "enemy"]:
		bm.hand_of(side).clear()
	var slot := get_nodes_in_group("enemy_front")[0] as CardSlot
	var target := bm.spawn_unit(load("res://data/cards/knight.tres"), slot)
	await create_timer(0.6).timeout # 先完成入槽回呼，再測已上桌目標的離場。
	target.current_hp = 1
	bm.cast_arcana(cards[0], target)
	effects = get_nodes_in_group("spell_visuals")
	_check(slot.is_empty and effects.size() == 1,
		"致死秘術清空目標卡槽後，已回收的演出容量可再使用")
	target.queue_free()
	await process_frame
	_check(not is_instance_valid(target) and not effects.is_empty()
		and is_instance_valid(effects[0]) and effects[0].get_parent() == scene,
		"死亡目標被移除後，場景上的秘術演出仍能播完")
	await create_timer(1.4).timeout
	_check(_all_freed(effects) and get_nodes_in_group("spell_visuals").is_empty(),
		"失去目標的演出也會按自己的生命週期清除")

	# 換場景不等待餘光播完：所有演出與子節點都必須跟著原場景離開。
	for card in cards:
		FX.play_arcana(host, card, positions)
	effects = get_nodes_in_group("spell_visuals")
	_check(effects.size() == cards.size(), "換場景測試先建立仍在播放的演出")
	current_scene = null
	scene.queue_free()
	await process_frame
	_check(not is_instance_valid(scene) and _all_freed(effects)
		and get_nodes_in_group("spell_visuals").is_empty(),
		"場景離開時立即回收全部秘術演出")
	app.reduce_motion = original_reduced
	app.quality = original_quality
	print("Spell visual lifecycle: ", "PASS" if _fails == 0 else "FAIL",
		" checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
