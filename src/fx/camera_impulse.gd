## 短促的鏡頭偏移；同時命中取最大強度，避免全體攻擊把震動累加。
extends Node
const SETTINGS = preload("res://src/settings/app_settings.gd")
var _camera: Camera3D
var _base := Vector2.ZERO
var _age := 0.0
var _strength := 0.0


static func play(host: Node, strength: float = 0.035) -> void:
	if SETTINGS.current().reduce_motion or NetMatch.is_dedicated_server \
			or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var camera := host.get_viewport().get_camera_3d()
	if camera == null:
		return
	var effect := camera.get_node_or_null("CameraImpulse")
	if effect == null:
		effect = (load("res://src/fx/camera_impulse.gd") as GDScript).new()
		effect.name = "CameraImpulse"
		effect._camera = camera
		effect._base = Vector2(camera.h_offset, camera.v_offset)
		camera.add_child(effect)
	# 不使用全域 RNG；演出不能改變抽牌使用的亂數序列。
	effect._strength = maxf(effect._strength, clampf(strength, 0.0, 0.065))
	effect._age = 0.0
	effect.set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.2 or SETTINGS.current().reduce_motion:
		_camera.h_offset = _base.x
		_camera.v_offset = _base.y
		_strength = 0.0
		set_process(false)
		return
	var amplitude := _strength * pow(1.0 - _age / 0.2, 2.0)
	_camera.h_offset = _base.x + sin(_age * 112.0) * amplitude
	_camera.v_offset = _base.y + sin(_age * 87.0) * amplitude * 0.55
