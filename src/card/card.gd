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

## ── 卡框圖集(像素風,四色一張圖)───────────────────
## cards_sheet.png:4 排 × 4 色卡面 + 第 5 欄卡背,每格 64×96。
## 格子公式與各區座標都是量出來的,不是目測——量法見 tests/probe_sheet_alpha.gd
## 與 tests/probe_frame_bands.gd,換素材時重跑那兩支就會吐出新座標。
const FRAME_SHEET: Texture2D = preload(
	"res://assets/ui/card_frames/pixel_template/cards_sheet.png")
const FRAME_CELL := Vector2(64.0, 96.0)
const FRAME_ORIGIN := Vector2(16.0, 16.0)
const FRAME_STEP := Vector2(80.0, 112.0)
## 卡片世界尺寸固定 1.6 × 2.4;圖從 364px 寬換成 64px,pixel_size 要跟著換算。
const FRAME_PIXEL_SIZE := 1.6 / 64.0
## 用排 1:有卡圖窗、下半留白。排 0 的圖上畫死了三條文字線,會和 SkillLabel 打架。
const FRAME_ROW := 1
## 卡型 → 欄(0=藍 1=綠 2=紫 3=紅)。刻意對齊 TYPE_BADGES 既有的印章配色,
## 讓「卡框色」和「卡型章色」講同一件事;四色不夠分五型 → 靈裝與從者共用紅。
const FRAME_COL := {
	CardData.CardType.MINION: 3,
	CardData.CardType.EQUIP: 3,
	CardData.CardType.ARCANA: 2,
	CardData.CardType.QUICK: 0,
	CardData.CardType.WARD: 1,
	CardData.CardType.DOMAIN: 1,
}
## 卡背:第 5 欄排 0(牌堆與對手手牌用得到)。
const FRAME_BACK_REGION := Rect2(336.0, 16.0, 64.0, 96.0)

## ── 卡框各區的本地座標(逐列掃描量出來的;換卡框圖就要重量)──────
## 卡圖窗:相對格子 上 0.177 / 高 0.354 → 本地中心 y = 1.2 − 0.177×2.4 − 0.850/2
const ART_WINDOW_CENTER := Vector2(0.0, 0.35)      # 窗中心(卡片本地 x/y)
const ART_WINDOW_SIZE := Vector2(1.600, 0.850)     # 窗寬高(世界單位)
const ART_ICON_SIDE_MARGIN := 0.040                # 法術圖示每側留白
const FRAME_COST_Y := 0.975      # 卡頂裝飾帶
const FRAME_NAME_Y := -0.262     # 卡名木牌中心
const FRAME_DESC_Y := -0.762     # 描述木框中心(高 0.425、寬 1.05)
const FRAME_STAT_Y := -1.030     # 卡底:ATK/HP 與卡型章

## 狀態效果的顯示名(§9;卡面狀態列用)。
const STATUS_NAMES := {
	SkillData.Status.BURN: "灼燒",
	SkillData.Status.FREEZE: "凍結",
	SkillData.Status.POISON: "中毒",
	SkillData.Status.NIGHT_VEIL: "夜幕",
	SkillData.Status.FORGE: "鍛強",
}

## §7 卡型章:非從者卡的底部印「卡型名 + 印章色」(從者卡的那個位置是攻血數字)。
## 色調刻意壓暗:要像蓋在羊皮紙上的印泥,不是螢光標籤。
const TYPE_BADGES := {
	CardData.CardType.EQUIP: ["靈裝", Color(0.5, 0.36, 0.1)],
	CardData.CardType.ARCANA: ["秘術", Color(0.4, 0.18, 0.5)],
	CardData.CardType.QUICK: ["瞬咒", Color(0.12, 0.32, 0.55)],
	CardData.CardType.WARD: ["伏印", Color(0.16, 0.4, 0.18)],
	CardData.CardType.DOMAIN: ["領域", Color(0.35, 0.35, 0.35)],
}

## 立牌「角色可見高度」(世界單位)。召喚時會掃描角色圖的不透明範圍,
## 把「看得見的身體」縮放到正好這個高度——素材格子的透明留白不參與計算,
## 所以不管素材留白多少、解析度多少,角色在卡上的份量都一致。
## 卡片在槽上長 1.92(原生 2.4 × slot_scale 0.8),1.3 ≈ 卡長的 2/3,
## 接近 ideal_layout 參考圖的角色/卡片比例。想更大/小隻就調這個數字。
@export var standee_char_height: float = 1.3

