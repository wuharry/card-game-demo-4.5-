extends SceneTree
## 真實牌桌截圖及 3D 演出的生命周期驗證；不寫入玩家設定。
const FX = preload("res://src/fx/spatial_effect.gd")
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error(message)


func _capture(suffix: String) -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(args[0] + suffix + ".png")
	_check(err == OK, "截圖寫入失敗")
	print("capture: ", suffix, " ", img.get_size())


func _run() -> void:
	var app := root.get_node("AppSettings")
	app.reduce_motion = false
	app.quality = 1
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	var cm := root.find_child("CardManger", true, false)
	var units: Array[Card] = []
	for slot in get_nodes_in_group("player_front"):
		units.append(cm.battle_manager.spawn_unit(load("res://data/cards/knight.tres"), slot))
	await create_timer(1.2).timeout
	# 每次只演一組，在同一牌桌上比較前中後三個時點。
	units[0].take_damage(1)
	units[2].current_hp -= 2
	units[2].heal(1)
	units[4].add_shield(2)
	_check(get_nodes_in_group("transient_spatial_fx").size() == 3,
		"傷害／實際治療／加盾必須各觸發一個 3D 演出")
	await create_timer(0.16).timeout
	await _capture("_start")
	await create_timer(0.2).timeout
	await _capture("_middle")
	await create_timer(0.9).timeout
	_check(get_nodes_in_group("transient_spatial_fx").is_empty(), "演出結束須回收")
	units[0].add_status(SkillData.Status.BURN, 2)
	units[2].add_status(SkillData.Status.FREEZE, 2)
	units[4].add_status(SkillData.Status.POISON, 2)
	await create_timer(0.25).timeout
	await _capture("_elements")
	await create_timer(1.0).timeout
	# 特效不綁在受擊者下；宿主離場後仍播完，且不繼承卡片旋轉／縮放。
	var host := Node3D.new()
	scene.add_child(host)
	host.scale = Vector3.ONE * 0.3
	var effect := FX.play_at(host, "shield")
	_check(effect != null and effect.get_parent() == scene, "特效須屬於場景")
	_check(effect != null and effect.global_basis.is_equal_approx(Basis.IDENTITY),
		"特效不應繼承宿主縮放")
	host.queue_free()
	await process_frame
	_check(is_instance_valid(effect), "宿主離場不應切斷特效")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(effect), "宿主離場後特效仍須自行清除")
	app.reduce_motion = true
	effect = FX.play_at(units[0], "shield")
	_check(effect.find_children("*", "GPUParticles3D", true, false).is_empty(),
		"減少動態模式不應生成粒子")
	await create_timer(0.6).timeout
	_check(not is_instance_valid(effect), "減少動態模式須回收")
	app.reduce_motion = false
	for i in 30:
		FX.play_at(units[0], "hit")
	_check(get_nodes_in_group("transient_spatial_fx").size() == FX.MAX_ACTIVE,
		"大量連擊必須受同時演出上限保護")
	await create_timer(1.2).timeout
	_check(get_nodes_in_group("transient_spatial_fx").is_empty(), "大量連擊後須全部回收")
	print("Spatial FX review: ", "PASS" if _fails == 0 else "FAIL", " failures=", _fails)
	quit(0 if _fails == 0 else 1)
