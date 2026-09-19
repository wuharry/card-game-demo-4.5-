extends SceneTree
## 全卡池資源綁定檢查；加 -- capture 使用正式卡面場景拍攝分頁。

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/art/card-background-manifest.json"))
	var checked := {}
	var cards: Array[CardData] = []
	for entry in manifest:
		var path: String = "res://data/cards/%s.tres" % entry.id
		var card := load(path) as CardData
		var expected: String = entry.output if entry.status == "complete" else entry.art
		if card == null or card.art == null or card.art.resource_path != expected \
				or entry.status not in ["complete", "retained"] or checked.has(entry.id):
			push_error("卡圖未完成或綁定錯誤：" + str(entry.id))
			quit(1)
			return
		checked[entry.id] = true
		cards.append(card)
	for file in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres") and not checked.has(file.get_basename()):
			push_error("漏列卡牌：" + file)
			quit(1)
			return
	print("PASS 全卡池卡圖綁定：", cards.size())
	if "capture" not in OS.get_cmdline_user_args():
		quit(0)
		return
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position.z = 20
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("141820")
	scene.add_child(environment)
	DirAccess.make_dir_recursive_absolute("res://docs/art/all-card-backgrounds-review")
	for page in range(ceili(cards.size() / 12.0)):
		var nodes: Array[Node] = []
		for i in range(12):
			var index := page * 12 + i
			if index >= cards.size():
				break
			var card := load("res://src/card/card.tscn").instantiate() as Card
			scene.add_child(card)
			card.setup(cards[index])
			card.position = Vector3((i % 6 - 2.5) * 2, 1.4 if i < 6 else -1.4, 0)
			nodes.append(card)
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(
			"res://docs/art/all-card-backgrounds-review/page_%02d.png" % (page + 1))
		if error != OK:
			quit(1)
			return
		for node in nodes:
			node.queue_free()
		await process_frame
	scene.queue_free()
	await process_frame
	quit(0)
