extends SceneTree
## UPnP 打洞探針:走真程式路徑(NetLobby.host_game → 輪詢打洞結果 → cancel 拆洞),
## 在「目前所在的網路」實測路由器支不支援。結果依網路而異——這不是 CI 測試,
## 是帶去任何新環境(家裡/公司/咖啡廳)先跑一次的體檢工具。
## ⚠ discover 實測可拖到 ~10 秒(多網卡逐一探測),所以上限給 25 秒。
## 用法:godot --headless --path . -s tests/upnp_probe.gd

var _done := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lobby := (load("res://src/net/net_lobby.gd") as GDScript).new() as Node
	root.add_child(lobby)
	await process_frame
	lobby.status_changed.connect(func(t: String) -> void:
		print("── 大廳狀態字 ──")
		print(t)
		if t.contains("異地朋友連") or t.contains("異地通道失敗"):
			_done = true)
	var err: int = lobby.host_game()
	if err != OK:
		print("FAIL: host_game err=%d" % err)
		quit(1)
		return
	for i in 50:   # 最多 25 秒,有結果就提前結束
		if _done:
			break
		await create_timer(0.5).timeout
	print("── 探針結果 ──")
	print("mapped=%s external_ip=%s" % [NetUpnp.mapped, NetUpnp.external_ip])
	if not _done:
		print("FAIL: 25 秒內沒有拿到打洞結果")
	lobby.cancel()
	await create_timer(2.0).timeout
	print("cancel 後 mapped=%s(應為 false,洞已拆)" % NetUpnp.mapped)
	NetUpnp.join_pending()   # 等拆洞執行緒收尾,quit 才不會警告
	quit(0 if _done else 1)
