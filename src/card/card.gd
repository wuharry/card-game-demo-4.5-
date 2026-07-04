## card.gd — 一張「卡片」的大腦
##
## 這支腳本掛在 card.tscn 的根節點 (Node3D) 上。
## 一張卡片在場景樹大概長這樣：
##   Card (Node3D, 掛這支腳本)
##   ├─ CardImage (Sprite3D)         ← 卡面圖
##   └─ Area3D                       ← 偵測滑鼠的感應區
##      └─ CollisionShape3D          ← 感應區的實際形狀(方塊)
##
## 它負責三件事：
##   1. 滑鼠移到卡片上 / 離開時，對外發出「信號」(signal) 通知別人。
##   2. 提供放大 / 縮小的動畫方法，讓 CardManager 決定何時播放。
##   3. 提供「鎖定 / 解鎖」方法，控制這張卡能不能被滑鼠抓取。

extends Node3D
## class_name 會把 Card 註冊成一個「全域型別」。
## 好處：其他腳本可以寫 var c: Card，並享有自動補全與型別檢查。
class_name Card


## ── 信號 (signal) ──────────────────────────────
## 信號就像「廣播」：這張卡不直接去呼叫別人，而是大喊一聲，
## 有訂閱的人 (這裡是 PlayerHand → CardManager) 自然會收到。
## 括號裡的 card: Card 代表廣播時會「附帶」自己這張卡，方便接收方知道是誰。
signal card_hovered(card: Card)
signal card_unhovered(card: Card)

## 記住卡片「原本的大小」。因為放大動畫是以原始大小為基準去乘倍數，
## 若不記住、每次都拿當下大小再放大，多播幾次就會越變越大而失真。
var original_scale: Vector3 = Vector3.ONE

## 這張卡目前套用的資料(由發牌端透過 setup() 餵入)。
## CardData = 純資料的 Resource(見 card_data.gd)；Card 只負責把它「顯示出來」。
@export var data: CardData

## ── 卡框挖空窗(卡圖要塞進去的那塊)──────────────
## 卡框 NewCard.png 上半部有一塊「透明挖空」的卡圖窗,以下常數是用 alpha 掃描
## 量出來的實際範圍(像素 x 40..334、y 59..265),換算成卡片本地座標。
## 換了卡框圖的話,這三個常數要重量(掃透明區的位置)。
const ART_WINDOW_CENTER := Vector2(0.022, 0.488)   # 窗中心(卡片本地 x/y)
const ART_WINDOW_SIZE := Vector2(1.297, 0.910)     # 窗寬高(世界單位)
const ART_BLEED := 1.06   # 出血:圖比窗大 6%,邊緣藏到卡框後面,接縫處不漏底

## 立牌「角色可見高度」(世界單位)。召喚時會掃描角色圖的不透明範圍,
## 把「看得見的身體」縮放到正好這個高度——素材格子的透明留白不參與計算,
## 所以不管素材留白多少、解析度多少,角色在卡上的份量都一致。
## 卡片在槽上長 1.92(原生 2.4 × slot_scale 0.8),1.3 ≈ 卡長的 2/3,
## 接近 ideal_layout 參考圖的角色/卡片比例。想更大/小隻就調這個數字。
@export var standee_char_height: float = 1.3

## 上桌立牌(召喚時站在卡片上的像素角色;只在入槽時存在)。
var _standee: Sprite3D = null


## _ready() 是 Godot 的生命週期函式：節點一進入場景、準備好時自動執行一次。
func _ready() -> void:
	# 把「進場時的縮放」存起來當基準。
	# scale 是每個 3D 節點都有的內建屬性，對應 Inspector 的 Transform → Scale。
	original_scale = scale


