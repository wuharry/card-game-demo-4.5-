## main_menu.gd — 遊戲主畫面(3D 城鎮背景 + 標題 + 開始遊戲 / 離開遊戲)
##
## 掛在 scenes/main_menu.tscn 的根 Node3D 上;project.godot 的 run/main_scene
## 已指向該場景,所以遊戲一啟動就是這個畫面,按「開始遊戲」才進牌桌。
##
## 結構(全部由程式組裝,場景檔只有一個空根節點):
##   MainMenu (Node3D, 本腳本)
##   ├─ Arena_Town        ← 3D 城鎮(scenes/arena_town.tscn,黃昏廣場)
##   ├─ Camera3D          ← 固定鏡頭:站在廣場內側望向對面房屋(不旋轉)
##   └─ CanvasLayer/UI    ← 2D 選單疊在 3D 畫面上(CanvasItem 永遠畫在 3D 之上)
##
## 視覺對標歧路旅人的標題畫面:襯線字標題 + 細金線 + 純文字選單(不是色塊
## 按鈕)+ 四周壓暗的 vignette;被選中的選項會亮起、底下浮出一條金線。
extends Node3D

## ── Inspector 可調參數 ──────────────────────────────
@export var game_title: String = "卡牌對決"                      # 主標題(改名不用動 code)
@export var game_subtitle: String = "CardGame Demo · Godot 4.5"  # 底部小字

@export_group("鏡頭構圖(不滿意就調這裡,不用動 code)")
## 房屋圈半徑 13(見 arena_town.gd);舊版鏡頭放在 r=12,等於「站進房子裡」,
## 開場整個畫面都是屋頂。退到廣場內側 r=9,一開場就是完整的廣場與對面街景。
@export var cam_position := Vector3(0.0, 5.0, 9.0)
@export var cam_pitch_deg: float = -13.0   # 俯角:兼顧廣場地面和對面房子
@export var cam_fov: float = 45.0          # 視角略窄:望遠感,街景比較「滿」

## ── 遊戲場景與牌桌抽籤 ─────────────────────────────
## 玩法場景永遠是 main.tscn;「這一局用哪個環境」(森林/洞窟/冰原)由
## ArenaPool 抽籤決定,main.tscn 上的 main_scene.gd 依抽籤結果把環境換上去。
const GAME_SCENE := "res://scenes/main.tscn"

## 主選單背景用的城鎮場景(黃昏廣場,見 src/environment/arena_town.gd)。
const TOWN_SCENE: PackedScene = preload("res://scenes/arena_town.tscn")

## ── 字型 ────────────────────────────────────────────
## 思源宋體(Noto Serif TC)= 中文襯線主角:標題與選單都用它,氣質靠它撐;
## Playpen Sans 只拿來排底部那行英文小字。兩套都是 SIL OFL 授權,可安心商用。
const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_MENU: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")
const FONT_SUB: FontFile = preload(
	"res://assets/fonts/Playpen_Sans/static/PlaypenSans-Regular.ttf")

## ── 配色:同一組「暮色金」貫穿全畫面,和城鎮的夕陽/窗光同色系 ──
const GOLD := Color("f2e3ae")       # 亮金:標題
const GOLD_DIM := Color("b8a984")   # 沉金:未選中的選單文字
const LINE_GOLD := Color(0.83, 0.72, 0.45, 0.85)   # 裝飾細線

var _start_button: Button    # 記住開始鈕,換場景前要鎖它防連點
var _fade_rect: ColorRect    # 蓋在最上層的黑幕:開場淡入、換場景淡出都靠它


func _ready() -> void:
	_build_town_backdrop()
	_build_ui()
	_start_button.grab_focus()   # 給鍵盤焦點:開場直接按 Enter 就能開始
	# 開場從全黑淡入:黑幕 alpha 1 → 0。黑幕蓋得住 3D 和 UI,整個畫面一起浮現。
	_fade_rect.color.a = 1.0
	create_tween().tween_property(_fade_rect, "color:a", 0.0, 0.8)


## ── 3D 背景:實例化城鎮 + 固定構圖鏡頭 ──────────────────
func _build_town_backdrop() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)   # 城鎮自帶 WorldEnvironment 與燈光(黃昏),選單直接沿用

	# 固定鏡頭、不再環繞:主選單要的是「一幅構圖好的畫」,不是場景導覽。
	# 城鎮用固定亂數種子生成(rng_seed 7777),所以這個構圖每次開遊戲都一樣。
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = cam_position
	cam.rotation_degrees = Vector3(cam_pitch_deg, 0.0, 0.0)
	cam.fov = cam_fov
	cam.current = true


