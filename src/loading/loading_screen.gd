## 暫時掛在 SceneTree.root：換場景後仍遮住初始化，淡出完自行釋放。
extends CanvasLayer

signal failed

const SETTINGS = preload("res://src/settings/app_settings.gd")
const STYLE = preload("res://src/ui/fantasy_ui_theme.gd")
const FONT = preload("res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-SemiBold.ttf")

var _ui: Control
var _status: Label
var _progress: ProgressBar
var _retry: Button
var _paths: Array[String] = []
# 強參考保留已載入的戰場，讓 main_scene 的 load() 命中快取。
var _resources: Array[PackedScene] = []
var _busy := false


class Sigil extends Control:
	var age := 0.0
	var reduced := false

	func _process(delta: float) -> void:
		if not reduced:
			age += delta
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var gold := Color("b7a073")
		draw_arc(center, 86.0, 0.0, TAU, 96, Color(gold, 0.18), 1.0, true)
		for i in 3:
			var angle := age * 0.35 + i * TAU / 3.0
			draw_arc(center, 92.0, angle, angle + 0.65, 24, Color(gold, 0.6), 2.0, true)
		for i in 3:
			var offset := float(i - 1)
			var bob := 0.0 if reduced else sin(age * 2.2 + i * 0.9) * 5.0
			draw_set_transform(center + Vector2(offset * 37.0, absf(offset) * 9.0 + bob), offset * 0.16)
			var rect := Rect2(-25, -38, 50, 76)
			draw_rect(rect, Color("151c24"))
			draw_rect(rect, gold, false, 1.5)
			draw_rect(rect.grow(-5), Color(gold, 0.3), false, 1.0)
			var diamond := PackedVector2Array([Vector2(0, -14), Vector2(9, 0), Vector2(0, 14), Vector2(-9, 0), Vector2(0, -14)])
			draw_polyline(diamond, gold, 1.5, true)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0b1018")
	_ui.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_ui.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 300
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var sigil := Sigil.new()
	sigil.custom_minimum_size = Vector2(300, 220)
	sigil.reduced = SETTINGS.current().reduce_motion
	column.add_child(sigil)
	var title := _label("ARCANE DUEL", 16, STYLE.GOLD)
	column.add_child(title)
	_status = _label(SETTINGS.current().text("loading_resources"), 22, STYLE.TEXT)
	column.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 4
	_progress.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("242b35")
	var fill := StyleBoxFlat.new()
	fill.bg_color = STYLE.GOLD
	_progress.add_theme_stylebox_override("background", track)
	_progress.add_theme_stylebox_override("fill", fill)
	column.add_child(_progress)
	var hint := _label(SETTINGS.current().text("loading_hint"), 14, STYLE.TEXT_DIM)
	column.add_child(hint)
	_retry = Button.new()
	_retry.text = SETTINGS.current().text("back")
	_retry.add_theme_font_override("font", FONT)
	_retry.custom_minimum_size.y = 44
	_retry.hide()
	_retry.pressed.connect(func() -> void:
		failed.emit()
		queue_free())
	column.add_child(_retry)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _input(_event: InputEvent) -> void:
	# 載入時包含鍵盤快捷鍵都攔住；失敗後交回 GUI 的返回按鈕。
	if _busy:
		get_viewport().set_input_as_handled()


func start(scene_path: String, arena_path: String = "") -> void:
	if _busy:
		return
	_busy = true
	_paths = [scene_path]
	if not arena_path.is_empty() and arena_path != scene_path:
		_paths.append(arena_path)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	# 先呈現遮罩再請求資源，避免首幀仍留在選單。
	await get_tree().process_frame
	await get_tree().process_frame
	for i in _paths.size():
		var path := _paths[i]
		var err := ResourceLoader.load_threaded_request(path, "PackedScene")
		if err != OK:
			_show_failure(path)
			return
		while true:
			var progress: Array = []
			var status := ResourceLoader.load_threaded_get_status(path, progress)
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_show_failure(path)
				return
			var fraction: float = float(progress[0]) if not progress.is_empty() else 0.0
			_progress.value = 100.0 * (float(i) + fraction) / float(_paths.size())
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var packed := ResourceLoader.load_threaded_get(path) as PackedScene
				if packed == null:
					_show_failure(path)
					return
				_resources.append(packed)
				break
			await get_tree().process_frame
	_progress.value = 100.0
	_status.text = SETTINGS.current().text("loading_prepare")
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	var err := tree.change_scene_to_packed(_resources[0])
	if err != OK:
		_show_failure(scene_path)
		return
	await tree.scene_changed
	# 場景已 ready，再留一幀給畫面提交；初始化仍由 Godot 主執行緒負責。
	await tree.process_frame
	var tween := create_tween()
	tween.tween_property(_ui, "modulate:a", 0.0, SETTINGS.current().motion_duration(0.3))
	await tween.finished
	queue_free()


func _show_failure(path: String) -> void:
	push_error("Scene loading failed: " + path)
	_busy = false
	_status.text = SETTINGS.current().text("loading_failed")
	_progress.hide()
	_retry.show()
	_retry.grab_focus()
