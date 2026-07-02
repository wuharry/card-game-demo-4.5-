class_name ArenaPool
extends RefCounted
# arena_pool.gd — 牌桌環境抽籤桶(純靜態工具,不實例化、不進場景樹)
#
# 流程:主選單按「開始遊戲」→ pick_random() 抽一個環境路徑存進 next_arena_path
#       → 切到 main.tscn → main_scene.gd 在 _ready 讀它,決定要不要換環境。
#
# 為什麼用 static 而不用 autoload 單例?
#   專案慣例是「目前沒有 autoload」。static 變數活在「類別」上、跟場景樹無關,
#   換場景不會消失——拿來跨場景傳「一句話」剛剛好,不必為此開一個常駐節點。
#   (若之後要傳的東西變多——玩家進度、牌組——再升級成 autoload 也不遲。)

## 牌桌環境池:做出新牌桌場景後,把路徑加進來就自動進入隨機輪替。
const ARENAS: Array[String] = [
	"res://scenes/arena_forest.tscn",      # 森林(流動的溪 + PSX 樹)
	"res://scenes/arena_caverns.tscn",     # 洞窟(發光蘑菇 + 鐘乳石)
	"res://scenes/arena_frostlands.tscn",  # 冰原(結冰的河 + 雪松)
]

## main.tscn 裡「烤死」的預設環境:抽到它就什麼都不用換,直接用場景裡現成的。
const DEFAULT_ARENA := "res://scenes/arena_forest.tscn"

## 這一局要用的環境路徑;空字串 = 還沒抽過(例如開發時直接 F6 跑牌桌)。
static var next_arena_path: String = ""


## 抽一個環境(均等機率),存起來並回傳。
static func pick_random() -> String:
	next_arena_path = ARENAS.pick_random()
	return next_arena_path
