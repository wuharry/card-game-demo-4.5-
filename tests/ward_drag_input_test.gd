extends SceneTree
## 伏印拖放操作層回歸：拖曳牌本身會擋在宿主前面，放開時必須把它從射線排除。

var fails := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		fails += 1
		print("FAIL: " + msg)


func _first_empty(group: String) -> CardSlot:
	for node in get_nodes_in_group(group):
		var slot := node as CardSlot
		if slot != null and slot.is_empty:
			return slot
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 25:
		await process_frame

	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var hand := cm.get("player_hand") as PlayerHand
	var ward := load("res://data/cards/ward_blast_sigil.tres") as CardData
	var host := bm.spawn_unit(load("res://data/cards/knight.tres"),
		_first_empty("player_front")) as Card
	bm.sides["player"].mana = ward.cost
	bm.sides["player"].hand.clear()
	bm.sides["player"].hand.append(ward)
	hand.rebuild_from(bm.sides["player"].hand, false)
	await process_frame
	await physics_frame

	var dragged := hand.cards[0] as Card
	var camera := cm.get("camera") as Camera3D
	var mouse_pos := camera.unproject_position(host.global_position)
	# 模擬 _process 的拖曳位置：牌停在手牌高度、但位於宿主同一條攝影機射線上。
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	var intersection = Plane(Vector3.UP, dragged.global_position.y).intersects_ray(
		ray_origin, ray_normal)
	_check(intersection != null, "滑鼠射線能與拖曳平面相交")
	if intersection != null:
		dragged.global_position = intersection
	dragged.reset_pick_area()
	await process_frame
	await physics_frame

	_check(cm._raycast_card_at(mouse_pos) == dragged,
		"未排除時射線會先撞到拖曳中的伏印")
	_check(cm._raycast_card_at(mouse_pos, dragged) == host,
		"排除拖曳牌後射線會找到場上宿主")

	cm.set("_pending_play_card", null)
	cm._try_set_ward_at(dragged, mouse_pos)
	await process_frame
	_check(bm.ward_count("player") == 1 and bm.host_has_ward(host),
		"實際 _try_set_ward 拖放入口成功埋設伏印")

	if fails == 0:
		print("PASS 伏印拖放操作層 4/4")
		quit(0)
	else:
		quit(1)