## ── 套用卡片資料 ─────────────────────────────────
## 由發牌端呼叫：PlayerHand 抽到一份 CardData → card.setup(data) → 卡面顯示該卡。
## 一份資料可以餵給很多張卡(資料與場上物件分離，見 card_data.gd 開頭的說明)。
func setup(card_data: CardData) -> void:
	data = card_data
	$NameLabel.text = data.card_name
	$CostLabel.text = str(data.cost)   # Label3D 的 text 只吃字串，int 要用 str() 轉
	$ATKLabel.text = str(data.atk)
	$HPLabel.text = str(data.hp)
	$CardArt.texture = data.art
	# ── 卡圖「塞進卡框挖空窗」:蓋滿窗、超出裁掉、永遠壓不到卡框美術 ──
	# 關鍵:卡圖擺在卡框「後面」(z = -0.01),從透明挖空處露出來——
	# 框的邊飾永遠畫在圖上面,所以不管圖多大,卡框美術都不會被改到。
	var tex_w := maxf(float(data.art.get_width()), 1.0)    # maxf 防呆:除以零
	var tex_h := maxf(float(data.art.get_height()), 1.0)
	if tex_w <= 128.0:
		# 像素佔位圖:整張塞進窗內(contain,不裁切),鄰近取樣保銳利格子。
		$CardArt.region_enabled = false
		$CardArt.pixel_size = minf(ART_WINDOW_SIZE.x / tex_w, ART_WINDOW_SIZE.y / tex_h)
		$CardArt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		# AI 繪畫圖:aspect-fill——縮放取「剛好蓋滿窗」的倍率,超出窗的部分
		# 用 region(裁切框)切掉。窗是橫式、圖是直式 3:4 → 上下會被裁;
		# 裁切框垂直「偏上」(0.30 而非置中 0.5):人像的頭在上半,置中裁會切頭。
		var fit := maxf(ART_WINDOW_SIZE.x * ART_BLEED / tex_w,
			ART_WINDOW_SIZE.y * ART_BLEED / tex_h)   # 單位/像素
		$CardArt.pixel_size = fit
		var crop_w := ART_WINDOW_SIZE.x * ART_BLEED / fit   # 換算回:窗需要幾「像素」
		var crop_h := ART_WINDOW_SIZE.y * ART_BLEED / fit
		$CardArt.region_enabled = true
		$CardArt.region_rect = Rect2(
			(tex_w - crop_w) * 0.5,    # 水平置中
			(tex_h - crop_h) * 0.30,   # 垂直偏上保頭部
			crop_w, crop_h)
		$CardArt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 擺到窗中心、退到卡框後 0.01(透明物件由遠到近畫:後面的圖先畫、框蓋在上)。
	$CardArt.position = Vector3(ART_WINDOW_CENTER.x, ART_WINDOW_CENTER.y, -0.01)


