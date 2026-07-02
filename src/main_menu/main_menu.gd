## main_menu.gd — 遊戲主畫面(3D 城鎮背景 + 標題 + 開始遊戲 / 離開遊戲)
##
## 掛在 scenes/main_menu.tscn 的根 Node3D 上;project.godot 的 run/main_scene
## 已指向該場景,所以遊戲一啟動就是這個畫面,按「開始遊戲」才進牌桌。
##
## 結構(全部由程式組裝,場景檔只有一個空根節點):
##   MainMenu (Node3D, 本腳本)
##   ├─ Arena_Town        ← 3D 城鎮(scenes/arena_town.tscn,黃昏廣場)
##   ├─ CameraPivot/Camera3D ← 繞著廣場緩慢環繞的鏡頭
##   └─ CanvasLayer/UI    ← 2D 選單疊在 3D 畫面上(CanvasItem 永遠畫在 3D 之上)
##
## 為什麼版面用程式碼組裝、場景檔保持極薄?
##   ① 「置中 + 垂直排列」的規則版面用容器程式碼描述,比在編輯器手擺更好讀;
##   ② 專案慣例是 .tscn 由編輯器維護,內容放 code,場景檔就幾乎不會再被改。
extends Node3D

## ── Inspector 可調參數 ──────────────────────────────
@export var game_title: String = "卡牌對決"                      # 主標題(改名不用動 code)
@export var game_subtitle: String = "CardGame Demo · Godot 4.5"  # 副標題
@export var orbit_speed: float = 0.04    # 鏡頭環繞速度(弧度/秒;0 = 不轉)

## ── 遊戲場景與牌桌抽籤 ─────────────────────────────
## 玩法場景永遠是 main.tscn;「這一局用哪個環境」(森林/洞窟/冰原)由
## ArenaPool 抽籤決定,main.tscn 上的 main_scene.gd 依抽籤結果把環境換上去。
## 想加新牌桌:去 src/environment/arena_pool.gd 的 ARENAS 加一行路徑即可。
const GAME_SCENE := "res://scenes/main.tscn"

## 主選單背景用的城鎮場景(黃昏廣場,見 src/environment/arena_town.gd)。
const TOWN_SCENE: PackedScene = preload("res://scenes/arena_town.tscn")

## 標題上方的裝飾卡背圖,直接重用牌堆的卡背素材。
const CARD_BACK: Texture2D = preload("res://assets/ui/textures/card_back.png")

var _start_button: Button    # 記住開始鈕,換場景前要鎖它防連點
var _cam_pivot: Node3D       # 鏡頭的旋轉軸(轉它,不轉相機本身)
var _fade_rect: ColorRect    # 蓋在最上層的黑幕:開場淡入、換場景淡出都靠它


func _ready() -> void:
	_build_town_backdrop()
	_build_ui()
	_start_button.grab_focus()   # 給鍵盤焦點:開場直接按 Enter 就能開始
	# 開場從全黑淡入:黑幕 alpha 1 → 0。黑幕蓋得住 3D 和 UI,整個畫面一起浮現。
	_fade_rect.color.a = 1.0
	create_tween().tween_property(_fade_rect, "color:a", 0.0, 0.8)


func _process(delta: float) -> void:
	# 鏡頭繞著廣場慢慢轉,讓背景是「活」的。轉的是 pivot(旋轉軸),
	# 相機掛在 pivot 上保持固定偏移——比直接搬相機座標簡單且不會累積誤差。
	if _cam_pivot != null:
		_cam_pivot.rotate_y(delta * orbit_speed)


## ── 3D 背景:實例化城鎮 + 架環繞鏡頭 ──────────────────
func _build_town_backdrop() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)   # 城鎮自帶 WorldEnvironment 與燈光(黃昏),選單直接沿用

	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CameraPivot"
	add_child(_cam_pivot)   # pivot 停在世界原點 = 廣場中心

	var cam := Camera3D.new()
	_cam_pivot.add_child(cam)
	cam.position = Vector3(0.0, 5.0, 12.0)        # 從廣場外緣、約兩層樓高往裡看
	cam.rotation_degrees = Vector3(-14.0, 0.0, 0.0)  # 微俯角:看得到廣場也看得到房子
	cam.fov = 50.0
	cam.current = true