## 上桌立牌(召喚時站在卡片上的像素角色;只在入槽時存在)。
var _standee: Sprite3D = null
## 立牌目前的動畫 tween(待機循環或一次性動畫)。換動畫前要先 kill 舊的,
## 不然兩個 tween 同時改 frame 會抖(和 card_slot 高亮動畫的防抖同一原則)。
var _standee_anim: Tween = null

## 是否已上桌(入槽)。上桌後不再能拖曳,但碰撞要留著——
## 點擊上桌的卡是「開指令選單」的入口(舊做法直接停用碰撞,射線打不到,
## 選單永遠開不起來);點擊的分流由 CardManager 依這個旗標決定。
var is_on_board: bool = false

## ── 執行期戰鬥狀態(由 BattleManager 讀寫)──────────
## CardData 是 24 張卡「共用」的資料模板,絕不能把當前血量寫回去
## (寫了 = 全場同名卡一起掉血);會變動的數值都放在場上這個 Card 實例身上。
var current_hp: int = 0
var attacked_this_turn: bool = false
var skill_used_this_turn: bool = false
var summoned_this_turn: bool = false
## 場上的狀態效果:[{id: SkillData.Status, turns: int}, ...](§9)。
## 鍛強在 atk_total() 生效;夜幕/鐵壁在 BattleManager 的傷害管線裡消耗。
var statuses: Array[Dictionary] = []
var iron_wall_used_this_turn: bool = false   # 【鐵壁】本回合的首傷減免用掉了?
var revived: bool = false                    # 【不滅】每場一次的復活用掉了?
## HPLabel 進場時的原色(受傷變紅、補滿要變得回來——基準先快照)。
var _hp_label_color: Color = Color.WHITE


## _ready() 是 Godot 的生命週期函式：節點一進入場景、準備好時自動執行一次。
func _ready() -> void:
	# 把「進場時的縮放」存起來當基準。
	# scale 是每個 3D 節點都有的內建屬性，對應 Inspector 的 Transform → Scale。
	original_scale = scale
	_area_base_pos = $Area3D.position   # 碰撞箱原位快照(hover 補償要歸得回來)


## 卡背貼圖(同一張圖集的第 5 欄排 0)。牌堆、對手手牌都跟卡面同一套美術,
## 才不會出現「正面像素風、背面手繪風」。static:誰都能拿,不必先有一張卡。
static func make_back_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAME_SHEET
	atlas.region = FRAME_BACK_REGION
	return atlas


## ── 卡框:依卡型換色 ───────────────────────────────
## 為什麼在 code 裡設而不是存進 card.tscn?
##   一、.tscn 由編輯器維護,是本專案的操作雷區(手改會讓 UID/路徑默默斷掉);
##   二、卡框要**依卡型換色**,場景檔只存得下一個預設值,分色本來就得寫在這裡。
## 同 BattleUI / SkillLabel 的做法:場景檔保持薄,內容由 code 重建。
func _apply_frame() -> void:
	var frame: Sprite3D = $CardFrame
	var col: int = FRAME_COL.get(data.card_type, 3)
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAME_SHEET
	atlas.region = Rect2(
		FRAME_ORIGIN.x + col * FRAME_STEP.x,
		FRAME_ORIGIN.y + FRAME_ROW * FRAME_STEP.y,
		FRAME_CELL.x, FRAME_CELL.y)
	frame.texture = atlas
	frame.pixel_size = FRAME_PIXEL_SIZE
	frame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 像素圖要銳利
	# 場景檔裡的字擺在舊卡框的版面上,新版面的區塊位置不同 → 一起搬。
	$CostLabel.position.y = FRAME_COST_Y
	$NameLabel.position.y = FRAME_NAME_Y
	$ATKLabel.position.y = FRAME_STAT_Y
	$HPLabel.position.y = FRAME_STAT_Y


