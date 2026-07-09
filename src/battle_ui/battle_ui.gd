## battle_ui.gd — 指令選單:點擊上桌單位後的「攻擊 / 技能 / 取消」面板
##
## 歧路旅人式:畫面左下的直式指令清單 + 面板底部的效果描述列;
## 指定目標時面板收起、畫面下緣改出提示字。
## 全程式生成(與 main_menu 同哲學,場景檔零改動):
## 由 CardManager 在 _ready 時 new 出來掛在自己底下,並訂閱三個信號。
extends CanvasLayer
class_name BattleUI

## 玩家在選單裡做了決定 → 廣播給 CardManager(它才是狀態機,UI 只負責問)。
signal attack_chosen
signal skill_chosen(skill: SkillData)
signal cancelled

const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_BODY: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")

## 配色與主選單同一組「暮色金」:整個遊戲的 UI 說同一種話。
const GOLD := Color("f2e3ae")
const GOLD_DIM := Color("b8a984")
const LINE_GOLD := Color(0.83, 0.72, 0.45, 0.85)
const ATTACK_DESC := "普通攻擊:對一名敵方單位造成等同攻擊力的傷害(免費,每回合一次)。"

var _panel: PanelContainer
var _title: Label
var _stats: Label
var _attack_btn: Button
var _skill_btn: Button
var _desc: Label
var _hint: Label
var _arrow_line: Line2D      # 指定目標導引箭頭(爐石式弧線)的線身
var _arrow_head: Polygon2D   # 箭頭尖端的三角
var _skill: SkillData = null   # 目前選單主角的主動技(null = 這隻沒有)


func _ready() -> void:
	_build_panel()
	_build_hint()
	_build_arrow()
	close()


## ── 公開 API(給 CardManager 呼叫)────────────────────────

## 打開指令選單,顯示這張卡的名字、數值、可用指令。
func open(card: Card) -> void:
	_skill = null
	if card.data != null:
		_skill = card.data.active_skill
		_title.text = card.data.card_name
		_stats.text = "ATK %d ／ HP %d" % [card.data.atk, card.data.hp]
	_skill_btn.visible = _skill != null
	if _skill != null:
		# 技能鈕直接標費用(◆),學費寫在門口,不用點進去才發現付不起。
		_skill_btn.text = "%s  ◆%d" % [_skill.skill_name, _skill.cost]
	_desc.text = ATTACK_DESC
	_hint.visible = false
	_panel.visible = true
	# 每次打開都重新量身、重貼左下角:建面板時內容是空的,當時量到的
	# 最小尺寸≈0;若只定位那一次,內容進來後面板會往螢幕外(下方)長,
	# 畫面只剩標題列。原則同主選單那課:量尺寸要在內容就位「之後」。
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_attack_btn.grab_focus()   # 鍵盤黨:開選單直接上下鍵+Enter


## 進入指定目標模式:收起面板、亮出提示字。
func show_targeting(hint_text: String) -> void:
	_panel.visible = false
	_hint.text = hint_text
	_hint.visible = true


## 指定目標中,由 CardManager 每幀餵座標:from=施放者、to=游標(或鎖定的目標)。
## locked = 游標正懸停在合法目標上 → 整條變亮,回饋「可以按了」。
func update_arrow(from_px: Vector2, to_px: Vector2, locked: bool) -> void:
	var color := Color("fff3cf") if locked else GOLD_DIM
	_arrow_line.default_color = color
	_arrow_head.color = color
	# 二次貝茲弧線:控制點取中點再往上抬(抬升量跟距離走,近了就別拱太高),
	# 箭頭像被「拋」向目標,比直線更容易看出從誰指向誰。
	var lift := clampf(from_px.distance_to(to_px) * 0.25, 40.0, 160.0)
	var ctrl := (from_px + to_px) * 0.5 - Vector2(0.0, lift)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(from_px.lerp(ctrl, t).lerp(ctrl.lerp(to_px, t), t))
	_arrow_line.points = pts
	_arrow_head.position = to_px
	# 尖端在多邊形原點、身體往 +Y 展開 → 朝行進方向要再轉 +90°。
	var dir := (to_px - pts[pts.size() - 2]).normalized()
	_arrow_head.rotation = dir.angle() + PI / 2.0
	_arrow_line.visible = true
	_arrow_head.visible = true


## 全部收起來(取消或發動完畢)。
func close() -> void:
	_panel.visible = false
	_hint.visible = false
	_hide_arrow()
	_skill = null


