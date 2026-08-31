extends SceneTree
## 官網首屏素材:跑戰場、召喚幾隻,然後把所有 UI 圖層與 3D 文字標籤藏起來,
## 拍一張沒有介面雜訊的純戰場。用法:
##   godot --path . -s tests/screenshot_clean.gd -- <out.png> [arena_path]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.is_empty():
		print("usage: out.png [arena_path]")
		quit(2)
		return
	ArenaPool.next_arena_path = ua[1] if ua.size() > 1 else ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 90:
		await process_frame

	var cm = root.find_child("CardManger", true, false)
	var ph = cm.get("player_hand")
	for _round in 4:
		var card = null
		for c in ph.cards:
			if c.data != null and c.data.card_type == 0:
				card = c
				break
		if card == null:
			break
		var slot = null
		for s in get_nodes_in_group("player_front"):
			if s.is_empty:
				slot = s
				break
		if slot == null:
			break
		cm._pending_play_card = card
		cm._net_summon(ph.cards.find(card), card.data.resource_path, cm.get_path_to(slot))
		await create_timer(0.55).timeout
	await create_timer(1.2).timeout

	_hide_ui(scene)
	for i in 8:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ua[0])
	print("saved: ", ua[0], " ", img.get_size())
	quit(0)


## 藏掉會干擾網站文字的東西:2D 介面層、所有 3D 文字標籤,
## 以及本體 HP 字底下那塊看板廣告牌(藏了字會只剩黑板子)。
func _hide_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer or child is Label3D:
			child.visible = false
		elif child is MeshInstance3D and _is_billboard_plate(child):
			child.visible = false
		else:
			_hide_ui(child)


func _is_billboard_plate(mesh: MeshInstance3D) -> bool:
	var mat := mesh.material_override as StandardMaterial3D
	return mat != null and mat.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
