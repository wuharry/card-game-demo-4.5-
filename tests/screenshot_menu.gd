extends SceneTree
## 官網素材:拍主選單(城鎮背景 + 歧路旅人式文字選單)。
## 用法:godot --path . -s tests/screenshot_menu.gd -- <out.png>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	var out: String = ua[0] if not ua.is_empty() else "menu.png"
	root.add_child((load("res://scenes/main_menu.tscn") as PackedScene).instantiate())
	for i in 120:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: ", out, " ", img.get_size())
	quit(0)
