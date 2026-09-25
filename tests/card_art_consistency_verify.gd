extends SceneTree
## 用正式 Card、圖鑑、hover、選牌與墓地 UI 比對貼圖和取景範圍。

var failures := 0
var comparisons := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verify_frame_window()
	var card := load("res://src/card/card.tscn").instantiate() as Card
	var gallery := CardGallery.new()
	var battle_ui := BattleUI.new()
	root.add_child(card)
	root.add_child(gallery)
	root.add_child(battle_ui)
	if battle_ui.archive == null:
		push_error("BattleUI 初始化失敗")
		quit(1)
		return
	var pool := Deck.load_pool()
	for data in pool:
		_compare_views(data, card, gallery, battle_ui)
	# 舊卡缺少專用插畫時，仍須在所有入口顯示同一個待機角色。
	var legacy := CardData.new()
	legacy.standee = load("res://data/cards/necromancer.tres").standee
	legacy.card_name = "legacy standee fallback"
	_compare_views(legacy, card, gallery, battle_ui)
	battle_ui.hide_card_preview()
	card.queue_free()
	gallery.queue_free()
	battle_ui.queue_free()
	await process_frame
	print("卡圖一致性：", comparisons, " comparisons / ", failures, " failures")
	quit(0 if failures == 0 and not pool.is_empty() and comparisons == (pool.size() + 1) * 4 else 1)


func _verify_frame_window() -> void:
	var sheet := Card.FRAME_SHEET.get_image()
	for col in 4:
		var origin := Vector2i(Card.FRAME_ORIGIN + Vector2(col, Card.FRAME_ROW) * Card.FRAME_STEP)
		var width := 0
		var height := 0
		for y in int(Card.FRAME_CELL.y):
			if sheet.get_pixel(origin.x + 32, origin.y + y).a >= 0.5:
				if height > 0:
					break # 卡窗已結束；底部卡框外緣的透明缺口不算在內。
				continue
			height += 1
			var left := 32
			var right := 32
			while left > 0 and sheet.get_pixel(origin.x + left - 1, origin.y + y).a < 0.5:
				left -= 1
			while right < 63 and sheet.get_pixel(origin.x + right + 1, origin.y + y).a < 0.5:
				right += 1
			width = maxi(width, right - left + 1)
		if not (Vector2(width, height) * Card.FRAME_PIXEL_SIZE).is_equal_approx(Card.ART_WINDOW_SIZE):
			failures += 1
			push_error("卡圖尺寸與卡框實際開口不符：column %d / %dx%d px" % [col, width, height])


func _compare_views(data: CardData, card: Card, gallery: CardGallery, battle_ui: BattleUI) -> void:
	card.setup(data)
	var sprite := card.get_node("CardArt") as Sprite3D
	var gallery_tile := gallery._make_card_tile(data)
	var pick_tile := battle_ui._make_pick_tile(data, 0)
	battle_ui.show_card_preview(card)
	battle_ui.archive._show_details(data)
	var views := {
		"gallery": _find_art(gallery_tile),
		"picker": _find_art(pick_tile),
		"hover": battle_ui._prev_art,
		"archive": battle_ui.archive._art,
	}
	for label in views:
		comparisons += 1
		var view := views[label] as TextureRect
		var atlas := view.texture as AtlasTexture if view != null else null
		if atlas == null or atlas.atlas != sprite.texture \
				or not atlas.region.is_equal_approx(sprite.region_rect):
			failures += 1
			push_error("取景不一致：%s / %s" % [data.card_name, label])
		elif view.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			failures += 1
			push_error("像素濾鏡不一致：%s / %s" % [data.card_name, label])
	gallery_tile.free()
	pick_tile.free()


func _find_art(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for child in node.get_children():
		var found := _find_art(child)
		if found != null:
			return found
	return null
