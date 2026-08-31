## mana_recycle.gd — 丟牌回魔專用投放區。
##
## 舊版把回魔洞與墓地牌疊塞在同一座 GravePile，玩家很難分辨「資源操作」和
## 「已使用卡牌」。現在黑洞只負責回魔：生成像素 Sprite、碰撞投放區與金色提示；
## 真正的墓地在棋盤另一側，由 GravePile 顯示。
class_name ManaRecycle
extends Node3D

const DROP_LAYER := 8
const PORTAL_TEXTURE: Texture2D = preload(
	"res://assets/ui/textures/battlefield/mana_recycle_portal.png")
const PORTAL_SHADER: Shader = preload("res://src/mana_recycle/mana_portal.gdshader")
const PORTAL_SIZE := 1.78
const BASE_Y := 0.065
const IDLE_TINT := Color(0.82, 0.9, 1.0)
const MANA_GOLD := Color(1.0, 0.82, 0.32)

var side: String = "player"
var _sprite: Sprite3D = null
var _portal_mat: ShaderMaterial = null
var _hint_label: Label3D = null
var _pulse_tween: Tween = null


func setup(well_side: String) -> void:
	side = well_side
	_build_sprite()
	_build_drop_area()
	_build_hint_label()


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "PortalSprite"
	_sprite.texture = PORTAL_TEXTURE
	_sprite.axis = 1   # Y 軸法線：Sprite 躺在 XZ 地面，而不是直立 billboard。
	_sprite.pixel_size = PORTAL_SIZE / maxf(
		float(PORTAL_TEXTURE.get_width()), float(PORTAL_TEXTURE.get_height()))
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_sprite.shaded = false
	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = PORTAL_SHADER
	_portal_mat.set_shader_parameter("portal_texture", PORTAL_TEXTURE)
	_portal_mat.set_shader_parameter("tint", IDLE_TINT)
	_sprite.material_override = _portal_mat
	_sprite.position.y = BASE_Y
	add_child(_sprite)


func _build_drop_area() -> void:
	var area := Area3D.new()
	area.name = "RecycleDropArea"
	area.collision_layer = DROP_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.6, 1.9)
	shape.shape = box
	shape.position = Vector3(0.0, 0.3, 0.0)
	area.add_child(shape)
	add_child(area)


func _build_hint_label() -> void:
	_hint_label = Label3D.new()
	_hint_label.name = "ManaHint"
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.no_depth_test = true
	_hint_label.font_size = 72
	_hint_label.outline_size = 18
	_hint_label.modulate = MANA_GOLD
	_hint_label.position = Vector3(0.0, 0.72, 0.0)
	_hint_label.visible = false
	add_child(_hint_label)


func show_recycle_hint(gain: int) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_set_tint(Color(1.3, 1.03, 0.48))
	_sprite.scale = Vector3.ONE * 1.06
	_hint_label.text = "+%d ◆" % gain
	_hint_label.visible = true


func hide_recycle_hint() -> void:
	_set_tint(IDLE_TINT)
	_sprite.scale = Vector3.ONE
	_hint_label.visible = false


## 回魔結算的單一視覺出口：黑洞收縮一下、閃成金色，再回到冰藍待機色。
func pulse_recycle() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_hint_label.visible = false
	_set_tint(Color(1.45, 1.12, 0.5))
	_sprite.scale = Vector3.ONE * 0.9
	_pulse_tween = create_tween().set_parallel(true)
	_pulse_tween.tween_method(_set_tint, _current_tint(), IDLE_TINT, 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_sprite, "scale", Vector3.ONE, 0.42)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FxBurst.spawn_at(self, MANA_GOLD)


func _set_tint(value: Color) -> void:
	_portal_mat.set_shader_parameter("tint", value)


func _current_tint() -> Color:
	var value: Variant = _portal_mat.get_shader_parameter("tint")
	return value as Color if value is Color else IDLE_TINT
