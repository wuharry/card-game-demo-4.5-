## opponent_hand.gd — 對手手牌的卡背小扇形(純視覺,不含任何卡片資料)
##
## 職責:在對手本體後上方,用 N 張卡背擺一排縮小的手牌;
##   update_count(n) 由 CardManager 在帳變動時呼叫(和右上 HUD 數字同一個觸發點)。
## 單人 vs AI 與連線模式共用——順便還掉「對手卡背扇形未做」這筆債。
## 卡背用 BILLBOARD_FIXED_Y(直立、水平面向鏡頭):host 和翻轉視角的 client
## 各自的鏡頭都能正對卡背,不用為兩種視角寫兩套朝向。
class_name OpponentHand
extends Node3D

## 卡背由 Card 供應(和卡面同一張圖集),別各自 preload 各自的圖——
## 兩邊分開拿的下場就是換了卡面沒換卡背,正面像素風、背面手繪風。
static var BACK_TEXTURE: Texture2D = Card.make_back_texture()
const MAX_SHOWN := 8          # 手牌上限 8(§1),卡背最多也就 8 張
const BACK_WIDTH := 0.62      # 每張卡背的世界寬度(縮小版,別跟本體搶戲)
const SPACING := 0.34         # 相鄰卡背的水平間距(疊出「一手牌」的密度)

var _backs: Array[Sprite3D] = []


## 開局定位:擺在對手本體「身後偏上」(side 決定「後方」是 -Z 還是 +Z)。
## y 壓在本體頭部高度:卡背在更遠的 z、由深度排序畫在本體後面,
## 讀起來像「手持在背後的一手牌」;太高會壓到 HP 標籤、還被畫面上緣裁掉。
func setup_at(hero_anchor: Vector3, side: String) -> void:
	var back_dir := -0.6 if side == "enemy" else 0.6
	global_position = hero_anchor + Vector3(0.0, 1.35, back_dir)


## 帳變動時刷新張數:卡背節點做一次、之後只切 visible(量級小,免物件池)。
func update_count(n: int) -> void:
	n = clampi(n, 0, MAX_SHOWN)
	while _backs.size() < n:
		_backs.append(_make_back(_backs.size()))
	for i in _backs.size():
		_backs[i].visible = i < n
	# 置中排開 + 兩端微微下垂,讀起來像一手牌而不是一列磚
	var center := (n - 1) / 2.0
	for i in n:
		_backs[i].position = Vector3(
			(i - center) * SPACING,
			-0.05 * absf(i - center),
			0.0
		)


func _make_back(order: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = BACK_TEXTURE
	s.pixel_size = BACK_WIDTH / maxf(float(BACK_TEXTURE.get_width()), 1.0)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS   # 寫深度,DOF 才不會拿背後森林糊它
	# 透明排序防閃:右邊的牌固定畫在左邊的上面(和玩家手牌扇形同一個疊法)
	s.render_priority = order
	add_child(s)
	return s
