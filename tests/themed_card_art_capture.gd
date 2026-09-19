extends SceneTree
## 正式卡面四張並排；不改規則或 sprite。非 headless 執行。

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 0, 10)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.4
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("141820")
	scene.add_child(environment)
	var ids := ["flame_golem", "treant_guardian", "necromancer", "desert_nomad"]
	for i in ids.size():
		var data := load("res://data/cards/%s.tres" % ids[i]) as CardData
		if data == null or data.art == null or not data.art.resource_path.ends_with("_themed_card_art.png"):
			push_error("新卡圖未綁定：" + ids[i])
			quit(1)
			return
		var card := load("res://src/card/card.tscn").instantiate() as Card
		scene.add_child(card)
		card.setup(data)
		card.position.x = (i - 1.5) * 2.0
		print("PASS themed art: ", data.card_name)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/art/themed-card-backgrounds-review.png")
	scene.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
