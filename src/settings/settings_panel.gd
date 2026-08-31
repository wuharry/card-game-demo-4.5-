## settings_panel.gd — 主選單的全螢幕設定疊層。
extends CanvasLayer

const SETTINGS: GDScript = preload("res://src/settings/app_settings.gd")

signal closed
signal settings_saved

const FONT_TITLE: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const FONT_BODY: FontFile = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")
const UI_STYLE: GDScript = preload("res://src/ui/fantasy_ui_theme.gd")

const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const UI_SCALES := [1.0, 1.25, 1.5]

var _mode: OptionButton
var _resolution: OptionButton
var _quality: OptionButton
var _language: OptionButton
var _ui_scale: OptionButton
var _contrast: CheckButton
var _motion: CheckButton
var _title: Label
var _display_header: Label
var _access_header: Label
var _labels: Dictionary = {}
var _hint: Label
var _apply: Button
var _cancel: Button
var _defaults: Button
var _available_resolutions: Array[Vector2i] = []


func _ready() -> void:
	layer = 20
	_build()
	hide()


func open() -> void:
	_load_current()
	_refresh_language()
	show()
	_mode.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.014, 0.04, 0.96)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_vertical_custom_step = 48
	scroll.follow_focus = true
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", UI_STYLE.panel(UI_STYLE.GOLD, true))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	_title = Label.new()
	_style_label(_title, 38, UI_STYLE.GOLD, true)
	col.add_child(_title)
	col.add_child(_separator())

	_display_header = Label.new()
	_style_label(_display_header, 16, UI_STYLE.AMETHYST_BRIGHT, false)
	col.add_child(_display_header)

	_mode = _option()
	_mode.add_item("")
	_mode.add_item("")
	_add_row(col, "settings_mode", _mode)
	_mode.item_selected.connect(func(_idx: int) -> void: _sync_resolution_enabled())
	_resolution = _option()
	_add_row(col, "settings_resolution", _resolution)
	_quality = _option()
	for i in 3:
		_quality.add_item("")
	_add_row(col, "settings_quality", _quality)
	_language = _option()
	_language.add_item("")
	_language.add_item("")
	_add_row(col, "settings_language", _language)
	_language.item_selected.connect(func(_idx: int) -> void: _refresh_language())

	col.add_child(_separator())
	_access_header = Label.new()
	_style_label(_access_header, 16, UI_STYLE.AMETHYST_BRIGHT, false)
	col.add_child(_access_header)

	_ui_scale = _option()
	for scale in UI_SCALES:
		_ui_scale.add_item("%d%%" % roundi(scale * 100.0))
	_add_row(col, "settings_ui_scale", _ui_scale)
	_contrast = CheckButton.new()
	_style_check(_contrast)
	_add_row(col, "settings_contrast", _contrast)
	_motion = CheckButton.new()
	_style_check(_motion)
	_add_row(col, "settings_motion", _motion)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", FONT_BODY)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", UI_STYLE.TEXT_DIM)
	col.add_child(_hint)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_defaults = _button()
	_defaults.pressed.connect(_restore_defaults)
	actions.add_child(_defaults)
	_cancel = _button()
	_cancel.pressed.connect(close)
	actions.add_child(_cancel)
	_apply = _button()
	_apply.pressed.connect(_apply_settings)
	actions.add_child(_apply)


func _add_row(parent: VBoxContainer, key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var label := Label.new()
	label.custom_minimum_size = Vector2(250, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BODY)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UI_STYLE.TEXT)
	row.add_child(label)
	_labels[key] = label
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _style_label(label: Label, size: int, color: Color, centered: bool) -> void:
	label.add_theme_font_override("font", FONT_TITLE)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_check(check: CheckButton) -> void:
	check.text = ""
	check.add_theme_color_override("font_color", UI_STYLE.TEXT)
	check.add_theme_icon_override("checked", _check_icon(true))
	check.add_theme_icon_override("unchecked", _check_icon(false))


