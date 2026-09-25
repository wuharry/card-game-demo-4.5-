## 飄字掛場景，目標死亡也能讀完；減少動態保留閱讀時間，不縮成 0.01 秒。
extends RefCounted
const SETTINGS = preload("res://src/settings/app_settings.gd")


static func show_at(host: Node3D, text_value: String, color: Color) -> Label3D:
	if NetMatch.is_dedicated_server or not host.is_inside_tree():
		return null
	var tree := host.get_tree()
	if tree.get_nodes_in_group("combat_numbers").size() >= 40:
		return null
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 68
	label.outline_size = 14
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	var parent := tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(label)
	label.add_to_group("combat_numbers")
	# 同一目標的盾／扣血／連擊排開，避免數字互相蓋住。
	var slot: int = int(host.get_meta("combat_number_slot", 0)) % 3
	host.set_meta("combat_number_slot", slot + 1)
	label.global_position = preload("res://src/fx/actor_feedback.gd").origin_of(host) \
		+ Vector3(0, 1.2 + slot * 0.28, 0)
	var tween := label.create_tween()
	if not SETTINGS.current().reduce_motion:
		label.scale = Vector3.ONE * 1.2
		tween.set_parallel(true)
		tween.tween_property(label, "scale", Vector3.ONE, 0.12)
		tween.tween_property(label, "position:y", label.position.y + 0.65, 0.65)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain()
	else:
		tween.tween_interval(0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)
	return label
