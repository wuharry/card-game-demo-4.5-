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
signal end_turn_pressed
## Debug 離線用:請 CardManager 建立「指定卡+足夠魔力+對位靶」的測試場。
signal debug_test_pressed
## 勝負畫面上的兩個去向(CardManager 接手換場景/重開)。
signal restart_pressed
signal menu_pressed
## 反制窗口(§5.1 守方瞬咒)的回答:true = 發動抵銷。CardManager await 這條。
signal reaction_decided(use_quick: bool)
## 中途離開:按鈕只發出「請求」,是否真的走由確認窗回覆(leave_decided)。
## 拆成兩條的理由:攔截窗要說什麼(連線=認輸/單人=進度不留)只有 CardManager 知道。
signal leave_requested
signal leave_decided(confirmed: bool)
## 選牌面板(§抽濾)的回答:選了第幾張(索引對齊 show_card_picker 傳入的陣列)。
signal card_picked(idx: int)

const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_BODY: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")

## 配色與主選單同一組「暮色金」:整個遊戲的 UI 說同一種話。
const GOLD := Color("f2e3ae")
const GOLD_DIM := Color("b8a984")
const LINE_GOLD := Color(0.83, 0.72, 0.45, 0.85)
const ATTACK_DESC := "普通攻擊:對目標造成等同攻擊力的傷害,並吃下目標的反擊(免費,每回合 1 次)。"

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
var _attack_note: String = ""  # 攻擊被擋的理由("" = 可以攻擊);描述列顯示用
var _skill_note: String = ""   # 技能被擋的理由(同上)

## 戰況 HUD(常駐):右上回合+魔力、右下結束回合、畫面中下的提示訊息。
var _hud_panel: PanelContainer
var _hud_turn: Label
# 魔力列拆四段 Label 排一列(藍◆正常/黃◆暫時/藍◇+數字/黃「+n」):
# 一個 Label 只有一種顏色;不用 RichTextLabel 是它不會用內容撐開最小寬度,
# 而 HUD 面板的寬度正是靠魔力列撐的(見 _build_hud 的置中註解)。
var _hud_mana_row: HBoxContainer
var _hud_mana_norm: Label
var _hud_mana_temp: Label
var _hud_mana_rest: Label
var _hud_mana_bonus: Label
var _hud_opp: Label   # 對方手牌張數(2d;只在連線時顯示)
var _end_turn_btn: Button
var _leave_btn: Button   # 中途離開(左上角;真正的攔截在確認窗)
var _debug_test_btn: Button = null   # Debug 離線才生成;Release/連線不存在
var _toast: Label
var _toast_tween: Tween

## 勝負畫面(第一次用到才組裝)。
var _over_dim: ColorRect = null
var _over_panel: PanelContainer = null
var _over_title: Label = null

## 選牌面板(§抽濾:看頂選一/換牌共用;第一次用到才組裝)。
var _pick_dim: ColorRect = null
var _pick_panel: PanelContainer = null
var _pick_title: Label = null
var _pick_hint: Label = null
var _pick_row: HBoxContainer = null


func _ready() -> void:
	_build_panel()
	_build_hint()
	_build_arrow()
	_build_hud()
	close()


## ── 公開 API(給 CardManager 呼叫)────────────────────────

