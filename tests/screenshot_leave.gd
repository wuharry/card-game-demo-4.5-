## screenshot_leave.gd — 截圖工具:拍「離開對戰」確認窗的版面(非 headless)
## 跑法:Godot --path . -s tests/screenshot_leave.gd -- <輸出的絕對路徑.png>
## 用途:確認窗是純視覺物件(面板寬高/文字換行/按鈕位置),只能用眼睛驗——
## 同 tests/screenshot.gd,不是 CI 測試。
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


## card_manager.gd 沒有 class_name(它是掛在 main.tscn 的 CardManger 節點上),
## 所以靠節點名找,不能用型別找。
func _find_cm(node: Node) -> Node:
	if node.name == "CardManger":
		return node
	for c in node.get_children():
		var r := _find_cm(c)
		if r != null:
			return r
	return null


func _run() -> void:
	var out := "leave_shot.png"
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		out = user_args[0]
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 90:   # 等發牌/入場動畫收斂
		await process_frame
	var cm := _find_cm(root)
	if cm == null:
		print("FAIL: 找不到 CardManager")
		quit(1)
		return
	cm._on_leave_requested()   # 等同玩家按左上角「離開對戰」
	# 第二個參數 "online" = 改用連線版警告文案(全專案最長的一句)驗版面撐不撐得住。
	if user_args.size() > 1 and user_args[1] == "online":
		cm.battle_ui.show_leave_confirm(
			"離開連線對戰等同認輸:對手會立刻看到「對方已離線」並被送回主選單,這一局無法回來。")
	for i in 15:               # 等面板 reset_size / 置中落定
		await process_frame
	# 版面報告:破圖時「肉眼看起來怪」和「數字錯在哪」是兩回事——
	# 2026-08-06 那次就是靠 panel size=(428,1744) 一眼定位到 autowrap 最小尺寸的坑。
	var ui: CanvasLayer = cm.battle_ui
	print("viewport = ", root.get_viewport().get_visible_rect().size)
	print("dim   size=", ui._leave_dim.size, " pos=", ui._leave_dim.position)
	print("panel size=", ui._leave_panel.size, " pos=", ui._leave_panel.position,
		"   ← 高度應該 ~230,若是四位數就是 Label 最小尺寸又爆了")
	print("body  size=", ui._leave_body.size)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: " + out)
	quit(0)