## ── 召喚立牌:像素角色站在卡片上(遊戲王式)────────────
## 由 CardSlot 在卡片入槽躺平後呼叫;取出時呼叫 hide_standee() 收掉。
func show_standee() -> void:
	hide_standee()   # 防呆:重複召喚先清掉舊立牌,不然會疊兩隻
	if data == null or data.standee == null:
		return   # 沒資料的空殼卡(或沒立牌圖)就不站東西
	_standee = Sprite3D.new()
	_standee.texture = data.standee
	# 動畫表是「一橫條、每格正方形」:幀數 = 圖寬 ÷ 圖高(這批素材都是 6 格)。
	# hframes 告訴 Sprite3D「這張圖橫向切幾格」,之後改 frame 就能換格播動畫。
	var sheet_h := maxf(1.0, float(data.standee.get_height()))   # maxf 防呆:除以零
	var frame_count := maxi(1, int(float(data.standee.get_width()) / sheet_h))
	_standee.hframes = frame_count
	_standee.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 像素角色要銳利
	# billboard FIXED_Y:永遠面向鏡頭、但只繞垂直軸轉(保持直立)——
	# 歧路旅人立牌的核心;素材只有單一朝向、沒有背面,靠這招四面八方都好看。
	_standee.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# ── 量出角色的「可見範圍」:大小與腳位都以它為準 ──────────
	# 素材每格 100×100 裡,角色本體只佔中間約 30px,其餘是透明留白;
	# 按「整格」算大小,角色會只剩帳面的三分之一、還因置中錨定而懸空。
	# 解法:掃第 0 幀的 alpha,找出最上/最下的不透明像素列——
	# 「可見高度」拿來算縮放,「最下列 = 腳底」拿來把腳貼到卡面。
	var top_row := 0.0
	var feet_row := sheet_h - 1.0   # 掃不到時的預設:當作整格都是身體
	var img := data.standee.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()   # VRAM 壓縮貼圖要先解壓,get_pixel 才讀得到
		var cell := int(sheet_h)
		var min_y := -1
		var max_y := -1
		for y in range(cell):
			for x in range(cell):   # 只掃第 0 幀(x 0..cell-1)
				if img.get_pixel(x, y).a > 0.1:
					if min_y < 0:
						min_y = y   # 第一次遇到不透明 = 最上緣(頭頂)
					max_y = y       # 持續更新 = 最後一次就是最下緣(腳底)
					break           # 這一列確定有身體,跳下一列
		if max_y >= 0:
			top_row = float(min_y)
			feet_row = float(max_y)
	var visible_px := maxf(1.0, feet_row - top_row + 1.0)

	# 縮放:讓「看得見的身體」正好 standee_char_height 這麼高(留白不算數)。
	var px_size := standee_char_height / visible_px
	_standee.pixel_size = px_size
	add_child(_standee)
	# 卡片在槽裡是「躺平」的(躺平來自父節點 PlayerHand 的 -90°X,card_slot 只是轉正),
	# 所以卡片的 local +Z = 世界正上方。節點要抬的高度 = 「腳底列到格子中心」的
	# 距離 + 一點縫,視覺的腳就正好踩在卡面上(不會再懸空)。
	_standee.position = Vector3(0.0, 0.0, (feet_row + 1.0 - sheet_h * 0.5) * px_size + 0.02)
	# 召喚彈出:從極小放大回 1;BACK + EASE_OUT = 微微過衝再回彈,有「登場」感。
	_standee.scale = Vector3.ONE * 0.05
	var pop := _standee.create_tween()
	pop.tween_property(_standee, "scale", Vector3.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 待機動畫:每 0.12 秒切下一格,set_loops() 無限循環 → 角色站在卡上「活著」。
	# tween 綁在 _standee 節點上,立牌被 free 時動畫自動跟著停,不會漏。
	var anim := _standee.create_tween().set_loops()
	for f in range(frame_count):
		anim.tween_callback(func() -> void: _standee.frame = f).set_delay(0.12)


## 收掉立牌(卡片被取出卡槽時由 CardSlot 呼叫)。
func hide_standee() -> void:
	if _standee != null:
		_standee.queue_free()
		_standee = null


## ── 滑鼠事件 → 轉成信號對外廣播 ──────────────────
## 這兩個函式是被 Area3D 的 mouse_entered / mouse_exited 信號呼叫的。
## (連接設定在 card.tscn 的 [connection] 區段，等同 Inspector 的 Node→Signals 面板手動連線)
func _on_area_3d_mouse_entered() -> void:
	# emit() = 把信號發射出去；self 代表「這張卡自己」。
	card_hovered.emit(self)

func _on_area_3d_mouse_exited() -> void:
	card_unhovered.emit(self)


## ── 動畫方法(由 CardManager 決定何時呼叫)──────────
## 把「要不要放大」的決策權交給 Manager，卡片只負責「怎麼放大」。
func animate_hover() -> void:
	# create_tween() 會建立一個補間動畫器：在一段時間內把某個屬性平滑地變化。
	var tw := create_tween()
	# 把 scale 在 0.15 秒內，從現在平滑變到「原始大小 × 1.2」(放大兩成)。
	tw.tween_property(self, "scale", original_scale * 1.2, 0.15)

func animate_unhover() -> void:
	var tw := create_tween()
	# 0.15 秒內縮回原始大小。
	tw.tween_property(self, "scale", original_scale, 0.15)


## ── 公開方法：鎖定 / 解鎖互動 ─────────────────────
## 卡片能不能被滑鼠射線「打到」，取決於它的 CollisionShape3D 有沒有被停用。
func lock_interaction() -> void:
	# $Area3D/CollisionShape3D 是「節點路徑」寫法：從自己往下找這個子節點。
	var col_shape := $Area3D/CollisionShape3D
	if col_shape:
		# disabled = true 等同在 Inspector 勾選 CollisionShape3D 的「Disabled」。
		# 停用後射線打不到它 → 卡片放進卡槽後就抓不動了。
		col_shape.disabled = true
		print("[狀態] 卡片已鎖定，滑鼠無法拖曳")

func unlock_interaction() -> void:
	var col_shape := $Area3D/CollisionShape3D
	if col_shape:
		# 重新啟用碰撞形狀，卡片又可以被滑鼠抓取(例如從卡槽拿回手牌時)。
		col_shape.disabled = false
		print("[狀態] 卡片已解鎖，恢復互動能力")