## 打開指令選單,顯示這張卡的名字、數值、可用指令。
## attack_note / skill_note = 該行動「被擋的理由」;空字串 = 可以做。
## 有理由 → 按鈕灰化、描述列轉述理由(規則在 BattleManager,UI 只負責說人話)。
func open(card: Card, attack_note: String = "", skill_note: String = "") -> void:
	_skill = null
	_attack_note = attack_note
	_skill_note = skill_note
	if card.data != null:
		_skill = card.data.active_skill
		_title.text = card.data.card_name
		# HP 顯示「當前/上限」:掉過血的單位一眼看得出來。
		_stats.text = "ATK %d ／ HP %d／%d" \
			% [card.data.atk, card.current_hp, card.data.hp]
	_attack_btn.disabled = attack_note != ""
	_skill_btn.visible = _skill != null
	if _skill != null:
		# 技能鈕直接標費用(◆)+三分類:學費和「佔不佔攻擊機會」都寫在門口。
		_skill_btn.text = "%s  ◆%d·%s" % [
			_skill.skill_name, _skill.cost, SkillData.KIND_NAMES[_skill.kind]]
		_skill_btn.disabled = skill_note != ""
	_show_attack_desc()
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
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
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
	_attack_btn.mouse_entered.connect(_show_attack_desc)
	_attack_btn.focus_entered.connect(_show_attack_desc)
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


## 描述列:能做就講效果,不能做就講「為什麼不行」(理由來自 BattleManager)。
func _show_attack_desc() -> void:
	_desc.text = ATTACK_DESC if _attack_note == "" else "✕ " + _attack_note


func _show_skill_desc() -> void:
	if _skill == null:
		return
	_desc.text = _skill.description if _skill_note == "" else "✕ " + _skill_note


## 深色半透明+金邊的面板底(指令選單/HUD/結束回合鈕共用同一張皮)。
func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.86)   # 深色半透明底:壓得住亮背景
	sb.border_color = LINE_GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14.0)
	return sb


