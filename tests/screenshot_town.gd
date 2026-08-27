extends SceneTree
## 官網素材:拍主選單的 3D 城鎮背景,但把 UI 圖層藏起來(避免遊戲選單文字
## 和網站自己的文字打架)。用法:godot --path . -s tests/screenshot_town.gd -- <out.png>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	var out: String = ua[0] if not ua.is_empty() else "town.png"
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for i in 60:
		await process_frame
	for child in menu.get_children():
		if child is CanvasLayer or child is Control:
			child.visible = false
	for i in 30:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: ", out, " ", img.get_size())
	quit(0)
