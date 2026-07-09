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

## @onready：等節點都準備好後，才執行右邊的取值並存進變數(太早拿可能還是 null)。
## camera：場景目前啟用中的攝影機。把滑鼠的 2D 座標換成 3D 射線時一定要用到它。
@onready var camera: Camera3D = get_viewport().get_camera_3d()

## 目前「被滑鼠抓著拖曳」的卡片。沒有在拖任何卡時是 null。
var card_being_dragged: Card = null
## 拖曳時把卡片鎖在這個高度(Y 軸)，避免它忽高忽低或穿進地板。
var drag_plane_height: float = 0.0
## 目前被滑鼠 hover(放大)的卡片。全場同時「只能有一張」被放大，避免畫面混亂。
var currently_hovered_card: Card = null
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
enum UiState { IDLE, DRAGGING, MENU_OPEN, TARGETING }
var ui_state: UiState = UiState.IDLE

## 指令選單(程式生成的 CanvasLayer,見 battle_ui.gd)。
var battle_ui: BattleUI = null
## 選單目前的主角(被點擊的上桌單位)。
var active_unit: Card = null
## 等待指定目標的技能;null 代表等待目標的是「普通攻擊」。
var pending_skill: SkillData = null
## TARGETING 狀態下目前亮起的候選目標。
var hovered_target: Card = null

## 有行動發動了(純演出版:只播動畫)。之後的戰鬥系統訂閱這個信號做
## 真正的結算(扣魔力、算傷害、上狀態);skill = null 代表普通攻擊。
signal action_performed(caster: Card, skill: SkillData, target: Card)


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


## ── 收到「滑鼠移到某張卡上」事件 ──────────────────
func on_card_hovered(card: Card) -> void:
	# 防呆 1：正在拖牌時，不要去放大底下其他的牌。
	if card_being_dragged != null:
		return

	# 上桌單位不做「手牌式放大」;只有在指定目標模式、而且是合法目標時,
	# 才亮起當「候選目標」的視覺回饋(借用同一套放大動畫)。
	if card.is_on_board:
		if ui_state == UiState.TARGETING and _is_valid_target(card):
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
	if currently_hovered_card != null and currently_hovered_card != card:
		currently_hovered_card.animate_unhover()

	# 記住目前放大的是這張，並播放它的放大動畫。
	currently_hovered_card = card
	card.animate_hover()
	# (未來可在這裡讓卡片往前移一點，避免被旁邊的牌擋住)


## ── 收到「滑鼠離開某張卡」事件 ──────────────────
func on_card_unhovered(card: Card) -> void:
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

	# 指定目標中:每幀把「施放者 → 游標」的螢幕座標餵給 BattleUI 畫導引箭頭。
	# unproject_position 是射線的反運算:3D 世界座標 → 螢幕像素座標。
	elif ui_state == UiState.TARGETING and active_unit != null:
		var aim := get_viewport().get_mouse_position()
		var locked := hovered_target != null
		if locked:
			# 鎖定合法目標時,箭頭尖端吸附到目標身上,不再跟著游標抖。
			aim = camera.unproject_position(
				hovered_target.global_position + Vector3.UP * 0.5)
		var from_px := camera.unproject_position(
			active_unit.global_position + Vector3.UP * 0.5)
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
		battle_ui.open(card)
		return
	# ── 抓牌(原本的拖曳邏輯)──
	card_being_dragged = card
	ui_state = UiState.DRAGGING
	# 記住卡片當下的高度，拖曳時就維持在這個高度水平移動。
	drag_plane_height = card.global_position.y
	# 抓起來的瞬間取消它的放大狀態，避免邊拖邊放大的怪畫面。
	if currently_hovered_card == card:
		currently_hovered_card = null
		card.animate_unhover()


