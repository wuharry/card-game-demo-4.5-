## match_room.gd — 一間 1v1 對局,是這局的**唯一權威**
##
## 由 game_server.gd 在配對成功時生成。開自己的 ENet 埠、自己的 MultiplayerAPI
## 分支,然後載入完整牌桌(選項 a:只是不畫),讓 BattleManager 的 SLOT_GROUPS
## 群組查詢原封不動可用。
##
## 路徑合約(這支能運作的關鍵,見 LEARNING_LEDGER §22):
##   伺服器這邊 root_path = 本房間節點 → 牌桌的路徑解析成 "MainScene/…"
##   玩家那邊   root_path = /root      → 牌桌的路徑解析成 "MainScene/…"
##   兩邊對得上,所以 CardManager 身上那批 @rpc 不必改路徑就能跨機器成對。
##   ⚠ 因此本節點自己**不收任何 RPC**:玩家那邊的 /root 是 Window,掛不了腳本。
##   玩家 → 伺服器的意圖一律走 CardManager(兩邊都有 MainScene/CardManger)。
##
## 帳在這裡,玩家端是視圖(關卡表第一梯隊 關 2 的最大現場)。
extends Node

signal finished   # 這局結束(收攤或逾時),由 game_server 回收

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

## 兩位玩家都沒連進來就收攤的逾時(秒)。玩家收到配對通知後要換場景、
## 載入牌桌、再連房間埠——給足時間,但不能無限等(不然崩掉的 client 會漏房間)。
const JOIN_TIMEOUT := 60.0

var room_index: int = 0
var room_port: int = 0
var arena_idx: int = 0

## token → 該 token 該執的側別。大廳發 token、房間驗 token:
## 沒有這道驗證,玩家可以在 req_join_room 裡謊報自己是 "player" 搶先手。
var expected: Dictionary = {}

var _peer: ENetMultiplayerPeer = null
var _card_manager: Node = null
var _joined: int = 0
var _elapsed: float = 0.0
var _started: bool = false


func _ready() -> void:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(room_port, 2)
	if err != OK:
		push_error("[ROOM %d] 開埠 %d 失敗(錯誤碼 %d)" % [room_index, room_port, err])
		_peer = null
		return
	# 這間房專屬的 MultiplayerAPI 分支:root_path 設成自己,牌桌就掛在自己底下。
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = _peer
	get_tree().set_multiplayer(api, get_path())
	api.peer_disconnected.connect(_on_player_lost)
	# 牌桌先載入、不等玩家:玩家一連進來就要有 CardManager 在對面接 RPC
	# (它同時是「玩家→伺服器」意圖的收件人,見檔頭路徑合約)。
	var table: Node = MAIN_SCENE.instantiate()
	add_child(table)
	_card_manager = table.find_child("CardManger", true, false)
	if _card_manager == null:
		push_error("[ROOM %d] 牌桌裡找不到 CardManger,路徑合約壞了" % room_index)
		return
	_card_manager.set("net_room", self)
	print("[ROOM %d] 就緒(埠 %d),等兩位玩家連進來…" % [room_index, room_port])


func is_listening() -> bool:
	return _peer != null


func _process(delta: float) -> void:
	if _started:
		return
	_elapsed += delta
	if _elapsed >= JOIN_TIMEOUT:
		print("[ROOM %d] 逾時:只等到 %d/2 位玩家,收攤" % [room_index, _joined])
		close()


## 由 CardManager 在收到玩家的 req_join_room 後回報(它才是 RPC 的收件人)。
## 回傳這個 token 對應的側別;token 不對回空字串 = 拒絕。
func claim_side(token: String, peer_id: int) -> String:
	if not expected.has(token):
		print("[ROOM %d] peer %d 出示的 token 不在名單上,拒絕" % [room_index, peer_id])
		return ""
	var side: String = expected[token]
	expected.erase(token)   # 一張 token 只能用一次(擋重複連線頂掉對手)
	_joined += 1
	print("[ROOM %d] peer %d 就位,執 %s(%d/2)" % [room_index, peer_id, side, _joined])
	if _joined >= 2:
		_started = true
		set_process(false)
		print("[ROOM %d] 兩位玩家到齊,開局" % room_index)
	return side


func _on_player_lost(peer_id: int) -> void:
	print("[ROOM %d] peer %d 斷線 → 這局結束" % [room_index, peer_id])
	close()


func close() -> void:
	set_process(false)
	if _peer != null:
		_peer.close()
		_peer = null
	finished.emit()