## ── 2D 選單:疊在 3D 畫面上 ────────────────────────────
func _build_ui() -> void:
	# CanvasLayer = 2D 疊層:它下面的 CanvasItem 一律畫在 3D 視圖之上。
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.name = "UI"
	layer.add_child(ui)
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)   # 撐滿整個視窗

	# 半透明暗角:上緣淡、下緣深的漸層壓在 3D 畫面上,
	# 不遮城鎮風景,但讓中央的白色標題字在亮背景上也讀得清。
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.25))
	grad.set_color(1, Color(0.0, 0.0, 0.0, 0.6))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)   # 垂直漸層:從上到下
	grad_tex.fill_to = Vector2(0.0, 1.0)
	var scrim := TextureRect.new()
	scrim.texture = grad_tex
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(scrim)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 選單主體:置中容器 → 垂直排列(卡背、標題、副標、按鈕)。
	var center_box := CenterContainer.new()
	ui.add_child(center_box)
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)   # 直排元素的統一間距(px)
	center_box.add_child(col)

	col.add_child(_make_card_emblem())
	col.add_child(_make_label(game_title, 64, Color("f2e3ae")))    # 暖金標題,呼應夕陽
	col.add_child(_make_label(game_subtitle, 18, Color("cdbfae")))
	col.add_child(_make_spacer(26))   # 標題區和按鈕區之間單獨拉開一段

	_start_button = _make_button("開始遊戲", 26, Vector2(280, 58), Color("2e6b46"))
	_start_button.pressed.connect(_on_start_pressed)
	col.add_child(_start_button)

	var quit_btn := _make_button("離開遊戲", 18, Vector2(280, 44), Color("3a3f44"))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())   # 直接關閉遊戲
	col.add_child(quit_btn)

	# 黑幕:最後才 add(畫在最上層)。IGNORE = 滑鼠事件穿透,不擋按鈕點擊。
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade_rect)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


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


## ── 標題上方的卡背圖:純裝飾,給畫面一個「這是卡牌遊戲」的視覺錨點 ──
func _make_card_emblem() -> TextureRect:
	var card := TextureRect.new()
	card.texture = CARD_BACK
	card.custom_minimum_size = Vector2(150, 210)                  # 展示用的小尺寸
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE             # 允許把大圖縮進上面的框
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 等比縮放置中,不變形
	# rotation 是繞著 pivot_offset 轉;pivot 預設在左上角,直接轉會整張「掃」出去。
	# 等它有了實際尺寸再把 pivot 移到中心——resized 信號會在尺寸確定/改變時發出。
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	# 微微搖擺的待機動畫:2.4 秒盪過去、2.4 秒盪回來,set_loops() = 無限循環。
	# SINE + EASE_IN_OUT = 兩端慢、中間快,像鐘擺,不會機械式急停。
	var sway := create_tween().set_loops()
	sway.tween_property(card, "rotation_degrees", 5.0, 2.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(card, "rotation_degrees", -5.0, 2.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return card


## ── 造一個置中的文字標籤,主/副標題共用 ──
func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var lb := Label.new()
	lb.text = text_value
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# add_theme_*_override:只影響「這一個」節點的主題屬性,不會動到全域 theme。
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", color)
	# 文字壓在 3D 風景上,加一圈深色描邊保住可讀性(比陰影穩:不挑背景亮暗)。
	lb.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	lb.add_theme_constant_override("outline_size", 6)
	return lb


## ── 純占位的透明空隙 ──
## VBox 的 separation 是均一間距;想「單獨拉開某一段」就塞一個固定高度的空節點。
func _make_spacer(height: float) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, height)
	return sp


## ── 造一顆按鈕:同一份底色自動衍生三態(normal / hover / pressed)──
func _make_button(text_value: String, font_size: int, size_px: Vector2,
		base_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = size_px
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("e6efe8"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	# lightened()/darkened() 回傳「調亮/調暗後的新顏色」,原色不變:
	# hover 提亮 25%、pressed 壓暗 25%,三態同形狀、只換色。
	btn.add_theme_stylebox_override("normal", _make_panel_style(base_color))
	btn.add_theme_stylebox_override("hover", _make_panel_style(base_color.lightened(0.25)))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(base_color.darkened(0.25)))
	return btn


## ── 圓角 + 細邊框的面板底,按鈕三態共用的形狀 ──
func _make_panel_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bg.lightened(0.35)   # 邊框比底色亮一階,便宜的立體感
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	return sb
