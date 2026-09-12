## 共用幀資源的一次性演出；只在結果結算後呼叫。
extends RefCounted

const SETTINGS = preload("res://src/settings/app_settings.gd")
const FRAMES_PATH := "res://assets/pixel/animations/pixel_animations_gfxpack/individual_frames/"
static var _frames: Dictionary = {}


static func play_at(host: Node3D, family: String, variant: int = 1,
		tint: Color = Color.WHITE) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	var key := "%s%d" % [family, variant]
	if not _frames.has(key):
		var frames := SpriteFrames.new()
		frames.set_animation_loop("default", false)
		frames.set_animation_speed("default", 16.0)
		var index := 1
		var path := FRAMES_PATH + "%s/%s_%d.png" % [family, key, index]
		while ResourceLoader.exists(path):
			frames.add_frame("default", load(path))
			index += 1
			path = FRAMES_PATH + "%s/%s_%d.png" % [family, key, index]
		if frames.get_frame_count("default") == 0:
			return
		_frames[key] = frames
	var fx := AnimatedSprite3D.new()
	fx.name = "PixelEffect"
	fx.sprite_frames = _frames[key]
	fx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fx.pixel_size = 0.025
	fx.shaded = false
	fx.modulate = tint
	# 死亡不切斷演出；切換場景時跟著場景收掉。
	var parent: Node = host.get_tree().current_scene
	if parent == null:
		parent = host.get_tree().root
	parent.add_child(fx)
	fx.add_to_group("transient_pixel_fx")
	fx.global_position = host.global_position + Vector3(0.0, 0.65, 0.0)
	if SETTINGS.current().reduce_motion:
		fx.frame = int(fx.sprite_frames.get_frame_count("default") / 2.0)
		var tw := fx.create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(fx.queue_free)
	else:
		fx.animation_finished.connect(fx.queue_free)
		fx.play()


static func status_at(host: Node3D, status: SkillData.Status) -> void:
	match status:
		SkillData.Status.BURN:
			play_at(host, "fire")
		SkillData.Status.FREEZE:
			play_at(host, "ice")
		SkillData.Status.POISON:
			play_at(host, "smoke", 1, Color("92d879"))
		SkillData.Status.NIGHT_VEIL, SkillData.Status.WEAKEN:
			play_at(host, "darkness")
		SkillData.Status.FORGE:
			play_at(host, "holy")
