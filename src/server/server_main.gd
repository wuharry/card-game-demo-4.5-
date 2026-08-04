## server_main.gd — 專用伺服器的進入點(VPS 上唯一常駐的進程)
##
## 用法(本機開發):
##   godot --headless -s src/server/server_main.gd
##   godot --headless -s src/server/server_main.gd -- --port 8910
##
## 為什麼是 `extends SceneTree` 而不是一個 .tscn 主場景?
##   1. `.tscn` 由編輯器維護,手寫會讓 UID 對不上(專案雷區,見 CLAUDE.md §2)
##   2. 伺服器沒有「畫面」要擺,一個 .tscn 只是空殼
##   3. 專案已有這個慣例:tests/ 底下八支 headless 腳本都是這樣跑的
##
## 匯出到 VPS 時的兩條路(等真要部署再選,本機驗證不需要):
##   (A) 匯出 Linux dedicated server 的 .pck,用
##       ./godot_server --headless --main-pack game.pck -s res://src/server/server_main.gd
##   (B) 或在 project.godot 另設一個 main scene 分流 OS.has_feature("dedicated_server")
extends SceneTree

const GAME_SERVER := preload("res://src/server/game_server.gd")


func _initialize() -> void:
	NetMatch.start_dedicated_server()
	var port := _arg_int("--port", NetMatch.PORT)
	var server: Node = GAME_SERVER.new()
	server.name = "GameServer"      # 名字是 RPC 合約的一部分(見 game_server.gd)
	server.lobby_port = port
	root.add_child(server)
	print("[SERVER] 專用伺服器啟動,大廳埠 %d(Ctrl+C 停止)" % port)


## 讀 `-- --port 8910` 這種使用者參數(-- 之後的才是給遊戲的,不是給引擎的)。
func _arg_int(key: String, fallback: int) -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find(key)
	if i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int():
		return int(args[i + 1])
	return fallback