## ── 戰況 HUD ─────────────────────────────────────────
## 右上:回合數+魔力(◆現有 ◇已用);右下:結束回合;中下:短暫提示。
func _build_hud() -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_hud_panel)
	_hud_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_hud_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # 內容變寬時往左長
	_hud_panel.grow_vertical = Control.GROW_DIRECTION_END

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_hud_panel.add_child(col)

	_hud_turn = Label.new()
	_hud_turn.add_theme_font_override("font", FONT_TITLE)
	_hud_turn.add_theme_font_size_override("font_size", 18)
	_hud_turn.add_theme_color_override("font_color", GOLD)
	# 置中:面板寬度由魔力列(◆…)撐開,回合字不管魔力多長都站中線。
	_hud_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hud_turn)

	# 魔力用冷色:和整片暮色金區隔,一眼找得到資源在哪。
	# 暫時魔力(丟牌回魔 §1.1)用暖黃:回合末就蒸發的錢,顏色先說。
	_hud_mana_row = HBoxContainer.new()
	_hud_mana_row.add_theme_constant_override("separation", 0)
	_hud_mana_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_hud_mana_row)
	_hud_mana_norm = _make_mana_label(Color("7fd9ff"))
	_hud_mana_temp = _make_mana_label(Color("ffd75e"))
	_hud_mana_rest = _make_mana_label(Color("7fd9ff"))
	_hud_mana_bonus = _make_mana_label(Color("ffd75e"))

	# 對方手牌張數(2d):平常隱藏,連線時由 update_opp_count 開燈。
	_hud_opp = Label.new()
	_hud_opp.add_theme_font_override("font", FONT_BODY)
	_hud_opp.add_theme_font_size_override("font_size", 14)
	_hud_opp.add_theme_color_override("font_color", GOLD_DIM)
	_hud_opp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_opp.visible = false
	col.add_child(_hud_opp)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "結束回合"
	_end_turn_btn.add_theme_font_override("font", FONT_TITLE)
	_end_turn_btn.add_theme_font_size_override("font_size", 18)
	_end_turn_btn.add_theme_color_override("font_color", GOLD_DIM)
	_end_turn_btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	_end_turn_btn.add_theme_stylebox_override("normal", _make_panel_style())
	var lit := _make_panel_style()
	lit.border_color = Color("fff3cf")
	_end_turn_btn.add_theme_stylebox_override("hover", lit)
	_end_turn_btn.add_theme_stylebox_override("focus", lit)
	_end_turn_btn.add_theme_stylebox_override("pressed", lit)
	_end_turn_btn.pressed.connect(func() -> void:
		Sfx.play(Sfx.CLICK, -8.0)
		end_turn_pressed.emit())
	add_child(_end_turn_btn)
	_end_turn_btn.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_end_turn_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_end_turn_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# 中途離開:擺左上角,和右側的「結束回合/魔力」隔一整個畫面寬——
	# 誤點的代價是「退出整局」,所以位置先隔開,再由確認窗攔一次(show_leave_confirm)。
	_leave_btn = Button.new()
	_leave_btn.text = "離開對戰"
	_leave_btn.add_theme_font_override("font", FONT_BODY)
	_leave_btn.add_theme_font_size_override("font_size", 15)
	_leave_btn.add_theme_color_override("font_color", GOLD_DIM)
	_leave_btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	_leave_btn.add_theme_stylebox_override("normal", _make_panel_style())
	var leave_lit := _make_panel_style()
	leave_lit.border_color = Color("fff3cf")
	_leave_btn.add_theme_stylebox_override("hover", leave_lit)
	_leave_btn.add_theme_stylebox_override("focus", leave_lit)
	_leave_btn.add_theme_stylebox_override("pressed", leave_lit)
	_leave_btn.pressed.connect(func() -> void:
		Sfx.play(Sfx.CLICK, -8.0)
		leave_requested.emit())
	add_child(_leave_btn)
	_leave_btn.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	# 測卡入口要能用滑鼠點:Godot Editor 可能先吃掉 F8(停止執行),不能只靠快捷鍵。
	if OS.is_debug_build() and not NetMatch.is_online and not NetMatch.is_dedicated_server:
		_debug_test_btn = Button.new()
		_debug_test_btn.text = "準備測試牌  [F8]"
		_debug_test_btn.tooltip_text = "把測試卡放進手牌、補足魔力，並在正對面放置測試靶"
		_debug_test_btn.add_theme_font_override("font", FONT_BODY)
		_debug_test_btn.add_theme_font_size_override("font_size", 14)
		_debug_test_btn.add_theme_color_override("font_color", Color("8edfff"))
		_debug_test_btn.add_theme_color_override("font_hover_color", Color("d9f7ff"))
		_debug_test_btn.add_theme_stylebox_override("normal", _make_panel_style())
		var debug_lit := _make_panel_style()
		debug_lit.border_color = Color("8edfff")
		_debug_test_btn.add_theme_stylebox_override("hover", debug_lit)
		_debug_test_btn.add_theme_stylebox_override("focus", debug_lit)
		_debug_test_btn.add_theme_stylebox_override("pressed", debug_lit)
		_debug_test_btn.pressed.connect(func() -> void:
			Sfx.play(Sfx.CLICK, -8.0)
			debug_test_pressed.emit())
		add_child(_debug_test_btn)
		_debug_test_btn.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)
		_debug_test_btn.position.y += 58.0

	_toast = Label.new()
	_toast.add_theme_font_override("font", FONT_TITLE)
	# 提示是「行動被擋下」的當下回饋,要一眼看到:大字、亮色、厚黑邊。
	_toast.add_theme_font_size_override("font_size", 32)
	_toast.add_theme_color_override("font_color", Color("ffe08a"))
	_toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_toast.add_theme_constant_override("outline_size", 10)
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.visible = false


## 魔力列的一段:字型/字級一致,只有顏色不同。
func _make_mana_label(color: Color) -> Label:
	var lb := Label.new()
	lb.add_theme_font_override("font", FONT_BODY)
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", color)
	_hud_mana_row.add_child(lb)
	return lb