## ── 套用卡片資料 ─────────────────────────────────
## 由發牌端呼叫：PlayerHand 抽到一份 CardData → card.setup(data) → 卡面顯示該卡。
## 一份資料可以餵給很多張卡(資料與場上物件分離，見 card_data.gd 開頭的說明)。
func setup(card_data: CardData) -> void:
	data = card_data
	_apply_frame()          # 卡框先換:下面擺卡圖與文字都以新版面的座標為準
	$NameLabel.text = data.card_name
	$CostLabel.text = str(data.cost)   # Label3D 的 text 只吃字串，int 要用 str() 轉
	$ATKLabel.text = str(data.atk)
	$HPLabel.text = str(data.hp)
	current_hp = data.hp                  # 執行期血量從模板拷貝出來(見上方變數說明)
	_hp_label_color = $HPLabel.modulate   # 原色快照:受傷變紅後要能變回來
	# 法術卡(§7 非從者)沒有攻血:數字藏起來,底部改印卡型章(_update_type_label)。
	var is_minion := data.card_type == CardData.CardType.MINION
	$ATKLabel.visible = is_minion
	$HPLabel.visible = is_minion
	# ── 卡圖:像素角色第 0 幀「放大」塞進卡框挖空窗 ──────────────
	# (AI 繪圖卡圖已棄用:和像素立牌風格打架。卡圖=立牌同一張動畫表,全場統一。)
	# 100×100 的格子裡角色本體只佔中間約 30px:整格塞窗,角色會小得像圖示。
	# 所以先掃出第 0 幀的「可見範圍」(和 show_standee 共用同一把尺),
	# 用 region 只裁出本體、等比放大進窗;NEAREST 讓放大後的像素塊保持銳利。
	# 卡圖擺在卡框「後面」(z = -0.01),從透明挖空處露出來——
	# 框的邊飾永遠畫在圖上面,所以不管圖放多大,卡框美術都不會被壓到。
	if data.standee != null:
		var cell := maxf(float(data.standee.get_height()), 1.0)
		var bounds := visible_bounds_of_frame0(data.standee)
		# grow(2):四周留 2px 呼吸邊;再夾回格子範圍,region 才不會取樣到界外。
		bounds = bounds.grow(2).intersection(Rect2(0.0, 0.0, cell, cell))
		$CardArt.texture = data.standee
		$CardArt.region_enabled = true
		$CardArt.region_rect = bounds
		$CardArt.pixel_size = minf(ART_WINDOW_SIZE.x / bounds.size.x,
			ART_WINDOW_SIZE.y / bounds.size.y)   # contain:整個本體進窗,不裁到肉
		$CardArt.scale = Vector3.ONE   # 從者卡維持等比,別吃到法術卡分支的拉伸
	elif data.art != null:
		# 法術卡的主要路徑:卡圖是 1:1 圖示(AtlasTexture 從圖示表切格),窗是橫向。
		# fill/stretch:高度等比貼齊窗高,寬度用 scale.x 拉寬到「窗寬 − 兩側呼吸邊」——
		# 不裁圖、不凸框,兩側各留 ≤5px 留白換較小的變形率(定案 2026-07-11)。
		var tex_w := maxf(float(data.art.get_width()), 1.0)   # maxf 是除零防呆
		var tex_h := maxf(float(data.art.get_height()), 1.0)
		$CardArt.texture = data.art
		$CardArt.region_enabled = false
		$CardArt.pixel_size = ART_WINDOW_SIZE.y / tex_h
		var target_w := ART_WINDOW_SIZE.x - ART_ICON_SIDE_MARGIN * 2.0
		$CardArt.scale = Vector3(target_w / (tex_w * $CardArt.pixel_size), 1.0, 1.0)
	$CardArt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST   # 像素圖要銳利
	# 擺到窗中心、退到卡框後 0.01(透明物件由遠到近畫:後面的圖先畫、框蓋在上)。
	$CardArt.position = Vector3(ART_WINDOW_CENTER.x, ART_WINDOW_CENTER.y, -0.01)
	_update_skill_label()


## ── 技能描述(卡框下半的文字區)────────────────────────────
## 程式生成 Label3D,不動 card.tscn;規格對齊場景裡的數值字
## (render_priority 1 + 貼卡面 z 0.02,躺平時才不會被卡面吃掉)。

