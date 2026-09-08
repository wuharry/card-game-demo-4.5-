extends SceneTree
## 回歸測試:瘋狂 hover 不得累積漂移(Harvey 實測回報的 bug)。
## 兩張手牌交錯快打 hover/unhover 30 輪(間隔比補間 0.15s 短),
## 收手後等動畫收斂,斷言每張卡都回到扇形基準位;
## 另驗「判定與演出分離」:抬升期間碰撞箱世界座標釘在扇形原位。
## 整卡前景也必須一起切換:卡圖、卡框、字及外框離開 hover 後都還原。

var _fails := 0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var ph = cm.get("player_hand")
	# 固定資料，避免隨機起手沒有 ShaderMaterial 或非從者的 TypeLabel。
	var cards: Array[CardData] = [
		load("res://data/cards/greatsword_skeleton.tres"),
		load("res://data/cards/ward_blast_sigil.tres"),
	]
	ph.rebuild_from(cards, false)
	await process_frame
	if ph.cards.size() < 2:
		print("FAIL: 手牌不足兩張")
		quit(1)
		return
	var a: Card = ph.cards[0]
	var b: Card = ph.cards[1]
	var base_a: Vector3 = a.hand_base_pos
	var base_b: Vector3 = b.hand_base_pos
	var area_a: Node3D = a.get_node("Area3D")
	var area_gpos0: Vector3 = area_a.global_position
	var original_a := _capture_render_state(a)
	var original_b := _capture_render_state(b)
	_expect(b.has_node("TypeLabel"), "固定非從者手牌缺少 TypeLabel")
	_expect(a.get_node("CardArt").material_override is ShaderMaterial,
		"固定手牌未走專用卡圖 ShaderMaterial")

	# ── 不變量:hover 抬升期間,碰撞箱的「世界位置」必須釘在扇形原位 ──
	# (判定與演出分離:判定幾何跟著演出跑,就是 enter/exit 閃爍迴圈的根源)
	cm.on_card_hovered(a)
	_check_frontmost(a, b, original_a)
	_check_render_state(original_b, "hover A 不得改到 B")
	var hovered_a := _capture_render_state(a)
	cm.on_card_hovered(a)
	_check_render_state(hovered_a, "重複 hover 不得累加排序或更換材質")
	await create_timer(0.3).timeout   # 等抬升補間走完
	var lifted_visual: float = (a.position - base_a).length()
	var pinned_drift: float = (area_a.global_position - area_gpos0).length()
	if lifted_visual < 1.0:
		print("FAIL: hover 後視覺未抬升(位移 %.2f)" % lifted_visual)
		quit(1)
		return
	if pinned_drift > 0.15:
		print("FAIL: hover 抬升時碰撞箱漂離扇形原位 %.3f" % pinned_drift)
		quit(1)
		return
	cm.on_card_unhovered(a)
	_check_render_state(original_a, "unhover A 立即還原")
	await create_timer(0.3).timeout
	if (area_a.global_position - area_gpos0).length() > 0.05:
		print("FAIL: 歸位後碰撞箱未回原位")
		quit(1)
		return
	print("  ok: 抬升 %.2f 期間碰撞箱釘住(漂移 %.3f)" % [lifted_visual, pinned_drift])

	# 瘋狂交錯:enter(B) 常在 exit(A) 之前——模擬扇形重疊的真實事件序
	for i in 30:
		cm.on_card_hovered(a)
		_check_frontmost(a, b, original_a)
		_check_render_state(original_b, "第 %d 輪 A 前景時 B 還原" % i)
		await create_timer(0.03).timeout
		cm.on_card_hovered(b)      # 先 enter B
		cm.on_card_unhovered(a)    # 再 exit A
		_check_frontmost(b, a, original_b)
		_check_render_state(original_a, "第 %d 輪 B 前景時 A 還原" % i)
		await create_timer(0.03).timeout
		cm.on_card_unhovered(b)
		_check_render_state(original_b, "第 %d 輪 B 離開後還原" % i)

	await create_timer(0.5).timeout   # 等最後一輪補間收斂

	for pair in [[a, base_a, "A"], [b, base_b, "B"]]:
		var card: Card = pair[0]
		var base: Vector3 = pair[1]
		var drift: float = (card.position - base).length()
		if drift > 0.01:
			_fails += 1
			print("FAIL: 卡 %s 未歸位,漂移 %.3f(pos=%s base=%s)" % [
				pair[2], drift, card.position, base])
	# 基準位本身也不准被動畫污染
	if a.hand_base_pos != base_a or b.hand_base_pos != base_b:
		_fails += 1
		print("FAIL: 扇形基準位被改寫")

	# 抽牌/回手重排與上桌可能先於 mouse_exited，不能靠 exit 事件才還原。
	a.animate_hover()
	a.sync_hand_base(base_a)
	_check_render_state(original_a, "重排手牌還原")
	a.animate_hover()
	a.enter_board_mode()
	_check_render_state(original_a, "上桌還原")
	a.animate_hover(1.5)
	_check_render_state(original_a, "上桌目標 hover 不啟用手牌前景")
	a.animate_unhover()
	_check_render_state(original_a, "上桌目標 unhover 保留原設定")
	a.exit_board_mode()
	a.sync_hand_base(base_a)
	if _fails == 0:
		print("PASS 瘋狂 hover 30 輪後全數歸位；整卡前景、重複 hover、重排與上桌還原通過")
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if _fails == 0 else 1)