## HUD 刷新(BattleManager.state_changed 接進來):回合+行動方+該方魔力。
func update_hud(turn: int, side: String, mana: int, mana_max: int, temp_mana: int) -> void:
	# 「我方」以本機視角判定(2b):my_side 離線恆為 "player",熱座語意不變;
	# 連線時 client 的我方是 "enemy" 側——別寫死字串。
	var side_name := "我方回合" if side == NetMatch.my_side else "對方回合"
	_hud_turn.text = "第 %d 回合 ‧ %s" % [turn, side_name]
	# 行動方用顏色再講一次:金=我方、緋=對方(熱座換邊要一眼可辨)。
	_hud_turn.add_theme_color_override(
		"font_color", GOLD if side == NetMatch.my_side else Color(0.92, 0.55, 0.5))
	# ◆=現有、◇=已用掉的上限:不讀數字也能一眼讀量。
	# 黃◆=暫時魔力,疊在最右(付費從右邊扣,見 battle_manager._pay);
	# 回收可能把 mana 推超過上限(5/5 再棄牌),◇ 用 maxi 兜住別變負。
	var temp := clampi(temp_mana, 0, maxi(mana, 0))
	_hud_mana_norm.text = "◆".repeat(maxi(mana - temp, 0))
	_hud_mana_temp.text = "◆".repeat(temp)
	_hud_mana_rest.text = "◇".repeat(maxi(mana_max - mana, 0)) + "  %d／%d" % [mana, mana_max]
	_hud_mana_bonus.text = "(+%d)" % temp
	_hud_mana_bonus.visible = temp > 0
	# 內容變了 → 重新量身、貼回右上角(量尺寸要在內容就位之後,同 open() 的課)。
	_hud_panel.reset_size()
	_hud_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)


## 短暫提示(魔力不足/回合切換…):畫面中下方停 1 秒後淡出。
func flash_message(text_value: String) -> void:
	_toast.text = text_value
	_toast.visible = true
	_toast.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_toast.reset_size()
	_toast.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


## ── 勝負畫面 ─────────────────────────────────────────
## 壓暗全場 + 置中面板:勝利金字/敗北紅字,兩個去向(再戰/回主選單)。
func show_game_over(victory: bool) -> void:
	Sfx.play(Sfx.VICTORY if victory else Sfx.DEFEAT)
	close()
	# 勝負已分 → 收掉中途離開的入口:去向改由勝負畫面的兩顆按鈕提供。
	# 這裡只做「視覺收窗」而不呼叫 dismiss_leave_confirm()——後者會 emit
	# leave_decided(false),把 CardManager 剛鎖上的 GAME_OVER 互動鎖解開。
	_leave_btn.visible = false
	if _debug_test_btn != null:
		_debug_test_btn.visible = false
	if _leave_dim != null:
		_leave_dim.visible = false
		_leave_panel.visible = false
	if _over_dim == null:
		_build_game_over()
	_over_title.text = "勝 利" if victory else "敗 北"
	_over_title.add_theme_color_override(
		"font_color", GOLD if victory else Color(0.85, 0.35, 0.3))
	_over_dim.visible = true
	_over_panel.visible = true
	# 標題字換過了 → 重新量身、貼回正中(量尺寸要在內容就位之後)。
	_over_panel.reset_size()
	_over_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _build_game_over() -> void:
	_over_dim = ColorRect.new()
	_over_dim.color = Color(0.0, 0.0, 0.0, 0.55)   # 壓暗戰場,視線收到面板上
	add_child(_over_dim)
	_over_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_over_panel = PanelContainer.new()
	_over_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_over_panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.add_theme_constant_override("separation", 10)
	_over_panel.add_child(col)

	_over_title = Label.new()
	_over_title.add_theme_font_override("font", FONT_TITLE)
	_over_title.add_theme_font_size_override("font_size", 44)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_over_title)

	col.add_child(_make_gold_line())

	var again := _make_option("再戰一場")
	again.pressed.connect(func() -> void: restart_pressed.emit())
	col.add_child(again)
	var menu := _make_option("回到主選單")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	col.add_child(menu)


