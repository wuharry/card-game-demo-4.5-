## 從者與英雄共用的命中演出；kind 只決定聲畫，不參與傷害規則。
extends RefCounted

const SPATIAL = preload("res://src/fx/spatial_effect.gd")
const CAMERA = preload("res://src/fx/camera_impulse.gd")


static func damage(host: Node3D, amount: int, kind: StringName = &"hit") -> void:
	if amount <= 0 or NetMatch.is_dedicated_server:
		return
	Sfx.impact(amount, false, kind)
	# 持續扣血只保留小範圍色環與飄字，不打斷動作或震動畫面。
	if kind in [&"burn", &"poison", &"affliction"]:
		SPATIAL.play_at(host, "poison_tick" if kind == &"poison" else String(kind))
		return
	preload("res://src/fx/fx_burst.gd").spawn_at(host)
	host.impact_feedback(amount)
	CAMERA.play(host, 0.05 if amount >= 5 else 0.025)


## 由確定死亡的入口呼叫；復活／死亡替代不會先播出擊殺提示。
static func death(host: Node3D) -> void:
	if NetMatch.is_dedicated_server:
		return
	Sfx.play(Sfx.DEATH_IMPACT, -7.0, 0.02, 0.82)
	SPATIAL.play_at(host, "death")
	CAMERA.play(host, 0.06)
