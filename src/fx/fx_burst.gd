## 保留既有傷害入口；命中演出由共用 3D 特效播放器負責。
class_name FxBurst
extends RefCounted

const SPATIAL_FX = preload("res://src/fx/spatial_effect.gd")


static func spawn_at(host: Node3D, color: Color = Color(1.0, 0.82, 0.35)) -> void:
	SPATIAL_FX.play_at(host, "hit", color)
