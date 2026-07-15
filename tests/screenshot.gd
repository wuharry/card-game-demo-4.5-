extends SceneTree
## 截圖工具:非 headless 跑 main.tscn,等開局動畫落定後存一張 PNG。
## 用來驗證純視覺改動(構圖、景深、後製)——headless 不出畫面,只能這樣拍。
## 用法:godot --path . -s tests/screenshot.gd -- /絕對路徑/out.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/shot.png"
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		out = user_args[0]
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 90:   # 等發牌/入場動畫收斂,拍的才是穩定構圖
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: " + out)
	quit(0)