## 拖曳中左鍵放開 = 嘗試出牌(原本的釋放邏輯)。
func _on_left_released_drag() -> void:
	# 往下射線，看看放開的位置下面有沒有卡槽。
	var found_slot := raycast_check_for_card_slot()

	# 找到卡槽、而且是空的 → 成功出牌。
	if found_slot and found_slot.is_empty:
		found_slot.place_card(card_being_dragged)         # 交給卡槽處理入槽動畫+鎖定
		player_hand.play_card(card_being_dragged)         # 移除手牌+重新靠攏，封裝在手牌自己身上
		print("成功把卡片放進卡槽！")
	else:
		# 沒對準卡槽 / 卡槽已滿 → 讓它回到手牌扇形原位。
		organize_hand()

	# 結算完畢，鬆手 → 清空「正在拖曳」的記錄。
	card_being_dragged = null
	ui_state = UiState.IDLE


## 指定目標中左鍵按下:點到合法目標就發動;點到別的東西不動作(右鍵才是取消)。
func _on_left_pressed_targeting() -> void:
	var card := raycast_check_for_card()
	if card == null or not _is_valid_target(card):
		return
	_execute_action(card)


## ── 指令選單的三個回應(BattleUI 的信號接進來)──────────

func _on_attack_chosen() -> void:
	pending_skill = null   # null = 這次等目標的是普通攻擊
	_enter_targeting("選擇攻擊目標(右鍵取消)")


func _on_skill_chosen(skill: SkillData) -> void:
	pending_skill = skill
	# 目標是「自己」的技能(戰吼、自療)不用選目標,選了直接發動。
	if skill.effect_target == SkillData.Target.SELF:
		_execute_action(active_unit)
		return
	_enter_targeting("選擇「%s」的目標(右鍵取消)" % skill.skill_name)


func _enter_targeting(hint: String) -> void:
	ui_state = UiState.TARGETING
	battle_ui.show_targeting(hint)


## 反悔 / 收尾共用:清掉所有指令狀態、關 UI、收高亮。
func _cancel_command() -> void:
	if hovered_target != null:
		hovered_target.animate_unhover()
		hovered_target = null
	pending_skill = null
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
	var side := _unit_side(card)
	if want_ally:
		return side == "player"
	return side == "enemy" and card != active_unit


## 這個單位站在誰的棋盤上?用卡槽群組反查——
## player_board 生成卡槽時就分好了 player_*/enemy_* 群組,正是給這種查詢用的。
## 量級:最多 20 個槽的線性掃描,一次點擊才查一次,不用快取。
func _unit_side(card: Card) -> String:
	for group in ["player_front", "player_back", "enemy_front", "enemy_back"]:
		for slot in get_tree().get_nodes_in_group(group):
			if slot is CardSlot and slot.card_in_slot == card:
				return "player" if (group as String).begins_with("player") else "enemy"
	return ""


## ── 發動(純演出版)────────────────────────────────
## 施放者播技能/攻擊動畫、目標播受擊動畫,並廣播 action_performed。
## 傷害、魔力、狀態的真結算屬於戰鬥系統(README 待辦 #5):它動工時訂閱這個信號,
## 這裡的流程一行都不用改——演出與規則分離。
func _execute_action(target: Card) -> void:
	var caster := active_unit
	var skill := pending_skill
	if skill != null:
		# 技能動畫表由資料指定(skill.anim);沒有該表就退回普攻動畫。
		if not caster.play_one_shot_anim(skill.anim):
			caster.play_one_shot_anim("Attack01")
	else:
		# 普攻預設 Attack01;牧師/骷髏弓手只有單張「Attack」表 → 備案。
		if not caster.play_one_shot_anim("Attack01"):
			caster.play_one_shot_anim("Attack")
	if target != caster:
		target.play_one_shot_anim("Hurt")   # 受擊回饋:所有角色都有 Hurt 表
	action_performed.emit(caster, skill, target)
	_cancel_command()


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


## 轉呼叫手牌的重排，讓出牌後剩下的牌靠攏。
func organize_hand() -> void:
	if player_hand:
		player_hand.organize_hand()
