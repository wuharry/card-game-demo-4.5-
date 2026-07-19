## card_manager.gd — 全場的「大腦」：負責滑鼠拖放、hover、出牌判定
##
## 掛在 main.tscn 的 CardManger (Node3D) 節點上。
## 它是整個互動的中樞，每一幀檢查滑鼠、處理點擊放開，
## 並協調 Card(卡片)、CardSlot(卡槽)、PlayerHand(手牌)三方。
##
## 核心觀念「射線偵測 (raycast)」：
##   螢幕是平的(2D)，但場景是立體的(3D)。要知道滑鼠點到哪個 3D 物件，
##   就從攝影機往滑鼠方向「射一條看不見的線」，看它打中什麼。

extends Node3D

# ==========================================
# 物理碰撞遮罩 (Collision Mask) 常數
# ==========================================
# Godot 用「層 (Layer)」來分類物件。我們把卡片放在第 1 層、卡槽放在第 2 層。
# 射線可以指定「只想打中哪一層」，這樣找卡片時不會誤抓到卡槽，反之亦然。
# 數值規則：第 N 層 = 2 的 (N-1) 次方。第1層=1、第2層=2、第3層=4…(用加法可組合多層)。
# (這些層的對應，也可在 Inspector 的 CollisionObject3D → Collision → Layer/Mask 勾選框設定)

const COLLISION_MASK_CARD = 1  # 第 1 層：卡片實體(拖曳時要找的對象)
const COLLISION_MASK_SLOT = 2  # 第 2 層：桌面卡槽(放牌時要找的對象)
const COLLISION_MASK_HERO = 4  # 第 3 層：本體(hero.gd 生成碰撞時自掛這層)
const COLLISION_MASK_GRAVE = 8  # 第 4 層：墓地投放區(grave_pile.gd 自掛;丟牌回魔 §1.1)

## @onready：等節點都準備好後，才執行右邊的取值並存進變數(太早拿可能還是 null)。
## camera：場景目前啟用中的攝影機。把滑鼠的 2D 座標換成 3D 射線時一定要用到它。
@onready var camera: Camera3D = get_viewport().get_camera_3d()

## 目前「被滑鼠抓著拖曳」的卡片。沒有在拖任何卡時是 null。
var card_being_dragged: Card = null
var _hint_pile: GravePile = null   # 目前亮著回魔提示的墓(拖曳懸停中)
## 拖曳時把卡片鎖在這個高度(Y 軸)，避免它忽高忽低或穿進地板。
var drag_plane_height: float = 0.0
## 目前被滑鼠 hover(放大)的卡片。全場同時「只能有一張」被放大，避免畫面混亂。
var currently_hovered_card: Card = null
## 右側放大預覽面板目前顯示的卡(和 currently_hovered_card 分開記:
## 預覽對「桌上單位」也開,而 currently_hovered_card 只管手牌的放大動畫)。
var _previewed_card: Card = null
## 單人模式的兩個配件(VS_AI 才生;卡背扇形連線模式也用)。
var _enemy_ai: EnemyAI = null
var _opp_hand: OpponentHand = null
## 拖曳時，目前懸停在哪個卡槽上方(用來控制卡槽的高亮提示)。
var currently_hovered_slot: CardSlot = null

## 手牌節點。改用 @export 注入：在 main.tscn 的 Inspector 把 PlayerHand 指定進來，
## 取代字串路徑 get_node("../PlayerHand")，這樣重命名/搬移節點時不會等到執行期才出錯，
## 也讓 player_hand 帶有 PlayerHand 型別，享有自動補全與編譯期檢查。
@export var player_hand: PlayerHand

## ── 互動狀態機 ─────────────────────────────────────
## 同一顆滑鼠左鍵在不同狀態下代表不同動作,全部集中在這裡分流:
##   IDLE      平時:點手牌=抓起拖曳、點上桌單位=開指令選單
##   DRAGGING  拖曳中(原本的行為)
##   MENU_OPEN 指令選單開著:3D 場景不吃點擊,等 BattleUI 的信號
##   TARGETING 指定目標中:懸停合法目標會亮、左鍵=發動、右鍵/ESC=取消
##   GAME_OVER 勝負已分:3D 互動全關,只剩勝負畫面的按鈕
enum UiState { IDLE, DRAGGING, MENU_OPEN, TARGETING, GAME_OVER }
var ui_state: UiState = UiState.IDLE

## 指令選單(程式生成的 CanvasLayer,見 battle_ui.gd)。
var battle_ui: BattleUI = null
## 戰鬥帳房:魔力/回合/HP 真結算(程式生成,見 battle_manager.gd)。
var battle_manager: BattleManager = null
## 選單目前的主角(被點擊的上桌單位)。
var active_unit: Card = null
## 等待指定目標的技能;null 代表等待目標的是「普通攻擊」。
var pending_skill: SkillData = null
## 等待指定目標的秘術(從手牌點選、還沒選到目標的那張);
## 非 null = 現在是「秘術瞄準」模式:箭頭改由玩家本體出發、目標限敵方從者。
## 用它和「單位攻擊瞄準」(active_unit != null)區分同一個 TARGETING 狀態。
var pending_spell_card: Card = null
## TARGETING 狀態下目前亮起的候選目標:Card 或 Hero
## (兩者都有 animate_hover/unhover,所以宣告成共同祖先 Node3D)。
var hovered_target: Node3D = null

## 雙方本體(程式生成的像素立牌,見 hero.gd);打倒對方本體 = 勝利。
var player_hero: Hero = null
var enemy_hero: Hero = null

## 有行動發動了(演出已起跑)。BattleManager 訂閱這個信號做真結算;
## skill = null 代表普通攻擊;target 是 Card(從者)或 Hero(打臉)。
signal action_performed(caster: Card, skill: SkillData, target: Node3D)


