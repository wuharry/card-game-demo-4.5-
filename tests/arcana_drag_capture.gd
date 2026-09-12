extends SceneTree
## 實際秘術拖放畫面：-- <輸出前綴> 拍照；-- preview 建立可自由操作的試玩場。

const HAND_PATHS := [
	"res://data/cards/arcana_fireblast.tres",
	"res://data/cards/arcana_insight.tres",
	"res://data/cards/arcana_life_spring.tres",
	"res://data/cards/arcana_eternal_winter_edict.tres",
]

var _cm: Node
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var preview := "preview" in args
	var app := root.get_node("AppSettings")
	app.reduce_motion = false
	app.quality = 2
	app.apply_quality()
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	# main 的 _ready 會套用使用者視窗設定；等它完成再固定拍照用尺寸。
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	_cm = scene.find_child("CardManger", true, false)
	_camera = _cm.get("camera") as Camera3D
	var bm := _cm.get("battle_manager") as BattleManager
	var hand := _cm.get("player_hand") as PlayerHand
	bm.sides["player"].mana_max = 7
	bm.sides["player"].mana = 7
	bm.sides["player"].temp_mana = 0
	bm.sides["player"].discard_cd = 0
	bm.sides["player"].hand.clear()
	for path in HAND_PATHS:
		bm.sides["player"].hand.append(load(path) as CardData)
	bm.sides["enemy"].hand.clear()
	hand.rebuild_from(bm.sides["player"].hand, false)
	_cm.battle_ui.update_hud(bm.turn, bm.active_side, 7, 7, 0)
	_cm.battle_ui.update_opp_count(0)
	var target := bm.spawn_unit(load("res://data/cards/knight.tres"),
		get_nodes_in_group("enemy_front")[2] as CardSlot)
	var ally := bm.spawn_unit(load("res://data/cards/knight.tres"),
		get_nodes_in_group("player_front")[1] as CardSlot)
	ally.take_damage(3)
	await create_timer(1.2).timeout
	await physics_frame
	if preview:
		root.title = "秘術拖放試玩：拖到敵人施法，拖到魔力回收換魔"
		_show_preview_help(scene)
		print("Arcana drag preview ready; close the game window to finish.")
		return
	if DisplayServer.get_name() == "headless":
		push_error("arcana_drag_capture requires a rendered window for screenshots")
		quit(1)
		return
	# 固定滑鼠座標只控制正在拍照的拖曳；正常試玩保持原本的輸入流程。
	_cm.set_process(false)
	var prefix: String = args[0] if not args.is_empty() else "user://arcana_drag"
	if not await _capture_drag(hand.cards[0] as Card,
		_camera.unproject_position(target.global_position), prefix + "_target.png"):
		return
	if not await _capture_drag(hand.cards[1] as Card,
		root.get_visible_rect().size * Vector2(0.5, 0.42), prefix + "_cast_zone.png"):
		return
	var well := _cm.get("_recycle_wells")["player"] as ManaRecycle
	if not await _capture_drag(hand.cards[3] as Card,
		_camera.unproject_position(well.global_position + Vector3(0, 0.3, 0)),
		prefix + "_recycle.png"):
		return
	print("Arcana drag capture complete: target, cast zone, insufficient-mana recycle")
	quit(0)


func _capture_drag(card: Card, destination: Vector2, path: String) -> bool:
	var pick_point := _camera.unproject_position(card.global_position)
	# 扇形相鄰牌可能遮住中心，找仍屬於這張牌的可點位置。
	for offset in [0.0, -18.0, 18.0, -36.0, 36.0]:
		var candidate := pick_point + Vector2(offset, 0)
		if _cm._raycast_card_at(candidate) == card:
			pick_point = candidate
			break
	_cm._on_left_pressed_idle_at(pick_point)
	if _cm.get("card_being_dragged") != card:
		push_error("Unable to pick capture card: " + card.data.card_name)
		quit(1)
		return false
	_cm._update_drag_at(destination)
	await create_timer(0.3).timeout
	await physics_frame
	_cm._update_drag_at(destination)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	_cm._cancel_command()
	if error != OK:
		push_error("Unable to save arcana drag capture: " + path)
		quit(1)
		return false
	await create_timer(0.35).timeout
	await physics_frame
	return true


func _show_preview_help(scene: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	scene.add_child(layer)
	var label := Label.new()
	label.position = Vector2(24, 190)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BattleUI.FONT_BODY)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.73))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 5)
	label.text = "拖火焰爆裂到敵人；生命湧泉到受傷友軍\n拖秘傳靈感到中央施放區；永冬敕令可拖去回收\n放開確認，右鍵／Esc 取消"
	layer.add_child(label)
