## 唯讀墓地／戰報視窗。資料由 CardManager 提供，不改動戰鬥帳。
extends CanvasLayer

signal closed

const STYLE = preload("res://src/ui/fantasy_ui_theme.gd")
const FONT = preload("res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")
var mode: String = ""
var side: String = ""
var _root: ColorRect
var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _detail: VBoxContainer
var _art: TextureRect
var _description: Label
var _close: Button
var _shown_card: CardData


func _ready() -> void:
	layer = 5
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.65)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", STYLE.panel(STYLE.STEEL_DIM, true))
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	_title = _label("", 23)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = Button.new()
	_close.text = "關閉 / Esc"
	_close.add_theme_font_override("font", FONT)
	_close.add_theme_stylebox_override("normal", STYLE.button(true))
	_close.add_theme_stylebox_override("hover", STYLE.button(false))
	_close.add_theme_stylebox_override("focus", STYLE.button(false))
	header.add_child(_close)
	_close.pressed.connect(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "Details"
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_art = TextureRect.new()
	_art.custom_minimum_size.y = 140
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail.add_child(_art)
	_description = _label("", 16)
	_detail.add_child(_description)
	get_viewport().size_changed.connect(_layout)
	_root.hide()
	_layout()


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", STYLE.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = Vector2(24, 24)
	_panel.size = viewport_size - Vector2(48, 48)
	if viewport_size.x > 1050:
		_panel.size.x = 960
		_panel.position.x = (viewport_size.x - 960) / 2


func is_open() -> bool:
	return _root != null and _root.visible


func close() -> void:
	_root.hide()
	mode = ""
	_shown_card = null
	closed.emit()


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


func show_grave(pile_side: String, cards: Array[CardData], side_label: String) -> void:
	var opening := not is_open() or mode != "grave" or side != pile_side
	mode = "grave"
	side = pile_side
	_title.text = "%s墓地 · %d 張" % [side_label, cards.size()]
	_detail.get_parent().show()
	_clear_rows()
	if cards.is_empty():
		_rows.add_child(_label("墓地目前沒有卡牌。\n死亡、用畢或捨棄的牌會出現在這裡。", 17))
		_art.texture = null
		_description.text = ""
		_shown_card = null
	for i in range(cards.size() - 1, -1, -1):
		var card := cards[i]
		var button := Button.new()
		button.text = "%s  ·  %d 費" % [AppSettings.current().card_name(card), card.cost]
		button.custom_minimum_size.y = 48
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_stylebox_override("normal", STYLE.button(true))
		button.add_theme_stylebox_override("hover", STYLE.button(false))
		button.add_theme_stylebox_override("focus", STYLE.button(false))
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.mouse_entered.connect(_show_details.bind(card))
		button.focus_entered.connect(_show_details.bind(card))
		button.pressed.connect(_show_details.bind(card))
		_rows.add_child(button)
	if not cards.is_empty():
		_show_details(cards.back() if opening or not cards.has(_shown_card) else _shown_card)
	_root.show()
	if opening:
		_close.grab_focus()


func _show_details(card: CardData) -> void:
	_shown_card = card
	var settings := AppSettings.current()
	var lines: PackedStringArray = [settings.card_name(card),
		"%s · %d 費" % [settings.type_name(card.card_type), card.cost]]
	if card.card_type == CardData.CardType.MINION:
		lines.append("攻擊 %d / 生命 %d" % [card.atk, card.hp])
		for keyword in card.keywords:
			lines.append(settings.keyword_name(keyword))
	if card.active_skill != null:
		lines.append("【%s】%d 費\n%s" % [settings.skill_name(card, card.active_skill),
			card.active_skill.cost, settings.skill_description(card.active_skill)])
	if card.battlecry != null:
		lines.append("【戰吼】" + settings.skill_description(card.battlecry))
	_description.text = "\n\n".join(lines)
	_art.texture = card.art
	if not card.use_dedicated_art and card.standee != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = card.standee
		atlas.region = Card.visible_bounds_of_frame0(card.standee)
		_art.texture = atlas


func show_history(entries: Array[Dictionary], local_side: String) -> void:
	var opening := not is_open() or mode != "history"
	mode = "history"
	_title.text = "戰鬥紀錄"
	_detail.get_parent().hide()
	_clear_rows()
	var last_turn := -1
	# 最新回合在上，同回合保留真正的發生順序。
	var turns: Array[int] = []
	for entry in entries:
		if not turns.has(int(entry.turn)):
			turns.append(int(entry.turn))
	turns.reverse()
	for turn_number in turns:
		for entry in entries:
			if int(entry.turn) != turn_number:
				continue
			if last_turn != turn_number:
				var heading := _label("第 %d 回合 · %s回合" % [turn_number,
					"我方" if entry.active_side == local_side else "對手"], 21)
				heading.add_theme_color_override("font_color", STYLE.GOLD_DIM)
				_rows.add_child(heading)
				last_turn = turn_number
			_rows.add_child(_label("%s：%s" % [
				"系統" if entry.side == "system" else (
				"我方" if entry.side == local_side else "對手"), entry.text], 16))
	if entries.is_empty():
		_rows.add_child(_label("尚無戰鬥紀錄。", 17))
	_root.show()
	if opening:
		_close.grab_focus()
