## 卡牌與召喚物共用的唯讀詳情；連結只查 CardData，不生成場上 Card。
extends PanelContainer
class_name CardDetailPanel

signal reference_hovered(data: CardData)
signal reference_left

const SETTINGS = preload("res://src/settings/app_settings.gd")
const STYLE = preload("res://src/ui/fantasy_ui_theme.gd")
const FONT = preload("res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")
const SPECIAL_SUMMONS := {
	&"ward_decoy": "tokens/decoy_puppet_token",
	&"arcana_dead_army_gate": "tokens/tomb_guard_token",
	&"ward_royal_tomb": "tokens/royal_tomb_guard_token",
}

var interactive := true
var source: Card
var data: CardData
var body: RichTextLabel
var _art: TextureRect
var _title: Label
var _type: Label
var _stats: Label
var _scroll: ScrollContainer
var _column: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", STYLE.panel(STYLE.GOLD, false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var col := VBoxContainer.new()
	_column = col
	col.custom_minimum_size.x = 250
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(col)
	_art = TextureRect.new()
	_art.custom_minimum_size.y = 110
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_art)
	_title = _label(col, 22, STYLE.GOLD)
	_type = _label(col, 14, STYLE.GOLD_DIM)
	_stats = _label(col, 16, Color("e8ddc4"))
	body = description_label(250, 15)
	col.add_child(body)
	body.meta_hover_started.connect(_on_reference)
	body.meta_hover_ended.connect(func(_meta: Variant) -> void: reference_left.emit())
	hide()


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 250
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func description_label(width: float, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = width
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color("cfc4a6"))
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


static func escaped(text: String) -> String:
	return text.replace("[", "[lb]")


static func summoned_data(owner: CardData, skill: SkillData) -> CardData:
	if skill == null:
		return null
	var slug := skill.summon_card
	if slug.is_empty() and owner != null and owner.active_skill == skill:
		slug = SPECIAL_SUMMONS.get(owner.special_id, "")
	if slug.is_empty():
		return null
	var path := "res://data/cards/%s.tres" % slug
	return load(path) as CardData if ResourceLoader.exists(path) else null


static func skill_text(owner: CardData, skill: SkillData, links: bool = true) -> String:
	var text := escaped(SETTINGS.current().skill_description(skill))
	var summoned := summoned_data(owner, skill) if links else null
	if summoned == null:
		return text
	var name: String = SETTINGS.current().card_name(summoned)
	var link := "[url=%s][color=#9cd9ee][u]%s[/u][/color][/url]" % [
		summoned.resource_path, escaped(name)]
	if text.contains(name):
		return text.replace(name, link)
	# 既有卡文可能使用別稱；連結仍指向真正召喚的資料。
	if SETTINGS.current().language != "en":
		for alias: String in ["秘偶", "爪牙"]:
			if text.contains(alias):
				return text.replace(alias, link)
	# 未寫明名稱的描述也能查看實際召喚物（包含英文特殊效果文案）。
	return text + "\n" + ("Summons: " if SETTINGS.current().language == "en" else "召喚物：") + link


func show_card(card_data: CardData, live_card: Card = null, status_text: String = "") -> void:
	data = card_data
	source = live_card
	var app := SETTINGS.current()
	_title.text = "%s  ◆%d" % [app.card_name(data), data.cost]
	_type.text = app.type_name(data.card_type)
	_stats.visible = data.card_type == CardData.CardType.MINION
	var atk := live_card.atk_total() if is_instance_valid(live_card) else data.atk
	var hp := live_card.current_hp if is_instance_valid(live_card) else data.hp
	var max_hp := data.hp + live_card.max_hp_bonus if is_instance_valid(live_card) else data.hp
	_stats.text = app.text("battle_stats") % [atk, hp, max_hp]
	if not data.keywords.is_empty():
		var words: PackedStringArray = []
		for keyword in data.keywords:
			words.append(app.keyword_name(keyword))
		_stats.text += "\n" + app.text("keywords") + ": " + ", ".join(words)
	if not status_text.is_empty():
		_stats.text += "\n" + status_text
	var lines: PackedStringArray = []
	if data.active_skill != null:
		var skill := data.active_skill
		var heading := ""
		if data.card_type == CardData.CardType.MINION:
			heading = escaped("【%s】◆%d·%s\n" % [app.skill_name(data, skill),
				skill.cost, app.kind_name(skill.kind)])
		lines.append(heading + skill_text(data, skill, interactive))
	if data.battlecry != null:
		lines.append(escaped("【%s】" % app.text("battlecry"))
			+ skill_text(data, data.battlecry, interactive))
	body.text = "\n".join(lines)
	body.visible = not lines.is_empty()
	_art.texture = Card.face_art(data)
	_art.visible = _art.texture != null
	show()
	_scroll.scroll_vertical = 0
	reset_size()
	fit_to_viewport.call_deferred()


func fit_to_viewport() -> void:
	var style := get_theme_stylebox("panel")
	var padding := style.get_minimum_size()
	var max_height := get_viewport_rect().size.y - 16 - padding.y
	var desired := Vector2(266, minf(_column.get_combined_minimum_size().y, max_height))
	if _scroll.custom_minimum_size != desired:
		_scroll.custom_minimum_size = desired
		reset_size()


func _on_reference(meta: Variant) -> void:
	if not interactive:
		return
	# 只接受目前卡片效果真正引用的召喚物，不把文字連結當任意資源路徑。
	for skill in [data.active_skill, data.battlecry]:
		var target := summoned_data(data, skill)
		if target != null and target.resource_path == str(meta):
			reference_hovered.emit(target)
			return