## 文字區容量(新卡框的描述木框:中心 -0.762、高 0.425、寬 1.05):
## 每行高 15px×0.005=0.075 → 4 行佔 -0.61~-0.91,上不撞卡名木牌(-0.262 下緣 ≈ -0.40)、
## 下不撞卡底那列(-1.030 上緣 ≈ -0.95)。第 5 行起就會撞。
const SKILL_TEXT_MAX_LINES := 4
const SKILL_TEXT_CHARS_PER_LINE := 11.0   # width 210px ÷ font 15px = 14,收到 11 留邊


## 估算截斷:超過 5 行的部分切掉、以 … 收尾(全文靠 BattleUI 的 hover 放大預覽看)。
## 用「全形=1、半形=0.5」估寬而非真的排版量測——Label3D 沒有 max_lines 可設,
## 量測 API 又依賴字型載入時機;卡面只要「保證不撞攻血列」,精確度夠用就好。
func _fit_card_text(raw: String) -> String:
	var budget := SKILL_TEXT_MAX_LINES * SKILL_TEXT_CHARS_PER_LINE
	var used := 0.0
	for i in raw.length():
		var ch := raw.unicode_at(i)
		if ch == 10:   # 手動換行:把目前這行「沒用完的容量」整行扣掉
			used = ceilf(used / SKILL_TEXT_CHARS_PER_LINE) * SKILL_TEXT_CHARS_PER_LINE
			continue
		used += 1.0 if ch > 0x2E7F else 0.5   # 0x2E80 起是 CJK 區;之前的都當半形
		if used > budget - 1.0:   # 留 1 個字位給省略號
			return raw.substr(0, i) + "…"
	return raw


func _update_skill_label() -> void:
	var lb: Label3D = get_node_or_null("SkillLabel")
	if lb == null:
		lb = Label3D.new()
		lb.name = "SkillLabel"
		add_child(lb)
		lb.position = Vector3(0.0, FRAME_DESC_Y, 0.02)   # 描述木框中心
		lb.font_size = 15          # 木框比舊框的羊皮紙窄,字級跟著縮
		lb.width = 210.0           # 木框世界寬 1.05 ÷ Label3D 預設 pixel_size 0.005
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.render_priority = 1
		# ⚠ 字色要跟著「底色」走,不是跟著卡框走:
		# 舊框的描述區是淺色羊皮紙 → 墨黑字;新框是深棕木框 → 墨黑字會直接隱形。
		# 換卡框時最容易漏掉的就是這一項(位置搬對了、字卻看不見)。
		lb.modulate = Color(0.90, 0.84, 0.72)
		lb.outline_size = 2
		lb.outline_modulate = Color(0.05, 0.03, 0.02)
	if data != null and data.active_skill != null:
		var s := data.active_skill
		if data.card_type == CardData.CardType.MINION:
			# 【技能名】◆費用·三分類 + 換行描述;◆ 與指令選單同符號。
			# 三分類(強化/獨立/非攻擊)決定行動經濟,桌遊試玩回饋:卡面要標出來。
			lb.text = _fit_card_text("【%s】◆%d·%s\n%s" % [
				s.skill_name, s.cost, SkillData.KIND_NAMES[s.kind], s.description])
		else:
			# 法術卡:卡名/費用已在卡框上緣,文字區只印效果,不重複報頭。
			lb.text = _fit_card_text(s.description)
	else:
		lb.text = ""   # 沒有主動技的白板(骷髏弓手):留白
	_update_type_label()


