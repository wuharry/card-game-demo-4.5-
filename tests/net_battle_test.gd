extends SceneTree
## 連線 2b–2e 驗收:兩個 headless 進程 loopback 實連。
## host:開房 → 等連線 → 等 client 同步 → 召喚+結束回合 → 等 client 行動 → 印簽名
## client:連線 → 等開局帳 → 印簽名 → 等 host 行動落地 → 自己召喚+結束回合 → 印簽名
## 用法:godot --headless -s 本檔 -- client(不帶參數 = host)

const PORT := 8917
var role := "host"


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("client"):
		role = "client"
	_run.call_deferred()


func _log(msg: String) -> void:
	print("[%s] %s" % [role.to_upper(), msg])


func _names(list) -> String:
	var out: PackedStringArray = []
	for cd in list:
		out.append(cd.card_name)
	return ",".join(out)


## 帳的簽名:雙方手牌內容+牌堆剩量——兩台印出來必須一字不差。
func _sig(bm) -> String:
	return "P手[%s] E手[%s] 堆P%d E%d 行動方%s" % [
		_names(bm.hand_of("player")), _names(bm.hand_of("enemy")),
		bm.deck_count("player"), bm.deck_count("enemy"), bm.active_side]


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _first_minion(ph):
	for c in ph.cards:
		if c.data != null and c.data.card_type == 0:
			return c
	return null


func _first_empty(group: String):
	for s in get_nodes_in_group(group):
		if s.is_empty:
			return s
	return null


func _run() -> void:
	var peer := ENetMultiplayerPeer.new()
	if role == "host":
		peer.create_server(PORT, 1)
		root.multiplayer.multiplayer_peer = peer
		NetMatch.start_online("player")
		_log("開房,等 client…")
		await root.multiplayer.peer_connected
		_log("client 已連上")
	else:
		peer.create_client("127.0.0.1", PORT)
		root.multiplayer.multiplayer_peer = peer
		NetMatch.start_online("enemy")
		await root.multiplayer.connected_to_server
		_log("已連上 host")

	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	var cm = root.find_child("CardManger", true, false)
	var bm = cm.get("battle_manager")
	var ph = cm.get("player_hand")

	# 等開局帳同步(host 天生 true;client 等 _request_state_loop 拿到)
	for i in 100:
		if cm.get("_accounts_synced"):
			break
		await _wait(0.1)
	if not cm.get("_accounts_synced"):
		_log("FAIL:開局帳同步逾時")
		quit(1)
		return
	_log("開局簽名:" + _sig(bm))

	if role == "host":
		# ── host 回合:召喚一隻+結束回合 ──
		var card = _first_minion(ph)
		var slot = _first_empty("player_front")
		cm._pending_play_card = card
		cm._net_summon.rpc(ph.cards.find(card), card.data.resource_path,
			cm.get_path_to(slot))
		_log("已召喚:" + card.data.card_name)
		await _wait(1.0)
		cm._on_end_turn()
		_log("已結束回合")
		# ── 等 client 那邊召喚+結束回合傳回來 ──
		for i in 200:
			if bm.active_side == "player" and _first_empty("enemy_front") != get_nodes_in_group("enemy_front")[0]:
				break
			await _wait(0.1)
		await _wait(1.0)
		var efront = get_nodes_in_group("enemy_front")[0]
		_log("client 的召喚在本機可見:%s" % (efront.card_in_slot.data.card_name if efront.card_in_slot else "(空!FAIL)"))
		_log("終局簽名:" + _sig(bm))
		await _wait(2.0)
		quit(0)
	else:
		# ── client:等 host 的召喚重放到本機 ──
		for i in 200:
			var pfront = get_nodes_in_group("player_front")[0]
			if pfront.card_in_slot != null:
				break
			await _wait(0.1)
		var pf = get_nodes_in_group("player_front")[0]
		_log("host 的召喚在本機可見:%s" % (pf.card_in_slot.data.card_name if pf.card_in_slot else "(空!FAIL)"))
		# 等輪到自己
		for i in 200:
			if bm.active_side == "enemy":
				break
			await _wait(0.1)
		_log("輪到我了(active=%s,my_side=%s)" % [bm.active_side, NetMatch.my_side])
		# ── client 回合:召喚一隻+結束回合 ──
		var card = _first_minion(ph)
		if card == null:
			_log("FAIL:手上沒有從者卡")
			quit(1)
			return
		var slot = _first_empty("enemy_front")
		cm._pending_play_card = card
		cm._net_summon.rpc(ph.cards.find(card), card.data.resource_path,
			cm.get_path_to(slot))
		_log("已召喚:" + card.data.card_name)
		await _wait(1.0)
		cm._on_end_turn()
		_log("已結束回合")
		await _wait(1.5)
		_log("終局簽名:" + _sig(bm))
		await _wait(1.0)
		quit(0)
