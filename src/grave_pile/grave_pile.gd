## grave_pile.gd — 墓地/棄牌堆(一側一座):底座 + 張數 + 最後入土那張卡躺在上面
##
## 帳在 BattleManager(SideState.grave),這裡純視覺:CardManager 訂閱
## card_buried 信號後呼叫 refresh()。把手牌拖到底座上放開 = 丟牌回魔(§1.1)。
## 底座的 Area3D 掛第 4 層(value 8),card_manager 用獨立射線掃——
## 不跟卡片(1)/卡槽(2)/本體(4)打架。
## 兩座墓的位置對稱於棋盤中線:client 的翻轉視角不需要任何特別處理(鏡像紅利)。
class_name GravePile
extends Node3D

const DROP_LAYER := 8   # 第 4 層:墓地投放區(= card_manager.COLLISION_MASK_GRAVE)
const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
const TOP_CARD_SCALE := 0.8   # 躺在墓上的展示卡,比手牌小一號別搶戲

var side: String = "player"
var shown_count: int = 0   # 視覺當下顯示的張數(headless 測試對帳用)

var _count_label: Label3D = null
var _top_card: Card = null


func setup(pile_side: String) -> void:
	side = pile_side
	_build_base()
	_build_label()


func _build_base() -> void:
	# 底座:貼地的暗色薄膜。半透明不寫深度沒關係——它貼著地面,
	# 背景就是同深度的地,DOF 糊不糊都一致(§31 的深度陷阱在這裡不成立)。
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


## 帳變動時刷新:張數 + 讓「最後入土那張」躺在墓上。
## 展示卡只生一個節點、之後重複 setup 換資料(量級小,免物件池的同款理由)。
func refresh(count: int, top: CardData) -> void:
	shown_count = count
	_count_label.text = str(count) if count > 0 else ""
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
		_top_card.scale = Vector3.ONE * TOP_CARD_SCALE
		_top_card.position = Vector3(0.0, 0.06, 0.0)
	_top_card.visible = true
	_top_card.setup(top)