## ── 卡型章(非從者卡):攻血列的位置改印「秘術/瞬咒/靈裝/伏印」─────
## 從者卡不印(攻血數字本身就是身分);和技能字同一套「印上去的油墨」質感。
func _update_type_label() -> void:
	var lb: Label3D = get_node_or_null("TypeLabel")
	if data == null or data.card_type == CardData.CardType.MINION:
		if lb != null:
			lb.queue_free()
		return
	if lb == null:
		lb = Label3D.new()
		lb.name = "TypeLabel"
		add_child(lb)
		lb.position = Vector3(0.0, FRAME_STAT_Y, 0.02)   # 攻血列的位置(數字已藏,空出來)
		lb.font_size = 26
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.render_priority = 1
		lb.outline_size = 0
	var badge: Array = TYPE_BADGES.get(data.card_type, ["?", Color(0.2, 0.2, 0.2)])
	lb.text = "‧ %s ‧" % badge[0]
	# TYPE_BADGES 的顏色是為舊框的淺色底調的「暗印泥」;新框的卡底是深色,
	# 原色會糊成一團 → 提亮後再用。基準色只有一份,亮度調整留在使用端(§3 基準/即時之分)。
	lb.modulate = (badge[1] as Color).lightened(0.55)


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
	# 寫深度:不然 DOF 讀到立牌「身後地形」的深度,站在對焦區也會被糊(hero.gd 同款)。
	_standee.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	# ── 量出角色的「可見範圍」:大小與腳位都以它為準 ──────────
	# 素材每格 100×100 裡,角色本體只佔中間約 30px,其餘是透明留白;
	# 按「整格」算大小,角色會只剩帳面的三分之一、還因置中錨定而懸空。
	# 「可見高度」拿來算縮放,「最下列 = 腳底」拿來把腳貼到卡面。
	var bounds := visible_bounds_of_frame0(data.standee)
	var top_row := bounds.position.y
	var feet_row := bounds.end.y - 1.0   # end 是「界外」的下一格,最下列要 -1
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
	# 待機動畫:交給共用的循環播放器(見下方 _play_sheet_loop)。
	_play_sheet_loop(frame_count)


## ── 立牌動畫工具組 ────────────────────────────────────────

## 待機循環:每 0.12 秒切下一格,set_loops() 無限循環 → 角色站在卡上「活著」。
## tween 綁在 _standee 節點上,立牌被 free 時動畫自動跟著停,不會漏。
func _play_sheet_loop(frame_count: int) -> void:
	if _standee_anim != null:
		_standee_anim.kill()
	_standee_anim = _standee.create_tween().set_loops()
	for f in range(frame_count):
		_standee_anim.tween_callback(func() -> void: _standee.frame = f).set_delay(0.12)


## 換上一張動畫表:設定貼圖、重算幀數(寬÷高,每格正方形),回傳幀數。
func _apply_sheet(tex: Texture2D) -> int:
	var h := maxf(1.0, float(tex.get_height()))
	var frames := maxi(1, int(float(tex.get_width()) / h))
	_standee.texture = tex
	_standee.hframes = frames
	_standee.frame = 0
	return frames


## 播一次性動畫(普攻 / 技能 / 受擊):換表 → 播一輪 → 自動切回待機循環。
## suffix 是動畫表後綴(如 "Attack02"、"Hurt"),交給 CardData.get_anim_sheet 解析;
## 找不到該表回傳 false,呼叫端可以換備案(牧師的普攻表叫 "Attack" 不是 "Attack01")。
## 縮放沿用召喚時掃出來的 pixel_size:同一隻角色不同動作,身形大小要一致。
func play_one_shot_anim(suffix: String) -> bool:
	if _standee == null or data == null:
		return false
	var tex := data.get_anim_sheet(suffix)
	if tex == null:
		return false
	var frames := _apply_sheet(tex)
	if _standee_anim != null:
		_standee_anim.kill()
	_standee_anim = _standee.create_tween()
	for f in range(frames):
		_standee_anim.tween_callback(func() -> void: _standee.frame = f).set_delay(0.1)
	_standee_anim.tween_callback(_restore_idle)   # 最後一格播完 → 回待機
	return true


## 一次性動畫收尾:換回待機表、重啟循環。
func _restore_idle() -> void:
	if _standee == null or data == null or data.standee == null:
		return
	var frames := _apply_sheet(data.standee)
	_play_sheet_loop(frames)


## 收掉立牌(卡片被取出卡槽時由 CardSlot 呼叫)。
func hide_standee() -> void:
	if _standee != null:
		_standee.queue_free()
		_standee = null


