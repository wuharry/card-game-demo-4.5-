## grave_pile.gd — 墓地/棄牌堆(一側一座):發光邊框 + 牌疊 + 張數 + 最後入土那張卡
##
## 帳在 BattleManager(SideState.grave),這裡純視覺:CardManager 訂閱
## card_buried 信號後呼叫 refresh()。把手牌拖到底座上放開 = 丟牌回魔(§1.1)。
## 底座的 Area3D 掛第 4 層(value 8),card_manager 用獨立射線掃——
## 不跟卡片(1)/卡槽(2)/本體(4)打架。
## 兩座墓的位置對稱於棋盤中線:client 的翻轉視角不需要任何特別處理(鏡像紅利)。
##
## 「入土要看得見」三件套(refresh):頂牌從半空落進墓裡 → 落地瞬間邊框
## emission 脈衝(推過 glow 門檻 0.95 → 泛光,同 FxBurst/卡槽高亮的招)+
## 幽紫爆點;牌疊隨張數長高。shown_count 與標籤數字一律「同步」更新,
## 動畫只是演出——帳與視覺對齊的斷言(grave_test §5)不必等補間。
class_name GravePile
extends Node3D

const DROP_LAYER := 8   # 第 4 層:墓地投放區(= card_manager.COLLISION_MASK_GRAVE)
const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
const TOP_CARD_SCALE := 0.8   # 躺在墓上的展示卡,比手牌小一號別搶戲
const DROP_HEIGHT := 1.5      # 頂牌從這個高度落下(「牌的去向」演出)
const STACK_STEP := 0.02      # 牌疊每張長高的厚度
const STACK_SHOWN_MAX := 12   # 疊高封頂:張數再多也只長到這,別長成塔
const GLOW_IDLE := 0.7        # 邊框平時的 emission 能量:隱約標出「這裡是墓」
const GLOW_PULSE := 3.5       # 入土瞬間打到這麼亮(過 glow 門檻 → 泛光)再衰減回平時
const SOUL_PURPLE := Color(0.62, 0.42, 0.95)   # 幽紫:和張數標籤同色系

var side: String = "player"
var shown_count: int = 0   # 視覺當下顯示的張數(headless 測試對帳用)

var _count_label: Label3D = null
var _top_card: Card = null
var _frame_mat: StandardMaterial3D = null   # 四條邊框共用一份材質,脈衝只調這裡
var _stack: MeshInstance3D = null
var _stack_box: BoxMesh = null
var _drop_tween: Tween = null
var _pulse_tween: Tween = null
var _label_tween: Tween = null


func setup(pile_side: String) -> void:
	side = pile_side
	_build_base()
	_build_frame()
	_build_stack()
	_build_label()


func _build_base() -> void:
	# 底座:貼地的暗色薄膜(邊框圈起來的「墓室內部」)。半透明不寫深度沒關係——
	# 它貼著地面,背景就是同深度的地,DOF 糊不糊都一致(§31 的深度陷阱在這裡不成立)。
	var base := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 2.5)
	base.mesh = quad
	base.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # 躺平貼地
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.04, 0.06, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base.material_override = mat
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.position.y = 0.02
	add_child(base)
	# 投放區(丟牌回魔的靶):比底座略大一圈,好瞄
	var area := Area3D.new()
	area.collision_layer = DROP_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 2.7)
	shape.shape = box
	shape.position = Vector3(0.0, 0.3, 0.0)
	area.add_child(shape)
	add_child(area)


func _build_frame() -> void:
	# 發光邊框:貼地四條細長方體圍一圈。舊版只有暗色薄膜貼在暗色地面上近乎隱形;
	# 邊框靠 emission 說話、不吃場景光,晝夜/陰影下都讀得到「這裡是墓」。
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.albedo_color = Color(0.12, 0.08, 0.18)
	_frame_mat.emission_enabled = true
	_frame_mat.emission = SOUL_PURPLE
	_frame_mat.emission_energy_multiplier = GLOW_IDLE
	var w := 1.8    # 邊框外圍略大於底座薄膜(1.7×2.5)
	var d := 2.6
	var t := 0.07   # 邊框粗細
	var specs: Array = [
		[Vector3(w, 0.05, t), Vector3(0.0, 0.03, (d - t) / 2.0)],
		[Vector3(w, 0.05, t), Vector3(0.0, 0.03, -(d - t) / 2.0)],
		[Vector3(t, 0.05, d), Vector3((w - t) / 2.0, 0.03, 0.0)],
		[Vector3(t, 0.05, d), Vector3(-(w - t) / 2.0, 0.03, 0.0)],
	]
	for s in specs:
		var edge := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s[0]
		edge.mesh = box
		edge.material_override = _frame_mat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		edge.position = s[1]
		add_child(edge)