func _ready() -> void:
	# 訂閱 PlayerHand 的中繼信號。之後任何一張手牌被 hover，事件都會流到這兩個函式。
	# connect(函式) = 「當信號發出時，請幫我呼叫這個函式」。
	player_hand.card_hovered.connect(on_card_hovered)
	player_hand.card_unhovered.connect(on_card_unhovered)
	# 指令選單:程式生成掛在自己底下(main.tscn 零改動),訂閱它的三個決定。
	battle_ui = BattleUI.new()
	add_child(battle_ui)
	battle_ui.attack_chosen.connect(_on_attack_chosen)
	battle_ui.skill_chosen.connect(_on_skill_chosen)
	battle_ui.cancelled.connect(_cancel_command)
	battle_ui.end_turn_pressed.connect(_on_end_turn)
	# 戰鬥帳房:規則與數值都在它那裡。UI 的決定經中樞轉發給帳房、
	# 帳的變化再流回 UI——兩端只認識中樞,互不相識(同 hover 中繼鏈的哲學)。
	battle_manager = BattleManager.new()
	battle_manager.hand_node = player_hand   # spawn_unit 的掛點(召喚技/連線重放生單位)
	battle_manager.state_changed.connect(battle_ui.update_hud)
	battle_manager.unit_died.connect(_on_unit_died)
	battle_manager.card_buried.connect(_on_card_buried)
	battle_manager.wards_changed.connect(_on_wards_changed)
	battle_manager.game_over.connect(_on_game_over)
	action_performed.connect(battle_manager.on_action_performed)
	add_child(battle_manager)
	# 勝負畫面的兩個去向:重開這局 / 回主選單(換場景是中樞的事,UI 只發信號)。
	# 連線時「再戰一場」單邊 reload 會讓兩台的帳分家 → 一律收線回主選單。
	battle_ui.restart_pressed.connect(func() -> void:
		if NetMatch.is_online:
			_leave_online_match()
		else:
			get_tree().reload_current_scene())
	battle_ui.menu_pressed.connect(func() -> void:
		if NetMatch.is_online:
			_leave_online_match()
		else:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	# 本體/敵方牌堆要等 PlayerBoard 把卡槽生完才能靠群組定位 → 延後到整棵樹 ready 後。
	_spawn_heroes.call_deferred()
	_spawn_enemy_deck.call_deferred()
	_spawn_grave_piles.call_deferred()
	_sync_hand_view.call_deferred()   # 起手牌的「帳」在帳房,視圖開局同步一次
	# ── 連線(2b–2e):斷線監聽、client 要開局帳、client 視角翻轉 ──
	if NetMatch.is_online:
		multiplayer.peer_disconnected.connect(_on_net_peer_lost)
		multiplayer.server_disconnected.connect(_on_net_server_lost)
		if multiplayer.is_server():
			_accounts_synced = true   # host 的帳就是權威,天生同步
		else:
			_request_state_loop()
		_apply_client_viewpoint.call_deferred()   # deferred FIFO:排在牌堆/本體生成之後
		_refresh_opp_hud.call_deferred()
	# ── 單人 vs AI:AI 玩家上桌;對手卡背扇形(單人+連線共用)──
	if MatchMode.is_vs_ai():
		_enemy_ai = EnemyAI.new()
		add_child(_enemy_ai)
		_enemy_ai.setup(self)
	if MatchMode.is_vs_ai() or NetMatch.is_online:
		_spawn_opp_hand.call_deferred()   # 等卡槽/本體就位後才能靠群組定位


## ── 收到「滑鼠移到某張卡上」事件 ──────────────────
func on_card_hovered(card: Card) -> void:
	# 防呆 1：正在拖牌時，不要去放大底下其他的牌。
	if card_being_dragged != null:
		return

	# 右側放大預覽:手牌、桌上單位都給(卡面字有截斷,全文在預覽面板看)。
	_previewed_card = card
	battle_ui.show_card_preview(card)

	# 上桌單位不做「手牌式放大」;只有在指定目標模式、而且是合法目標時,
	# 才亮起當「候選目標」的視覺回饋(借用同一套放大動畫)。
	if card.is_on_board:
		if ui_state == UiState.TARGETING and _is_valid_targeting_target(card):
			if hovered_target != null and hovered_target != card:
				hovered_target.animate_unhover()
			hovered_target = card
			# 比手牌 hover 更大的倍數:目標卡躺平又離鏡頭遠,要放大到讀得清技能字。
			card.animate_hover(1.5)
		return

	# 開著選單/指定目標時,手牌不要湊熱鬧(視覺焦點要留在指令流程上)。
	if ui_state != UiState.IDLE:
		return

	# 防呆 2：若已經有「別張」卡被放大，先把它縮回去，確保同時只有一張放大。
	# is_instance_valid:換邊重建手牌後,舊參考可能指向已釋放的卡(摸了就炸)。
	if currently_hovered_card != null and is_instance_valid(currently_hovered_card) \
			and currently_hovered_card != card:
		currently_hovered_card.animate_unhover()

	# 記住目前放大的是這張，並播放它的放大動畫。
	currently_hovered_card = card
	card.animate_hover()
	# (未來可在這裡讓卡片往前移一點，避免被旁邊的牌擋住)


## ── 收到「滑鼠離開某張卡」事件 ──────────────────
func on_card_unhovered(card: Card) -> void:
	# 收放大預覽——只有「離開的正是預覽中那張」才收:扇形手牌重疊時
	# 事件序是 enter(B) 可能先於 exit(A),無條件收會把剛開的 B 預覽誤殺。
	if _previewed_card == card:
		_previewed_card = null
		battle_ui.hide_card_preview()

	# 指定目標模式:離開的是亮著的候選目標 → 收掉高亮。
	if hovered_target == card:
		hovered_target = null
		card.animate_unhover()
		return

	# 確認離開的就是目前記錄的那張，才把它縮回去。
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()

		# 補償邏輯：扇形手牌彼此重疊，滑鼠從上面那張移開時，
		# 其實可能正停在下面另一張牌上 → 主動再射一條線確認。
		var underneath_card := raycast_check_for_card()
		# 若底下真的還有牌、而且是平時狀態，就主動幫它觸發 hover(放大)。
		if underneath_card and underneath_card is Card and ui_state == UiState.IDLE:
			on_card_hovered(underneath_card)


## ── 每一幀都會執行：負責「拖曳中」的即時跟手 ──────────
## _process(delta) 是 Godot 的逐幀回呼。delta 是距離上一幀的秒數(這裡用不到，故加底線)。
func _process(_delta: float) -> void:
	# 拖曳結束(出牌/棄牌/取消,不管走哪條路)= 在這個單一收斂點清回魔提示。
	# 比在每條退出路徑各補一刀可靠:之後新增退出路徑也不會漏。
	if card_being_dragged == null and _hint_pile != null:
		_hint_pile.hide_recycle_hint()
		_hint_pile = null
	# 只有真的抓著卡時才需要處理。
	if card_being_dragged:
		# 1. 想像桌面是一個「數學平面」：法線朝上(Vector3.UP)、高度為 drag_plane_height。
		#    卡片只會在這個水平面上滑動，不會亂飛。
		var drop_plane := Plane(Vector3.UP, drag_plane_height)

		# 2. 取得滑鼠在螢幕上的像素位置。
		var mouse_position := get_viewport().get_mouse_position()

		# 3. 從攝影機朝滑鼠方向射線：origin = 起點、normal = 方向。
		var ray_origin := camera.project_ray_origin(mouse_position)
		var ray_normal := camera.project_ray_normal(mouse_position)

		# 4. 算出這條射線和桌面平面的交點 = 滑鼠在桌面上對應的 3D 位置。
		var intersect_pos = drop_plane.intersects_ray(ray_origin, ray_normal)

		if intersect_pos:
			# 把卡片直接移到該位置(跟著滑鼠走)。
			card_being_dragged.global_position = intersect_pos

			# ── 拖曳時的卡槽高亮預覽 ──
			# 順便往下看現在懸停在哪個卡槽上。
			var found_slot := raycast_check_for_card_slot()
			# 只有當「懸停的卡槽改變了」才更新，避免每幀重複觸發動畫。
			if found_slot != currently_hovered_slot:
				# 先把上一個卡槽的高亮收掉。
				if currently_hovered_slot != null:
					currently_hovered_slot.unhighlight()
				# 若新的是空卡槽，就讓它亮起來。
				if found_slot != null and found_slot.is_empty:
					found_slot.highlight()
				# 更新記錄。
				currently_hovered_slot = found_slot

			# ── 拖曳時的回魔提示:懸停墓地 = 光環轉金 + 「+n ◆」(§1.1)──
			var pile := raycast_check_for_grave()
			if not battle_manager.can_discard_for_mana(battle_manager.active_side):
				pile = null   # 冷卻中不亮提示;真丟下去 _try_discard 會用人話拒絕
			if pile != _hint_pile:
				if _hint_pile != null:
					_hint_pile.hide_recycle_hint()
				_hint_pile = pile
				if _hint_pile != null:
					_hint_pile.show_recycle_hint(
						floori(card_being_dragged.data.cost / 2.0))

	# 指定目標中:每幀把「施放者 → 游標」的螢幕座標餵給 BattleUI 畫導引箭頭。
	# unproject_position 是射線的反運算:3D 世界座標 → 螢幕像素座標。
	elif ui_state == UiState.TARGETING \
			and (active_unit != null or pending_spell_card != null):
		var aim := get_viewport().get_mouse_position()
		var locked := hovered_target != null
		if locked:
			# 鎖定合法目標時,箭頭尖端吸附到目標身上,不再跟著游標抖。
			aim = camera.unproject_position(
				hovered_target.global_position + Vector3.UP * 0.5)
		# 施放者起點:單位攻擊 = 該單位;秘術 = 行動方的本體(§7 箭頭由玩家出發)。
		var caster_node: Node3D = active_unit
		if caster_node == null:
			caster_node = player_hero if battle_manager.active_side == "player" \
				else enemy_hero
		var from_px := camera.unproject_position(
			caster_node.global_position + Vector3.UP * 0.5)
		battle_ui.update_arrow(from_px, aim, locked)


## ── 處理滑鼠輸入:依「互動狀態」分流 ──────────────
## _input(event) 在每次有輸入(滑鼠/鍵盤)時被呼叫,event 帶有這次事件的資訊。
func _input(event: InputEvent) -> void:
	# 右鍵 / ESC = 反悔:不管在選單還是指定目標,都退回平時狀態。
	var is_rmb: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	var is_esc: bool = event is InputEventKey and event.pressed \
		and event.keycode == KEY_ESCAPE
	if (is_rmb or is_esc) \
			and (ui_state == UiState.MENU_OPEN or ui_state == UiState.TARGETING):
		_cancel_command()
		return

	# 只關心「滑鼠左鍵」事件。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match ui_state:
				UiState.IDLE:
					_on_left_pressed_idle()
				UiState.TARGETING:
					_on_left_pressed_targeting()
				_:
					# MENU_OPEN:點擊交給 UI 按鈕處理(Control 自己吃事件),
					# 點在 3D 空地不做事——要反悔請按「取消」或右鍵。
					pass
		elif ui_state == UiState.DRAGGING:
			_on_left_released_drag()


## 平時左鍵按下:點手牌 = 抓起拖曳;點上桌單位 = 開指令選單(歧路旅人式:先選人再選招)。
func _on_left_pressed_idle() -> void:
	var card := raycast_check_for_card()
	if card == null:
		return
	if card.is_on_board:
		active_unit = card
		ui_state = UiState.MENU_OPEN
		# 把「不能做的理由」一起交給選單:按鈕灰化+描述列說明。
		# 規則只寫在帳房一份,按鈕永遠只是轉述。
		battle_ui.open(card,
			battle_manager.attack_block_reason(card),
			battle_manager.skill_block_reason(card))
		return
	# 連線(2b):不是你的回合不能出牌;開局帳未同步完成前也先擋著。
	if NetMatch.is_online:
		if not _accounts_synced:
			battle_ui.flash_message("開局同步中…")
			return
		if battle_manager.active_side != NetMatch.my_side:
			battle_ui.flash_message("對方回合:等待對方行動…")
			return
	# 單人模式:AI 的回合不能出牌(和連線「非己回合鎖操作」同一個閘的兄弟)。
	if MatchMode.is_vs_ai() and battle_manager.active_side != "player":
		battle_ui.flash_message("對方回合:AI 行動中…")
		return
	# ── 秘術:改走「爐石式箭頭瞄準」而非拖放(§7 施放手感)──
	# 點手牌的秘術 = 選定要施放的卡並進 TARGETING;箭頭由玩家本體射向游標,
	# 再點敵方從者結算。其餘卡型(從者/靈裝/伏印)仍走原本的拖放。
	if card.data.card_type == CardData.CardType.ARCANA:
		if not battle_manager.can_afford(card.data.cost):
			battle_ui.flash_message("魔力不足:需要 ◆%d(現有 %d)" % [
				card.data.cost, battle_manager.active_mana()])
			return
		_begin_spell_targeting(card)
		return
	# ── 抓牌(原本的拖曳邏輯)──
	card_being_dragged = card
	ui_state = UiState.DRAGGING
	Sfx.play(Sfx.CARD_PICKUP, -6.0)
	# 記住卡片當下的高度，拖曳時就維持在這個高度水平移動。
	drag_plane_height = card.global_position.y
	# 抓起來的瞬間取消它的放大狀態，避免邊拖邊放大的怪畫面。
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()
	# 殺掉 hover 的位置補間:它和「拖曳跟手」同幀都在寫 position,不殺會互搶抖動。
	card.stop_hover_motion()
	# 碰撞箱歸位:拖曳中判定要跟著卡走(hover 的反向補償只在扇形裡才成立)。
	card.reset_pick_area()
	# 右側預覽也收:拖曳中視覺焦點在投影落點,資訊卡留著只會擋畫面。
	_previewed_card = null
	battle_ui.hide_card_preview()


## 拖曳中左鍵放開 = 嘗試出牌。依卡型分流(§7):從者進卡槽、秘術丟目標、
## 靈裝貼我方從者、伏印蓋我方半場;瞬咒不能主動施放(只在反制窗口被詢問)。
func _on_left_released_drag() -> void:
	# 先清空拖曳狀態:秘術的反制窗口是 async(會 await),留著舊狀態會被覆寫打架。
	var card := card_being_dragged
	card_being_dragged = null
	ui_state = UiState.IDLE
	# 丟牌回魔(§1.1):放到墓地投放區 = 棄牌換魔,任何卡型都可棄——比卡型分流優先。
	if raycast_check_for_grave() != null:
		_try_discard(card)
		return
	match card.data.card_type:
		CardData.CardType.MINION:
			_try_summon(card)
		CardData.CardType.ARCANA:
			# 秘術改走點選+箭頭瞄準(見 _begin_spell_targeting),照理不會走到拖放;
			# 保險:萬一狀態機漏接,把卡放回扇形,不讓它懸在半空。
			organize_hand()
		CardData.CardType.EQUIP:
			_try_attach_equip(card)
		CardData.CardType.WARD:
			_try_set_ward(card)
		_:
			battle_ui.flash_message("瞬咒不能主動施放:對方施放秘術時會自動詢問反制(§7)")
			organize_hand()


## 從者:入槽召喚(原本的釋放邏輯,原封不動搬進來)。
func _try_summon(card: Card) -> void:
	# 往下射線,看看放開的位置下面有沒有卡槽。
	var found_slot := raycast_check_for_card_slot()
	# 找到卡槽、而且是空的 → 先驗這一側(§3),再過「召喚費」(§1)。
	if found_slot and found_slot.is_empty:
		var cost := card.data.cost
		if battle_manager.slot_side(found_slot) != battle_manager.active_side:
			# 熱座:手牌屬於行動方,只能召喚到行動方自己那側。
			battle_ui.flash_message("只能召喚到自己這一側的卡槽")
			organize_hand()
		elif battle_manager.can_afford(cost):
			# 連線走 RPC 兩台同步結算;單機直呼同一個函式(同 _net_end_turn 的分流)。
			_pending_play_card = card
			var idx := player_hand.cards.find(card)
			if NetMatch.is_online:
				_net_summon.rpc(idx, card.data.resource_path, get_path_to(found_slot))
			else:
				_net_summon(idx, card.data.resource_path, get_path_to(found_slot))
		else:
			battle_ui.flash_message(
				"魔力不足:召喚需要 ◆%d(現有 %d)" % [cost, battle_manager.active_mana()])
			organize_hand()
	else:
		# 沒對準卡槽 / 卡槽已滿 → 讓它回到手牌扇形原位。
		organize_hand()


## 秘術瞄準開始(§7 爐石式):選定手牌那張秘術、進 TARGETING、亮提示。
## 卡不離手(留在扇形裡),由 _process 每幀從玩家本體畫箭頭到游標;
## 目標與付費的最終驗證在點目標時(_on_left_pressed_spell_target → _cast_arcana_at)。
func _begin_spell_targeting(card: Card) -> void:
	pending_spell_card = card
	pending_skill = null
	active_unit = null
	ui_state = UiState.TARGETING
	# 收掉這張卡在扇形裡的 hover 放大與右側預覽,瞄準時畫面別再有一張浮著。
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()
	_previewed_card = null
	battle_ui.hide_card_preview()
	battle_ui.show_targeting("選擇【%s】的目標:敵方從者(點其他地方取消)" % card.data.card_name)


## TARGETING 中「懸停高亮」用的合法性:秘術走秘術規則,其餘走單位攻擊規則。
## (兩者不能共用 _is_valid_target:後者靠 active_unit 判敵我,秘術時它是 null。)
func _is_valid_targeting_target(card: Card) -> bool:
	if pending_spell_card != null:
		return _is_valid_spell_target(card)
	return _is_valid_target(card)


## 秘術的合法目標:在場上、敵方(相對行動方)、且非潛行(§8)。
func _is_valid_spell_target(card: Card) -> bool:
	if card == null or not card.is_on_board:
		return false
	if card.data.keywords.has(&"潛行"):
		return false
	return battle_manager.side_of(card) != battle_manager.active_side


## 秘術瞄準中左鍵:點到合法敵方從者 = 施放結算;
## 點到其他任何地方 = 取消施放(爐石/暗影詩章式:沒指定目標就是反悔,
## 不必特地按右鍵;右鍵/ESC 照舊可用)。點錯「東西」先講原因再收,
## 點空地/手牌就是想收手,安靜取消不彈訊息。
func _on_left_pressed_spell_target() -> void:
	var target := raycast_check_for_card()
	if target == null:
		# 點到本體或空白:秘術不能打臉(§7 只指定從者)→ 講原因,一樣取消。
		if raycast_check_for_hero() != null:
			battle_ui.flash_message("已取消:秘術只能指定敵方從者,不能打本體")
		_cancel_command()
		return
	if not target.is_on_board:
		# 射線也打得到手牌卡(同一層):side_of 對無槽卡回 "",不擋會被
		# 誤判成「敵方」而把秘術砸在手牌上——視同點空地,取消。
		_cancel_command()
		return
	if target.data.keywords.has(&"潛行"):
		battle_ui.flash_message("已取消:【%s】具有潛行,無法被秘術指定(§8)" % target.data.card_name)
		_cancel_command()
		return
	if battle_manager.side_of(target) == battle_manager.active_side:
		battle_ui.flash_message("已取消:【%s】只能指定敵方從者" % pending_spell_card.data.card_name)
		_cancel_command()
		return
	# 合法目標:先收瞄準的視覺與狀態,再交給既有結算(反制窗口/連線宣告都在裡面)。
	var card := pending_spell_card
	_clear_spell_targeting()
	_cast_arcana_at(card, target)


## 收掉秘術瞄準的視覺與狀態(成功施放前呼叫;取消改走 _cancel_command)。
## 回到 IDLE 讓後續 _resolve_arcana / 連線宣告自己去設它要的狀態(反制時 MENU_OPEN)。
func _clear_spell_targeting() -> void:
	if hovered_target != null and is_instance_valid(hovered_target):
		hovered_target.animate_unhover()
	hovered_target = null
	pending_spell_card = null
	ui_state = UiState.IDLE
	battle_ui.close()


## 秘術結算入口(目標已由瞄準流程驗過):付費宣告 → 反制窗口 → 落地。
## 連線走宣告 RPC(反制開在守方那台);單機就地問反制(async)。
func _cast_arcana_at(card: Card, target: Card) -> void:
	if not battle_manager.can_afford(card.data.cost):
		battle_ui.flash_message("魔力不足:需要 ◆%d(現有 %d)" % [
			card.data.cost, battle_manager.active_mana()])
		return
	if NetMatch.is_online:
		# 連線:宣告廣播出去,反制窗口開在「守方那台」;結果回來前鎖操作。
		_pending_play_card = card
		var idx := player_hand.cards.find(card)
		_net_arcana_declare.rpc(idx, card.data.resource_path,
			get_path_to(battle_manager.find_slot_of(target)))
		return
	_resolve_arcana(card, target)   # 熱座:反制窗口就地問(async)


## 秘術結算(§5.1 的 STEP 1→2→4):宣告即付費 → 守方瞬咒窗口 → 未被抵銷才落地。
func _resolve_arcana(card: Card, target: Card) -> void:
	battle_manager.spend(card.data.cost)   # STEP 1:宣告就支付,被抵銷不退費
	Sfx.play(Sfx.SPELL_CAST, -2.0)
	var defender := "enemy" if battle_manager.active_side == "player" else "player"
	var quick: CardData = battle_manager.quick_candidate(defender)
	var countered := false
	if quick != null:
		if MatchMode.is_vs_ai():
			# 單人:守方是 AI,自動決策(有付得起的瞬咒就抵銷),不開人類面板——
			# 面板一開等於把 AI 的手牌資訊攤給玩家,還得由玩家替 AI 按鈕。
			countered = true
		else:
			# STEP 2:熱座把螢幕轉給守方回答;await = 整條流程停在這裡等面板的信號。
			ui_state = UiState.MENU_OPEN   # 鎖住其他 3D 互動,別讓玩家邊回答邊拖卡
			battle_ui.show_reaction("守方反制窗口",
				"對方施放【%s】→ 發動【%s】抵銷?(◆%d)" % [
					card.data.card_name, quick.card_name, quick.cost])
			countered = await battle_ui.reaction_decided
			ui_state = UiState.IDLE
	if countered:
		battle_manager.consume_quick(defender, quick)
		battle_ui.flash_message("【%s】被【%s】抵銷了!" % [
			card.data.card_name, quick.card_name])
	elif is_instance_valid(target):
		# STEP 4:結算(秘術傷害不吃反擊)。
		battle_manager.cast_arcana(card.data, target)
		battle_ui.flash_message("【%s】對【%s】造成 %d 點傷害" % [
			card.data.card_name, target.data.card_name, card.data.active_skill.power])
	# 秘術結算後離場(§7):不管有沒有被抵銷,牌都用掉了 → 入土。
	# (queue_free 掉的是「節點」,card.data 是 Resource、進墓地照樣活著。)
	battle_manager.bury(battle_manager.active_side, card.data)
	player_hand.play_card(card)
	card.queue_free()


## 靈裝:放開在我方從者身上 = 裝備(§7:宿主離場一併離場)。
func _try_attach_equip(card: Card) -> void:
	var target := raycast_check_for_card()
	if target == null or not target.is_on_board \
			or battle_manager.side_of(target) != battle_manager.active_side:
		battle_ui.flash_message("靈裝要放到「我方」場上從者身上")
		organize_hand()
		return
	if not battle_manager.can_afford(card.data.cost):
		battle_ui.flash_message("魔力不足:需要 ◆%d(現有 %d)" % [
			card.data.cost, battle_manager.active_mana()])
		organize_hand()
		return
	_pending_play_card = card
	var idx := player_hand.cards.find(card)
	var slot_np := get_path_to(battle_manager.find_slot_of(target))
	if NetMatch.is_online:
		_net_equip.rpc(idx, card.data.resource_path, slot_np)
	else:
		_net_equip(idx, card.data.resource_path, slot_np)


## 伏印(§7 宿主制):放開在「我方場上從者」身上 = 埋設在它底下。
## 埋好後我方整排卡槽泛紅警戒——對手知道「有陷阱」,但不知道埋在誰底下(威懾)。
func _try_set_ward(card: Card) -> void:
	var host := raycast_check_for_card()
	if host == null or not host.is_on_board \
			or battle_manager.side_of(host) != battle_manager.active_side:
		battle_ui.flash_message("伏印要埋設在「我方」場上從者底下(宿主制)")
		organize_hand()
		return
	if battle_manager.host_has_ward(host):
		battle_ui.flash_message("【%s】底下已經埋著一張伏印(一格一張)" % host.data.card_name)
		organize_hand()
		return
	if not battle_manager.can_afford(card.data.cost):
		battle_ui.flash_message("魔力不足:需要 ◆%d(現有 %d)" % [
			card.data.cost, battle_manager.active_mana()])
		organize_hand()
		return
	_pending_play_card = card
	var idx := player_hand.cards.find(card)
	var host_np := get_path_to(battle_manager.find_slot_of(host))
	if NetMatch.is_online:
		_net_ward.rpc(idx, card.data.resource_path, host_np)
	else:
		_net_ward(idx, card.data.resource_path, host_np)


## 丟牌回魔(§1.1):把手牌拖到墓地放開。回魔 = Cost÷2 捨去;最多隔回合一次。
## 出牌端先驗冷卻(給人話的拒絕理由),真正的帳在 _net_discard 兩台重放。
func _try_discard(card: Card) -> void:
	if not battle_manager.can_discard_for_mana(battle_manager.active_side):
		battle_ui.flash_message("丟牌回魔冷卻中:要隔一回合才能再用(§1.1)")
		organize_hand()
		return
	_pending_play_card = card
	var idx := player_hand.cards.find(card)
	if NetMatch.is_online:
		_net_discard.rpc(idx, card.data.resource_path)
	else:
		_net_discard(idx, card.data.resource_path)


@rpc("any_peer", "call_local", "reliable")
func _net_discard(hand_idx: int, card_path: String) -> void:
	var cd := load(card_path) as CardData
	if cd == null or not battle_manager.can_discard_for_mana(battle_manager.active_side):
		return
	var pile := _grave_piles.get(battle_manager.active_side) as GravePile
	if pile != null:
		pile.arm_recycle()   # 先上膛再結算:這次入土演出走回魔金,不跟陣亡的紫混
	var gained: int = battle_manager.apply_discard_for_mana(battle_manager.active_side, cd)
	_consume_played(hand_idx)   # 出牌端移視圖節點、重放端扣帳(同召喚的不對稱)
	Sfx.play(Sfx.MANA_GAIN, -4.0)   # 數錢聲:回魔的「入帳感」
	battle_ui.flash_message(
		"捨棄【%s】回暫時魔力 ◆%d(用不完不保留;丟牌下回合不可再用)" % [cd.card_name, gained])


## 指定目標中左鍵按下:點到合法目標就發動;點到其他任何地方 = 取消
## (和秘術同一套手感:點空地/非法目標都是反悔;右鍵/ESC 照舊可用)。
## 先找從者、再找本體——本體被擋時把理由講出來(路線有人擋、不能打自己人…)。
func _on_left_pressed_targeting() -> void:
	# 秘術瞄準:目標限敵方從者、不能打臉,獨立一條處理(見該函式)。
	if pending_spell_card != null:
		_on_left_pressed_spell_target()
		return
	var card := raycast_check_for_card()
	if card != null:
		if _is_valid_target(card):
			_execute_action(card)
		else:
			# 非法目標(自己人/手牌/潛行…):爐石式=點錯即反悔。
			battle_ui.flash_message("已取消行動")
			_cancel_command()
		return
	var hero := raycast_check_for_hero()
	if hero == null:
		_cancel_command()   # 點空地=想收手,安靜取消
		return
	var reason := battle_manager.face_block_reason(active_unit, hero, pending_skill)
	if reason == "":
		_execute_action(hero)
	else:
		battle_ui.flash_message("已取消:" + reason)
		_cancel_command()


## ── 指令選單的三個回應(BattleUI 的信號接進來)──────────

func _on_attack_chosen() -> void:
	# UI 已灰化過,這裡再驗一次:規則的最後一道門在帳房,不在按鈕。
	var reason := battle_manager.attack_block_reason(active_unit)
	if reason != "":
		battle_ui.flash_message(reason)
		return
	pending_skill = null   # null = 這次等目標的是普通攻擊
	_enter_targeting("選擇攻擊目標(點其他地方取消)")


func _on_skill_chosen(skill: SkillData) -> void:
	var reason := battle_manager.skill_block_reason(active_unit)
	if reason != "":
		battle_ui.flash_message(reason)
		return
	pending_skill = skill
	# 目標是「自己」的技能(戰吼、自療)不用選目標,選了直接發動。
	if skill.effect_target == SkillData.Target.SELF:
		_execute_action(active_unit)
		return
	_enter_targeting("選擇「%s」的目標(點其他地方取消)" % skill.skill_name)


func _enter_targeting(hint: String) -> void:
	ui_state = UiState.TARGETING
	battle_ui.show_targeting(hint)


## 反悔 / 收尾共用:清掉所有指令狀態、關 UI、收高亮。
func _cancel_command() -> void:
	if hovered_target != null and is_instance_valid(hovered_target):
		hovered_target.animate_unhover()
	hovered_target = null
	pending_skill = null
	pending_spell_card = null   # 秘術瞄準中途取消:卡沒離手,清狀態+收箭頭即可
	active_unit = null
	ui_state = UiState.IDLE
	battle_ui.close()


## ── 目標合法性 ────────────────────────────────────
## 普攻與敵對技能 → 指定敵方單位;友軍技能(ALLY)→ 指定我方單位(含自己)。
func _is_valid_target(card: Card) -> bool:
	if card == null or not card.is_on_board:
		return false
	var want_ally: bool = pending_skill != null \
		and pending_skill.effect_target == SkillData.Target.ALLY
	# 敵我用「相對施放者」判斷,別寫死 "player"/"enemy"——
	# 連線時 client 的我方單位在 enemy 群組,寫死會敵我顛倒(2b)。
	var side := battle_manager.side_of(card)
	var caster_side := battle_manager.side_of(active_unit)
	if want_ally:
		return side == caster_side
	return side != "" and side != caster_side


## (陣營查詢已搬進 BattleManager.side_of:帳房管規則,查詢跟著規則走。)


## ── 本體(Hero)────────────────────────────────────
## 造型借現成的卡資料:玩家=巫師、敵方=死靈法師(法師對決);HP 都是 20。
func _spawn_heroes() -> void:
	player_hero = _make_hero("player", "res://data/cards/wizard.tres")
	enemy_hero = _make_hero("enemy", "res://data/cards/necromancer.tres")
	battle_manager.register_heroes(player_hero, enemy_hero)


func _make_hero(side: String, look_path: String) -> Hero:
	var hero := Hero.new()
	add_child(hero)
	hero.setup(side, load(look_path))
	hero.global_position = _hero_anchor(side)
	# 本體只有兩尊、又是中樞自己生的,直接連;卡片那條中繼鏈是給「一大群」用的。
	hero.hero_hovered.connect(_on_hero_hovered)
	hero.hero_unhovered.connect(_on_hero_unhovered)
	return hero


## 本體站位:從卡槽群組的實際位置算,不寫死座標——換戰場、改排法都不用回來改。
## 兩側鏡像:各自站在「後排正後方」的中線上,鏡頭沿中線一眼看穿:
## 我方本體 → 我方卡槽 → (溪流) → 敵方卡槽 → 敵方本體。
## (舊版我方站左翼,是因為舊鏡頭壓得低、正後方會被手牌擋住;
##  這次鏡頭拉高拉遠後限制解除,站位回歸鏡像對稱。)
func _hero_anchor(side: String) -> Vector3:
	# 不能用三元運算式:它產出的是無型別 Array,執行期塞不進 Array[String] 會炸。
	var groups: Array[String] = ["player_front", "player_back"]
	if side != "player":
		groups = ["enemy_front", "enemy_back"]
	var sum := Vector3.ZERO
	var count := 0
	var far_z := 0.0   # 該側「後緣」的 z(玩家側取最大、敵方側取最小)
	for group in groups:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot:
				var p: Vector3 = (slot as CardSlot).global_position
				sum += p
				count += 1
				if count == 1:
					far_z = p.z
				elif side == "player":
					far_z = maxf(far_z, p.z)
				else:
					far_z = minf(far_z, p.z)
	if count == 0:
		return Vector3.ZERO   # 找不到卡槽(不該發生):放世界原點至少看得見
	var center := sum / float(count)
	# 貼近後排:本體站得越遠越貼畫面邊緣——我方會被手牌整個蓋住、敵方頂到上緣;
	# 但貼太近(1.3)會站進後排卡槽裡,1.8 是「分得開又看得全」的折中。
	var back_gap := 1.8   # 本體離自家後排的距離(兩側同值,維持鏡像)
	if side == "enemy":
		return Vector3(center.x, center.y, far_z - back_gap)
	return Vector3(center.x, center.y, far_z + back_gap)


## 指定目標中懸停本體:合法的打臉目標才亮(理由不為空就不亮,點下去才提示)。
func _on_hero_hovered(hero: Hero) -> void:
	if ui_state != UiState.TARGETING or active_unit == null:
		return
	if battle_manager.face_block_reason(active_unit, hero, pending_skill) != "":
		return
	if hovered_target != null and hovered_target != hero:
		hovered_target.animate_unhover()
	hovered_target = hero
	hero.animate_hover()


func _on_hero_unhovered(hero: Hero) -> void:
	if hovered_target == hero:
		hovered_target = null
		hero.animate_unhover()


## 勝負已分(BattleManager 廣播):收指令流程、鎖住 3D 互動、亮勝負畫面。
func _on_game_over(winner: String) -> void:
	# 正在拖的卡先放回手牌,別讓它懸在半空(GAME_OVER 後放開事件不會再處理)。
	if ui_state == UiState.DRAGGING:
		organize_hand()
		card_being_dragged = null
	_cancel_command()
	ui_state = UiState.GAME_OVER
	# 勝敗以「本機視角」判定:my_side 離線恆為 "player",熱座語意不變(2b)。
	battle_ui.show_game_over(winner == NetMatch.my_side)


## 結束回合(BattleUI 的按鈕)。連線時只有行動方按得動;
## 真正的換頁走 RPC 讓兩台同步翻頁(單機時 call_local 就地執行,行為不變)。
func _on_end_turn() -> void:
	if ui_state == UiState.GAME_OVER:
		return
	# 連線視角鎖定(2b 第一塊):不是你的回合,按了不換頁。
	if NetMatch.is_online and battle_manager.active_side != NetMatch.my_side:
		battle_ui.flash_message("還在對方的回合")
		return
	# 單人模式:AI 的回合它自己會結束,人類按了不算數。
	if MatchMode.is_vs_ai() and battle_manager.active_side != "player":
		battle_ui.flash_message("AI 行動中…")
		return
	# 離線直接本地呼叫:從主選單進來時 lobby 已把 multiplayer_peer 清成 null,
	# 此時 .rpc() 會報錯且「整個不執行」(call_local 也救不了)——rpc 只留給真連線。
	if NetMatch.is_online:
		_net_end_turn.rpc()
	else:
		_net_end_turn()


## 換頁令(兩端各跑一份)。"any_peer":輪到 client 時得由它發令;
## 發令資格由 _on_end_turn 的回合閘把關(伺服端驗證是 2b 剩餘的債,見學習債 §25)。
@rpc("any_peer", "call_local", "reliable")
func _net_end_turn() -> void:
	if ui_state == UiState.GAME_OVER:
		return
	Sfx.play(Sfx.TURN_FLIP, -2.0)   # 翻頁聲:回合交替(兩端各響各的)
	# 兩端各自收拾自己的互動狀態:拖到一半的卡先放回扇形——手牌視圖若重建,
	# 被拖著的卡遭 queue_free 就成懸空參考(摸了就炸);開著的選單一併收掉。
	if ui_state == UiState.DRAGGING:
		organize_hand()
		card_being_dragged = null
		ui_state = UiState.IDLE
	if ui_state == UiState.MENU_OPEN or ui_state == UiState.TARGETING:
		_cancel_command()
	currently_hovered_card = null
	# 換邊三步:①視圖上的手牌若正是行動方的帳,現況存回去
	# (熱座恆真;連線只有行動方那台為真——另一台顯示的是自己的手牌,別污染對方的帳)
	if _hand_view_shows_active_side():
		battle_manager.stash_hand(player_hand.hand_data())
	# ②帳房換邊+抽牌(資料層)
	var result: Dictionary = battle_manager.end_turn()
	# ③視圖:熱座跟著行動方換頁;連線鎖在自己這側——輪到對方時我的手牌原封不動
	# (=「對方回合不會發牌到我這邊」);輪到我才就位+單獨飛入新抽那張。
	if _hand_view_shows_active_side():
		player_hand.rebuild_from(battle_manager.active_hand(), false)
		if result.drawn != null:
			var deck_path := "../Deck" if battle_manager.active_side == "player" else "../EnemyDeck"
			player_hand.deal_last_from_deck(deck_path)
	_update_deck_labels()
	_refresh_opp_hud()   # 抽牌讓對方手牌張數變了(2d)
	# my_side 離線時恆為 "player",所以這行在熱座的語意跟以前一模一樣。
	var side_name := "我方" if battle_manager.active_side == NetMatch.my_side else "對方"
	var msg := "第 %d 回合:%s行動" % [battle_manager.turn, side_name]
	if result.burned and _hand_view_shows_active_side():
		msg += "(手牌已滿,抽到的牌燒掉了!)"
	battle_ui.flash_message(msg)
	# 單人模式:輪到 enemy = AI 上工(deferred:讓換頁流程先收乾淨再開始演)。
	if _enemy_ai != null and battle_manager.active_side == "enemy":
		_enemy_ai.take_turn.call_deferred()


## 這台機器的手牌視圖,顯示的是不是「行動方」的帳?
## 熱座:視圖永遠跟著行動方 → 恆真。連線:視圖鎖在 my_side → 輪到自己才真。
## 單人 vs AI:視圖鎖死玩家那側——AI 的回合你的手牌原封不動,對面的牌不攤給你看。
func _hand_view_shows_active_side() -> bool:
	if MatchMode.is_vs_ai():
		return battle_manager.active_side == "player"
	return not NetMatch.is_online or battle_manager.active_side == NetMatch.my_side


## 開局同步:手牌視圖餵「這台機器該看的那側」+ 掛上牌堆剩量標籤。
## 連線:鎖自己這側(client 開局看到自己的手牌,不是 host 的);
## 離線:my_side 恆 "player" = 開局行動方,行為不變。
func _sync_hand_view() -> void:
	player_hand.rebuild_from(battle_manager.hand_of(NetMatch.my_side))
	_update_deck_labels()


## 兩疊牌堆上方的剩量數字(帳在 BattleManager,這裡只是顯示)。
func _update_deck_labels() -> void:
	_set_deck_label("../Deck", battle_manager.deck_count("player"))
	_set_deck_label("../EnemyDeck", battle_manager.deck_count("enemy"))


func _set_deck_label(path: String, count: int) -> void:
	var deck := get_node_or_null(path) as Node3D
	if deck == null:
		return   # EnemyDeck 是延後生成的,第一次呼叫時可能還沒到,下次刷新會補上
	var lb: Label3D = deck.get_node_or_null("CountLabel")
	if lb == null:
		lb = Label3D.new()
		lb.name = "CountLabel"
		deck.add_child(lb)
		lb.position = Vector3(0.0, 0.55, 0.0)
		lb.font_size = 96
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		# 想過才不做:不掛 alpha_cut(Label3D 掛了會讓外框蓋掉字身,見 hero.gd);
		# 敵方牌堆在景深過渡帶、數字會微糊——和周圍地景同深度同糊法,視覺上是一致的。
		lb.outline_size = 16
		lb.modulate = Color(0.95, 0.9, 0.75)
	lb.text = str(count)


## 敵方牌堆(純視覺):把玩家牌堆整組複製、對角鏡射到敵方那側。
## main.tscn 零改動;敵方 AI 動工、有真抽牌邏輯時再回來接數量顯示。
func _spawn_enemy_deck() -> void:
	var deck := get_node_or_null("../Deck") as Node3D
	if deck == null:
		return
	var enemy_deck := deck.duplicate() as Node3D
	enemy_deck.name = "EnemyDeck"
	get_parent().add_child(enemy_deck)
	# 對角鏡射:x 取負(玩家右手邊 → 敵方右手邊),z 以雙方棋盤中線為軸翻過去。
	var mid_z := _board_mid_z()
	enemy_deck.position = Vector3(
		-deck.position.x, deck.position.y, mid_z * 2.0 - deck.position.z)


var _grave_piles: Dictionary = {}   # "player"/"enemy" → GravePile(純視覺,帳在 BattleManager)


## 墓地雙座:玩家墓在牌堆旁、靠場中央那側(挪 x 不挪 z——往中線挪會踩進
## 溪流的水帶 ±1.7,見 §29 的岸線保證),敵方對角鏡射(同 EnemyDeck)。
## 位置對稱於中線 → client 翻轉視角免特別處理(鏡像紅利)。
func _spawn_grave_piles() -> void:
	var deck := get_node_or_null("../Deck") as Node3D
	if deck == null:
		return
	var mid_z := _board_mid_z()
	var p_pos := deck.position + Vector3(-1.9, 0.0, 0.0)
	for side in ["player", "enemy"]:
		var pile := GravePile.new()
		pile.name = "GravePlayer" if side == "player" else "GraveEnemy"
		get_parent().add_child(pile)
		pile.setup(side)
		pile.position = p_pos if side == "player" \
			else Vector3(-p_pos.x, p_pos.y, mid_z * 2.0 - p_pos.z)
		_grave_piles[side] = pile


## 伏印帳有變(帳房廣播):整排卡槽的紅色警戒跟著開/關。
## 推「整排」而不是宿主那格——威懾要成立,對手就不能從視覺定位宿主(§7)。
func _on_wards_changed(side: String, count: int) -> void:
	for group in [side + "_front", side + "_back"]:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot:
				(slot as CardSlot).set_ward_alert(count > 0)


## 有牌入土(帳房廣播):刷新那一側的墓地視覺(張數+最上面那張)。
func _on_card_buried(side: String, _cd: CardData) -> void:
	var pile: GravePile = _grave_piles.get(side)
	if pile != null:
		pile.refresh(battle_manager.grave_count(side), battle_manager.grave_top(side))


## 雙方棋盤的中線 z(全部卡槽的平均):鏡射敵方牌堆用。
func _board_mid_z() -> float:
	var sum := 0.0
	var count := 0
	for group in BattleManager.SLOT_GROUPS:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot:
				sum += (slot as CardSlot).global_position.z
				count += 1
	return sum / float(count) if count > 0 else 0.0


## 有單位死了(BattleManager 廣播):把指向死者的參考清掉,
## 之後才不會去摸已被 free 的物件(懸空參考)。
func _on_unit_died(unit: Card) -> void:
	if hovered_target == unit:
		hovered_target = null
	if currently_hovered_card == unit:
		currently_hovered_card = null
	if active_unit == unit:
		_cancel_command()


## ── 發動(純演出版)────────────────────────────────
## 施放者播技能/攻擊動畫、目標播受擊動畫,並廣播 action_performed。
## 傷害、魔力、狀態的真結算屬於戰鬥系統(README 待辦 #5):它動工時訂閱這個信號,
## 這裡的流程一行都不用改——演出與規則分離。
func _execute_action(target: Node3D) -> void:
	var caster := active_unit
	var skill := pending_skill
	if NetMatch.is_online:
		# 連線:把「誰、用什麼、打誰」序列化成跨機器的身分證(單位=所在卡槽的路徑,
		# 兩台場景樹一致;本體=側別字串),廣播後兩台各自重放同一個行動。
		var tgt_is_hero := target is Hero
		var tgt_ref := (target as Hero).side if tgt_is_hero \
			else str(get_path_to(battle_manager.find_slot_of(target as Card)))
		_net_action.rpc(get_path_to(battle_manager.find_slot_of(caster)),
			skill != null, tgt_is_hero, tgt_ref)
	else:
		_do_execute_action(caster, skill, target)
	_cancel_command()


## 行動的本地執行(單機直呼;連線由 _net_action 在兩台各跑一份)。
func _do_execute_action(caster: Card, skill: SkillData, target: Node3D) -> void:
	if skill != null:
		# 技能動畫表由資料指定(skill.anim);沒有該表就退回普攻動畫。
		if not caster.play_one_shot_anim(skill.anim):
			caster.play_one_shot_anim("Attack01")
	else:
		# 普攻預設 Attack01;牧師/骷髏弓手只有單張「Attack」表 → 備案。
		if not caster.play_one_shot_anim("Attack01"):
			caster.play_one_shot_anim("Attack")
	# 受擊動畫改由 BattleManager 在「傷害落地」那刻播(和飄浮數字同步),
	# 也順便修掉「被治療卻播受傷動畫」的怪象——挨打是結算的事,不是宣告的事。
	action_performed.emit(caster, skill, target)


## ── 射線：找滑鼠下方的「卡片」(第 1 層)──────────────
func raycast_check_for_card() -> Card:
	var mouse_pos := get_viewport().get_mouse_position()

	# 射線起點 = 攝影機；終點 = 往滑鼠方向延伸 1000 單位(夠長即可)。
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0

	# 取得 3D 物理世界，準備做查詢。
	var space_state := get_world_3d().direct_space_state

	# 建立射線查詢參數(3D 用 intersect_ray；2D 才是 intersect_point)。
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true   # 卡片用的是 Area3D，必須打開才掃得到
	query.collide_with_bodies = true
	query.collision_mask = COLLISION_MASK_CARD  # 只掃第 1 層(卡片)

	# 執行射線。打中東西時 result 是一個字典，沒打中是空的。
	var result := space_state.intersect_ray(query)

	if result:
		# result.collider 是被打中的 Area3D，它的父節點才是 Card 本體。
		print('點擊在卡片上', result.collider.get_parent())
		return result.collider.get_parent() as Card
	print('點擊在卡片外面')
	return null


## ── 射線:找滑鼠下方的「本體」(第 3 層)──────────────
func raycast_check_for_hero() -> Hero:
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true   # 本體的感應區也是 Area3D
	query.collision_mask = COLLISION_MASK_HERO
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.collider.get_parent() as Hero
	return null


## ── 射線：找滑鼠下方的「卡槽」(第 2 層)──────────────
## 回傳型別寫成 -> CardSlot，代表這個函式保證回傳一個卡槽(或 null)。
func raycast_check_for_card_slot() -> CardSlot:
	var space_state := get_world_3d().direct_space_state
	var mouse_pos := get_viewport().get_mouse_position()

	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# 關鍵：這次只掃第 2 層(卡槽)，所以不會誤打到卡片。
	query.collision_mask = COLLISION_MASK_SLOT
	# CardSlot 本身就是 Area3D，必須打開這個才掃得到。
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result:
		# as CardSlot：把打中的東西「當作」CardSlot 型別回傳(方便後續取用它的方法)。
		return result.collider as CardSlot

	return null


## ── 射線:找滑鼠下方的「墓地投放區」(第 4 層;丟牌回魔 §1.1)──────
func raycast_check_for_grave() -> GravePile:
	var space_state := get_world_3d().direct_space_state
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = COLLISION_MASK_GRAVE
	query.collide_with_areas = true
	var result := space_state.intersect_ray(query)
	if result:
		# 打中的是墓座底下的 Area3D,它的父節點才是 GravePile 本體。
		return (result.collider as Area3D).get_parent() as GravePile
	return null


## 轉呼叫手牌的重排，讓出牌後剩下的牌靠攏。
func organize_hand() -> void:
	if player_hand:
		player_hand.organize_hand()


## ═══ 連線對戰(2b–2e):行動同步、開局帳、視角、斷線 ═══════════════
## 架構(ADR-001 的 demo 簡化版):host 開局把雙方牌堆/起手打包給 client(帳同步),
## 之後每個行動在「出牌端」驗證後廣播,兩台各自重放——資料一致+操作一致=狀態一致。
## 已知債(公開上架前要還):①行動合法性只在出牌端驗(client 可作弊)
## ②對方手牌「內容」其實在本機記憶體裡(真正的資訊隱藏 = host 只送張數)。

var _accounts_synced := false        # client:開局帳收到了沒(host 天生 true)
var _pending_play_card: Card = null  # 出牌端暫存「正被打出的手牌節點」,給重放函式取用
var _pending_arcana_target: NodePath # 秘術宣告後、等反制結果期間的目標(兩台都記)
var _pending_arcana_path: String = ""


## 這台機器是不是「行動方本人」(單機恆真;連線只有輪到自己那台為真)。
## 單人 vs AI 的 enemy 回合:行動方是 AI 不是這台的人類 → false。
## 這讓 AI 自動走 _net_summon/_consume_played 的「重放端」分支(帳面路徑)——
## AI 和連線重放端處境相同:沒有被拖過來的卡節點,只有帳和索引。
func _acting_locally() -> bool:
	if MatchMode.is_vs_ai():
		return battle_manager.active_side == "player"
	return not NetMatch.is_online or battle_manager.active_side == NetMatch.my_side


## 取出並清空暫存的出牌節點(只有出牌端有;重放端拿到 null,走帳面路徑)。
func _take_pending_card() -> Card:
	var c := _pending_play_card
	_pending_play_card = null
	return c


## 打出的牌離手:出牌端移視圖節點、重放端扣帳面手牌(兩台的帳保持一致)。
func _consume_played(hand_idx: int) -> void:
	if _acting_locally():
		var card := _take_pending_card()
		if card != null:
			player_hand.play_card(card)
			card.queue_free()
	else:
		battle_manager.remove_from_hand(battle_manager.active_side, hand_idx)
	_refresh_opp_hud()


## 用「所在卡槽的路徑」反查單位——卡槽路徑是單位的跨機器身分證(兩台場景樹一致)。
func _unit_at(slot_np: NodePath) -> Card:
	var slot := get_node_or_null(slot_np) as CardSlot
	return slot.card_in_slot if slot != null else null


## ── 召喚 ─────────────────────────────────────────
@rpc("any_peer", "call_local", "reliable")
func _net_summon(hand_idx: int, card_path: String, slot_np: NodePath) -> void:
	var slot := get_node_or_null(slot_np) as CardSlot
	var cd := load(card_path) as CardData
	if slot == null or not slot.is_empty or cd == null:
		return
	battle_manager.spend(cd.cost)
	var msg: String
	if _acting_locally():
		# 出牌端:用手上真的被拖過來的那張卡節點(動畫連續)。
		var card := _take_pending_card()
		if card == null:
			return
		msg = battle_manager.mark_summoned(card)   # 召喚暈眩+對方伏印觸發(§7)
		slot.place_card(card)
		player_hand.play_card(card)
	else:
		# 重放端:帳面扣牌 + 生一個新單位節點放進同一格。
		battle_manager.remove_from_hand(battle_manager.active_side, hand_idx)
		var unit := battle_manager.spawn_unit(cd, slot)
		if unit == null:
			return
		msg = battle_manager.mark_summoned(unit)
	if msg != "":
		battle_ui.flash_message(msg)
	_refresh_opp_hud()


## ── 攻擊/技能 ─────────────────────────────────────
@rpc("any_peer", "call_local", "reliable")
func _net_action(caster_np: NodePath, use_skill: bool, tgt_is_hero: bool, tgt_ref: String) -> void:
	var caster := _unit_at(caster_np)
	if caster == null:
		return
	var target: Node3D
	if tgt_is_hero:
		target = battle_manager.player_hero if tgt_ref == "player" \
			else battle_manager.enemy_hero
	else:
		target = _unit_at(NodePath(tgt_ref))
	if target == null:
		return
	_do_execute_action(caster, caster.data.active_skill if use_skill else null, target)


## ── 秘術宣告與反制(§5.1 跨機器版:反制窗口開在「守方那台」)──────
@rpc("any_peer", "call_local", "reliable")
func _net_arcana_declare(hand_idx: int, card_path: String, target_np: NodePath) -> void:
	var cd := load(card_path) as CardData
	if cd == null:
		return
	battle_manager.spend(cd.cost)   # STEP 1:宣告即付費,被抵銷不退(兩台同記)
	_pending_arcana_path = card_path
	_pending_arcana_target = target_np
	if _acting_locally():
		battle_ui.flash_message("等待對方反應…")
		ui_state = UiState.MENU_OPEN   # 鎖操作,直到守方那台把結果送回來
	else:
		battle_manager.remove_from_hand(battle_manager.active_side, hand_idx)
		_refresh_opp_hud()
		_ask_reaction_and_reply(cd)


## 守方那台:有付得起的瞬咒就開面板問玩家,沒有就直接回「不反制」。
func _ask_reaction_and_reply(arcana: CardData) -> void:
	var quick: CardData = battle_manager.quick_candidate(NetMatch.my_side)
	if quick == null:
		_net_arcana_resolve.rpc(false)
		return
	ui_state = UiState.MENU_OPEN
	battle_ui.show_reaction("反制窗口",
		"對方施放【%s】→ 發動【%s】抵銷?(◆%d)" % [
			arcana.card_name, quick.card_name, quick.cost])
	var used: bool = await battle_ui.reaction_decided
	ui_state = UiState.IDLE
	_net_arcana_resolve.rpc(used)


@rpc("any_peer", "call_local", "reliable")
func _net_arcana_resolve(countered: bool) -> void:
	var cd := load(_pending_arcana_path) as CardData
	_pending_arcana_path = ""
	if cd == null:
		return
	var defender := "enemy" if battle_manager.active_side == "player" else "player"
	Sfx.play(Sfx.SPELL_CAST, -2.0)   # 連線/AI 的結算端也要出聲(熱座走 _resolve_arcana)
	battle_manager.bury(battle_manager.active_side, cd)   # 秘術用掉即入土(兩台各埋各的帳)
	if countered:
		# 兩台的帳同步,quick_candidate 的「第一張付得起」在兩台挑到同一張。
		var quick: CardData = battle_manager.quick_candidate(defender)
		if quick != null:
			battle_manager.consume_quick(defender, quick)
		battle_ui.flash_message("【%s】被抵銷了!" % cd.card_name)
	else:
		var target := _unit_at(_pending_arcana_target)
		if target != null:
			battle_manager.cast_arcana(cd, target)
			battle_ui.flash_message("【%s】造成 %d 點傷害" % [
				cd.card_name, cd.active_skill.power])
	if _acting_locally():
		ui_state = UiState.IDLE
		var card := _take_pending_card()
		if card != null:
			player_hand.play_card(card)
			card.queue_free()
	_refresh_opp_hud()


## ── 靈裝/伏印 ─────────────────────────────────────
@rpc("any_peer", "call_local", "reliable")
func _net_equip(hand_idx: int, card_path: String, target_np: NodePath) -> void:
	var cd := load(card_path) as CardData
	var target := _unit_at(target_np)
	if cd == null or target == null:
		return
	battle_manager.spend(cd.cost)
	var replaced: String = battle_manager.attach_equip(cd, target)
	if replaced != "":
		battle_ui.flash_message("【%s】替換了【%s】(舊裝進墓地):生命上限 +%d" % [
			cd.card_name, replaced, cd.active_skill.amount])
	else:
		battle_ui.flash_message("【%s】裝備到【%s】:生命上限 +%d" % [
			cd.card_name, target.data.card_name, cd.active_skill.amount])
	_consume_played(hand_idx)


@rpc("any_peer", "call_local", "reliable")
func _net_ward(hand_idx: int, card_path: String, host_slot: NodePath) -> void:
	var cd := load(card_path) as CardData
	var host := _unit_at(host_slot)
	if cd == null or host == null or battle_manager.host_has_ward(host):
		return
	battle_manager.spend(cd.cost)
	battle_manager.set_ward(cd, host)
	# ⚠ 訊息不能報宿主名字:這行兩台都會 flash,說了就把陷阱位置洩給對手。
	battle_ui.flash_message("伏印已埋設(敵方召喚從者時觸發)")
	_consume_played(hand_idx)


## ── 開局帳同步(host 權威發牌;client 進場後主動來要)──────────
@rpc("any_peer", "reliable")
func _net_request_state() -> void:
	if not multiplayer.is_server():
		return
	_net_apply_state.rpc_id(multiplayer.get_remote_sender_id(),
		battle_manager.export_accounts())


@rpc("authority", "reliable")
func _net_apply_state(data: Dictionary) -> void:
	battle_manager.import_accounts(data)
	_accounts_synced = true
	_sync_hand_view()
	_refresh_opp_hud()


## client:每 0.5 秒要一次直到拿到——host 的場景可能比我晚 ready,先發的請求會撲空。
func _request_state_loop() -> void:
	for i in range(20):
		if _accounts_synced or not NetMatch.is_online:
			return
		_net_request_state.rpc_id(1)
		await get_tree().create_timer(0.5).timeout
	battle_ui.flash_message("開局同步失敗:請回主選單重新連線")


## ── 視角(2b):client 把鏡頭/手牌/雙牌堆繞棋盤中線轉 180°,從自己那側看桌 ──
func _apply_client_viewpoint() -> void:
	if not NetMatch.is_online or NetMatch.my_side != "enemy":
		return
	var mid_z := _board_mid_z()
	# 繞「通過棋盤中線 (0,*,mid_z) 的垂直軸」轉半圈:v → (-x, y, 2·mid_z − z)。
	# 只轉觀察者這一掛(鏡頭/手牌/牌堆),棋盤和單位不動——世界只有一份,視角有兩個。
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, 2.0 * mid_z))
	for path in ["../CameraRig", "../PlayerHand", "../Deck", "../EnemyDeck"]:
		var node := get_node_or_null(path) as Node3D
		if node != null:
			node.global_transform = flip * node.global_transform


