## grave_pile.gd — 一側一座的墓地視覺：像素墓碑地標 + 牌疊 + 張數。
##
## 帳仍在 BattleManager(SideState.grave)，本節點只訂閱刷新。回魔投放已拆到
## ManaRecycle，墓地因此不再帶碰撞區，也不再用程序化星雲黑洞冒充墓碑。
class_name GravePile
extends Node3D

const CARD_SCENE: PackedScene = preload("res://src/card/card.tscn")
const GRAVE_TEXTURE: Texture2D = preload(
	"res://assets/ui/textures/battlefield/graveyard_marker.png")
const TEST_FONT: Font = preload(
	"res://assets/fonts/Noto_Serif_TC/static/NotoSerifTC-Bold.ttf")
const TEST_DROP_LAYER := 16
const TOP_CARD_SCALE := 0.62
const DROP_HEIGHT := 1.2
const STACK_STEP := 0.02
const STACK_SHOWN_MAX := 12
const MARKER_SIZE := 2.0
const BASE_Y := 0.065
const SOUL_PURPLE := Color(0.62, 0.42, 0.95)

var side: String = "player"
var shown_count: int = 0

var _marker: Sprite3D = null
var _count_label: Label3D = null
var _test_hint_label: Label3D = null
var _test_drop_area: Area3D = null
var _top_card: Card = null
var _stack: MeshInstance3D = null
var _stack_box: BoxMesh = null
var _drop_tween: Tween = null
var _marker_tween: Tween = null
var _label_tween: Tween = null


func setup(pile_side: String) -> void:
	side = pile_side
	_build_marker()
	_build_test_drop_area()
	_build_stack()
	_build_label()
	_build_test_hint()


func _build_marker() -> void:
	_marker = Sprite3D.new()
	_marker.name = "GraveyardSprite"
	_marker.texture = GRAVE_TEXTURE
	_marker.axis = 1
	_marker.pixel_size = MARKER_SIZE / maxf(
		float(GRAVE_TEXTURE.get_width()), float(GRAVE_TEXTURE.get_height()))
	_marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_marker.shaded = false
	_marker.position.y = BASE_Y
	add_child(_marker)


## 墓地只在 F8 沙盒開碰撞；正式對局 layer=0，所以拖牌到這裡仍會回手。
func _build_test_drop_area() -> void:
	_test_drop_area = Area3D.new()
	_test_drop_area.name = "DebugDiscardDropArea"
	_test_drop_area.collision_layer = 0
	_test_drop_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 1.9)
	shape.shape = box
	shape.position = Vector3(0.0, 0.3, 0.0)
	_test_drop_area.add_child(shape)
	add_child(_test_drop_area)


func _build_stack() -> void:
	_stack = MeshInstance3D.new()
	_stack.name = "BuriedCardStack"
	_stack_box = BoxMesh.new()
	_stack_box.size = Vector3(0.75, STACK_STEP, 1.05)
	_stack.mesh = _stack_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.15, 0.22)
	mat.roughness = 0.9
	_stack.material_override = mat
	_stack.visible = false
	add_child(_stack)


func _build_label() -> void:
	_count_label = Label3D.new()
	_count_label.name = "GraveCount"
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count_label.no_depth_test = true
	_count_label.font_size = 56
	_count_label.outline_size = 14
	_count_label.modulate = Color(0.78, 0.84, 0.94)
	_count_label.position = Vector3(0.6, 0.46, 0.58)
	_count_label.text = ""
	add_child(_count_label)


func _build_test_hint() -> void:
	_test_hint_label = Label3D.new()
	_test_hint_label.name = "DebugDiscardHint"
	_test_hint_label.font = TEST_FONT
	_test_hint_label.font_size = 46
	_test_hint_label.outline_size = 14
	_test_hint_label.modulate = Color(0.9, 0.76, 1.0)
	_test_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_test_hint_label.no_depth_test = true
	_test_hint_label.position = Vector3(0.0, 0.82, 0.0)
	_test_hint_label.text = "測試捨棄\n不回魔"
	_test_hint_label.visible = false
	add_child(_test_hint_label)


func set_debug_discard_enabled(enabled: bool) -> void:
	if _test_drop_area == null:
		return
	_test_drop_area.collision_layer = TEST_DROP_LAYER if enabled else 0
	if not enabled:
		hide_debug_discard_hint()


func show_debug_discard_hint() -> void:
	if _test_drop_area == null or _test_drop_area.collision_layer == 0:
		return
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_test_hint_label.visible = true
	_marker.modulate = Color(1.16, 0.94, 1.3)
	_marker.scale = Vector3.ONE * 1.06


func hide_debug_discard_hint() -> void:
	if _test_hint_label != null:
		_test_hint_label.visible = false
	if _marker != null:
		_marker.modulate = Color.WHITE
		_marker.scale = Vector3.ONE


func _stack_height(count: int) -> float:
	return STACK_STEP * mini(maxi(count - 1, 0), STACK_SHOWN_MAX)


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
		var area := _top_card.get_node_or_null("Area3D") as Area3D
		if area != null:
			area.collision_layer = 0
			area.monitoring = false
			area.monitorable = false
	_top_card.visible = true
	_top_card.setup(top)
	var land_y := BASE_Y + 0.02 + h
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	if not grew:
		_top_card.position = Vector3(0.0, land_y, 0.0)
		_top_card.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_top_card.scale = Vector3.ONE * TOP_CARD_SCALE
		return
	_top_card.position = Vector3(0.0, land_y + DROP_HEIGHT, 0.0)
	_top_card.rotation_degrees = Vector3(-90.0, 0.0, 55.0)
	_top_card.scale = Vector3.ONE * TOP_CARD_SCALE * 1.18
	_drop_tween = create_tween().set_parallel(true)
	_drop_tween.tween_property(_top_card, "position:y", land_y, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.tween_property(_top_card, "rotation_degrees:z", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_property(_top_card, "scale", Vector3.ONE * TOP_CARD_SCALE, 0.35)
	_drop_tween.chain().tween_callback(_on_card_landed)
	_pop_label()


func _on_card_landed() -> void:
	_pulse_marker()
	FxBurst.spawn_at(self, SOUL_PURPLE)
	Sfx.play(Sfx.CARD_BURY, -4.0)


func _pulse_marker() -> void:
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker.modulate = Color(1.24, 1.04, 1.38)
	_marker.scale = Vector3.ONE * 1.07
	_marker_tween = create_tween().set_parallel(true)
	_marker_tween.tween_property(_marker, "modulate", Color.WHITE, 0.65)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_marker_tween.tween_property(_marker, "scale", Vector3.ONE, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_label() -> void:
	if _label_tween != null and _label_tween.is_valid():
		_label_tween.kill()
	_count_label.scale = Vector3.ONE * 1.6
	_label_tween = create_tween()
	_label_tween.tween_property(_count_label, "scale", Vector3.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
