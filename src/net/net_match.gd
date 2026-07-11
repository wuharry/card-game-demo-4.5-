## net_match.gd — 連線對戰的「跨場景一句話」(仿 ArenaPool 的純 static 慣例)
##
## 大廳握手完成時由 net_lobby.gd 寫入;main.tscn 載入後讀。
## ADR-001:host 執「player」側且是規則權威;client 執「enemy」側。
## 為什麼不開 autoload?要跨場景傳的只有兩個值,static 活在類別上、
## 換場景不消失,剛剛好(專案慣例:目前沒有 autoload,見 arena_pool.gd)。
class_name NetMatch
extends RefCounted

const PORT := 8910        # ENet 監聽埠(雙方要一致;先寫死,真的撞埠再做成輸入框)
const MAX_CLIENTS := 1    # 1v1:房間只收一個客人


## 這台機器在牌桌上執哪一側("player" = host / "enemy" = client)。
## 離線(單機熱座)時維持 "player",牌桌行為完全不變。
static var my_side: String = "player"

## 這一局是否為連線對戰(2b 起 main.tscn 據此鎖視角與操作)。
static var is_online: bool = false


## 進入連線狀態(大廳握手完成時由 net_lobby 呼叫)。
## 為什麼不讓外面直接指派?經 preload 的 const 類別引用「寫」static 變數
## 會被編譯器當成改常數而擋下(讀和呼叫函式都行)——所以寫的動作收在類別自己身上。
static func start_online(side: String) -> void:
	my_side = side
	is_online = true


## 回到離線狀態(進主選單、連線失敗、或斷線時呼叫)。
static func reset() -> void:
	my_side = "player"
	is_online = false