## ── 版面組裝 ─────────────────────────────────────────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.86)   # 深色半透明底:壓得住亮背景
	sb.border_color = LINE_GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	# 面板貼左下角、離邊 24px;PanelContainer 會自己縮到內容大小。
	_panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	# 內容若比定位時再變大,往「上」長而不是往下掉出螢幕(底邊釘住)。
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)

	_title = Label.new()
	_title.add_theme_font_override("font", FONT_TITLE)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", GOLD)
	col.add_child(_title)

	_stats = Label.new()
	_stats.add_theme_font_override("font", FONT_BODY)
	_stats.add_theme_font_size_override("font_size", 14)
	_stats.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	col.add_child(_stats)

	col.add_child(_make_gold_line())

	_attack_btn = _make_option("攻擊")
	_attack_btn.pressed.connect(func() -> void: attack_chosen.emit())
	_attack_btn.mouse_entered.connect(func() -> void: _desc.text = ATTACK_DESC)
	_attack_btn.focus_entered.connect(func() -> void: _desc.text = ATTACK_DESC)
	col.add_child(_attack_btn)

	_skill_btn = _make_option("技能")
	_skill_btn.pressed.connect(func() -> void:
		if _skill != null:
			skill_chosen.emit(_skill))
	_skill_btn.mouse_entered.connect(_show_skill_desc)
	_skill_btn.focus_entered.connect(_show_skill_desc)
	col.add_child(_skill_btn)

	var cancel_btn := _make_option("取消")
	cancel_btn.pressed.connect(func() -> void: cancelled.emit())
	cancel_btn.mouse_entered.connect(func() -> void: _desc.text = "收回指令。")
	cancel_btn.focus_entered.connect(func() -> void: _desc.text = "收回指令。")
	col.add_child(cancel_btn)

	col.add_child(_make_gold_line())

	# 描述列:游標懸停/焦點停在哪個指令,就講那個指令的效果(歧路旅人的做法)。
	_desc = Label.new()
	_desc.add_theme_font_override("font", FONT_BODY)
	_desc.add_theme_font_size_override("font_size", 14)
	_desc.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(340, 44)
	col.add_child(_desc)


## 指定目標的提示字:畫面下緣置中,金字黑邊(壓在 3D 場景上要讀得清)。
func _build_hint() -> void:
	_hint = Label.new()
	_hint.add_theme_font_override("font", FONT_BODY)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 48)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH   # 文字變長仍保持置中


## 導引箭頭的兩個零件。CanvasLayer 可以收任何 CanvasItem,Node2D 也行——
## 用現成的 Line2D / Polygon2D 拼,不用自己寫 _draw。
func _build_arrow() -> void:
	_arrow_line = Line2D.new()
	_arrow_line.width = 5.0
	_arrow_line.default_color = GOLD_DIM
	_arrow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_arrow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_arrow_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_arrow_line.antialiased = true
	add_child(_arrow_line)
	_arrow_head = Polygon2D.new()
	# 尖端放在原點(0,0)、燕尾往 +Y 展開;rotation 由 update_arrow 對準行進方向。
	_arrow_head.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-11, 26), Vector2(0, 18), Vector2(11, 26)])
	_arrow_head.color = GOLD_DIM
	_arrow_head.antialiased = true
	add_child(_arrow_head)
	_hide_arrow()


func _hide_arrow() -> void:
	_arrow_line.visible = false
	_arrow_head.visible = false


func _show_skill_desc() -> void:
	if _skill != null:
		_desc.text = _skill.description


## 歧路旅人式「文字指令」:平常沉金純文字,hover / 鍵盤焦點時亮起+金底線
## (樣式與 main_menu 的選項一致,見該檔的說明)。
func _make_option(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	btn.add_theme_color_override("font_focus_color", Color("fff3cf"))
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	lit.border_color = LINE_GOLD
	lit.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", lit)
	btn.add_theme_stylebox_override("focus", lit)
	btn.add_theme_stylebox_override("pressed", lit)
	# 游標懸停即奪走焦點:滑鼠與鍵盤共用同一個「亮起」狀態,
	# 金底線永遠只有一條、跟著游標走(歧路旅人的選單手感)。
	btn.mouse_entered.connect(btn.grab_focus)
	return btn


## 細金分隔線(同主選單的印刷品語彙)。
func _make_gold_line() -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE_GOLD
	line.custom_minimum_size = Vector2(0, 1)
	return line
