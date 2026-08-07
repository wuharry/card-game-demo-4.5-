extends SceneTree
## 換卡框預覽:並排拍「現用 NewCard 框」與「cards_sheet 新框」的對照圖。
##   godot --path . -s tests/preview_new_frame.gd -- /絕對路徑/out.png
##
## ⚠ 這支**不改任何正式檔案**:card.tscn / card.gd 一行不動,
## 新框是在實例上覆寫 CardFrame 的貼圖與 CardArt 的擺位,拍完就丟。
## 目的是「先看到再決定」,不是先改再後悔(換框要動的是雷區 .tscn)。
##
## 座標來源:tests/probe_sheet_alpha.gd 量出來的
##   格子    Rect2(16 + 欄×80, 16 + 排×112, 64, 96)
##   卡圖窗  相對格子 左 0.000 / 上 0.177 / 寬 1.000 / 高 0.354(排 0、排 1 才有)

const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
const SHEET_PATH := "res://assets/ui/card_frames/pixel_template/cards_sheet.png"

## 卡片在世界裡的固定尺寸(card.tscn 用 pixel_size 湊出來的 1.6 × 2.4)。
const CARD_W := 1.6
const CARD_H := 2.4
## 新框每格 64×96 → pixel_size 要 1.6/64 = 0.025,高自動是 96×0.025 = 2.4(比例本來就一致)
const NEW_PIXEL_SIZE := 1.6 / 64.0

## 新框的卡圖窗(換算成卡片本地座標):
## 上緣 y = +1.2 − 0.177×2.4 = 0.775;高 = 0.354×2.4 = 0.850 → 中心 y = 0.35
const NEW_WIN_CENTER := Vector2(0.0, 0.35)
const NEW_WIN_SIZE := Vector2(1.600, 0.850)

## 版面各區的本地 y(tests/probe_frame_bands.gd 逐列量出來的,不是目測):
const NEW_TOP_BAND_Y := 0.975    # 卡頂裝飾帶(費用擺這)
const NEW_NAME_Y := -0.262       # 卡名木牌中心
const NEW_DESC_Y := -0.762       # 描述木框中心(高 0.425、寬 1.05)
const NEW_STAT_Y := -1.030       # 卡底(ATK/HP、卡型章)
## 木框世界寬 1.05 ÷ Label3D 預設 pixel_size 0.005 = 210px
const NEW_DESC_W_PX := 210.0

## 四色欄位:0=藍 1=綠 2=紫 3=紅;排 1 = 有卡圖窗、下半留白(沒有畫死的文字線)
const COL_BLUE := 0
const COL_GREEN := 1
const COL_PURPLE := 2
const COL_RED := 3
const ROW_PLAIN := 1


func _initialize() -> void:
	_run.call_deferred()


func _cell(col: int, row: int) -> Rect2:
	return Rect2(16 + col * 80, 16 + row * 112, 64, 96)


