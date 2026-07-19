## card_gallery.gd — 牌庫圖鑑:一次看完卡池裡目前有哪些牌
##
## 主選單按「牌庫圖鑑」時開啟的全螢幕疊層:暗幕 + 可捲動的卡片方格 +
## 依卡型分頁篩選。純顯示、不影響任何遊戲帳——資料一律走 Deck.load_pool()
## (和開局洗牌、@tool 手牌預覽同一個卡池來源,新增 .tres 自動出現在這)。
##
## 掛法:main_menu.gd 在 _ready 生成掛在自己底下、平時 hide();按鈕呼叫 open()。
## 自成一個 CanvasLayer(layer=10)= 疊在選單 UI 之上,關掉時把焦點還給選單。
## 為什麼獨立成節點而非塞進 main_menu:主選單已 ~400 行,且「一功能一資料夾」
## 是專案慣例;圖鑑之後可能長出搜尋/排序,先切開職責。
class_name CardGallery
extends CanvasLayer

## 關閉圖鑑(把焦點交還給主選單)。main_menu 訂閱這條決定收尾動作。
signal closed

const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_BODY: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")

## 配色沿用主選單/戰鬥 UI 的「暮色金」,整個遊戲說同一種話。
const GOLD := Color("f2e3ae")
const GOLD_DIM := Color("b8a984")
const LINE_GOLD := Color(0.83, 0.72, 0.45, 0.85)

## 卡型顯示名 + 印章色(和 card.gd 的 TYPE_BADGES 同語彙;MINION 另給「從者」)。
const TYPE_INFO := {
	CardData.CardType.MINION: ["從者", Color(0.55, 0.42, 0.2)],
	CardData.CardType.EQUIP: ["靈裝", Color(0.5, 0.36, 0.1)],
	CardData.CardType.ARCANA: ["秘術", Color(0.4, 0.18, 0.5)],
	CardData.CardType.QUICK: ["瞬咒", Color(0.12, 0.32, 0.55)],
	CardData.CardType.WARD: ["伏印", Color(0.16, 0.4, 0.18)],
	CardData.CardType.DOMAIN: ["領域", Color(0.35, 0.35, 0.35)],
}

## 篩選分頁:全部 + 五種在用的卡型(順序即分頁順序;-1 = 全部)。
const FILTER_TABS: Array = [
	[-1, "全部"],
	[CardData.CardType.MINION, "從者"],
	[CardData.CardType.ARCANA, "秘術"],
	[CardData.CardType.EQUIP, "靈裝"],
	[CardData.CardType.QUICK, "瞬咒"],
	[CardData.CardType.WARD, "伏印"],
]

const GRID_COLUMNS := 5

var _all_cards: Array[CardData] = []   # 卡池全量(load 一次、篩選只是重排視圖)
var _active_filter: int = -1
var _grid: GridContainer = null
var _count_label: Label = null
var _tab_row: HBoxContainer = null
var _back_btn: Button = null   # 開啟時搶焦點:別讓 Enter 漏到選單的「開始遊戲」
var _built := false


func _ready() -> void:
	layer = 10   # 疊在主選單 UI(預設 layer 1)之上
	hide()


## 開啟圖鑑:第一次開才組裝 UI(卡池載入一次),之後重複開只切 visible。
func open() -> void:
	if not _built:
		_build()
		_built = true
	_active_filter = -1
	_refresh_grid()
	_sync_tab_highlight()
	show()
	_back_btn.grab_focus()   # 搶焦點:圖鑑裡按 Enter/Space 不會漏到底下的選單按鈕


func close() -> void:
	hide()
	closed.emit()


## ESC / 右鍵都收:圖鑑是「看一看」,退出要順手。
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_esc: bool = event is InputEventKey and event.pressed \
		and event.keycode == KEY_ESCAPE
	var is_rmb: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	if is_esc or is_rmb:
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_all_cards = Deck.load_pool()
	# 排序:先卡型(enum 序)、再費用、再卡名——瀏覽時同類聚在一起、費用由低到高。
	_all_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.card_type != b.card_type:
			return a.card_type < b.card_type
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.card_name < b.card_name)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.92)   # 近乎全黑:圖鑑是獨立畫面、不用透出城鎮
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 主欄:標題列 → 分頁列 → 捲動方格 → 返回。用邊距容器留出四周呼吸空間。
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	_build_header(col)
	_build_tabs(col)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