func _check_icon(on: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	var color := UI_STYLE.GOLD_BRIGHT if on else Color(UI_STYLE.TEXT_DIM, 0.34)
	gradient.colors = PackedColorArray([color, color])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 28
	tex.height = 28
	return tex


func _option() -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(300, 38)
	option.add_theme_font_override("font", FONT_BODY)
	option.add_theme_font_size_override("font_size", 17)
	option.add_theme_color_override("font_color", UI_STYLE.TEXT)
	option.add_theme_color_override("font_disabled_color", Color(UI_STYLE.TEXT_DIM, 0.62))
	option.add_theme_stylebox_override("normal", UI_STYLE.field())
	option.add_theme_stylebox_override("disabled", UI_STYLE.field())
	option.add_theme_stylebox_override("hover", UI_STYLE.panel(UI_STYLE.AMETHYST_BRIGHT, true))
	option.add_theme_stylebox_override("focus", UI_STYLE.panel(UI_STYLE.AMETHYST_BRIGHT, true))
	return option


func _button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 42)
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", UI_STYLE.GOLD_DIM)
	btn.add_theme_color_override("font_hover_color", UI_STYLE.GOLD_BRIGHT)
	btn.add_theme_color_override("font_focus_color", UI_STYLE.GOLD_BRIGHT)
	btn.add_theme_stylebox_override("normal", UI_STYLE.button(true))
	btn.add_theme_stylebox_override("hover", UI_STYLE.button(false))
	btn.add_theme_stylebox_override("focus", UI_STYLE.button(false))
	btn.pressed.connect(func() -> void: Sfx.play(Sfx.CLICK, -8.0))
	btn.mouse_entered.connect(btn.grab_focus)
	return btn


func _separator() -> TextureRect:
	var line := TextureRect.new()
	line.texture = UI_STYLE.separator_gradient()
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _load_current() -> void:
	_build_resolution_list()
	_mode.select(SETTINGS.current().display_mode)
	_resolution.select(maxi(_available_resolutions.find(SETTINGS.current().resolution), 0))
	_quality.select(SETTINGS.current().quality)
	_language.select(1 if SETTINGS.current().language == "en" else 0)
	_ui_scale.select(maxi(UI_SCALES.find(SETTINGS.current().ui_scale), 0))
	_contrast.button_pressed = SETTINGS.current().high_contrast
	_motion.button_pressed = SETTINGS.current().reduce_motion
	_sync_resolution_enabled()


func _build_resolution_list() -> void:
	_available_resolutions.clear()
	_resolution.clear()
	var screen_size := DisplayServer.screen_get_size() \
		if DisplayServer.get_name() != "headless" else Vector2i(3840, 2160)
	for size in RESOLUTIONS:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			_available_resolutions.append(size)
	if SETTINGS.current().resolution not in _available_resolutions:
		_available_resolutions.append(SETTINGS.current().resolution)
	_available_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	for size in _available_resolutions:
		_resolution.add_item("%d × %d" % [size.x, size.y])


func _refresh_language() -> void:
	var old_language: String = SETTINGS.current().language
	SETTINGS.current().language = "en" if _language != null and _language.selected == 1 else "zh_TW"
	_title.text = SETTINGS.current().text("settings_title")
	_display_header.text = SETTINGS.current().text("settings_display")
	_access_header.text = SETTINGS.current().text("settings_accessibility")
	for key in _labels:
		(_labels[key] as Label).text = SETTINGS.current().text(key)
	_hint.text = SETTINGS.current().text("settings_hint")
	_apply.text = SETTINGS.current().text("settings_apply")
	_cancel.text = SETTINGS.current().text("settings_cancel")
	_defaults.text = SETTINGS.current().text("settings_defaults")
	_set_option_texts(_mode, ["mode_windowed", "mode_fullscreen"])
	_set_option_texts(_quality, ["quality_low", "quality_medium", "quality_high"])
	_set_option_texts(_language, ["language_zh", "language_en"])
	SETTINGS.current().language = old_language


func _set_option_texts(option: OptionButton, keys: Array) -> void:
	for i in range(mini(option.item_count, keys.size())):
		option.set_item_text(i, SETTINGS.current().text(keys[i]))


func _sync_resolution_enabled() -> void:
	_resolution.disabled = _mode.selected == SETTINGS.MODE_FULLSCREEN


func _restore_defaults() -> void:
	var values: Dictionary = SETTINGS.current().defaults()
	_mode.select(int(values.display_mode))
	_quality.select(int(values.quality))
	_language.select(0)
	_ui_scale.select(0)
	_contrast.button_pressed = false
	_motion.button_pressed = false
	var idx := _available_resolutions.find(values.resolution)
	_resolution.select(maxi(idx, 0))
	_sync_resolution_enabled()
	_refresh_language()


func _apply_settings() -> void:
	var selected_resolution := SETTINGS.DEFAULT_RESOLUTION
	if _resolution.selected >= 0 and _resolution.selected < _available_resolutions.size():
		selected_resolution = _available_resolutions[_resolution.selected]
	SETTINGS.current().apply_values({
		"resolution": selected_resolution,
		"display_mode": _mode.selected,
		"quality": _quality.selected,
		"language": "en" if _language.selected == 1 else "zh_TW",
		"ui_scale": UI_SCALES[_ui_scale.selected],
		"high_contrast": _contrast.button_pressed,
		"reduce_motion": _motion.button_pressed,
	})
	hide()
	settings_saved.emit()
