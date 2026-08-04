## net_match.gd — 連線對戰的「跨場景一句話」(仿 ArenaPool 的純 static 慣例)
##
## 大廳握手完成時由 net_client.gd 寫入;main.tscn 載入後讀。
## ADR-002:權威搬到 VPS 上的專用伺服器,玩家兩邊都是 client(沒有人當房主)。
## 為什麼不開 autoload?要跨場景傳的只有幾個值,static 活在類別上、
## 換場景不消失,剛剛好(專案慣例:目前沒有 autoload,見 arena_pool.gd)。
class_name NetMatch
extends RefCounted

## 大廳埠:所有玩家先連這裡排配對。房間埠由伺服器另外配(見 ROOM_PORT_BASE)。
const PORT := 8910
const MAX_CLIENTS := 1    # 保留給舊的區網測試路徑(net_battle_test.gd 還在用)

## 房間埠從這裡開始配:第 i 間房 = ROOM_PORT_BASE + i。
## 為什麼房間不共用大廳那個埠?每間房要一條獨立的 MultiplayerAPI 分支
## (RPC 路徑以各自 root_path 為基準解析),一條分支要一個自己的 peer,
## 一個 peer 要一個自己的埠(見 LEARNING_LEDGER §22 的 set_multiplayer)。
const ROOM_PORT_BASE := 8911
const MAX_ROOMS := 20


## 這台機器在牌桌上執哪一側("player" / "enemy")。
## 離線(單機熱座)時維持 "player",牌桌行為完全不變。
## ⚠ 專用伺服器上是空字串:它不屬於任何一側——這讓 CardManager 的
## _acting_locally() 恆為 false,所有行動都走「重放端」(從帳生節點),
## 正是伺服器要的行為(它沒有人在拖牌,不需要出牌端的動畫連續性)。
static var my_side: String = "player"

## 這一局是否為連線對戰(main.tscn 據此鎖視角與操作)。
static var is_online: bool = false

## 這個進程是不是專用伺服器(godot --headless 跑 server_main.gd)。
## CardManager 據此跳過所有視圖工作:不建 UI、不排手牌扇形、不翻視角。
static var is_dedicated_server: bool = false

## 玩家端要連的位址(正式版填網域;本機測試用 127.0.0.1)。
static var server_host: String = "127.0.0.1"

## 配對成功後伺服器指派的房間埠(玩家端從大廳拿到後改連這個)。
static var room_port: int = 0

## 配對成功後伺服器發的入場券:連房間埠時要出示,房間據此決定你執哪一側。
## 為什麼不讓玩家自己報側別?那等於讓 client 決定先後手——改過的 client
## 兩邊都報 "player" 就搶到先手。憑證由伺服器發、伺服器驗,才是權威。
static var join_token: String = ""


## 進入連線狀態(玩家端:大廳配對成功時呼叫)。
static func start_online(side: String) -> void:
	my_side = side
	is_online = true


## 進入專用伺服器狀態(server_main.gd 開機時呼叫一次)。
## side 留空 = 不屬於任何一側,是刻意的(見 my_side 的註解)。
static func start_dedicated_server() -> void:
	my_side = ""
	is_online = true
	is_dedicated_server = true


## 回到離線狀態(進主選單、連線失敗、或斷線時呼叫)。
## 不重設 is_dedicated_server:伺服器進程一輩子都是伺服器,重設會讓
## 開下一間房時退化成玩家端行為。
static func reset() -> void:
	if is_dedicated_server:
		return
	my_side = "player"
	is_online = false
	room_port = 0