## ── 掃描動畫表第 0 幀的「可見範圍」───────────────────────
## 回傳不透明像素的最小外接矩形(像素座標)。卡圖放大、立牌縮放/貼地、
## 本體(Hero)的身形量測共用這一把尺——所以是「公開 static」:
## 不碰任何實例狀態,誰都能用 Card.visible_bounds_of_frame0(sheet) 呼叫。
## 素材格子的透明留白從此不參與任何大小計算(基準值用「量的」,別信帳面)。
## 掃不到東西(圖讀不出來、整格全透明)就回傳整格,行為退化成按整格算,不會炸。
static func visible_bounds_of_frame0(sheet: Texture2D) -> Rect2:
	var cell := maxi(int(sheet.get_height()), 1)   # 每格正方形:格寬 = 圖高
	var full := Rect2(0.0, 0.0, cell, cell)
	var img := sheet.get_image()
	if img == null:
		return full
	if img.is_compressed():
		img.decompress()   # VRAM 壓縮貼圖要先解壓,get_pixel 才讀得到
	var min_x := cell
	var max_x := -1
	var min_y := cell
	var max_y := -1
	for y in range(cell):
		for x in range(cell):   # 只掃第 0 幀(x 0..cell-1)
			if img.get_pixel(x, y).a > 0.1:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return full   # 整格全透明:退回整格
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


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
## zoom = 放大倍數:手牌瀏覽用預設值;指定目標時 CardManager 會傳更大的倍數,
## 讓玩家看清楚目標卡面上的技能描述字。
## 手牌卡 hover 抬升距離(手牌局部座標的 +Y = 沿扇形面往畫面上方)。
## 手牌平時縮在畫面下緣只露卡頂(爐石式),hover 要整張浮出來才讀得到。
const HOVER_LIFT := 1.8

## 扇形基準位:由 PlayerHand 的 _arrange_fan 寫入,是抬升/歸位唯一的「真位置」。
## 第一版曾在 hover 當下快照 position 當基準——hover/unhover 快速交錯時,
## 歸位補間還在飛就重新快照,「抬到一半」被當成新基準 → 卡越 hover 越往前不歸位。
## 教訓:基準值要快照「沒錯」,但快照點必須是資料源頭(排扇形),不是動畫中途。
var hand_base_pos := Vector3.ZERO
var _has_hand_base := false
var _pos_tween: Tween = null
var _area_base_pos := Vector3.ZERO   # $Area3D 在卡片 local 的原位(_ready 快照)


## PlayerHand 排扇形時同步基準位,並殺掉進行中的抬升/歸位補間(別跟扇形動畫搶)。
func sync_hand_base(p: Vector3) -> void:
	hand_base_pos = p
	_has_hand_base = true
	stop_hover_motion()
	reset_pick_area()


## 殺掉進行中的位置補間。開始拖曳時也要呼叫:補間和拖曳跟手都在寫 position,
## 兩者同幀互搶會抖動,而且補間結束瞬間會把卡拉回舊位。
func stop_hover_motion() -> void:
	if _pos_tween != null and _pos_tween.is_valid():
		_pos_tween.kill()


## 碰撞箱歸位(開始拖曳、重排扇形時呼叫,讓判定跟回視覺)。
func reset_pick_area() -> void:
	$Area3D.position = _area_base_pos


func animate_hover(zoom: float = 1.35) -> void:
	# create_tween() 會建立一個補間動畫器：在一段時間內把某個屬性平滑地變化。
	var tw := create_tween()
	# 把 scale 在 0.15 秒內，從現在平滑變到「原始大小 × zoom」(基準用快照,見 original_scale)。
	tw.tween_property(self, "scale", original_scale * zoom, 0.15)
	# 手牌卡同步抬升+微微向前(local +Z 朝鏡頭),蓋過鄰卡;上桌單位不抬(它們沒被遮)。
	# 目標是「絕對位置」(基準+固定偏移),連打多少次 hover 都收斂到同一點,不累積。
	if not is_on_board and _has_hand_base:
		stop_hover_motion()
		_pos_tween = create_tween().set_parallel(true)
		var lift := Vector3(0.0, HOVER_LIFT, 0.05)
		_pos_tween.tween_property(self, "position", hand_base_pos + lift, 0.15)
		# 判定與演出分離:視覺抬上去,碰撞箱反向補償「釘在扇形原位」——
		# hover 演出若把判定幾何一起搬走,游標下一幀就不再指到這張卡,
		# exit→歸位→又 enter→又抬……enter/exit 迴圈 = 卡片閃爍。
		# 換算:抬升是「手牌空間」向量,$Area3D.position 是「卡片 local」→
		# 先用卡的純旋轉反轉方向,再除以 hover 結束時的等比縮放。
		var rot := transform.basis.orthonormalized()
		var s := original_scale.x * zoom
		_pos_tween.tween_property($Area3D, "position",
			_area_base_pos + (rot.inverse() * -lift) / s, 0.15)


