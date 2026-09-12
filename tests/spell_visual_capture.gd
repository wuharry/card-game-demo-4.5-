extends SceneTree
## 非 headless 拍實際法術；加 preview 可循環預覽，關閉視窗結束。
const SPELLS := ["arcana_fireblast", "arcana_thunder_pierce", "arcana_frozen_pulse"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var app := root.get_node("AppSettings")
	app.reduce_motion = false
	app.quality = 2
	app.apply_quality()
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280,720)
	var cm := root.find_child("CardManger", true, false)
	var bm: BattleManager = cm.battle_manager
	var front := get_nodes_in_group("enemy_front")[2] as CardSlot
	var back := get_nodes_in_group("enemy_back")[2] as CardSlot
	var target: Card = bm.spawn_unit(load("res://data/cards/knight.tres"), front)
	var rear: Card = bm.spawn_unit(load("res://data/cards/knight.tres"), back)
	await create_timer(1.2).timeout
	var repeat := true
	while repeat:
		for spell in SPELLS:
			target.current_hp = target.data.hp
			rear.current_hp = rear.data.hp
			target.shield = 0
			rear.shield = 0
			target.remove_status(SkillData.Status.FREEZE)
			var card := load("res://data/cards/" + spell + ".tres") as CardData
			cm.battle_ui.flash_message(app.card_name(card))
			bm.cast_arcana(card, target)
			if "frames" in args and DisplayServer.get_name() != "headless":
				# 搭配 --fixed-fps 30，保留原始畫面供動畫預覽，不裁切或放大。
				for frame in 36:
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("%s_%s_%03d.png" % [args[0], spell, frame])
			else:
				await create_timer(0.16).timeout
			if DisplayServer.get_name() != "headless" and not args.is_empty() and not "frames" in args:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[0] + "_" + spell + ".png")
			await create_timer(1.6).timeout
		repeat = "preview" in args
	print("Spell capture complete")
	quit()
