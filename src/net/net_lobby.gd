## net_lobby.gd — 大廳的連線邏輯(無 UI):開房 / 加入 / 握手 / 開局
##
## 掛在 MainMenu 底下、名字固定叫 "NetLobby"。RPC 是「呼叫對面**同路徑**節點上的
## 同名函式」,兩端路徑必須一模一樣——所以這個節點的名字與掛點是合約的一部分。
##
## 流程(ADR-001 host-client):
##   host  :host_game() 開門等人 → peer_connected → 抽牌桌 → _start_match.rpc(...)
##   client:join_game(ip) → connected_to_server(等 host 發令)
##   兩端  :_start_match 寫好共識(NetMatch / ArenaPool)→ 發 match_ready,UI 接手。
##
## 大廳是「用完就丟」的:peer 掛在 SceneTree 的 MultiplayerAPI 上
## (multiplayer.multiplayer_peer),換場景時本節點會死,但**連線不會斷**。
class_name NetLobby
extends Node

signal status_changed(text: String)   # 給 UI 的狀態字(等待加入/連線中/失敗原因…)
signal match_ready                    # 握手完成,雙方可以進牌桌了

## NetMatch 和本檔是同批新檔:用 preload 路徑引用、不用 class_name——
## 新 class_name 要等編輯器重掃才進全域快取,沒進快取前連引用它的腳本都解析失敗(§19)。
const NET_MATCH: GDScript = preload("res://src/net/net_match.gd")
const NET_UPNP: GDScript = preload("res://src/net/net_upnp.gd")


func _ready() -> void:
	# 回到主選單 = 放棄任何舊連線(打完一場回來、或上次連到一半就按返回)。
	# ⚠ 賦 null ≠ 還原成 OfflineMultiplayerPeer:null 是「沒有 peer」,之後任何
	# .rpc() 都會報錯且不執行——所以離線的換頁令在 card_manager 走本地直呼,不走 rpc。
	multiplayer.multiplayer_peer = null
	NET_MATCH.reset()
	# 上一局若開過 UPnP 洞,對局中大廳早死了沒人拆——回到主選單由新大廳收殘局。
	NET_UPNP.close(NET_MATCH.PORT)
	set_process(false)   # 輪詢只在「開房後等打洞結果」期間打開
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## 開房:建立 ENet 伺服器,等一位客人。回傳 OK 或錯誤碼(UI 據此鎖按鈕)。
func host_game() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(NET_MATCH.PORT, NET_MATCH.MAX_CLIENTS)
	if err != OK:
		status_changed.emit(
			"開房失敗(埠 %d 可能被占用,錯誤碼 %d)" % [NET_MATCH.PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
	status_changed.emit(
		"房間已開,等朋友加入…(埠 %d)\n同網路朋友連:%s\n正在向路由器申請異地通道…"
		% [NET_MATCH.PORT, local_ipv4()])
	# 異地連線:非同步向路由器打洞(discover 會阻塞 1~2 秒,不能凍住選單),
	# 結果用 _process 輪詢取回(執行緒裡 call_deferred 到不了主執行緒,見 net_upnp.gd)。
	NET_UPNP.open(NET_MATCH.PORT)
	set_process(true)
	return OK


## 輪詢打洞結果:有結果的那一幀關掉輪詢、轉交 _on_upnp_done。
func _process(_delta: float) -> void:
	var r: Array = NET_UPNP.take_result()
	if r.is_empty():
		return
	set_process(false)
	_on_upnp_done(r[0], r[1])


## UPnP 打洞結果(慢半拍回來,可能已時過境遷——先驗自己還在開房)。
func _on_upnp_done(ok: bool, message: String) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		NET_UPNP.close(NET_MATCH.PORT)   # 洞開好時人已取消開房:直接拆掉
		return
	var head := "房間已開,等朋友加入…(埠 %d)\n同網路朋友連:%s\n" % [
		NET_MATCH.PORT, local_ipv4()]
	if ok:
		status_changed.emit(head + "異地朋友連:%s(已自動打洞)" % message)
	else:
		status_changed.emit(head + "異地通道失敗:%s\n→ 備案:路由器手動轉發 UDP %d,或雙方裝 Tailscale 組虛擬區網"
			% [message, NET_MATCH.PORT])


## 加入:向房主發起連線。成功只代表「開始連」,結果看 connected/failed 信號。
func join_game(ip: String) -> Error:
	var target := ip.strip_edges()
	if target.is_empty():
		status_changed.emit("請先輸入房主的 IP(同一台電腦測試用 127.0.0.1)")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target, NET_MATCH.PORT)
	if err != OK:
		status_changed.emit("無法發起連線(IP 格式錯了?錯誤碼 %d)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	status_changed.emit("連線中:%s…" % target)
	return OK


## 收攤:關閉連線、回到離線狀態(按「返回」或連線失敗時)。
func cancel() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	NET_MATCH.reset()
	NET_UPNP.close(NET_MATCH.PORT)   # 不當房主了,把路由器上的洞拆掉
	set_process(false)


## 找一個能念給朋友的區網 IPv4(192.168.* / 10.* 優先);找不到就回 127.0.0.1。
## 機器常同時掛好幾個位址(VPN、虛擬網卡),挑「最像家用區網」的那個顯示。
static func local_ipv4() -> String:
	var candidates: Array[String] = []
	for addr in IP.get_local_addresses():
		if addr.count(".") == 3 and not addr.begins_with("127."):
			candidates.append(addr)
	for addr in candidates:
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	if not candidates.is_empty():
		return candidates[0]
	return "127.0.0.1"


## ── multiplayer 信號 ────────────────────────────────


## 有 peer 連上(host、client 兩邊都會收到:client 連上時會收到代表 host 的 1 號)。
## 只有 host 有資格發開局令——順便完成第一次「亂數只在 host、結果廣播」(ADR-001):
## 這一局的牌桌由 host 抽,client 從 RPC 參數拿結果,兩台才會進同一張桌。
func _on_peer_connected(_id: int) -> void:
	if not multiplayer.is_server():
		return
	var idx := ArenaPool.ARENAS.find(ArenaPool.pick_random())
	_start_match.rpc(idx)


func _on_connected_to_server() -> void:
	status_changed.emit("已連上房主,等待開局…")


func _on_connection_failed() -> void:
	cancel()
	status_changed.emit("連不上:確認房主已開房、IP 沒打錯;同網路用「同網路」那個 IP、異地用「異地」那個(房主畫面上有)。")


func _on_server_disconnected() -> void:
	cancel()
	status_changed.emit("房主離線了,請重新加入。")


## 開局令(host → 兩端)。@rpc 三個參數:
##   "authority"  = 只有權威(host)有資格呼叫,client 偽造會被丟棄
##   "call_local" = host 自己也執行一份(不然只有 client 開局)
##   "reliable"   = 走可靠傳輸,開局令不容掉包
@rpc("authority", "call_local", "reliable")
func _start_match(arena_idx: int) -> void:
	var safe_idx := clampi(arena_idx, 0, ArenaPool.ARENAS.size() - 1)
	ArenaPool.next_arena_path = ArenaPool.ARENAS[safe_idx]
	NET_MATCH.start_online("player" if multiplayer.is_server() else "enemy")
	status_changed.emit("對手已就位,進入牌桌…")
	match_ready.emit()