func animate_unhover() -> void:
	var tw := create_tween()
	# 0.15 秒內縮回原始大小。
	tw.tween_property(self, "scale", original_scale, 0.15)
	if not is_on_board and _has_hand_base:
		stop_hover_motion()
		_pos_tween = create_tween().set_parallel(true)
		_pos_tween.tween_property(self, "position", hand_base_pos, 0.15)
		# 歸位途中補償也同步收回:兩條補間淨效果 = 碰撞箱全程釘在原位,
		# 卡片下降「掃過」游標時才不會又觸發 enter(反向的閃爍迴圈)。
		_pos_tween.tween_property($Area3D, "position", _area_base_pos, 0.15)


## ── 公開方法:上桌 / 回手 ─────────────────────────
## 舊版在這裡直接停用 CollisionShape(射線打不到 = 不能拖)——但指令選單
## 需要「點得到上桌的卡」,所以改成:碰撞永遠開著,用旗標讓 CardManager 分流
## (手牌點擊=拖曳、上桌點擊=開選單)。
func enter_board_mode() -> void:
	is_on_board = true
	print("[狀態] 卡片上桌:拖曳關閉,點擊改開指令選單")

func exit_board_mode() -> void:
	is_on_board = false
	print("[狀態] 卡片回手:恢復拖曳")


## 靈裝加成(§7):生命上限增量,記在「節點」不記在共享的 CardData 上——
## 一份資料生多張卡,寫回 data.hp 會讓全場同名卡一起變厚;宿主離場加成隨節點消失。
var max_hp_bonus: int = 0

## 裝備中的靈裝「卡」(§7):加成數值在上面,這裡記的是卡本身——
## 宿主陣亡時要知道「哪幾張」跟著入墓(BattleManager._check_death 隨葬用)。
var equipped_cards: Array[CardData] = []


## ── 血量增減(由 BattleManager 呼叫)────────────────
func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	_refresh_hp_label()
	if amount > 0:
		_popup_number("-%d" % amount, Color(1.0, 0.3, 0.25))
		# 命中爆點:所有傷害(普攻/反擊/技能/灼燒中毒)都經過這裡,一次接線全生效。
		# 用 preload 引用而非裸名 FxBurst:新 class_name 未進編輯器快取前裸名會解析失敗(§19)。
		preload("res://src/fx/fx_burst.gd").spawn_at(self)
		Sfx.play(Sfx.HIT, -3.0)


func heal(amount: int) -> void:
	# 先算「實際回了多少」(不超上限),數字報實帳,不報帳面治療量。
	var healed := mini(data.hp + max_hp_bonus, current_hp + amount) - current_hp
	current_hp += healed
	_refresh_hp_label()
	if healed > 0:
		_popup_number("+%d" % healed, Color(0.45, 1.0, 0.5))


## 飄浮戰鬥數字:冒出 → 上飄 → 淡出 → 自毀。
## 掉血看 HP 小字太吃力,尤其反擊是「攻擊的同時自己也掉血」,
## 沒有這個數字,反擊看起來就像沒發生(驗收時的真實回饋)。
func _popup_number(text_value: String, color: Color) -> void:
	var lb := Label3D.new()
	lb.text = text_value
	lb.font_size = 64
	lb.modulate = color
	lb.outline_size = 14
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # 永遠面向鏡頭
	lb.no_depth_test = true      # 不做深度測試 = 不會被立牌/地形擋住
	lb.render_priority = 2
	add_child(lb)
	# 上桌的卡躺平,local +Z = 世界正上方(同 show_standee 的座標邏輯)。
	lb.position = Vector3(0.0, 0.0, 1.1)
	var tw := lb.create_tween().set_parallel(true)
	tw.tween_property(lb, "position:z", 2.0, 0.8)
	tw.tween_property(lb, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lb.queue_free)


