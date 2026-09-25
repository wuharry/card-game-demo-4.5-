extends SceneTree
## --fixed-fps 30 --script res://tests/combat_feedback_capture.gd
## 輸出原始 viewport 的 WebP 連續畫面；HTML 播放器不裁切、不修圖。
const OUT := "res://docs/combat-feedback-preview/"


func _initialize() -> void:
	_run.call_deferred()


func _frames(prefix: String, count: int) -> void:
	for frame in count:
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_webp(OUT + "%s_%02d.webp" % [prefix, frame], true, 0.8)
		if error != OK:
			push_error("Cannot save preview frame")
			quit(1)
			return


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires Forward+ viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	var app := root.get_node("AppSettings")
	app.reduce_motion = false
	app.quality = 2
	app.language = "zh_TW"
	app.apply_quality()
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var cm := root.find_child("CardManger", true, false)
	var bm: BattleManager = cm.battle_manager
	for side in ["player", "enemy"]:
		bm.hand_of(side).clear()
	cm.player_hand.rebuild_from(bm.hand_of("player"), false)
	var attacker := bm.spawn_unit(load("res://data/cards/swordsman.tres"), get_nodes_in_group("player_front")[2])
	var target := bm.spawn_unit(load("res://data/cards/knight.tres"), get_nodes_in_group("enemy_front")[2])
	bm.spawn_unit(load("res://data/cards/knight.tres"), get_nodes_in_group("enemy_back")[2])
	for unit in [attacker, target]:
		unit.max_hp_bonus = 20
		unit.heal(20)
	await create_timer(1.2).timeout
	bm.on_action_performed(attacker, null, target)
	await _frames("slash", 30)
	await create_timer(0.3).timeout
	target.add_shield(5)
	await create_timer(1.2).timeout
	bm.on_action_performed(attacker, null, target)
	await _frames("block", 30)
	await create_timer(0.4).timeout
	target.shield = 0
	bm.cast_arcana(load("res://data/cards/arcana_thunder_pierce.tres"), target)
	await _frames("thunder", 30)
	await create_timer(0.3).timeout
	print("Combat preview captured: 90 frames at 30 fps, 1280 x 720, Forward+")
	quit()
