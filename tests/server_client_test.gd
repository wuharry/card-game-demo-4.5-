extends SceneTree
## ADR-002 專用伺服器驗收(玩家端)。要先另開一個進程跑伺服器:
##   godot --headless -s src/server/server_main.gd
## 然後開兩個玩家:
##   godot --headless -s tests/server_client_test.gd -- --name A
##   godot --headless -s tests/server_client_test.gd -- --name B
## 或直接跑 tests/run_server_match.sh(三個進程一起開、收尾自己殺掉)。
##
## 驗什麼(缺一不可):
##   1. 連大廳 → 配對 → 拿到房間埠與側別(先後手由伺服器指派,不是玩家自報)
##   2. 進牌桌 → 連房間埠 → 出示入場券 → 拿到伺服器發的開局帳
##   3. 兩台的帳簽名**一字不差**(沿用 §28 的簽名比對驗收法)
##   4. 換回合走「意圖 → 伺服器驗證 → 廣播結果」:非當前玩家按了要被伺服器丟棄

const NET_CLIENT := preload("res://src/net/net_client.gd")

var pname := "?"
var _cm: Node = null
var _bm: Node = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--name")
	if i >= 0 and i + 1 < args.size():
		pname = args[i + 1]
	_run.call_deferred()


func _log(msg: String) -> void:
	print("[%s] %s" % [pname, msg])


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _names(list) -> String:
	var out: PackedStringArray = []
	for cd in list:
		out.append(cd.card_name)
	return ",".join(out)


## 帳的簽名:雙方手牌內容+牌堆剩量+行動方——兩台印出來必須一字不差。
func _sig() -> String:
	return "P手[%s] E手[%s] 堆P%d E%d 行動方%s" % [
		_names(_bm.hand_of("player")), _names(_bm.hand_of("enemy")),
		_bm.deck_count("player"), _bm.deck_count("enemy"), _bm.active_side]


func _fail(msg: String) -> void:
	_log("FAIL:" + msg)
	quit(1)


func _run() -> void:
	# ── 1. 連大廳排配對 ──
	var nc: Node = NET_CLIENT.new()
	nc.name = "NetClient"
	root.add_child(nc)
	nc.status_changed.connect(func(t: String) -> void: _log("狀態:" + t))
	var err: int = nc.connect_to_lobby("127.0.0.1")
	if err != OK:
		_fail("connect_to_lobby 回傳 %d(伺服器沒開?)" % err)
		return
	var paired := false
	nc.match_ready.connect(func() -> void: paired = true)
	for i in 150:
		if paired:
			break
		await _wait(0.1)
	if not paired:
		_fail("配對逾時(15 秒都沒湊到對手)")
		return
	_log("配對完成:我執 %s,房間埠 %d" % [NetMatch.my_side, NetMatch.room_port])
	if NetMatch.join_token.is_empty():
		_fail("沒拿到入場券")
		return

	# ── 2. 進牌桌(CardManager 會自己連房間埠並出示入場券)──
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	for i in 20:
		await process_frame
	_cm = root.find_child("CardManger", true, false)
	if _cm == null:
		_fail("牌桌裡找不到 CardManger")
		return
	_bm = _cm.get("battle_manager")

	# ── 3. 等伺服器發的開局帳 ──
	for i in 150:
		if _cm.get("_accounts_synced"):
			break
		await _wait(0.1)
	if not _cm.get("_accounts_synced"):
		_fail("開局帳同步逾時(入場券被拒?伺服器沒回?)")
		return
	_log("開局簽名:" + _sig())

	# ── 4. 權威驗證:非當前玩家按結束回合,伺服器必須丟棄 ──
	var turn_before: int = _bm.turn
	if _bm.active_side != NetMatch.my_side:
		_log("不是我的回合,故意送一次 req_end_turn(伺服器應該丟棄)")
		_cm.req_end_turn.rpc_id(1)
		await _wait(1.0)
		if _bm.turn != turn_before:
			_fail("伺服器沒擋住非當前玩家的換回合意圖!回合從 %d 變成 %d"
				% [turn_before, _bm.turn])
			return
		_log("OK:伺服器丟棄了越權的意圖(回合仍為 %d)" % _bm.turn)

	# ── 5. 輪到自己 → 正常結束回合,兩台都該跟著換 ──
	for i in 200:
		if _bm.active_side == NetMatch.my_side:
			break
		await _wait(0.1)
	if _bm.active_side != NetMatch.my_side:
		_fail("等不到自己的回合")
		return
	_log("輪到我了(回合 %d),按結束回合" % _bm.turn)
	turn_before = _bm.turn
	_cm._on_end_turn()
	for i in 100:
		if _bm.turn != turn_before:
			break
		await _wait(0.1)
	if _bm.turn == turn_before:
		_fail("自己的回合送意圖後,伺服器沒廣播換回合")
		return
	_log("換回合成功:第 %d 回合,行動方 %s" % [_bm.turn, _bm.active_side])
	await _wait(1.5)
	_log("終局簽名:" + _sig())
	await _wait(0.5)
	quit(0)
