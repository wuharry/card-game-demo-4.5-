## net_upnp.gd — 向路由器申請「對外打洞」(UPnP 端口轉發),讓不同區網的朋友連進來
##
## 背景:家用機器只有區網 IP(192.168.*),對外只有路由器那顆「對外 IP」。
## 朋友連「對外 IP:埠」時封包到路由器就停了——路由器不知道該轉給哪台機器。
## UPnP = 程式對路由器說「8910 埠的 UDP 進來都轉給我」;打完洞,對外 IP 才有意義。
##
## 洞是「路由器的狀態」,不隨遊戲進程/場景死活——所以整包列管在 static 上
## (仿 ArenaPool / NetMatch 的跨場景慣例):對局中大廳節點死了洞要留著,
## 回主選單時由新大廳的 _ready 檢查殘洞拆掉。
##
## 執行緒模型:discover() 標稱 2 秒,實測在多網卡的 Mac 上可拖到 ~10 秒
## (逐介面廣播找路由器)——所以一定開 Thread 跑,絕不能擋主執行緒。
## 結果由主執行緒**輪詢** take_result() 取回:這是官方 Thread 教學的正統做法
## (is_alive() 輪詢 + wait_to_finish() 拿回傳值),比執行緒裡 call_deferred
## 回打主執行緒好推理——回呼何時送達取決於佇列沖刷時機,輪詢則每幀確定檢查。
class_name NetUpnp
extends RefCounted

const PROTO := "UDP"   # ENet 走 UDP;TCP 的洞打了也沒用

static var external_ip: String = ""   # 查到的對外 IP("" = 還沒查到/失敗)
static var mapped: bool = false       # 路由器上現在有沒有我們開的洞
static var _upnp: UPNP = null         # 拆洞要用「已 discover 過」的同一個實例
static var _thread: Thread = null


## 開洞(非同步)。發起後由呼叫方每幀輪詢 take_result()。
static func open(port: int) -> void:
	_join_thread()   # 上一件事若還在跑,最多等 2 秒(連點開房/取消才會遇到)
	_thread = Thread.new()
	if mapped and not external_ip.is_empty():
		var ip := external_ip   # 上一局的洞還開著:沿用,走同一條輪詢通道回報
		_thread.start(func() -> Array: return [true, ip])
	else:
		_thread.start(func() -> Array: return _open_blocking(port))


## 主執行緒輪詢:還沒好回 [];好了回 [ok: bool, message: String] 並收乾淨執行緒。
## ok=true 時 message 是對外 IP;false 時是人話的失敗原因。
static func take_result() -> Array:
	if _thread == null or _thread.is_alive():
		return []
	var r: Variant = _thread.wait_to_finish()
	_thread = null
	# 拆洞執行緒的回傳不是結果(空陣列),過濾掉,只放行 [ok, message] 形狀的
	return r if (r is Array and (r as Array).size() == 2) else []


## 拆洞(非同步)。沒開過就是 no-op;取消開房/回主選單時呼叫。
## race 備註:open 還在跑時取消 → 這裡看到 mapped=false 直接走人;
## 洞若稍後才開好,由大廳的輪詢回呼(見 _on_upnp_done 的早退分支)收殘局。
static func close(port: int) -> void:
	if not mapped:
		return
	_join_thread()   # mapped=true 代表 open 執行緒已收尾,這裡瞬回
	mapped = false
	external_ip = ""
	var upnp := _upnp
	_upnp = null
	_thread = Thread.new()
	_thread.start(func() -> Array:
		upnp.delete_port_mapping(port, PROTO)
		return [])


## 等背景工作收尾(測試腳本 quit 前呼叫,免得執行緒未 join 的警告)。
static func join_pending() -> void:
	_join_thread()


static func _join_thread() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## 真正的打洞流程(在 Thread 裡跑,全程阻塞沒關係)。回 [ok, message]。
static func _open_blocking(port: int) -> Array:
	var upnp := UPNP.new()
	var err := upnp.discover()
	if err != UPNP.UPNP_RESULT_SUCCESS:
		return [false, "找不到支援 UPnP 的路由器(錯誤 %d)" % err]
	if upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		return [false, "路由器不支援 UPnP(或該功能被關閉)"]
	var ip := upnp.query_external_address()
	if ip.is_empty():
		return [false, "查不到對外 IP"]
	# CGNAT 偵測:「對外 IP」竟然還是私有位址 = 電信商在你的路由器外面又包了
	# 一層 NAT(RFC 6598),打自家路由器的洞沒有用,直說並提示備案。
	if _is_private(ip):
		return [false, "電信商是 CGNAT(對外 IP %s 仍是內部位址),打洞無效" % ip]
	var map_err := upnp.add_port_mapping(port, port, "CardGameDemo", PROTO, 0)
	if map_err != UPNP.UPNP_RESULT_SUCCESS:
		return [false, "路由器拒絕開洞(錯誤 %d)" % map_err]
	_upnp = upnp
	external_ip = ip
	mapped = true
	return [true, ip]


## 私有/保留位址判定:10.* / 192.168.* / 172.16~31.* / 100.64~127.*(CGNAT 段)
static func _is_private(ip: String) -> bool:
	if ip.begins_with("10.") or ip.begins_with("192.168."):
		return true
	var parts := ip.split(".")
	if parts.size() != 4:
		return true   # 格式不對,當不可用
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 172 and b >= 16 and b <= 31:
		return true
	if a == 100 and b >= 64 and b <= 127:
		return true
	return false
