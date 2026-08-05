## game_server.gd — 專用伺服器的門房(大廳:接客、配對、開房、收房)
##
## 進入點:src/server/server_main.gd(godot --headless -s …)
## 取代 ADR-001 的「玩家當房主」:沒有人需要被連進來,兩位玩家都是 client
## 主動往外連,所以 NAT 不必打洞(net_upnp.gd 因此退場)。
##
## RPC 路徑合約(這支能運作的關鍵,見 LEARNING_LEDGER §22):
##   RPC 是「叫對面**同路徑**節點跑同名函式」,而路徑是相對各自 root_path 解析的。
##   伺服器這邊 root_path = 本節點(/root/GameServer)、
##   玩家那邊 root_path = NetClient 節點(/root/MainMenu/NetClient)——
##   兩邊的 RPC 目標都是「root_path 自己」,所以路徑一律解析成空路徑,對得上。
##   ⚠ 因此本節點與 NetClient 的 @rpc 函式**名稱與簽名必須成對**,改一邊會靜默失效。
##
## 引用同批新檔一律用 preload 路徑存 const,不用 class_name
## ——新 class_name 要等編輯器重掃才進全域快取(見 LEARNING_LEDGER §22)。
extends Node

const MATCH_ROOM := preload("res://src/server/match_room.gd")

## 由 server_main.gd 在 add_child 之前指定。
var lobby_port: int = NetMatch.PORT

## 等配對的 peer id(先進先配;1v1 所以湊到兩個就開房)。
var _queue: Array[int] = []
## 房間索引 → MatchRoom 節點。索引決定埠號(ROOM_PORT_BASE + index),
## 用字典而不是陣列:房間會中途結束,索引要能挖洞重用而不影響其他房。
var _rooms: Dictionary = {}
## peer id → 它所屬的房間索引(斷線時要知道去哪間房報喪)。
var _peer_room: Dictionary = {}


func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(lobby_port, NetMatch.MAX_ROOMS * 2)
	if err != OK:
		push_error("[SERVER] 大廳開埠 %d 失敗(錯誤碼 %d)" % [lobby_port, err])
		get_tree().quit(1)
		return
	# 大廳專屬的 MultiplayerAPI 分支:root_path 設成自己,讓路徑合約成立(見檔頭)。
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = peer
	get_tree().set_multiplayer(api, get_path())
	api.peer_disconnected.connect(_on_peer_left)
	print("[SERVER] 大廳就緒(埠 %d),等玩家排隊…" % lobby_port)


## ── 玩家 → 伺服器的意圖 ──────────────────────────────
##
## 「我要配對」。@rpc 三參數:any_peer(玩家才是發起方)/ 不 call_local
## (伺服器自己不排隊)/ reliable(配對請求不容掉包)。
@rpc("any_peer", "reliable")
func req_find_match() -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0 or _queue.has(id) or _peer_room.has(id):
		return   # 重複請求 / 已經在房裡:丟棄(伺服器對重複意圖一律無反應)
	_queue.append(id)
	print("[SERVER] peer %d 進佇列(%d 人等)" % [id, _queue.size()])
	_try_pair()


## ── 伺服器 → 玩家的結果 ──────────────────────────────
##
## 由伺服器單方發出,玩家端實作在 net_client.gd 的同名函式。
## authority:玩家偽造這則訊息會被丟棄(它不是權威)。
@rpc("authority", "reliable")
func on_room_assigned(_room_port: int, _side: String, _arena_idx: int, _token: String) -> void:
	pass   # 伺服器端不執行,實作在 NetClient(路徑合約成對,見檔頭)


@rpc("authority", "reliable")
func on_queue_status(_waiting: int) -> void:
	pass   # 同上


## ── 配對 ──────────────────────────────────────────
func _try_pair() -> void:
	if _queue.is_empty():
		return
	if _queue.size() < 2:
		on_queue_status.rpc_id(_queue[0], _queue.size())
		return
	var idx := _free_room_index()
	if idx < 0:
		print("[SERVER] 房間已滿(%d 間),佇列繼續等" % NetMatch.MAX_ROOMS)
		return
	# 先取出兩人再開房:開房失敗要能把他們放回佇列前面,不能已經 pop 掉又沒房。
	var a: int = _queue[0]
	var b: int = _queue[1]
	var port := NetMatch.ROOM_PORT_BASE + idx
	# 亂數只在伺服器發生(ADR-001 第 3 條唯一沒被推翻的部分):
	# 牌桌由伺服器抽、把「結果」(index)發給兩人,否則兩台各抽各的。
	var arena_idx := ArenaPool.ARENAS.find(ArenaPool.pick_random())
	# 入場券:房間憑它決定誰執哪一側。玩家自己報側別 = 讓 client 決定先後手,
	# 改過的 client 兩邊都報 "player" 就搶到先手 → 憑證必須由伺服器發、伺服器驗。
	var token_a := _new_token()
	var token_b := _new_token()
	var room: Node = MATCH_ROOM.new()
	room.name = "Room_%d" % idx
	room.room_index = idx
	room.room_port = port
	room.arena_idx = arena_idx
	room.expected = {token_a: "player", token_b: "enemy"}
	room.finished.connect(_on_room_finished.bind(idx))
	# ⚠ 房間掛在 /root 底下,**不能**掛在自己底下:Godot 不允許在「已配置
	# MultiplayerAPI 的節點」的子路徑再設一條分支(大廳的分支就設在本節點上),
	# 掛成子節點會得到 "Multiplayer is already configured for a parent of this path"。
	get_tree().root.add_child(room)
	if not room.is_listening():
		room.queue_free()
		print("[SERVER] 房間 %d 開埠 %d 失敗,兩人留在佇列" % [idx, port])
		return
	_queue.remove_at(1)
	_queue.remove_at(0)
	_rooms[idx] = room
	_peer_room[a] = idx
	_peer_room[b] = idx
	# 誰執哪一側:先排隊的執 "player"(先手)。這是唯一的先後手來源,
	# 兩位玩家都不參與決定——避免「兩邊都認為自己先手」。
	on_room_assigned.rpc_id(a, port, "player", arena_idx, token_a)
	on_room_assigned.rpc_id(b, port, "enemy", arena_idx, token_b)
	print("[SERVER] 配對成功:peer %d(player) vs peer %d(enemy) → 房間 %d 埠 %d"
		% [a, b, idx, port])


## 入場券:夠亂就好(它只要在這間房開著的幾分鐘內猜不到)。
## 不用 crypto 級隨機的理由——猜中也只能搶到先手,不能偽造出牌(那由伺服器驗帳)。
func _new_token() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]


func _free_room_index() -> int:
	for i in NetMatch.MAX_ROOMS:
		if not _rooms.has(i):
			return i
	return -1


## ── 收攤 ──────────────────────────────────────────
func _on_peer_left(id: int) -> void:
	_queue.erase(id)
	# 已配對但還沒連進房間就跑掉:房間會自己因湊不齊而逾時收攤(見 match_room.gd)。
	_peer_room.erase(id)
	print("[SERVER] peer %d 離開大廳" % id)


func _on_room_finished(idx: int) -> void:
	var room: Node = _rooms.get(idx)
	if room != null:
		room.queue_free()
	_rooms.erase(idx)
	for id in _peer_room.keys():
		if _peer_room[id] == idx:
			_peer_room.erase(id)
	print("[SERVER] 房間 %d 收攤,埠 %d 釋出" % [idx, NetMatch.ROOM_PORT_BASE + idx])
	_try_pair()   # 有房了,看佇列還有沒有人等
