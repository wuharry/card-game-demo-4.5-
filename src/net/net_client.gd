## net_client.gd — 玩家端的連線(取代 net_lobby.gd 的開房分支)
##
## 掛在 MainMenu 底下。ADR-002:沒有開房、沒有 IP 輸入框、沒有 UPnP——
## 玩家只做一件事:往外連專用伺服器排配對。NAT 對「出向」連線自動建對應表,
## 所以兩邊都不需要被連進來,不必打洞。
##
## 路徑合約(見 game_server.gd 檔頭):大廳分支的 root_path = 本節點自己,
## 伺服器那邊 = GameServer 自己 → 兩邊 RPC 路徑都解析成空路徑,對得上。
## ⚠ 本檔與 game_server.gd 的 @rpc 函式**名稱與簽名必須成對**,改一邊會靜默失效
## (RPC 簽名錯要發射才炸,不是 parse 期——關卡表 關 7)。
##
## 流程:
##   connect_to_lobby() → connected_to_server → req_find_match
##   → on_room_assigned(埠/側別/牌桌/入場券) → 存共識 → emit match_ready
##   → MainMenu 換場景到 main.tscn → CardManager 自己連房間埠(見 card_manager.gd)
extends Node

signal status_changed(text: String)   # 給 UI 的狀態字
signal match_ready                    # 配對完成,可以進牌桌了

const NET_MATCH: GDScript = preload("res://src/net/net_match.gd")

var _peer: ENetMultiplayerPeer = null
var _api: SceneMultiplayer = null


func _ready() -> void:
	# 回到主選單 = 放棄任何舊連線(打完一場回來、或上次連到一半就按返回)。
	NET_MATCH.reset()
	_teardown_room_branch()


## 連大廳並排配對。回傳 OK 或錯誤碼(UI 據此鎖按鈕)。
func connect_to_lobby(host: String = "") -> Error:
	var target := host.strip_edges()
	if target.is_empty():
		target = NET_MATCH.server_host
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(target, NET_MATCH.PORT)
	if err != OK:
		_peer = null
		status_changed.emit("無法連線到伺服器(錯誤碼 %d)" % err)
		return err
	# 大廳專屬分支:root_path 設成自己(路徑合約,見檔頭)。
	_api = SceneMultiplayer.new()
	_api.multiplayer_peer = _peer
	get_tree().set_multiplayer(_api, get_path())
	_api.connected_to_server.connect(_on_connected)
	_api.connection_failed.connect(_on_failed)
	_api.server_disconnected.connect(_on_server_lost)
	NET_MATCH.server_host = target
	status_changed.emit("連線中:%s…" % target)
	return OK


func cancel() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_api = null
	NET_MATCH.reset()


## ── 玩家 → 伺服器的意圖(實作在 game_server.gd,這邊只要簽名成對)──
@rpc("any_peer", "reliable")
func req_find_match() -> void:
	pass


## ── 伺服器 → 玩家的結果 ──────────────────────────────
##
## 配對成功:伺服器指派房間埠、側別、牌桌、入場券。
## authority = 只有伺服器有資格發這則,別的玩家偽造會被丟棄。
@rpc("authority", "reliable")
func on_room_assigned(room_port: int, side: String, arena_idx: int, token: String) -> void:
	# 亂數只在伺服器發生:牌桌由它抽、這裡只寫結果(不自己 pick_random)。
	var safe_idx := clampi(arena_idx, 0, ArenaPool.ARENAS.size() - 1)
	ArenaPool.next_arena_path = ArenaPool.ARENAS[safe_idx]
	NET_MATCH.start_online(side)
	NET_MATCH.room_port = room_port
	NET_MATCH.join_token = token
	# 大廳的活到這裡結束:斷開大廳連線,房間連線由 CardManager 進牌桌後自己建
	# (它才是意圖 RPC 的收件人,路徑合約見 match_room.gd 檔頭)。
	if _peer != null:
		_peer.close()
	_peer = null
	status_changed.emit("配對成功!你執%s,進入牌桌…" % ("先手" if side == "player" else "後手"))
	match_ready.emit()


@rpc("authority", "reliable")
func on_queue_status(waiting: int) -> void:
	status_changed.emit("已進入配對佇列(目前 %d 人等待)…" % waiting)


## ── multiplayer 信號 ────────────────────────────────
func _on_connected() -> void:
	status_changed.emit("已連上伺服器,排配對中…")
	req_find_match.rpc_id(1)   # 1 = 伺服器


func _on_failed() -> void:
	cancel()
	status_changed.emit("連不上伺服器:確認網路正常,或伺服器正在維護。")


func _on_server_lost() -> void:
	cancel()
	status_changed.emit("與伺服器的連線中斷了。")


## 上一局的房間分支(root_path = /root)可能還掛著死掉的 peer:
## 回主選單時清掉,不然下一局的 rpc 會走到舊 peer 上。
func _teardown_room_branch() -> void:
	var api := get_tree().get_multiplayer(^"/root")
	if api != null and api.multiplayer_peer != null:
		api.multiplayer_peer.close()
		api.multiplayer_peer = null
