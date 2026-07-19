## grave_pile.gd — 墓地/棄牌堆(一側一座):黑洞旋渦盤 + 吸積光環 + 牌疊 + 張數
##
## 帳在 BattleManager(SideState.grave),這裡純視覺:CardManager 訂閱
## card_buried 信號後呼叫 refresh()。把手牌拖到黑洞上放開 = 丟牌回魔(§1.1)。
## 投放區 Area3D 掛第 4 層(value 8),card_manager 用獨立射線掃——
## 不跟卡片(1)/卡槽(2)/本體(4)打架。
## 兩座墓對稱於棋盤中線:client 翻轉視角不需特別處理(鏡像紅利)。
##
## 視覺分兩份材質,職責切開:
##   ‧ 黑洞盤 = ShaderMaterial(grave_vortex.gdshader),TIME 自轉,純裝飾,
##     遊戲邏輯永遠不戳它——常駐小動畫放 GPU,CPU 一幀都不用管。
##   ‧ 吸積環 = StandardMaterial3D(_frame_mat),脈衝/回魔金/懸停提示都只調這份。
## 「入土要看得見」:頂牌旋轉著被吸進洞裡 → 落定瞬間光環脈衝 + 爆點;
## 回魔(§1.1)走金色、陣亡入土走幽紫——同一座墓、兩種語意、兩套顏色。
## shown_count 與標籤數字一律「同步」更新,動畫只是演出(grave_test §5 不等補間)。
class_name GravePile
extends Node3D

const DROP_LAYER := 8   # 第 4 層:墓地投放區(= card_manager.COLLISION_MASK_GRAVE)
const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
const VORTEX_SHADER: Shader = preload("res://src/grave_pile/grave_vortex.gdshader")
const TOP_CARD_SCALE := 0.62  # 躺在洞口的展示卡(整座縮小,卡也跟著小一號)
const DROP_HEIGHT := 1.2      # 頂牌從這個高度被吸下來
const STACK_STEP := 0.02      # 牌疊每張長高的厚度
const STACK_SHOWN_MAX := 12   # 疊高封頂:張數再多也只長到這,別長成塔
const GLOW_IDLE := 1.8        # 光環「常駐」過 glow 門檻(0.95)→ 不 hover 也持續泛光,
                              # 新手第一眼就看到這裡是可互動區(§1.1 醒目度)
const GLOW_PULSE := 4.5       # 入土瞬間的脈衝:要壓得過常亮的底才讀得出「事件」
const HINT_GLOW := 2.6        # 拖曳懸停提示:介於常亮與脈衝之間,配合轉金色仍分得出層
const SOUL_PURPLE := Color(0.62, 0.42, 0.95)   # 幽紫:陣亡入土
const MANA_GOLD := Color(1.0, 0.82, 0.32)      # 回魔金:和 HUD 暫時魔力黃同語彙
const HOLE_SIZE := 1.7        # 黑洞盤直徑(舊方框 1.8×2.6 → 圓盤,桌面鬆一圈)
const RING_RADIUS := 0.75     # 吸積光環半徑(貼著盤的發光帶外緣,約盤半徑的 0.88)
const RING_THICK := 0.05      # 環的粗細
const BASE_Y := 0.06          # 視覺起算高度:冰原湖面是「浮起的圓柱」、頂面在 y=0.021,
                              # 低於它的整片被深度測試蓋掉(盤 0.02 差 1mm 就全滅)。
                              # 場地是抽籤換的——貼地裝飾要抬過「全池」最高的地板,不是預設場地的。

var side: String = "player"
var shown_count: int = 0   # 視覺當下顯示的張數(headless 測試對帳用)

var _count_label: Label3D = null
var _hint_label: Label3D = null
var _top_card: Card = null
var _frame_mat: StandardMaterial3D = null   # 吸積環材質:脈衝/提示只調這裡
var _stack: MeshInstance3D = null
var _stack_box: BoxMesh = null
var _recycle_armed := false   # 下一次落定演出走「回魔金」而非「陣亡紫」
var _drop_tween: Tween = null
var _pulse_tween: Tween = null
var _label_tween: Tween = null


func setup(pile_side: String) -> void:
	side = pile_side
	_build_hole()
	_build_ring()
	_build_stack()
	_build_label()
	_build_hint_label()


func _build_hole() -> void:
	# 黑洞盤:貼地 quad 跑旋渦 shader。貼著地面所以 DOF 糊不糊都一致
	# (§31 的深度陷阱在這裡不成立,和舊版暗色薄膜同理)。
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(HOLE_SIZE, HOLE_SIZE)
	disc.mesh = quad
	disc.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # 躺平貼地
	var mat := ShaderMaterial.new()
	mat.shader = VORTEX_SHADER
	# 三色/速度/亮度全在 shader 的 uniform 預設值裡調(單一調參處,存檔即生效)
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = BASE_Y
	add_child(disc)
	# 投放區(丟牌回魔的靶):比盤面大一圈,好瞄
	var area := Area3D.new()
	area.collision_layer = DROP_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 1.9)
	shape.shape = box
	shape.position = Vector3(0.0, 0.3, 0.0)
	area.add_child(shape)
	add_child(area)


func _build_ring() -> void:
	# 吸積光環:壓扁的 Torus 圍住黑洞。靠 emission 說話、不吃場景光,
	# 晝夜/陰影下都讀得到「這裡是墓」——脈衝與回魔提示全在這份材質上做。
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.albedo_color = Color(0.12, 0.08, 0.18)
	_frame_mat.emission_enabled = true
	_frame_mat.emission = SOUL_PURPLE
	_frame_mat.emission_energy_multiplier = GLOW_IDLE
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - RING_THICK
	torus.outer_radius = RING_RADIUS + RING_THICK
	ring.mesh = torus
	ring.scale.y = 0.3   # 壓扁:要的是「光圈」不是甜甜圈
	ring.material_override = _frame_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = BASE_Y + 0.01
	add_child(ring)


