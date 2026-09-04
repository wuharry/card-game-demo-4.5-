extends SceneTree
## 玩家瞬咒反制回歸：符合事件且魔力足夠時，必須真的開面板並由玩家決定。

var fails := 0
var reaction_panel_was_visible := false


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		fails += 1
		print("FAIL: " + msg)


func _initialize() -> void:
	_run.call_deferred()


func _accept_visible_reaction(ui: BattleUI) -> void:
	await process_frame
	var panel := ui.get("_react_panel") as PanelContainer
	reaction_panel_was_visible = panel != null and panel.visible
	# 等同玩家在反制面板按下「發動」。
	ui._answer_reaction(true)


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	MatchMode.mode = MatchMode.Mode.HOTSEAT
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 25:
		await process_frame

	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var ui := cm.get("battle_ui") as BattleUI
	var quick := load("res://data/cards/quick_void_rebuke.tres") as CardData

	# 敵方正在行動，因此 player 是守方；瞬咒留在守方帳上並保留足夠魔力。
	bm.active_side = "enemy"
	bm.sides["player"].hand.clear()
	bm.sides["player"].hand.append(quick)
	bm.sides["player"].mana = quick.cost
	_accept_visible_reaction(ui)
	var countered: bool = await cm._ask_counter_hotseat("測試秘術")

	_check(reaction_panel_was_visible, "符合條件時玩家端會顯示瞬咒反制面板")
	_check(countered, "玩家按下發動後回傳反制成功")
	_check(bm.sides["player"].hand.is_empty(), "發動的瞬咒會從守方手牌移除")
	_check(bm.grave_count("player") == 1, "發動的瞬咒會進入守方墓地")
	_check(bm.sides["player"].mana == 0, "發動的瞬咒會支付魔力")

	if fails == 0:
		print("PASS 玩家瞬咒反制流程 5/5")
		quit(0)
	else:
		quit(1)
