extends SceneTree
## 真實牌桌的接近攻擊驗收；不更動玩家設定檔。
const SETTINGS = preload("res://src/settings/app_settings.gd")
var _checks := 0
var _fails := 0
var _bm: BattleManager


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		_fails += 1
		push_error(message)


func _spawn(id: String, group: String, index: int) -> Card:
	var unit := _bm.spawn_unit(load("res://data/cards/%s.tres" % id), get_nodes_in_group(group)[index])
	unit.max_hp_bonus = 40
	unit.current_hp = unit.data.hp + unit.max_hp_bonus
	return unit


func _run() -> void:
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	SETTINGS.current().reduce_motion = false
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.2).timeout
	var cm := root.find_child("CardManger", true, false)
	_bm = cm.battle_manager
	for side in ["player", "enemy"]:
		_bm.hand_of(side).clear()
	var attacker := _spawn("swordsman", "player_front", 2)
	var target := _spawn("knight", "enemy_front", 2)
	await create_timer(0.8).timeout
	var base := attacker.global_position
	var sprite_base: Vector3 = attacker._standee.position
	var collision: Node3D = attacker.get_node("Area3D/CollisionShape3D")
	var collision_base := collision.global_transform
	var hp := target.current_hp
	_bm.on_action_performed(attacker, null, target)
	await create_timer(0.23).timeout
	_check(attacker.combat_position().distance_to(target.global_position) < 1.05,
		"劍士抵達敵人身前的武器距離，不只前移固定一小步")
	_check(attacker.combat_position().distance_to(base) > 1.0, "角色跨越雙方卡槽間的實際距離")
	_check(attacker.global_position.is_equal_approx(base) and collision.global_transform.is_equal_approx(collision_base),
		"移動演出不改卡片和點擊碰撞的世界位置")
	_check(_bm.find_slot_of(attacker).card_in_slot == attacker, "移動演出不改卡槽佔用")
	_check(target.current_hp == hp, "移動到位後仍等到命中點才扣血")
	await create_timer(0.15).timeout
	_check(target.current_hp == hp - 2, "到位命中仍保留鐵壁與原有傷害結算")
	var impact_near_attacker := false
	for fx in get_nodes_in_group("transient_spatial_fx"):
		if fx.global_position.distance_to(attacker.combat_position()) < 0.02:
			impact_near_attacker = true
	_check(impact_near_attacker, "反擊爆點在移動後的角色位置，不在空卡槽")
	var counter_number_near_attacker := false
	for number in get_nodes_in_group("combat_numbers"):
		var planar: Vector3 = number.global_position - attacker.combat_position()
		planar.y = 0
		if number.text == "-3" and planar.length() < 0.02:
			counter_number_near_attacker = true
	_check(counter_number_near_attacker, "反擊傷害數字跟隨移動後的角色位置")
	await create_timer(0.8).timeout
	_check(attacker._standee.position.is_equal_approx(sprite_base), "命中停頓後確實返回原站位")

	# 英雄沒有卡槽，仍必須計算接近位置與退回原點。
	var hero: Hero = _bm.enemy_hero
	hp = hero.hp
	_bm.on_action_performed(attacker, null, hero)
	await create_timer(0.23).timeout
	_check(attacker.combat_position().distance_to(hero.global_position) < 1.05, "攻擊英雄也抵達英雄身前")
	await create_timer(0.8).timeout
	_check(hero.hp == hp - attacker.atk_total() and attacker._standee.position.is_equal_approx(sprite_base),
		"打臉扣血後歸位，不產生額外反擊")

	# 近戰不限持刃白名單；遠程與非攻擊技能保持原地。
	var lancer := _spawn("lancer", "player_front", 1)
	var archer := _spawn("archer", "player_back", 1)
	await create_timer(0.8).timeout
	lancer.play_action_animation(null, target)
	archer.play_action_animation(null, target)
	await create_timer(0.23).timeout
	_check(lancer.combat_position().distance_to(target.global_position) < 1.05, "槍兵等其他近戰也會接近目標")
	_check(archer.combat_position().is_equal_approx(archer.global_position), "遠程卡保留原地出手")
	await create_timer(0.7).timeout
	var heal := SkillData.new()
	heal.kind = SkillData.Kind.NON_ATTACK
	lancer.play_action_animation(heal, attacker)
	await create_timer(0.23).timeout
	_check(lancer.combat_position().is_equal_approx(lancer.global_position), "非攻擊技能不向友軍突進")

	# 反向攻擊與父座標縮放不能把世界距離誤當 local 座標。
	var enemy_base: Vector3 = target._standee.position
	target.scale *= 1.15
	var camera := root.get_camera_3d()
	var camera_basis := camera.global_basis
	camera.global_basis = Basis(Vector3.UP, PI) * camera_basis
	target.play_action_animation(null, attacker)
	await create_timer(0.23).timeout
	_check(target.combat_position().distance_to(attacker.global_position) < 1.05,
		"反向視角與縮放後仍使用正確世界距離")
	await create_timer(0.7).timeout
	_check(target._standee.position.is_equal_approx(enemy_base), "敵方角色歸位無漂移")
	target.scale /= 1.15
	camera.global_basis = camera_basis

	# 在歸位途中再起手，不得把半途位置當成新的永久原點。
	for i in 4:
		attacker.play_action_animation(null, target)
		await create_timer(0.55).timeout
	await create_timer(0.8).timeout
	_check(attacker._standee.position.is_equal_approx(sprite_base), "連續重播與中途重啟不會累積站位漂移")

	var doomed := _spawn("soldier", "enemy_front", 0)
	await create_timer(0.7).timeout
	_bm.on_action_performed(attacker, null, doomed)
	await create_timer(0.08).timeout
	_bm.find_slot_of(doomed).on_unit_died()
	doomed.queue_free()
	await create_timer(0.7).timeout
	_check(attacker._standee.position.is_equal_approx(sprite_base), "途中目標被移除時安全退回原位")
	_check(get_nodes_in_group("slash_visuals").is_empty(), "目標消失後不播放成功刀光")

	# 屍體尚未 free 也不能繼續出手；死亡演出停在倒下的位置。
	var doomed_attacker := _spawn("swordsman", "player_front", 0)
	await create_timer(0.7).timeout
	hp = target.current_hp
	_bm.on_action_performed(doomed_attacker, null, target)
	await create_timer(0.1).timeout
	_bm._deal_damage(doomed_attacker, 99, false)
	_bm._check_death(doomed_attacker)
	var death_position: Vector3 = doomed_attacker._standee.position
	await create_timer(0.3).timeout
	_check(target.current_hp == hp, "前衝途中死亡不在稍後繼續攻擊")
	_check(doomed_attacker._standee.position.is_equal_approx(death_position), "死亡時停在交戰位置播放死亡動畫")
	await create_timer(0.7).timeout

	attacker.play_action_animation(null, target)
	await create_timer(0.06).timeout
	SETTINGS.current().reduce_motion = true
	await create_timer(0.4).timeout
	_check(attacker._standee.position.is_equal_approx(sprite_base), "前衝中開啟減少動態會歸位")
	_check(attacker._standee.texture == attacker.data.standee, "取消移動後不殘留無限跑步動畫")
	attacker.play_action_animation(null, target)
	await create_timer(0.2).timeout
	_check(attacker._standee.position.is_equal_approx(sprite_base), "減少動態模式不移動角色")
	SETTINGS.current().reduce_motion = false

	# 換場景時回收帶 callback 的移動元件，不能有稍後觸發的失效參考。
	attacker.play_action_animation(null, target)
	await create_timer(0.06).timeout
	current_scene = null
	scene.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	_check(not is_instance_valid(attacker), "移動中換場景可完整回收角色")
	print("Attack approach: ", "PASS" if _fails == 0 else "FAIL", " checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