## ── HUD:對方手牌張數(2d 的張數版;卡背扇形之後再說)────────────
func _refresh_opp_hud() -> void:
	if not (NetMatch.is_online or MatchMode.is_vs_ai()):
		return
	var opp := "enemy" if NetMatch.my_side == "player" else "player"
	var n: int = battle_manager.hand_of(opp).size()
	battle_ui.update_opp_count(n)
	if _opp_hand != null:
		_opp_hand.update_count(n)
	_update_deck_labels()


## 對手卡背扇形:錨在「對手本體」後上方(離線對手=enemy;連線 client 的對手=player,
## 世界座標在 +Z 側,而 client 的鏡頭已翻轉,看過去一樣是畫面頂端)。
func _spawn_opp_hand() -> void:
	var opp := "enemy" if NetMatch.my_side == "player" else "player"
	_opp_hand = OpponentHand.new()
	get_parent().add_child(_opp_hand)
	_opp_hand.setup_at(_hero_anchor(opp), opp)
	_refresh_opp_hud()


## ── 斷線(2e):任一方掉線 = 收桌回主選單 ───────────────────
func _on_net_peer_lost(_id: int) -> void:
	_handle_net_lost()


func _on_net_server_lost() -> void:
	_handle_net_lost()


func _handle_net_lost() -> void:
	if ui_state == UiState.GAME_OVER:
		return
	ui_state = UiState.GAME_OVER   # 鎖住一切互動
	battle_ui.flash_message("對方已離線,返回主選單…")
	await get_tree().create_timer(2.0).timeout
	_leave_online_match()


## 收線離場:關 peer、清 NetMatch、回主選單(勝負畫面的兩顆按鈕也走這裡)。
func _leave_online_match() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	NetMatch.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