## 歧路旅人式「文字指令」:平常沉金純文字,hover / 鍵盤焦點時亮起+金底線
## (樣式與 main_menu 的選項一致,見該檔的說明)。
func _make_option(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	# 點擊聲掛在「建構器」:指令選單/反制窗口/勝負畫面的選項一次全接上。
	btn.pressed.connect(func() -> void: Sfx.play(Sfx.CLICK, -8.0))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", Color("fff3cf"))
	btn.add_theme_color_override("font_focus_color", Color("fff3cf"))
	btn.add_theme_color_override("font_pressed_color", GOLD)
	# 灰化態:理由由描述列轉述,按鈕本身只要「看得出不能按」。
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.42, 0.5))
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
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


## ── 反制窗口(§5.1 守方瞬咒;熱座:把螢幕轉給守方回答)─────────
## 面板蓋全場壓暗,兩個選項:發動 / 放棄。答案用 reaction_decided 信號送回,
## CardManager 以 await 等待——遊戲流程在這裡「暫停」到守方做出決定。
var _react_dim: ColorRect = null
var _react_panel: PanelContainer = null
var _react_title: Label = null
var _react_body: Label = null


func show_reaction(title_text: String, body_text: String) -> void:
	if _react_dim == null:
		_build_reaction()
	_react_title.text = title_text
	_react_body.text = body_text
	_react_dim.visible = true
	_react_panel.visible = true
	_react_panel.reset_size()
	_react_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _build_reaction() -> void:
	_react_dim = ColorRect.new()
	_react_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(_react_dim)
	_react_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_react_panel = PanelContainer.new()
	_react_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_react_panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 10)
	_react_panel.add_child(col)

	_react_title = Label.new()
	_react_title.add_theme_font_override("font", FONT_TITLE)
	_react_title.add_theme_font_size_override("font_size", 26)
	_react_title.add_theme_color_override("font_color", GOLD)
	_react_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_react_title)
	col.add_child(_make_gold_line())

	_react_body = Label.new()
	_react_body.add_theme_font_override("font", FONT_BODY)
	_react_body.add_theme_font_size_override("font_size", 17)
	_react_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 同 _leave_body 那顆地雷(2026-08-06 修):這裡的文字短才一直沒炸,
	# 但卡名一長(「對方施放【XXXXX】→ 發動【YYYYY】抵銷?」)就會踩到。
	_react_body.custom_minimum_size = Vector2(360, 0)
	_react_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_react_body)

	var use_btn := _make_option("發動抵銷")
	use_btn.pressed.connect(func() -> void: _answer_reaction(true))
	col.add_child(use_btn)
	var pass_btn := _make_option("放棄反制")
	pass_btn.pressed.connect(func() -> void: _answer_reaction(false))
	col.add_child(pass_btn)


func _answer_reaction(use_quick: bool) -> void:
	_react_dim.visible = false
	_react_panel.visible = false
	reaction_decided.emit(use_quick)


## ── 中途離開的確認窗 ─────────────────────────────────
## 和反制窗口同一套語彙(壓暗全場+置中面板),但選項順序刻意相反:
## 安全選項(繼續遊戲)在上、破壞性選項(離開)在下並染成緋色——
## 誤點第一顆的代價要是「什麼都沒發生」,不是「整局沒了」。
var _leave_dim: ColorRect = null
var _leave_panel: PanelContainer = null
var _leave_body: Label = null


## warning_text 由 CardManager 依連線/單人/熱座組好傳進來:
## UI 不判斷模式,只負責把後果說清楚(同 open() 的 note 參數,規則在別處、UI 轉述)。
func show_leave_confirm(warning_text: String) -> void:
	if _leave_dim == null:
		_build_leave_confirm()
	_leave_body.text = warning_text
	_leave_dim.visible = true
	_leave_panel.visible = true
	_leave_panel.reset_size()
	_leave_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## 外部收窗(ESC / 右鍵反悔):走和按「繼續遊戲」同一條路,
## 免得面板收了、CardManager 那邊的鎖沒解(狀態分家)。
func dismiss_leave_confirm() -> void:
	if _leave_dim != null and _leave_dim.visible:
		_answer_leave(false)


