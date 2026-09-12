extends SceneTree
## 秘術拖放操作層驗收：按下、移動、放開都走真實輸入入口與 3D 射線。
## godot --headless --path . --script res://tests/arcana_drag_input_test.gd

var _checks := 0
var _fails := 0
var _cm
var _bm: BattleManager
var _hand: PlayerHand
var _camera: Camera3D


func _initialize() -> void:
	create_timer(75.0).timeout.connect(func() -> void:
		_check(false, "拖放測試逾時；請檢查前面的腳本錯誤或未結束的反制窗口")
		quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok: ", message)
	else:
		_fails += 1
		push_error(message)


func _settle() -> void:
	await create_timer(0.45).timeout
	await physics_frame
	await process_frame


func _prepare_hand(cd: CardData, mana: int, cooldown: int = 0) -> Card:
	var own = _bm.sides["player"]
	own.hand.clear()
	own.hand.append(cd)
	own.mana = mana
	own.temp_mana = 0
	own.discard_cd = cooldown
	_bm.hand_of("enemy").clear()
	_hand.rebuild_from(_bm.hand_of("player"), false)
	await _settle()
	return _hand.cards[0] as Card


func _screen(card: Card) -> Vector2:
	var shape := card.get_node("Area3D/CollisionShape3D") as CollisionShape3D
	return _camera.unproject_position(shape.global_position)


func _press(card: Card) -> void:
	_cm._on_left_pressed_idle_at(_screen(card))
	_check(_cm.card_being_dragged == card,
		"按下秘術會拿起這張牌，進入共同拖曳流程")


func _move(point: Vector2) -> void:
	_cm._update_drag_at(point)
	await physics_frame
	await process_frame


func _drop(point: Vector2) -> void:
	_cm._on_left_released_drag_at(point)
	await process_frame


func _left_event(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	event.pressed = pressed
	_cm._input(event)


func _still_in_hand(card: Card) -> bool:
	return is_instance_valid(card) and _hand.cards.has(card)


func _board_count(side: String) -> int:
	var count := 0
	for group in [side + "_front", side + "_back"]:
		for slot in get_nodes_in_group(group):
			if slot.card_in_slot != null:
				count += 1
	return count


func _run() -> void:
	NetMatch.reset()
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await _settle()
	_cm = root.find_child("CardManger", true, false)
	if _cm == null or not _cm.has_method("_on_left_pressed_idle_at") \
			or not _cm.has_method("_on_left_released_drag_at") \
			or not _cm.has_method("_update_drag_at"):
		_check(false, "CardManager 必須提供按下／移動／放開的座標輸入入口")
		quit(1)
		return
	_cm.set_process(false) # 實際游標不得蓋掉測試明確傳入的拖曳位置。
	_cm.set_process_input(false) # 本測試直接傳 InputEvent，不接受桌面輸入干擾。
	_bm = _cm.battle_manager
	_hand = _cm.player_hand
	_camera = _cm.camera
	if not _cm.battle_ui.has_method("spell_drop_contains"):
		_check(false, "BattleUI 必須公開施放區的落點判定")
		quit(1)
		return
	var fire := load("res://data/cards/arcana_fireblast.tres") as CardData
	var heal := load("res://data/cards/arcana_life_spring.tres") as CardData
	var draw := load("res://data/cards/arcana_insight.tres") as CardData
	var summon := load("res://data/cards/arcana_raise_dead.tres") as CardData
	var knight := load("res://data/cards/knight.tres") as CardData
	var quick := load("res://data/cards/quick_void_rebuke.tres") as CardData
	var enemy_slot := get_nodes_in_group("enemy_front")[0] as CardSlot
	var ally_slot := get_nodes_in_group("player_front")[0] as CardSlot
	var enemy := _bm.spawn_unit(knight, enemy_slot)
	var ally := _bm.spawn_unit(knight, ally_slot)
	await create_timer(0.7).timeout # 入槽、站起與碰撞位置都先穩定。
	await physics_frame
	var enemy_point := _screen(enemy)
	var ally_point := _screen(ally)
	var well := scene.get_node("RecyclePlayer") as ManaRecycle
	var well_shape := well.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	var recycle_point := _camera.unproject_position(well_shape.global_position)
	var recycle_hint := well.get_node("ManaHint") as Label3D
	var arrow := _cm.battle_ui.get("_arrow_line") as Line2D
	var off_board := Vector2(20, 400)
	var cast_point := root.get_visible_rect().size * Vector2(0.5, 0.42)

	# 零魔力仍可拿起昂貴秘術；按下不宣告、不付費，也不把卡丟進墓地。
	var card := await _prepare_hand(fire, 0)
	var grave_before := _bm.grave_count("player")
	_press(card)
	_check(_bm.active_mana() == 0 and _bm.grave_count("player") == grave_before
		and _still_in_hand(card), "零魔力按下秘術只拿起，不消耗手牌或魔力")
	await _move(recycle_point)
	await _drop(recycle_point)
	var gain := floori(fire.cost / 2.0)
	_check(_bm.active_mana() == gain and _bm.sides["player"].temp_mana == gain,
		"低魔力秘術拖到真實回收區可換取暫時魔力")
	_check(_hand.cards.is_empty() and _bm.grave_count("player") == grave_before + 1
		and _bm.sides["player"].grave.back() == fire,
		"回收秘術從手牌離開並進入墓地")
	_check(_bm.sides["player"].discard_cd == 2,
		"秘術回收仍啟用既有的隔回合冷卻")

	card = await _prepare_hand(fire, 0, 2)
	grave_before = _bm.grave_count("player")
	_press(card)
	await _move(recycle_point)
	_check(recycle_hint.visible and recycle_hint.text.contains("冷卻"),
		"回收冷卻中仍有可見提示，放開前就能知道會被拒絕")
	await _drop(recycle_point)
	_check(_still_in_hand(card) and _bm.active_mana() == 0
		and _bm.grave_count("player") == grave_before
		and _bm.sides["player"].discard_cd == 2,
		"回收冷卻中放開會拒絕，保留卡片與原本魔力")
	await _settle()
	var enemy_hp := enemy.current_hp
	_press(card)
	await _move(enemy_point)
	await _drop(enemy_point)
	_check(_still_in_hand(card) and enemy.current_hp == enemy_hp
		and _bm.active_mana() == 0, "魔力不足只在提交施放時拒絕，不造成傷害")

	# 用真正的 _input(InputEventMouseButton) 驗證 event.position，且排除拖曳牌自己。
	card = await _prepare_hand(fire, fire.cost)
	grave_before = _bm.grave_count("player")
	_left_event(_screen(card), true)
	_check(_cm.card_being_dragged == card,
		"_input 按下使用事件座標，能拿起指定秘術")
	await _move(enemy_point)
	_check(_cm.hovered_target == enemy and arrow.visible,
		"可施放的敵人會高亮並顯示指向箭頭")
	await _move(recycle_point)
	_check(_cm.hovered_target == null and not arrow.visible and recycle_hint.visible,
		"從敵人移到回收區會收起攻擊箭頭與目標高亮，改顯示回收提示")
	await _move(enemy_point)
	# 正常秘術偏移游標避免遮擋；此處刻意恢復遮擋，保留自身碰撞排除的壓力案例。
	var intersection = Plane(Vector3.UP, float(_cm.drag_plane_height)).intersects_ray(
		_camera.project_ray_origin(enemy_point), _camera.project_ray_normal(enemy_point))
	_check(intersection != null, "可在目標射線上建立拖曳牌遮擋情境")
	if intersection != null:
		card.global_position = intersection
	card.scale = Vector3.ONE * _hand.card_uniform_scale * 1.5
	card.reset_pick_area()
	await physics_frame
	await process_frame
	_check(_cm._raycast_card_at(enemy_point) == card
		and _cm._raycast_card_at(enemy_point, card) == enemy,
		"拖曳牌會擋住目標，排除自己後才命中場上敵人")
	_left_event(enemy_point, false)
	await process_frame
	_check(enemy.current_hp == enemy_hp - fire.active_skill.power
		and _bm.active_mana() == 0, "拖到合法敵人放開才施放並支付費用")
	_check(_hand.cards.is_empty() and _bm.grave_count("player") == grave_before + 1,
		"成功的拖放施法仍消耗秘術並進墓地")

	ally.current_hp = 1
	card = await _prepare_hand(heal, heal.cost)
	_press(card)
	await _move(ally_point)
	_check(_cm.hovered_target == ally and arrow.visible,
		"治療秘術高亮我方從者，與放開時採用的合法目標一致")
	await _drop(ally_point)
	_check(ally.current_hp == mini(knight.hp, 1 + heal.active_skill.amount)
		and _hand.cards.is_empty() and _bm.active_mana() == 0,
		"友方治療秘術拖到我方從者可成功使用")

	card = await _prepare_hand(fire, fire.cost)
	var ally_hp := ally.current_hp
	grave_before = _bm.grave_count("player")
	_press(card)
	await _move(ally_point)
	await _drop(ally_point)
	_check(_still_in_hand(card) and ally.current_hp == ally_hp
		and _bm.active_mana() == fire.cost and _bm.grave_count("player") == grave_before,
		"攻擊秘術拖到友軍會取消，保留卡片與費用")
	card = await _prepare_hand(heal, heal.cost)
	enemy_hp = enemy.current_hp
	_press(card)
	await _move(enemy_point)
	_check(_cm.hovered_target == null,
		"治療秘術拖到敵人不顯示合法目標高亮")
	await _drop(enemy_point)
	_check(_still_in_hand(card) and enemy.current_hp == enemy_hp
		and _bm.active_mana() == heal.cost,
		"治療秘術拖到敵人也會取消，不把友方規則反過來")

	# 無目標秘術按下／放回手牌／丟到場外都不能誤施放。
	card = await _prepare_hand(draw, draw.cost)
	_bm.sides["player"].deck.clear()
	for cd in [knight, fire, knight]:
		_bm.sides["player"].deck.append(cd)
	var deck_before := _bm.deck_count("player")
	grave_before = _bm.grave_count("player")
	var hand_point := _screen(card)
	_press(card)
	_check(_still_in_hand(card) and _bm.active_mana() == draw.cost
		and _bm.deck_count("player") == deck_before,
		"無目標秘術按下時不直接施放或抽牌")
	await _drop(hand_point)
	_check(_still_in_hand(card) and _bm.grave_count("player") == grave_before
		and _bm.deck_count("player") == deck_before,
		"無目標秘術放回手牌不消耗")
	await _settle()
	_press(card)
	await process_frame
	_check(_cm.battle_ui.spell_drop_contains(cast_point)
		and not _cm.battle_ui.spell_drop_contains(off_board),
		"拖曳無目標秘術時，施放區有明確可用範圍")
	await _move(off_board)
	await _drop(off_board)
	_check(not _cm.battle_ui.spell_drop_contains(cast_point),
		"取消無目標秘術後收起施放區")
	_check(_still_in_hand(card) and _bm.active_mana() == draw.cost
		and _bm.deck_count("player") == deck_before,
		"無目標秘術放在施放區外會取消，不扣費也不抽牌")
	await _settle()
	_press(card)
	await _move(cast_point)
	await _drop(cast_point)
	_check(not _cm.battle_ui.spell_drop_contains(cast_point),
		"成功施放後也收起施放區")
	_check(_bm.deck_count("player") == deck_before - draw.active_skill.amount
		and _hand.cards.size() == draw.active_skill.amount
		and _bm.active_mana() == 0,
		"無目標秘術拖進施放區才付費並執行抽牌")
	_check(_bm.grave_count("player") == grave_before + 1
		and _bm.sides["player"].grave.back() == draw,
		"施放區使用的秘術只入墓一次")

	# SELF 代表不用選場上目標；召喚秘術不應被抽牌用的空牌堆檢查擋掉。
	card = await _prepare_hand(summon, summon.cost)
	_bm.sides["player"].deck.clear()
	var units_before := _board_count("player")
	_press(card)
	await _move(cast_point)
	await _drop(cast_point)
	_check(_board_count("player") == units_before + 1 and _hand.cards.is_empty()
		and _bm.active_mana() == 0 and _bm.deck_count("player") == 0,
		"空牌堆仍可在施放區使用 SELF 召喚秘術")

	# 拖曳中的反悔沿用右鍵／ESC；回到手牌位置後才開始下一個案例。
	for use_escape in [false, true]:
		card = await _prepare_hand(fire, fire.cost)
		var home := card.global_position
		grave_before = _bm.grave_count("player")
		_press(card)
		await _move(enemy_point)
		var cancel: InputEvent
		if use_escape:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.pressed = true
			cancel = key
		else:
			var button := InputEventMouseButton.new()
			button.button_index = MOUSE_BUTTON_RIGHT
			button.position = enemy_point
			button.pressed = true
			cancel = button
		_cm._input(cancel)
		await _settle()
		_check(_cm.card_being_dragged == null and _still_in_hand(card)
			and card.global_position.is_equal_approx(home)
			and _bm.active_mana() == fire.cost and _bm.grave_count("player") == grave_before,
			"%s 取消拖曳，牌歸原位且不消耗" % ("ESC" if use_escape else "右鍵"))

	# 放開即宣告，但守方仍有反制窗口；在玩家回答之前不得造成傷害。
	card = await _prepare_hand(fire, fire.cost)
	enemy.current_hp = knight.hp
	_bm.hand_of("enemy").append(quick)
	_bm.sides["enemy"].mana = quick.cost
	_bm.sides["enemy"].temp_mana = 0
	grave_before = _bm.grave_count("player")
	var enemy_grave_before := _bm.grave_count("enemy")
	_press(card)
	await _move(enemy_point)
	await _drop(enemy_point)
	var reaction := _cm.battle_ui.get("_react_panel") as PanelContainer
	var reaction_visible := reaction != null and reaction.visible
	_check(reaction_visible and enemy.current_hp == knight.hp
		and _bm.active_mana() == 0,
		"拖放宣告先支付費用，反制窗口回答前不結算傷害")
	if reaction_visible:
		_cm.battle_ui._answer_reaction(true)
		await process_frame
	_check(enemy.current_hp == knight.hp and _hand.cards.is_empty()
		and _bm.sides["enemy"].mana == 0
		and _bm.grave_count("player") == grave_before + 1
		and _bm.grave_count("enemy") == enemy_grave_before + 1,
		"守方發動瞬咒後抵銷拖放秘術，雙方牌與費用仍正確消耗")
	await create_timer(1.2).timeout
	print("Arcana drag input: ", "PASS" if _fails == 0 else "FAIL",
		" checks=", _checks, " failures=", _fails)
	quit(0 if _fails == 0 else 1)