func _build_stack() -> void:
	# 牌疊:頂牌底下的暗色方磚,高度跟張數走 → 「墓越埋越厚」看得見。
	_stack = MeshInstance3D.new()
	_stack_box = BoxMesh.new()
	_stack_box.size = Vector3(0.75, STACK_STEP, 1.05)
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
	_count_label.font_size = 56
	_count_label.outline_size = 12
	_count_label.modulate = Color(0.82, 0.76, 0.92)   # 淡紫:和牌堆的米金區隔
	_count_label.position = Vector3(0.52, 0.45, 0.6)  # 佔地縮了,標籤跟著收進來
	_count_label.text = ""
	add_child(_count_label)


func _build_hint_label() -> void:
	_hint_label = Label3D.new()
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.no_depth_test = true
	_hint_label.font_size = 80
	_hint_label.outline_size = 16
	_hint_label.modulate = MANA_GOLD
	_hint_label.position = Vector3(0.0, 0.75, 0.0)
	_hint_label.visible = false
	add_child(_hint_label)


## 拖著手牌懸停黑洞上:光環轉金 + 浮出「+n ◆」。affordance 跟著拖曳狀態走,不常駐。
func show_recycle_hint(gain: int) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_frame_mat.emission = MANA_GOLD
	_frame_mat.emission_energy_multiplier = HINT_GLOW
	_hint_label.text = "+%d ◆" % gain
	_hint_label.visible = true


func hide_recycle_hint() -> void:
	_frame_mat.emission = SOUL_PURPLE
	_frame_mat.emission_energy_multiplier = GLOW_IDLE
	_hint_label.visible = false


## card_manager 在回魔結算「前」呼叫:讓下一次落定的演出走金色。
## (先上膛再結算——正確性不依賴「補間至少 0.3 秒」這種巧合。)
func arm_recycle() -> void:
	_recycle_armed = true


## 頂牌「以下」的牌疊厚度:count-1 張、封頂 STACK_SHOWN_MAX。
func _stack_height(count: int) -> float:
	return STACK_STEP * mini(maxi(count - 1, 0), STACK_SHOWN_MAX)


## 帳變動時刷新:張數/牌疊同步更新,新頂牌播「被吸進洞」的演出。
## 展示卡只生一個節點、之後重複 setup 換資料(量級小,免物件池的同款理由)。
func refresh(count: int, top: CardData) -> void:
	var grew := count > shown_count
	shown_count = count
	_count_label.text = str(count) if count > 0 else ""
	var h := _stack_height(count)
	_stack.visible = h > 0.0
	if h > 0.0:
		_stack_box.size.y = h
		_stack.position.y = BASE_Y + 0.01 + h / 2.0
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
	_top_card.visible = true
	_top_card.setup(top)
	var land_y := BASE_Y + 0.02 + h
	# 同幀連埋(陣亡+隨葬靈裝)會連呼 refresh:先殺舊補間,
	# 別讓兩條 tween 同時寫 position(§29 的同款教訓)。
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	if not grew:
		_top_card.position = Vector3(0.0, land_y, 0.0)
		_top_card.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_top_card.scale = Vector3.ONE * TOP_CARD_SCALE
		return
	# 吸入演出:新頂牌歪著角度從半空旋轉收正、縮小落進洞口——黑洞在吃牌。
	_top_card.position = Vector3(0.0, land_y + DROP_HEIGHT, 0.0)
	_top_card.rotation_degrees = Vector3(-90.0, 0.0, 60.0)
	_top_card.scale = Vector3.ONE * TOP_CARD_SCALE * 1.2
	_drop_tween = create_tween().set_parallel(true)
	_drop_tween.tween_property(_top_card, "position:y", land_y, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.tween_property(_top_card, "rotation_degrees:z", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_property(_top_card, "scale", Vector3.ONE * TOP_CARD_SCALE, 0.35)
	_drop_tween.chain().tween_callback(_on_card_landed)
	_pop_label()


## 落定瞬間:回魔走金、其他入土走紫——光環脈衝 + 爆點(FxBurst 換色複用)。
## 數錢聲(MANA_GAIN)在 card_manager 的回魔結算就播了,這裡只管落定聲。
func _on_card_landed() -> void:
	if _recycle_armed:
		_recycle_armed = false
		_pulse(MANA_GOLD)
		FxBurst.spawn_at(self, MANA_GOLD)
	else:
		_pulse(SOUL_PURPLE)
		FxBurst.spawn_at(self, SOUL_PURPLE)
	Sfx.play(Sfx.CARD_BURY, -4.0)


func _pulse(color: Color) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_frame_mat.emission = color
	_frame_mat.emission_energy_multiplier = GLOW_PULSE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_frame_mat, "emission_energy_multiplier", GLOW_IDLE, 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 顏色也要退場:金色脈衝結束後把光環還給幽紫,別停在上一次的顏色
	_pulse_tween.parallel().tween_property(_frame_mat, "emission", SOUL_PURPLE, 0.7)


func _pop_label() -> void:
	if _label_tween != null and _label_tween.is_valid():
		_label_tween.kill()
	_count_label.scale = Vector3.ONE * 1.6
	_label_tween = create_tween()
	_label_tween.tween_property(_count_label, "scale", Vector3.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
