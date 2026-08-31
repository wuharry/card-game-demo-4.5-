## F8 測卡沙盒回歸：只改離線 Debug 側別，固定 10/10，墓地捨棄不回魔。
## 用法：Godot --headless --path . -s res://tests/debug_sandbox_test.gd
extends SceneTree

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok: ", label)
	else:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in range(20):
		await process_frame

	var cm := root.find_child("CardManger", true, false)
	var bm := cm.get("battle_manager") as BattleManager if cm != null else null
	var hand := cm.get("player_hand") as PlayerHand if cm != null else null
	var ui := cm.get("battle_ui") as BattleUI if cm != null else null
	_check(cm != null and bm != null and hand != null and ui != null,
		"找到測卡所需節點")
	if cm == null or bm == null or hand == null or ui == null:
		quit(1)
		return

	_check(not bm.is_debug_test_mode("player"), "開局尚未啟用 F8 沙盒")
	_check(not bm.is_debug_test_mode("enemy"), "敵方也維持正式規則")
	ui.debug_test_pressed.emit()

	var player = bm.sides["player"]
	var enemy = bm.sides["enemy"]
	_check(bm.is_debug_test_mode("player"), "F8 只替目前側別啟用沙盒")
	_check(not bm.is_debug_test_mode("enemy"), "未替敵方偷偷開沙盒")
	_check(player.mana == 10 and player.mana_max == 10 and player.temp_mana == 0,
		"F8 魔力為乾淨的 10/10")

	var piles: Dictionary = cm.get("_grave_piles")
	var player_drop := (piles["player"] as GravePile).get_node_or_null(
		"DebugDiscardDropArea") as Area3D
	var enemy_drop := (piles["enemy"] as GravePile).get_node_or_null(
		"DebugDiscardDropArea") as Area3D
	_check(player_drop != null and player_drop.collision_layer == 16,
		"玩家墓地已成為可拖放的測試捨棄區")
	_check(enemy_drop != null and enemy_drop.collision_layer == 0,
		"非測試側墓地仍不可接牌")

	var card := hand.cards[0] as Card
	var discarded := card.data
	var hand_before := hand.cards.size()
	var grave_before := bm.grave_count("player")
	player.discard_cd = 1  # 黑洞仍在冷卻，也不應阻擋純測試捨棄。
	cm.call("_try_debug_grave_discard", card)
	_check(hand.cards.size() == hand_before - 1, "測試捨棄會移除手牌視圖")
	_check(bm.grave_count("player") == grave_before + 1
		and bm.grave_top("player") == discarded, "被丟的牌真正進入墓地帳")
	_check(player.mana == 10 and player.temp_mana == 0, "墓地捨棄完全不回魔")
	_check(player.discard_cd == 1, "墓地捨棄不改黑洞回魔冷卻")

	bm.spend(7)
	bm._begin_side_turn(player)
	_check(player.mana == 10 and player.mana_max == 10,
		"沙盒側下一回合仍固定回滿 10/10")
	var enemy_max_before: int = enemy.mana_max
	bm._begin_side_turn(enemy)
	_check(enemy.mana_max == mini(BattleManager.MANA_CAP, enemy_max_before + 1),
		"正式側仍使用原本 7 點成長上限")

	print("")
	if _fails == 0:
		print("PASS F8 測卡沙盒 %d 斷言全過" % _checks)
	else:
		print("FAIL %d/%d 斷言未過" % [_fails, _checks])
	quit(1 if _fails > 0 else 0)