## ── 2D 選單:疊在 3D 畫面上 ────────────────────────────
func _build_ui() -> void:
	# CanvasLayer = 2D 疊層:它下面的 CanvasItem 一律畫在 3D 視圖之上。
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.name = "UI"
	layer.add_child(ui)
	# ⚠ 一定要用 set_anchors_AND_offsets_preset:舊版用的 set_anchors_preset()
	# 只改「錨點」,而且會反算偏移、保留呼叫當下的矩形——UI 根節點因此被鎖在
	# 開遊戲那一刻的視窗大小,視窗一放大,選單中心就往左上飄(之前「沒置中」的
	# 根因)。帶 offsets 的版本才等於編輯器 Layout 選單裡的「Full Rect」。
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_vignette(ui)
	_build_menu_column(ui)
	_build_footer(ui)

	# 黑幕:最後才 add(畫在最上層)。IGNORE = 滑鼠事件穿透,不擋按鈕點擊。
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## ── vignette:中央透亮、四角沉黑的放射狀壓暗 ─────────────
## 歧路旅人標題畫面的同款手法:不遮風景,但把視線「推」向中央的標題與選單。
## (之前的上下漸層只壓天和地,左右兩側壓不住,亮背景時字會浮。)
func _build_vignette(ui: Control) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.10))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.62))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)    # 圓心 = 畫面正中央
	tex.fill_to = Vector2(0.5, -0.15)    # 半徑略超出畫面,只有邊角吃到最深的黑
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## ── 選單主體:置中一欄(標題 → 金線 → 選項)──────────────
func _build_menu_column(ui: Control) -> void:
	var center_box := CenterContainer.new()
	ui.add_child(center_box)
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center_box.add_child(col)

	# 標題:襯線粗體 + 往下柔影。陰影比粗描邊高級:大字配粗描邊會有「貼紙感」。
	var title := Label.new()
	title.text = game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(title)

	# 標題底下一條細金線:印刷品式的裝飾,成本一個 ColorRect,氣質到位。
	var line := ColorRect.new()
	line.color = LINE_GOLD
	line.custom_minimum_size = Vector2(300, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(line)

	col.add_child(_make_spacer(52))   # 標題區和選項區之間拉開呼吸空間

	_start_button = _make_menu_option("開始遊戲")
	_start_button.pressed.connect(_on_start_pressed)
	col.add_child(_start_button)

	var quit_btn := _make_menu_option("離開遊戲")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())   # 直接關閉遊戲
	col.add_child(quit_btn)


## ── 底部小字:版本行,像標題畫面角落的版權訊息 ─────────────
func _build_footer(ui: Control) -> void:
	var sub := Label.new()
	sub.text = game_subtitle
	sub.add_theme_font_override("font", FONT_SUB)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
	ui.add_child(sub)
	# CENTER_BOTTOM 預設模式會用文字的最小尺寸定位;最後的 18 = 離底邊 18px。
	sub.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)


## ── 按下「開始遊戲」:抽牌桌環境,淡出後進入遊戲 ──
func _on_start_pressed() -> void:
	_start_button.disabled = true   # 先鎖按鈕:淡出期間連點也不會觸發第二次
	# 抽這一局的牌桌環境(森林/洞窟/冰原,均等機率)。結果存在 ArenaPool 的
	# static 變數上——static 活在類別上、不隨場景切換消失,main.tscn 載入後讀得到。
	ArenaPool.pick_random()
	# 淡出到全黑(純手感)。await = 停在這行,等 tween 的 finished 信號發出才繼續。
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	await tw.finished
	# change_scene_to_file:卸載目前場景,載入並切換到指定路徑的場景。
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		# 換場景失敗(路徑打錯/檔案壞了)時別讓玩家卡在黑畫面:報錯並還原選單。
		push_error("進入牌桌失敗:%s(錯誤碼 %d)" % [GAME_SCENE, err])
		_fade_rect.color.a = 0.0
		_start_button.disabled = false


## ── 歧路旅人式「文字選單項」────────────────────────────
## 平常是沉金純文字;滑鼠 hover「或」鍵盤焦點時文字亮起、底下浮出金線。
## 同一份樣式同時接 hover 和 focus:滑鼠派和鍵盤派看到的回饋一致。
func _make_menu_option(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(280, 48)
	btn.add_theme_font_override("font", FONT_MENU)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	btn.add_theme_color_override("font_focus_color", Color("fff3cf"))
	btn.add_theme_color_override("font_pressed_color", GOLD)
	# normal 狀態給「空樣式」= 沒有底沒有框,就是一行字(色塊按鈕感從這裡消失)。
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var lit := _make_underline_style()
	btn.add_theme_stylebox_override("hover", lit)
	btn.add_theme_stylebox_override("focus", lit)
	btn.add_theme_stylebox_override("pressed", _make_underline_style())
	return btn


## 選中狀態的樣式:透明底 + 只開「下邊框」的金線(StyleBoxFlat 可逐邊開關)。
func _make_underline_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.04)   # 極淡提亮,整行有「浮起」感
	sb.border_color = LINE_GOLD
	sb.border_width_bottom = 2
	return sb


## ── 純占位的透明空隙 ──
## VBox 的 separation 是均一間距;想「單獨拉開某一段」就塞一個固定高度的空節點。
func _make_spacer(height: float) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, height)
	return sp