## 上限變動後把現血夾回上限(裝備替換:舊裝拆走、bonus 縮水時由帳房呼叫)。
func clamp_hp() -> void:
	current_hp = mini(current_hp, data.hp + max_hp_bonus)
	_refresh_hp_label()


func _refresh_hp_label() -> void:
	$HPLabel.text = str(current_hp)
	# 殘血紅字:一眼掃出誰快死了;補滿就恢復原色。
	if current_hp < data.hp:
		$HPLabel.modulate = Color(1.0, 0.32, 0.28)
	else:
		$HPLabel.modulate = _hp_label_color


## ── 狀態效果(§9;由 BattleManager 讀寫)──────────────
func add_status(id: SkillData.Status, turns: int) -> void:
	# 灼燒/凍結互斥(§9):新狀態把對立的舊狀態擠掉。
	if id == SkillData.Status.BURN:
		remove_status(SkillData.Status.FREEZE)
	elif id == SkillData.Status.FREEZE:
		remove_status(SkillData.Status.BURN)
	for s in statuses:
		if s.id == id:
			s.turns = maxi(int(s.turns), turns)   # 重複上同狀態:刷新回合數,不疊加
			_update_status_label()
			return
	statuses.append({"id": id, "turns": turns})
	_update_status_label()


func has_status(id: SkillData.Status) -> bool:
	for s in statuses:
		if s.id == id:
			return true
	return false


func remove_status(id: SkillData.Status) -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].id == id:
			statuses.remove_at(i)
	_update_status_label()


## 回合開始:所有狀態剩餘回合 -1,歸零解除(§5 開始階段「解除凍結等狀態」)。
func decay_statuses() -> void:
	for i in range(statuses.size() - 1, -1, -1):
		statuses[i].turns = int(statuses[i].turns) - 1
		if int(statuses[i].turns) <= 0:
			statuses.remove_at(i)
	_update_status_label()


## 目前攻擊力 = 基礎 + 鍛強(§9:ATK +2)。傷害計算一律用這個,別直接讀 data.atk。
func atk_total() -> int:
	return data.atk + (2 if has_status(SkillData.Status.FORGE) else 0)


## 卡面頂緣的狀態列(程式生成 Label3D,同 SkillLabel 的規矩):「灼燒2 中毒3」。
func _update_status_label() -> void:
	var lb: Label3D = get_node_or_null("StatusLabel")
	if lb == null:
		lb = Label3D.new()
		lb.name = "StatusLabel"
		add_child(lb)
		lb.position = Vector3(0.0, 1.02, 0.02)   # 卡頂中央(費用在角落,不打架)
		lb.font_size = 22
		lb.render_priority = 1
		lb.modulate = Color(1.0, 0.62, 0.2)   # 橘=「有事發生中」的警示色
		lb.outline_size = 8
	var parts: PackedStringArray = []
	for s in statuses:
		parts.append("%s%d" % [STATUS_NAMES.get(s.id, "?"), int(s.turns)])
	lb.text = " ".join(parts)


## ── 死亡演出:死亡表定格 → 縮小消失 → 自毀 ─────────
## 由 BattleManager 在 HP 歸零時呼叫(卡槽已先清位)。
func die() -> void:
	is_on_board = false
	# 屍體不該再吃射線:關碰撞(用 deferred——物理回呼期間直接改會報錯)。
	var shape: CollisionShape3D = get_node_or_null("Area3D/CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)
	var played := _play_death_anim()
	var tw := create_tween()
	tw.tween_interval(0.65 if played else 0.1)   # 讓倒地動畫(6 格 × 0.1s)播完
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## 播死亡表:與 play_one_shot_anim 幾乎相同,但「不」回待機——定格在最後一格。
## 死靈法師的表名是全大寫 DEATH(素材包命名地雷),找不到就換備案再試。
func _play_death_anim() -> bool:
	if _standee == null or data == null:
		return false
	var tex := data.get_anim_sheet("Death")
	if tex == null:
		tex = data.get_anim_sheet("DEATH")
	if tex == null:
		return false
	var frames := _apply_sheet(tex)
	if _standee_anim != null:
		_standee_anim.kill()
	_standee_anim = _standee.create_tween()
	for f in range(frames):
		_standee_anim.tween_callback(func() -> void: _standee.frame = f).set_delay(0.1)
	return true