func _build_leave_confirm() -> void:
	_leave_dim = ColorRect.new()
	_leave_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	add_child(_leave_dim)
	_leave_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_leave_panel = PanelContainer.new()
	_leave_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_leave_panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(400, 0)
	col.add_theme_constant_override("separation", 10)
	_leave_panel.add_child(col)

	var title := Label.new()
	title.text = "離開對戰?"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(_make_gold_line())

	_leave_body = Label.new()
	_leave_body.add_theme_font_override("font", FONT_BODY)
	_leave_body.add_theme_font_size_override("font_size", 17)
	_leave_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 自動換行的 Label 一定要自己知道寬度上限:少了這行,reset_size() 會在 layout
	# 之前問它最小尺寸,而它只能按「每個字一行」回報(45 個中文字 → 高 1700+),
	# 這個錯值會被 PRESET_MODE_MINSIZE 烤進面板 offsets,之後換行算對了也回不來。
	# 父容器的 custom_minimum_size 救不了——那是父的下限,不是子的上限。
	_leave_body.custom_minimum_size = Vector2(400, 0)
	_leave_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_leave_body)

	var stay := _make_option("繼續遊戲")
	stay.pressed.connect(func() -> void: _answer_leave(false))
	col.add_child(stay)
	var quit := _make_option("確定離開,回到主選單")
	# 緋色 = 這一顆會毀掉這局(和敗北標題同一個色系,玩家早就學過這個顏色)。
	quit.add_theme_color_override("font_color", Color(0.8, 0.42, 0.36))
	quit.add_theme_color_override("font_hover_color", Color(0.97, 0.56, 0.46))
	quit.add_theme_color_override("font_focus_color", Color(0.97, 0.56, 0.46))
	quit.pressed.connect(func() -> void: _answer_leave(true))
	col.add_child(quit)


func _answer_leave(confirmed: bool) -> void:
	_leave_dim.visible = false
	_leave_panel.visible = false
	leave_decided.emit(confirmed)


## ── hover 卡片放大預覽(畫面右側的資訊卡)──────────────────────
## 卡面空間小、描述超過 5 行會截斷(card.gd 的 _fit_card_text);
## hover 任何卡(手牌或桌上單位)時,右側顯示完整資訊:
## 卡圖/名稱/費用/卡型/攻血(桌上單位含當前血與靈裝加成)/關鍵字/技能全文。
## 純顯示、mouse_filter 全設 IGNORE——面板絕不攔截滑鼠,不干擾拖曳與點擊。
var _prev_panel: PanelContainer = null
var _prev_art: TextureRect = null
var _prev_name: Label = null
var _prev_type: Label = null
var _prev_stats: Label = null
var _prev_body: Label = null
var _prev_source: Card = null   # 來源卡:被釋放(換手牌/陣亡)時面板要自動收起

const TYPE_NAMES := {
	CardData.CardType.MINION: "從者",
	CardData.CardType.EQUIP: "靈裝",
	CardData.CardType.ARCANA: "秘術",
	CardData.CardType.QUICK: "瞬咒",
	CardData.CardType.WARD: "伏印",
	CardData.CardType.DOMAIN: "領域",
}


