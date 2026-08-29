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

## 連線邏輯(src/net/net_client.gd)。用 preload 路徑而非 class_name 實例化:
## 新 class_name 要等編輯器重掃才進全域快取,路徑載入沒有這個時間差(§19 的老坑)。
## ADR-002:從 net_lobby.gd(玩家開房)換成 net_client.gd(連專用伺服器)——
## 沒有開房、沒有 UPnP,兩位玩家都是 client 往外連,NAT 不必打洞。
const NET_CLIENT_SCRIPT: GDScript = preload("res://src/net/net_client.gd")

## 牌庫圖鑑(src/card_gallery/card_gallery.gd)。同樣走 preload 路徑實例化(§19)。
const CARD_GALLERY_SCRIPT: GDScript = preload("res://src/card_gallery/card_gallery.gd")

## ── 字型 ────────────────────────────────────────────
## 思源宋體(Noto Serif TC)= 中文襯線主角:標題與選單都用它,氣質靠它撐;
## Playpen Sans 只拿來排底部那行英文小字。兩套都是 SIL OFL 授權,可安心商用。
const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_MENU: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")
const FONT_SUB: FontFile = preload(
	"res://assets/fonts/Playpen_Sans/static/PlaypenSans-Regular.ttf")
const UI_STYLE: GDScript = preload("res://src/ui/fantasy_ui_theme.gd")
const MENU_SIGIL_SCRIPT: GDScript = preload("res://src/ui/arcane_sigil.gd")

## ── 配色:同一組「暮色金」貫穿全畫面,和城鎮的夕陽/窗光同色系 ──
const GOLD := UI_STYLE.GOLD
const GOLD_DIM := UI_STYLE.GOLD_DIM
const LINE_GOLD := Color(UI_STYLE.GOLD, 0.76)

var _start_button: Button    # 記住開始鈕,換場景前要鎖它防連點
var _practice_button: Button # 單人練習鈕(和開始鈕一起鎖,兩顆都能進牌桌)
var _fade_rect: ColorRect    # 蓋在最上層的黑幕:開場淡入、換場景淡出都靠它

## ── 連線大廳(ADR-002):選單欄 ↔ 大廳欄互斥顯示,連線邏輯全在 NetClient ──
var _net_client: Node            # NetClient 實例(連線邏輯,無 UI)
var _menu_col: VBoxContainer     # 選單欄(開始遊戲/連線對戰/離開遊戲)
var _lobby_col: VBoxContainer    # 大廳欄(伺服器位址+尋找對手/狀態字/返回)
var _lobby_status: Label         # 大廳狀態字(排隊中/配對成功/失敗原因…)
var _ip_edit: LineEdit           # 伺服器位址(正式版會填死網域並隱藏這格)
var _host_btn: Button            # 尋找對手鈕(排隊中鎖住,返回才解鎖)

## 牌庫圖鑑(全螢幕疊層,自成 CanvasLayer):平時藏著,按「牌庫圖鑑」才 open。
var _card_gallery: CanvasLayer


func _ready() -> void:
	_build_town_backdrop()
	_build_ui()
	# 連線邏輯節點:名字固定 "NetClient"(RPC 路徑合約的一部分,見 net_client.gd 檔頭)。
	# 它的 _ready 會順手斷掉任何舊連線——回主選單 = 放棄上一場。
	_net_client = NET_CLIENT_SCRIPT.new()
	_net_client.name = "NetClient"
	add_child(_net_client)
	_net_client.status_changed.connect(_on_lobby_status)
	_net_client.match_ready.connect(_on_match_ready)
	# 牌庫圖鑑:自成 CanvasLayer,生成後掛著、平時藏著,按鈕才 open()。
	_card_gallery = CARD_GALLERY_SCRIPT.new()
	_card_gallery.name = "CardGallery"
	add_child(_card_gallery)
	_card_gallery.closed.connect(_on_gallery_closed)
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
	_build_menu_sigil(ui)
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
	grad.set_color(0, Color(0.025, 0.02, 0.08, 0.14))
	grad.set_color(1, Color(0.01, 0.01, 0.035, 0.76))
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


## 原創奧術徽記只當低彩度背光，不承擔資訊；縮放與透明度都刻意壓低。
func _build_menu_sigil(ui: Control) -> void:
	var sigil := MENU_SIGIL_SCRIPT.new() as Control
	sigil.custom_minimum_size = Vector2(660, 660)
	sigil.modulate = Color(0.84, 0.80, 0.92, 0.44)
	ui.add_child(sigil)
	sigil.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## ── 選單主體:置中一欄(標題 → 金線 → 選項)──────────────