func _build_stack() -> void:
	# 牌疊:頂牌底下的暗色方磚,高度跟張數走 → 「墓越埋越厚」看得見。
	_stack = MeshInstance3D.new()
	_stack_box = BoxMesh.new()
	_stack_box.size = Vector3(1.15, STACK_STEP, 1.6)
	_stack.mesh = _stack_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.18, 0.28)
	_stack.material_override = mat
	_stack.visible = false
	add_child(_stack)


func _build_label() -> void:
	_count_label = Label3D.new()
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count_label.no_depth_test = true
	_count_label.font_size = 64
	_count_label.outline_size = 12
	_count_label.modulate = Color(0.82, 0.76, 0.92)   # 淡紫:和牌堆的米金區隔
	_count_label.position = Vector3(0.75, 0.5, 0.95)
	_count_label.text = ""
	add_child(_count_label)


## 頂牌「以下」的牌疊厚度:count-1 張、封頂 STACK_SHOWN_MAX。
func _stack_height(count: int) -> float:
	return STACK_STEP * mini(maxi(count - 1, 0), STACK_SHOWN_MAX)


## 帳變動時刷新:張數/牌疊同步更新,新頂牌播「落進墓裡」的演出。
## 展示卡只生一個節點、之後重複 setup 換資料(量級小,免物件池的同款理由)。
func refresh(count: int, top: CardData) -> void:
	var grew := count > shown_count
	shown_count = count
	_count_label.text = str(count) if count > 0 else ""
	var h := _stack_height(count)
	_stack.visible = h > 0.0
	if h > 0.0:
		_stack_box.size.y = h
		_stack.position.y = 0.03 + h / 2.0
	if top == null:
		if _top_card != null:
			_top_card.visible = false
		return
	if _top_card == null:
		_top_card = CARD_SCENE.instantiate()
		add_child(_top_card)
		# 展示品不是互動對象:碰撞整層拔掉,別攔 hover / 拖曳 / 目標指定的射線
		var area := _top_card.get_node_or_null("Area3D") as Area3D
		if area != null:
			area.collision_layer = 0
			area.monitoring = false
			area.monitorable = false
		_top_card.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # 躺平、卡面朝上
	_top_card.visible = true
	_top_card.setup(top)
	var land_y := 0.04 + h
	# 同幀連埋(陣亡+隨葬靈裝)會連呼 refresh:先殺舊補間,
	# 別讓兩條 tween 同時寫 position(§29 的同款教訓)。
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	if not grew:
		_top_card.position = Vector3(0.0, land_y, 0.0)
		_top_card.scale = Vector3.ONE * TOP_CARD_SCALE
		return
	# 入土演出:新頂牌從半空落進墓裡——「牌的去向」要看得見。
	_top_card.position = Vector3(0.0, land_y + DROP_HEIGHT, 0.0)
	_top_card.scale = Vector3.ONE * TOP_CARD_SCALE * 1.15
	_drop_tween = create_tween().set_parallel(true)
	_drop_tween.tween_property(_top_card, "position:y", land_y, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.tween_property(_top_card, "scale", Vector3.ONE * TOP_CARD_SCALE, 0.3)
	_drop_tween.chain().tween_callback(_on_card_landed)
	_pop_label()


## 落地瞬間:邊框脈衝 + 幽紫爆點(FxBurst 複用:同一顆範本換個顏色)。
func _on_card_landed() -> void:
	_pulse()
	FxBurst.spawn_at(self, SOUL_PURPLE)
	Sfx.play(Sfx.CARD_BURY, -4.0)


func _pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_frame_mat.emission_energy_multiplier = GLOW_PULSE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_frame_mat, "emission_energy_multiplier", GLOW_IDLE, 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _pop_label() -> void:
	if _label_tween != null and _label_tween.is_valid():
		_label_tween.kill()
	_count_label.scale = Vector3.ONE * 1.6
	_label_tween = create_tween()
	_label_tween.tween_property(_count_label, "scale", Vector3.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