## 從公開節點屬性記住實際原值，不讀 Card 的內部還原帳本。
func _capture_render_state(card: Card) -> Array[Dictionary]:
	var state: Array[Dictionary] = []
	for child in card.get_children():
		if not (child is Sprite3D or child is Label3D):
			continue
		var properties := {"render_priority": child.render_priority,
			"no_depth_test": child.no_depth_test}
		if child is Label3D:
			properties["outline_render_priority"] = child.outline_render_priority
		if child is Sprite3D:
			properties["material_override"] = child.material_override
		state.append({"target": child, "properties": properties})
		if child is Sprite3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override
			state.append({"target": material,
				"properties": {"render_priority": material.render_priority, "shader": material.shader},
				"parameters": {"art_texture": material.get_shader_parameter("art_texture"),
					"source_uv_rect": material.get_shader_parameter("source_uv_rect")}})
	return state


func _check_render_state(state: Array[Dictionary], context: String) -> void:
	for entry in state:
		for property in entry.properties:
			_expect(entry.target.get(property) == entry.properties[property],
				"%s: %s 未恢復記錄值" % [context, property])
		for parameter in entry.get("parameters", {}):
			_expect(entry.target.get_shader_parameter(parameter) == entry.parameters[parameter],
				"%s: 卡圖 %s 被改動" % [context, parameter])


func _check_frontmost(card: Card, neighbor: Card, original: Array[Dictionary]) -> void:
	var neighbor_top := -128
	for child in neighbor.get_children():
		if child is Sprite3D or child is Label3D:
			neighbor_top = maxi(neighbor_top, child.render_priority)
		if child is Label3D:
			neighbor_top = maxi(neighbor_top, child.outline_render_priority)
		if child is Sprite3D and child.material_override != null:
			neighbor_top = maxi(neighbor_top, child.material_override.render_priority)
	var art: Sprite3D = card.get_node("CardArt")
	var frame: Sprite3D = card.get_node("CardFrame")
	_expect(frame.render_priority > art.render_priority, "hover 卡框必須排在卡圖前")
	for child in card.get_children():
		if child is Sprite3D or child is Label3D:
			_expect(child.render_priority > neighbor_top, "%s 仍可能被鄰卡遮住" % child.name)
			_expect(child.no_depth_test, "%s 仍會被鄰卡深度遮住" % child.name)
		if child is Label3D:
			_expect(child.outline_render_priority > frame.render_priority,
				"%s 外框未在 hover 卡框前" % child.name)
			_expect(child.render_priority > child.outline_render_priority,
				"%s 文字未在自身外框前" % child.name)
	if art.material_override is ShaderMaterial:
		_expect(art.material_override.render_priority > neighbor_top,
			"專用卡圖材質未排到鄰卡前")
		_expect(art.material_override.render_priority < frame.render_priority,
			"專用卡圖材質未排在自身卡框後")
		for entry in original:
			if entry.target == art.material_override:
				_expect(art.material_override.shader != entry.properties.shader,
					"專用卡圖 hover 未切換前景 shader")
				for parameter in entry.parameters:
					_expect(art.material_override.get_shader_parameter(parameter) == entry.parameters[parameter],
						"專用卡圖 hover 不得更動 %s" % parameter)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: " + message)