func _build_menu_column(ui: Control) -> void:
	var center_box := CenterContainer.new()
	ui.add_child(center_box)
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(430, 0)
	stage.add_theme_stylebox_override("panel", UI_STYLE.panel(UI_STYLE.GOLD, true))
	center_box.add_child(stage)

	var stack := VBoxContainer.new()
	stage.add_child(stack)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	stack.add_child(col)
	_menu_col = col   # 記住選單欄:進大廳時要把它藏起來、返回時再現身

	var eyebrow := Label.new()
	eyebrow.text = "◆  ARCANE DUEL  ◆"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", FONT_SUB)
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", UI_STYLE.AMETHYST_BRIGHT)
	col.add_child(eyebrow)

	# 標題:襯線粗體 + 往下柔影。陰影比粗描邊高級:大字配粗描邊會有「貼紙感」。
	var title := Label.new()
	title.text = game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0.18, 0.08, 0.28, 0.52))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(title)

	# 標題底下一條細金線:印刷品式的裝飾,成本一個 ColorRect,氣質到位。
	var line := TextureRect.new()
	line.texture = UI_STYLE.separator_gradient()
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(300, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(line)

	col.add_child(_make_spacer(20))

	_start_button = _make_menu_option("開始遊戲")
	_start_button.pressed.connect(_on_start_pressed)
	col.add_child(_start_button)

	_practice_button = _make_menu_option("單人練習")
	_practice_button.pressed.connect(_on_practice_pressed)
	col.add_child(_practice_button)

	var net_btn := _make_menu_option("連線對戰")
	net_btn.pressed.connect(_open_lobby)
	col.add_child(net_btn)

	var gallery_btn := _make_menu_option("牌庫圖鑑")
	gallery_btn.pressed.connect(_open_gallery)
	col.add_child(gallery_btn)

	var quit_btn := _make_menu_option("離開遊戲")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())   # 直接關閉遊戲
	col.add_child(quit_btn)

	# 大廳欄與主選單共用同一塊黑曜石舞台，靠 visible 互斥切換。
	_build_lobby_column(stack)


## ── 底部小字:版本行,像標題畫面角落的版權訊息 ─────────────
func _build_footer(ui: Control) -> void:
	var sub := Label.new()
	sub.text = game_subtitle
	sub.add_theme_font_override("font", FONT_SUB)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(UI_STYLE.TEXT_DIM, 0.58))
	ui.add_child(sub)
	# CENTER_BOTTOM 預設模式會用文字的最小尺寸定位;最後的 18 = 離底邊 18px。
	sub.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)


## ── 按下「開始遊戲」:抽牌桌環境,淡出後進入遊戲 ──
func _on_start_pressed() -> void:
	_lock_entry_buttons()   # 先鎖按鈕:淡出期間連點也不會觸發第二次
	# MatchMode 是 static:上一局若玩過單人練習,值會留著——每個入口都明確設定。
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	# 抽這一局的牌桌環境(森林/洞窟/冰原,均等機率)。結果存在 ArenaPool 的
	# static 變數上——static 活在類別上、不隨場景切換消失,main.tscn 載入後讀得到。
	ArenaPool.pick_random()
	await _enter_game()


## ── 按下「單人練習」:同一條進場路,只差把玩法設成 vs AI ──
func _on_practice_pressed() -> void:
	_lock_entry_buttons()
	MatchMode.mode = MatchMode.Mode.VS_AI
	ArenaPool.pick_random()
	await _enter_game()


func _lock_entry_buttons() -> void:
	_start_button.disabled = true
	_practice_button.disabled = true


## 淡出到黑 → 切進牌桌。單機與連線共用同一段演出;呼叫前牌桌環境要先定案
## (單機:自己 pick_random;連線:伺服器抽好、經 NetClient 的配對 RPC 寫進 ArenaPool)。
func _enter_game() -> void:
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


