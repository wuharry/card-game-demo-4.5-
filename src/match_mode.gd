## match_mode.gd — 這一局的玩法模式(static 純工具,仿 ArenaPool,不進場景樹)
##
## 職責:跨場景傳「這局是熱座還是單人 vs AI」一句話。
## 主選單設定 → main.tscn 的 CardManager 讀取。
## (連線與否由 NetMatch 表示,這裡不重複;is_vs_ai() 已把「連線優先」收進判斷,
##  下游永遠問 is_vs_ai(),不要自己組合兩個旗標。)
class_name MatchMode
extends RefCounted

enum Mode { HOTSEAT, VS_AI }

## static 活在類別上、不隨場景切換消失(和 ArenaPool.next_arena_path 同一招)。
## 也因此「上一局的值會留著」——主選單每個入口都要明確設定,不能依賴預設。
static var mode: Mode = Mode.HOTSEAT


static func is_vs_ai() -> bool:
	return mode == Mode.VS_AI and not NetMatch.is_online
