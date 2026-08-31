extends SceneTree
## 設定驗收：不寫 user://，只暫存與還原執行中數值。

const SETTINGS_SCRIPT: GDScript = preload("res://src/settings/app_settings.gd")
const UI_STYLE: GDScript = preload("res://src/ui/fantasy_ui_theme.gd")

var fails := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		fails += 1
		print("FAIL: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var app = SETTINGS_SCRIPT.current()
	var saved := {
		"resolution": app.resolution,
		"display_mode": app.display_mode,
		"quality": app.quality,
		"language": app.language,
		"ui_scale": app.ui_scale,
		"high_contrast": app.high_contrast,
		"reduce_motion": app.reduce_motion,
	}

	root.add_child((load("res://scenes/main_menu.tscn") as PackedScene).instantiate())
	for i in 12:
		await process_frame
	var panel = root.find_child("SettingsPanel", true, false)
	_check(panel != null, "主選單已建立 SettingsPanel")
	if panel == null:
		quit(1)
		return
	panel.open()
	_check(panel.visible, "設定面板可開啟")
	_check(panel.get("_mode").item_count == 2, "顯示模式包含視窗／全螢幕")
	_check(panel.get("_quality").item_count == 3, "畫質包含低／中／高")
	_check(panel.get("_language").item_count == 2, "語言只有繁中／英文")
	_check(panel.get("_ui_scale").item_count == 3, "無障礙 UI 比例有三檔")
	_check(panel.get("_resolution").item_count >= 1, "至少提供一組合法解析度")
	panel.get("_mode").select(SETTINGS_SCRIPT.MODE_FULLSCREEN)
	panel._sync_resolution_enabled()
	_check(panel.get("_resolution").disabled, "全螢幕時解析度選單會鎖定")
	panel.get("_mode").select(SETTINGS_SCRIPT.MODE_WINDOWED)
	panel.get("_language").select(1)
	panel._refresh_language()
	panel._sync_resolution_enabled()
	_check(not panel.get("_resolution").disabled
		and not panel.get("_resolution").get_item_text(panel.get("_resolution").selected).is_empty(),
		"英文視窗模式仍會顯示解析度")

	app.language = "en"
	_check(app.text("menu_settings") == "Settings", "英文 UI 字串可載入")
	var soldier: CardData = load("res://data/cards/soldier.tres")
	_check(app.card_name(soldier) == "Soldier", "英文卡名可由資源路徑穩定生成")
	_check("Shield" in app.skill_description(soldier.active_skill),
		"英文技能說明會由規則資料生成")
	app.language = "zh_TW"
	_check(app.card_name(soldier) == "士兵", "繁中卡名保留編輯文字")

	app.reduce_motion = false
	_check(is_equal_approx(app.motion_duration(0.3), 0.3), "正常模式保留動畫時間")
	app.reduce_motion = true
	_check(app.motion_duration(0.3) <= 0.01, "減少動態會實際縮短 UI 動畫")

	app.high_contrast = false
	var normal_border: int = UI_STYLE.panel().border_width_left
	app.high_contrast = true
	var contrast_border: int = UI_STYLE.panel().border_width_left
	_check(contrast_border > normal_border, "高對比 UI 會實際加強邊框與底色")

	app.quality = SETTINGS_SCRIPT.QUALITY_LOW
	app.apply_quality()
	_check(is_equal_approx(root.scaling_3d_scale, 0.75)
		and root.msaa_3d == Viewport.MSAA_DISABLED, "低畫質會降低 3D 渲染與抗鋸齒")
	app.quality = SETTINGS_SCRIPT.QUALITY_HIGH
	app.apply_quality()
	_check(is_equal_approx(root.scaling_3d_scale, 1.0)
		and root.msaa_3d == Viewport.MSAA_4X, "高畫質會啟用 4x MSAA")

	# 還原進入測試前的執行中設定，不存檔。
	app.resolution = saved.resolution
	app.display_mode = saved.display_mode
	app.quality = saved.quality
	app.language = saved.language
	app.ui_scale = saved.ui_scale
	app.high_contrast = saved.high_contrast
	app.reduce_motion = saved.reduce_motion
	app.apply_quality()
	root.content_scale_factor = app.ui_scale

	if fails == 0:
		print("PASS 顯示／畫質／語言／無障礙設定全數通過")
		quit(0)
	else:
		quit(1)
