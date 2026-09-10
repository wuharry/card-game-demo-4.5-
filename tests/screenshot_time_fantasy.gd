extends SceneTree
## Capture Time Fantasy characters beside Tiny RPG units on the real board.
## godot --path . -s tests/screenshot_time_fantasy.gd -- build/tf-svbattle-20260910/game 0

var units: Array[Card] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "build/tf-svbattle-20260910/game"
	DirAccess.make_dir_recursive_absolute(out)
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	preload("res://src/settings/app_settings.gd").current().reduce_motion = false
	for i in 90:
		await process_frame
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/time_fantasy/cards.json"))
	var batch := int(args[1]) if args.size() > 1 else 0
	var ids: Array[String] = ["knight", "wizard"]
	for i in range(batch * 6, mini(batch * 6 + 6, entries.size())):
		ids.append("tf_" + str(entries[i].id))
	var preview_hand: Array[CardData] = []
	for id: String in ids.slice(2, 7):
		preview_hand.append(load("res://data/cards/%s.tres" % id) as CardData)
	var manager := scene.find_child("CardManger", true, false)
	(manager.get("player_hand") as PlayerHand).rebuild_from(preview_hand, false)
	var slots: Array[Node] = []
	for group in ["player_front", "enemy_front"]:
		var row := get_nodes_in_group(group)
		row.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
		slots.append_array(row)
	for i in mini(ids.size(), slots.size()):
		var card := (load("res://src/card/card.tscn") as PackedScene).instantiate() as Card
		card.data = load("res://data/cards/%s.tres" % ids[i]) as CardData
		scene.add_child(card)
		(slots[i] as CardSlot).place_card(card)
		units.append(card)
	await create_timer(1.5).timeout
	for action in ["Idle", "Attack01", "Attack02", "Hurt", "Death"]:
		for unit in units:
			if action == "Death":
				unit._play_death_anim()
			elif action != "Idle":
				unit.play_one_shot_anim(action)
		await create_timer(0.32 if action != "Death" else 0.62).timeout
		for i in 2:
			await process_frame
		RenderingServer.force_draw(false)
		var states: Array[String] = []
		for unit in units:
			var sprite := unit.get("_standee") as Sprite3D
			states.append("%s:%d" % [sprite.texture.resource_path.get_file(), sprite.frame])
		print(action, " ", states)
		var path := out.path_join(action + ".png")
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		await create_timer(0.5).timeout
	var gallery := CardGallery.new()
	root.add_child(gallery)
	gallery.open()
	gallery._all_cards = gallery._all_cards.filter(func(cd: CardData) -> bool:
		return cd.resource_path.get_file().begins_with("tf_"))
	gallery._refresh_grid()
	await create_timer(0.5).timeout
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(out.path_join("Gallery.png"))
	quit(0)