func show_card_preview(card: Card) -> void:
	if card == null or card.data == null:
		return
	if _prev_panel == null:
		_build_preview()
	_prev_source = card
	var d := card.data
	_prev_name.text = "%s  ◆%d" % [d.card_name, d.cost]
	_prev_type.text = TYPE_NAMES.get(d.card_type, "?")
	if d.card_type == CardData.CardType.MINION:
		# 桌上單位印當前血/上限(含靈裝加成);手牌印模板值(setup 時 current_hp = hp)。
		var lines: PackedStringArray = ["攻 %d    血 %d/%d" % [
			d.atk, card.current_hp, d.hp + card.max_hp_bonus]]
		if not d.keywords.is_empty():
			var words: PackedStringArray = []
			for w in d.keywords:
				words.append(String(w))
			lines.append("關鍵字:" + "、".join(words))
		_prev_stats.text = "\n".join(lines)
		_prev_stats.visible = true
	else:
		_prev_stats.visible = false
	var body: PackedStringArray = []
	if d.active_skill != null:
		var s := d.active_skill
		if d.card_type == CardData.CardType.MINION:
			# 三分類跟著標(強化=用掉攻擊機會/獨立=額外一刀/非攻擊=登場回合也能用)。
			body.append("【%s】◆%d·%s\n%s" % [
				s.skill_name, s.cost, SkillData.KIND_NAMES[s.kind], s.description])
		else:
			body.append(s.description)
	# 戰吼不收費、也不佔行動經濟(登場自動跑),所以不標 ◆ 與三分類。
	if d.battlecry != null:
		body.append("【戰吼】%s" % d.battlecry.description)
	_prev_body.text = "\n".join(body)
	_prev_body.visible = not body.is_empty()
	# 有專用卡圖時優先使用;舊從者才裁立牌第 0 幀,法術則直接顯示圖示。
	if d.use_dedicated_art and d.art != null:
		_prev_art.texture = d.art
		_prev_art.visible = true
	elif d.standee != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = d.standee
		atlas.region = Card.visible_bounds_of_frame0(d.standee)
		_prev_art.texture = atlas
		_prev_art.visible = true
	elif d.art != null:
		_prev_art.texture = d.art
		_prev_art.visible = true
	else:
		_prev_art.visible = false
	_prev_panel.visible = true
	_prev_panel.reset_size()
	_prev_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 24)


func hide_card_preview() -> void:
	_prev_source = null
	if _prev_panel != null:
		_prev_panel.visible = false


func _build_preview() -> void:
	_prev_panel = PanelContainer.new()
	_prev_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_prev_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prev_panel)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prev_panel.add_child(col)

	_prev_art = TextureRect.new()
	_prev_art.custom_minimum_size = Vector2(0, 110)
	_prev_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prev_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prev_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素圖放大要銳利
	_prev_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_prev_art)

	_prev_name = Label.new()
	_prev_name.add_theme_font_override("font", FONT_TITLE)
	_prev_name.add_theme_font_size_override("font_size", 22)
	_prev_name.add_theme_color_override("font_color", GOLD)
	_prev_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prev_name)

	_prev_type = Label.new()
	_prev_type.add_theme_font_override("font", FONT_BODY)
	_prev_type.add_theme_font_size_override("font_size", 14)
	_prev_type.add_theme_color_override("font_color", GOLD_DIM)
	_prev_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prev_type)
	col.add_child(_make_gold_line())

	_prev_stats = Label.new()
	_prev_stats.add_theme_font_override("font", FONT_BODY)
	_prev_stats.add_theme_font_size_override("font_size", 16)
	_prev_stats.add_theme_color_override("font_color", Color("e8ddc4"))
	_prev_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prev_stats)

	_prev_body = Label.new()
	_prev_body.add_theme_font_override("font", FONT_BODY)
	_prev_body.add_theme_font_size_override("font_size", 15)
	_prev_body.add_theme_color_override("font_color", Color("cfc4a6"))
	_prev_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prev_body.custom_minimum_size = Vector2(250, 0)
	col.add_child(_prev_body)


func _process(_delta: float) -> void:
	# 防呆:hover 中的卡被釋放(換邊重建手牌、單位陣亡)不會發 unhover 信號,
	# 面板會永遠卡在畫面上——來源卡死了就自動收起。
	if _prev_panel != null and _prev_panel.visible and not is_instance_valid(_prev_source):
		hide_card_preview()


## 對方手牌張數(2d;連線時 CardManager 每次帳變動就刷新)。
func update_opp_count(count: int) -> void:
	if _hud_opp == null:
		return
	_hud_opp.visible = true
	_hud_opp.text = "對方手牌:%d 張" % count
	_hud_panel.reset_size()


