extends SceneTree
## 官網素材截圖工具:指定戰場拍一張 PNG,可選擇先召喚一批單位讓畫面有戰局。
## 用法:godot --path . -s tests/screenshot_arena.gd -- <out.png> [arena_path] [summon]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.is_empty():
		print("usage: out.png [arena_path] [summon]")
		quit(2)
		return
	var out: String = ua[0]
	ArenaPool.next_arena_path = ua[1] if ua.size() > 1 else ArenaPool.DEFAULT_ARENA
	var want_summon := ua.size() > 2 and ua[2] == "summon"

	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 90:
		await process_frame

	if want_summon:
		var cm = root.find_child("CardManger", true, false)
		var ph = cm.get("player_hand")
		for _round in 3:
			var card = null
			for c in ph.cards:
				if c.data != null and c.data.card_type == 0:
					card = c
					break
			if card == null:
				break
			var slot = null
			for s in get_nodes_in_group("player_front"):
				if s.is_empty:
					slot = s
					break
			if slot == null:
				break
			cm._pending_play_card = card
			cm._net_summon(ph.cards.find(card), card.data.resource_path, cm.get_path_to(slot))
			await create_timer(0.6).timeout
		await create_timer(1.2).timeout

	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved: ", out, " ", img.get_size())
	quit(0)
