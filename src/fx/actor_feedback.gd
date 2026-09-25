## 只控制立牌的位置、亮度與動畫 Tween；不暫停場景、規則或網路。
extends Node

const SETTINGS = preload("res://src/settings/app_settings.gd")
const CONTACT_TIME := 0.35
const ARRIVAL_TIME := 0.18
const RETURN_START := 0.46
const RETURN_DURATION := 0.28
const CONTACT_DISTANCE := 0.95
var _sprite: Sprite3D
var _actor: WeakRef
var _animation_property: StringName
var _base_position: Vector3
var _base_color: Color
var _base_flip_h := false
var _target: WeakRef
var _attack_offset := Vector3.ZERO
var _start_offset := Vector3.ZERO
var _return_offset := Vector3.ZERO
var _begin_swing: Callable
var _swing_started := false
var _attack_age := -1.0
var _hold := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _paused_animation: Tween


static func attach(actor: Node, sprite: Sprite3D, animation_property: StringName) -> Node:
	var existing := sprite.get_node_or_null("ActorFeedback")
	if existing != null:
		return existing
	var feedback: Node = (load("res://src/fx/actor_feedback.gd") as GDScript).new()
	feedback.name = "ActorFeedback"
	feedback._sprite = sprite
	feedback._actor = weakref(actor)
	feedback._animation_property = animation_property
	feedback._base_position = sprite.position
	feedback._base_color = sprite.modulate
	feedback._base_flip_h = sprite.flip_h
	sprite.add_child(feedback)
	feedback.set_process(false)
	return feedback


static func origin_of(host: Node3D) -> Vector3:
	return host.combat_position() if host.has_method("combat_position") else host.global_position


func visual_origin() -> Vector3:
	var actor := _actor.get_ref() as Node3D
	return actor.global_position + actor.global_basis * (_sprite.position - _base_position)


func attack_toward(target: Node3D, begin_swing: Callable) -> void:
	if SETTINGS.current().reduce_motion:
		return
	var actor := _actor.get_ref() as Node3D
	if actor == null or not is_instance_valid(target):
		return
	_target = weakref(target)
	_begin_swing = begin_swing
	_swing_started = false
	_start_offset = actor.global_basis * (_sprite.position - _base_position)
	# 停在目標側前方，保留武器距離；鏡頭翻面後也保持兩個角色都看得見。
	var away := actor.global_position - target.global_position
	away.y = 0.0
	var camera := actor.get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized()
	var side := -1.0 if away.dot(right) <= 0.0 else 1.0
	var approach := (away.normalized() * 0.6 + right * side * 0.8).normalized()
	var destination := target.global_position + approach * minf(CONTACT_DISTANCE, away.length())
	_attack_offset = destination - actor.global_position
	_return_offset = _attack_offset
	_sprite.flip_h = _base_flip_h if (target.global_position - destination).dot(right) >= 0.0 else not _base_flip_h
	_attack_age = 0.0
	set_process(true)


## 結算點校準：即使前衝中被另一個命中短暫停住，也先抵達才產生刀光與扣血。
func reach_contact() -> void:
	if _attack_age < 0.0 or _attack_age >= RETURN_START or SETTINGS.current().reduce_motion:
		return
	_attack_age = CONTACT_TIME
	_place_offset(_attack_offset)
	_start_swing()


func return_home() -> void:
	if _attack_age < 0.0 or _attack_age >= RETURN_START:
		return
	var actor := _actor.get_ref() as Node3D
	_return_offset = actor.global_basis * (_sprite.position - _base_position)
	_attack_age = RETURN_START
	_begin_swing = Callable()
	_swing_started = true
	_hold = 0.0
	_resume_animation()


## 死亡停在交戰位置，不把屍體滑回卡槽；死亡動畫仍由 Card 負責。
func stop_attack() -> void:
	_resume_animation()
	_attack_age = -1.0
	_hold = 0.0
	_flash = 0.0
	_begin_swing = Callable()
	_sprite.modulate = _base_color
	set_process(false)


func _place_offset(offset: Vector3) -> void:
	var actor := _actor.get_ref() as Node3D
	_sprite.position = _base_position + actor.global_basis.inverse() * offset


func _start_swing() -> void:
	if _swing_started:
		return
	_swing_started = true
	if _begin_swing.is_valid():
		_begin_swing.call()


func impact(amount: int, blocked: bool = false) -> void:
	if SETTINGS.current().reduce_motion:
		return
	_hold = maxf(_hold, 0.045 if blocked else (0.075 if amount >= 5 else 0.055))
	_flash = 0.13
	_flash_color = Color(1.2, 1.8, 2.4) if blocked else Color(2.6, 1.9, 1.4)
	_pause_current_animation()
	set_process(true)


func _pause_current_animation() -> void:
	var actor := _actor.get_ref() as Node
	if actor == null:
		return
	var animation := actor.get(_animation_property) as Tween
	# Hurt／Death 可能在命中同幀換掉 Attack；每幀追目前那條，避免漏停或永遠停住。
	if animation != null and animation.is_valid():
		if _paused_animation != animation:
			_resume_animation()
		_paused_animation = animation
		animation.pause()


func _resume_animation() -> void:
	if _paused_animation != null and _paused_animation.is_valid():
		_paused_animation.play()
	_paused_animation = null


func _process(delta: float) -> void:
	if SETTINGS.current().reduce_motion:
		# 前衝中切換低動態時仍接上動作收尾，不能留下一條無限 Run 動畫。
		if _attack_age >= 0.0:
			_start_swing()
		_reset()
		return
	_flash = maxf(0.0, _flash - delta)
	_sprite.modulate = _base_color.lerp(_flash_color, clampf(_flash / 0.13, 0.0, 1.0))
	if _attack_age >= 0.0 and _attack_age < RETURN_START \
			and (_target == null or not is_instance_valid(_target.get_ref())):
		return_home()
	if _hold > 0.0:
		_pause_current_animation()
		_hold = maxf(0.0, _hold - delta)
		return
	_resume_animation()
	if _attack_age >= 0.0:
		_attack_age += delta
		if _attack_age < ARRIVAL_TIME:
			_place_offset(_start_offset.lerp(_attack_offset, smoothstep(0.0, ARRIVAL_TIME, _attack_age)))
		else:
			_start_swing()
			var progress := smoothstep(RETURN_START, RETURN_START + RETURN_DURATION, _attack_age)
			_place_offset(_return_offset * (1.0 - progress))
		if _attack_age >= RETURN_START + RETURN_DURATION:
			_attack_age = -1.0
	if _attack_age < 0.0 and _flash <= 0.0:
		_reset()


func _reset() -> void:
	_resume_animation()
	_hold = 0.0
	_flash = 0.0
	_attack_age = -1.0
	_begin_swing = Callable()
	_target = null
	if is_instance_valid(_sprite):
		_sprite.position = _base_position
		_sprite.modulate = _base_color
		_sprite.flip_h = _base_flip_h
	set_process(false)


func _exit_tree() -> void:
	_reset()