## ── 大廳欄(2a):建立房間 / 輸 IP 加入 / 狀態字 / 返回 ──────────
## UI 只負責「顯示與轉告」:按鈕轉呼叫 NetLobby,狀態字聽 status_changed 更新。
func _build_lobby_column(parent: Container) -> void:
	_lobby_col = VBoxContainer.new()
	_lobby_col.add_theme_constant_override("separation", 10)
	_lobby_col.visible = false   # 平時藏著,按「連線對戰」才現身
	parent.add_child(_lobby_col)

	var title := Label.new()
	title.text = "連線對戰"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	title.add_theme_constant_override("shadow_offset_y", 3)
	_lobby_col.add_child(title)

	var line := TextureRect.new()
	line.texture = UI_STYLE.separator_gradient()
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.custom_minimum_size = Vector2(240, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lobby_col.add_child(line)

	_lobby_col.add_child(_make_spacer(30))

	# 伺服器位址:正式版會填死網域(NetMatch.server_host 的預設值)並把這格藏起來。
	# 現在留著是為了本機測試(127.0.0.1),以及換 VPS 時不必重新匯出執行檔。
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lobby_col.add_child(row)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "伺服器位址(本機測試 127.0.0.1)"
	_ip_edit.text = NetMatch.server_host
	_ip_edit.custom_minimum_size = Vector2(300, 44)
	_ip_edit.add_theme_font_override("font", FONT_MENU)
	_ip_edit.add_theme_font_size_override("font_size", 17)
	_ip_edit.add_theme_color_override("font_color", UI_STYLE.TEXT)
	_ip_edit.add_theme_color_override("font_placeholder_color", UI_STYLE.TEXT_DIM)
	_ip_edit.add_theme_color_override("caret_color", UI_STYLE.AMETHYST_BRIGHT)
	_ip_edit.add_theme_stylebox_override("normal", UI_STYLE.field())
	_ip_edit.add_theme_stylebox_override("focus", UI_STYLE.panel(UI_STYLE.AMETHYST_BRIGHT, true))
	# 在輸入框按 Enter = 按「尋找對手」:鍵盤派不用伸手拿滑鼠。
	_ip_edit.text_submitted.connect(func(_text: String) -> void: _on_find_match_pressed())
	row.add_child(_ip_edit)

	_lobby_col.add_child(_make_spacer(14))

	# 只剩一顆按鈕:ADR-002 之後玩家不再需要決定「當房主還是加入」——
	# 兩邊都是 client,伺服器負責配對與指派先後手。
	_host_btn = _make_menu_option("尋找對手")
	_host_btn.pressed.connect(_on_find_match_pressed)
	_lobby_col.add_child(_host_btn)

	_lobby_col.add_child(_make_spacer(8))

	_lobby_status = Label.new()
	_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_status.custom_minimum_size = Vector2(460, 0)
	_lobby_status.add_theme_font_override("font", FONT_MENU)
	_lobby_status.add_theme_font_size_override("font_size", 16)
	_lobby_status.add_theme_color_override("font_color", UI_STYLE.TEXT_DIM)
	_lobby_col.add_child(_lobby_status)

	_lobby_col.add_child(_make_spacer(20))

	var back_btn := _make_menu_option("返回")
	back_btn.pressed.connect(_close_lobby)
	_lobby_col.add_child(back_btn)


## 牌庫圖鑑:藏選單欄(避免鍵盤焦點漏到選單按鈕)、開全螢幕圖鑑疊層。
## 圖鑑自帶暗幕蓋住城鎮,選單欄藏不藏視覺上看不出,但焦點要收乾淨。
func _open_gallery() -> void:
	_menu_col.visible = false
	_card_gallery.open()


func _on_gallery_closed() -> void:
	_menu_col.visible = true
	_start_button.grab_focus()


func _open_lobby() -> void:
	_menu_col.visible = false
	_lobby_col.visible = true
	_lobby_status.text = "按「尋找對手」連上伺服器排配對,湊到兩人就自動開局。"
	_ip_edit.grab_focus()


func _close_lobby() -> void:
	_net_client.cancel()   # 返回 = 斷線退出佇列,回離線狀態
	_host_btn.disabled = false
	_lobby_col.visible = false
	_menu_col.visible = true
	_start_button.grab_focus()


## 排配對。失敗原因會經 status_changed 顯示;「返回」退出佇列並解鎖按鈕。
func _on_find_match_pressed() -> void:
	if _net_client.connect_to_lobby(_ip_edit.text) == OK:
		_host_btn.disabled = true   # 排隊中就別重複送(伺服器會丟棄重複意圖,但別讓 UI 說謊)


func _on_lobby_status(text: String) -> void:
	_lobby_status.text = text


## 握手完成(雙方共識已寫進 NetMatch / ArenaPool),這裡只負責演出與換場景。
func _on_match_ready() -> void:
	await _enter_game()


## ── 歧路旅人式「文字選單項」────────────────────────────
## 平常是沉金純文字;滑鼠 hover「或」鍵盤焦點時文字亮起、底下浮出金線。
## 同一份樣式同時接 hover 和 focus:滑鼠派和鍵盤派看到的回饋一致。
func _make_menu_option(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.pressed.connect(func() -> void: Sfx.play(Sfx.CLICK, -8.0))
	btn.custom_minimum_size = Vector2(300, 46)
	btn.add_theme_font_override("font", FONT_MENU)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", UI_STYLE.GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", UI_STYLE.GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_color_override("font_disabled_color", Color(UI_STYLE.TEXT_DIM, 0.36))
	btn.add_theme_stylebox_override("normal", UI_STYLE.button(true))
	btn.add_theme_stylebox_override("disabled", UI_STYLE.button(true))
	var lit: StyleBoxFlat = UI_STYLE.button(false)
	btn.add_theme_stylebox_override("hover", lit)
	btn.add_theme_stylebox_override("focus", lit)
	btn.add_theme_stylebox_override("pressed", UI_STYLE.button(false))
	btn.mouse_entered.connect(btn.grab_focus)
	return btn


## ── 純占位的透明空隙 ──
## VBox 的 separation 是均一間距;想「單獨拉開某一段」就塞一個固定高度的空節點。
func _make_spacer(height: float) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, height)
	return sp
