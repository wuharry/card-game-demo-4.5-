extends SceneTree
## 在正式森林牌桌並排放置原素材與重繪角色，擷取待機、攻擊、受傷與倒地。
## godot --path . -s tests/screenshot_character_style.gd -- build/sprite-style-20260909/game

var units: Array[Card] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "build/sprite-style-20260909/game"
	DirAccess.make_dir_recursive_absolute(out)
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	preload("res://src/settings/app_settings.gd").current().reduce_motion = false
	for i in 90:
		await process_frame
	var ids := ["knight", "adventurer", "wizard", "frost_witch", "soldier", "pirate_captain", "gargoyle_sentinel", "frog_shaman"]
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
	quit(0)