func _make_card(cd: CardData, x: float, new_frame: bool, col: int) -> Node3D:
	var card: Node3D = CARD_SCENE.instantiate()
	root.add_child(card)
	card.setup(cd)
	card.position = Vector3(x, 0.0, 0.0)
	if not new_frame:
		return card

	# ── 換框:CardFrame 換成 sheet 的一格 ──
	var sheet: Texture2D = ResourceLoader.load(SHEET_PATH)
	if sheet == null:
		# 素材還沒被編輯器匯入(沒有 .import)→ 走原始檔後門(§23)
		var img := Image.load_from_file(SHEET_PATH)
		if img == null:
			push_error("讀不到 %s" % SHEET_PATH)
			return card
		sheet = ImageTexture.create_from_image(img)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = _cell(col, ROW_PLAIN)
	var frame: Sprite3D = card.get_node("CardFrame")
	frame.texture = atlas
	frame.pixel_size = NEW_PIXEL_SIZE
	frame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 像素圖要銳利

	# ── 卡圖重新塞進「新窗」(複製 card.gd setup 的兩條分支,只換窗尺寸)──
	var art: Sprite3D = card.get_node("CardArt")
	if cd.standee != null:
		var bounds: Rect2 = art.region_rect
		art.pixel_size = minf(NEW_WIN_SIZE.x / bounds.size.x,
			NEW_WIN_SIZE.y / bounds.size.y)      # contain:整個本體進窗
		art.scale = Vector3.ONE
	elif cd.art != null:
		var tex_h := maxf(float(cd.art.get_height()), 1.0)
		var tex_w := maxf(float(cd.art.get_width()), 1.0)
		art.pixel_size = NEW_WIN_SIZE.y / tex_h
		var target_w := NEW_WIN_SIZE.x - 0.08                     # 兩側各留一點呼吸邊
		art.scale = Vector3(target_w / (tex_w * art.pixel_size), 1.0, 1.0)
	art.position = Vector3(NEW_WIN_CENTER.x, NEW_WIN_CENTER.y, -0.01)

	# ── 字的位置跟著新版面調(座標來自 tests/probe_frame_bands.gd 的實測)──
	card.get_node("CostLabel").position = Vector3(-0.62, NEW_TOP_BAND_Y, 0.02)
	card.get_node("NameLabel").position = Vector3(0.0, NEW_NAME_Y, 0.022)
	card.get_node("ATKLabel").position = Vector3(-0.62, NEW_STAT_Y, 0.02)
	card.get_node("HPLabel").position = Vector3(0.62, NEW_STAT_Y, 0.02)

	# 描述文字:舊框是「淺色羊皮紙 → 墨黑字」,新框是「深棕木框 → 淺色字」。
	# 只搬位置不改顏色的話,墨黑字在深棕底上等於隱形——這是換框最容易漏的一項。
	var skill: Label3D = card.get_node_or_null("SkillLabel")
	if skill != null:
		skill.position = Vector3(0.0, NEW_DESC_Y, 0.02)
		skill.width = NEW_DESC_W_PX
		skill.font_size = 15                       # 木框比羊皮紙窄,字要跟著縮
		skill.modulate = Color(0.90, 0.84, 0.72)   # 米白:深棕底上的可讀色
		skill.outline_size = 2
		skill.outline_modulate = Color(0.05, 0.03, 0.02)
	# 卡型章:原色是為淺底調的暗色印泥,深色底上要提亮才看得見
	var type_lb: Label3D = card.get_node_or_null("TypeLabel")
	if type_lb != null:
		type_lb.position = Vector3(0.0, NEW_STAT_Y, 0.02)
		type_lb.modulate = type_lb.modulate.lightened(0.55)
	return card


func _caption(text: String, x: float, y: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.004
	l.position = Vector3(x, y, 0.1)
	l.modulate = Color(1, 1, 0.7)
	root.add_child(l)


func _run() -> void:
	var out := "/tmp/frame_preview.png"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		out = ua[0]

	# 背景:純深色,別讓天空干擾判讀
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.11)
	env.environment = e
	root.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2
	cam.position = Vector3(0.0, 0.0, 6.0)
	root.add_child(cam)
	cam.make_current()

	var minion: CardData = load("res://data/cards/knight.tres")
	var arcana: CardData = load("res://data/cards/arcana_fireblast.tres")

	# 左二:從者卡 舊 vs 新;右二:秘術卡 舊 vs 新
	_make_card(minion, -2.7, false, COL_RED)
	_make_card(minion, -0.9, true, COL_RED)
	_make_card(arcana, 0.9, false, COL_PURPLE)
	_make_card(arcana, 2.7, true, COL_PURPLE)
	_caption("舊", -2.7, 1.45)
	_caption("新", -0.9, 1.45)
	_caption("舊", 0.9, 1.45)
	_caption("新", 2.7, 1.45)

	for i in 60:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: " + out)
	quit(0)