## ── 選牌面板(§抽濾:看頂選一/換牌共用)──────────────────
## 沒有取消鈕:費用在宣告時已付,選擇是義務(同爐石「發現」,防免費偷看)。
## 開著時 CardManager 用 _picking 旗標擋掉取消/結束回合。
func show_card_picker(title_text: String, hint_text: String,
		cards: Array[CardData]) -> void:
	if _pick_panel == null:
		_build_picker()
	_pick_title.text = title_text
	_pick_hint.text = hint_text
	for child in _pick_row.get_children():
		_pick_row.remove_child(child)   # 先摘再 free:queue_free 的殘影會撐壞本幀排版
		child.queue_free()
	for i in range(cards.size()):
		_pick_row.add_child(_make_pick_tile(cards[i], i))
	_pick_dim.visible = true
	_pick_panel.visible = true
	Sfx.play(Sfx.CARD_FAN, -4.0)
	_pick_panel.reset_size()
	_pick_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _build_picker() -> void:
	_pick_dim = ColorRect.new()
	_pick_dim.color = Color(0.0, 0.0, 0.0, 0.62)
	add_child(_pick_dim)
	_pick_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_pick_panel = PanelContainer.new()
	_pick_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_pick_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_pick_panel.add_child(col)

	_pick_title = Label.new()
	_pick_title.add_theme_font_override("font", FONT_TITLE)
	_pick_title.add_theme_font_size_override("font_size", 26)
	_pick_title.add_theme_color_override("font_color", GOLD)
	_pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pick_title)
	col.add_child(_make_gold_line())

	_pick_hint = Label.new()
	_pick_hint.add_theme_font_override("font", FONT_BODY)
	_pick_hint.add_theme_font_size_override("font_size", 16)
	_pick_hint.add_theme_color_override("font_color", GOLD_DIM)
	_pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pick_hint)

	_pick_row = HBoxContainer.new()
	_pick_row.add_theme_constant_override("separation", 14)
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_pick_row)


## 一張可點選的卡面磚:圖+名+費+一句話。整塊都是按鈕(hover 微亮)。
func _make_pick_tile(d: CardData, idx: int) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _make_panel_style())
	tile.custom_minimum_size = Vector2(190, 0)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	tile.add_child(col)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 96)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素圖放大要銳利
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = _cardface_art(d)
	col.add_child(art)

	var name_l := Label.new()
	name_l.add_theme_font_override("font", FONT_TITLE)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", GOLD)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text = "%s ◆%d" % [d.card_name, d.cost]
	col.add_child(name_l)

	var info := Label.new()
	info.add_theme_font_override("font", FONT_BODY)
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", GOLD_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(170, 0)
	if d.card_type == CardData.CardType.MINION:
		info.text = "從者  攻 %d / 血 %d" % [d.atk, d.hp]
	elif d.active_skill != null:
		info.text = d.active_skill.description
	else:
		info.text = TYPE_NAMES.get(d.card_type, "")
	col.add_child(info)

	tile.mouse_entered.connect(func() -> void: tile.modulate = Color(1.25, 1.2, 1.0))
	tile.mouse_exited.connect(func() -> void: tile.modulate = Color.WHITE)
	tile.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton \
				and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_answer_pick(idx))
	return tile


## 卡面圖:專用插畫優先;舊從者=立牌第 0 幀;法術=圖示(和 hover 預覽同一把尺)。
func _cardface_art(d: CardData) -> Texture2D:
	if d.use_dedicated_art and d.art != null:
		return d.art
	if d.standee != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = d.standee
		atlas.region = Card.visible_bounds_of_frame0(d.standee)
		return atlas
	return d.art


func _answer_pick(idx: int) -> void:
	_pick_dim.visible = false
	_pick_panel.visible = false
	Sfx.play(Sfx.CLICK, -6.0)
	card_picked.emit(idx)
	_hud_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