## 標題列:「牌庫圖鑑」+ 張數 ────── 返回鈕(靠右)。
func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)

	var title := Label.new()
	title.text = "牌庫圖鑑"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	row.add_child(title)

	_count_label = Label.new()
	_count_label.add_theme_font_override("font", FONT_BODY)
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", GOLD_DIM)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_back_btn = _make_text_button("返回", 24)
	_back_btn.pressed.connect(close)
	row.add_child(_back_btn)

	var line := ColorRect.new()
	line.color = LINE_GOLD
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)


## 分頁列:全部 / 從者 / 秘術 / …,點了重排方格並更新高亮。
func _build_tabs(col: VBoxContainer) -> void:
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 6)
	col.add_child(_tab_row)
	for tab in FILTER_TABS:
		var type_id: int = tab[0]
		var btn := _make_text_button(tab[1], 20)
		btn.pressed.connect(func() -> void:
			_active_filter = type_id
			_refresh_grid()
			_sync_tab_highlight())
		_tab_row.add_child(btn)


## 依目前篩選重建方格。清空只 free 舊磚——卡片資料本身留在 _all_cards。
func _refresh_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var shown := 0
	for cd in _all_cards:
		if _active_filter != -1 and cd.card_type != _active_filter:
			continue
		_grid.add_child(_make_card_tile(cd))
		shown += 1
	_count_label.text = "  共 %d 張" % shown


## 分頁高亮:當前分頁的字轉亮金,其餘沉金(靠字色區分,不做底色按鈕)。
func _sync_tab_highlight() -> void:
	for i in range(_tab_row.get_child_count()):
		var btn := _tab_row.get_child(i) as Button
		var is_active: bool = FILTER_TABS[i][0] == _active_filter
		btn.add_theme_color_override("font_color", GOLD if is_active else GOLD_DIM)


## 一張圖鑑卡磚:卡圖 + 名/費 + 卡型章 + 攻血或技能描述。
func _make_card_tile(d: CardData) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _make_tile_style())
	tile.custom_minimum_size = Vector2(0, 250)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	tile.add_child(col)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 104)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素圖放大要銳利
	art.texture = _cardface_art(d)
	col.add_child(art)

	var name_l := Label.new()
	name_l.add_theme_font_override("font", FONT_TITLE)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", GOLD)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.text = "%s  ◆%d" % [d.card_name, d.cost]
	col.add_child(name_l)

	var info: Array = TYPE_INFO.get(d.card_type, ["?", GOLD_DIM])
	var badge := Label.new()
	badge.add_theme_font_override("font", FONT_BODY)
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", (info[1] as Color).lightened(0.35))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if d.card_type == CardData.CardType.MINION:
		badge.text = "從者  攻 %d / 血 %d" % [d.atk, d.hp]
	else:
		badge.text = info[0]
	col.add_child(badge)

	var desc := Label.new()
	desc.add_theme_font_override("font", FONT_BODY)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color("cfc4a6"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.text = _skill_text(d)
	col.add_child(desc)

	return tile


## 技能/關鍵字摘要:有主動技印技能全文;從者再補關鍵字;都沒有印一條淡字。
func _skill_text(d: CardData) -> String:
	var parts: PackedStringArray = []
	if d.active_skill != null:
		var s := d.active_skill
		if d.card_type == CardData.CardType.MINION:
			parts.append("【%s】%s" % [s.skill_name, s.description])
		else:
			parts.append(s.description)
	if not d.keywords.is_empty():
		var words: PackedStringArray = []
		for w in d.keywords:
			words.append(String(w))
		parts.append("關鍵字:" + "、".join(words))
	if parts.is_empty():
		return "—"
	return "\n".join(parts)


## 卡面圖:從者=立牌動畫第 0 幀裁可見範圍;法術=圖示(和戰鬥 hover 預覽同一把尺)。
func _cardface_art(d: CardData) -> Texture2D:
	if d.standee != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = d.standee
		atlas.region = Card.visible_bounds_of_frame0(d.standee)
		return atlas
	return d.art


## 卡磚底:半透明深底 + 細金框,和暗幕拉出層次。
func _make_tile_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.12, 0.85)
	sb.border_color = Color(0.45, 0.38, 0.24, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


## 純文字按鈕(返回/分頁共用):沉金字,hover/focus 轉亮、底浮金線。
func _make_text_button(text_value: String, size: int) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.pressed.connect(func() -> void: Sfx.play(Sfx.CLICK, -8.0))
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	btn.add_theme_color_override("font_focus_color", Color("fff3cf"))
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	lit.border_color = LINE_GOLD
	lit.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", lit)
	btn.add_theme_stylebox_override("focus", lit)
	return btn
