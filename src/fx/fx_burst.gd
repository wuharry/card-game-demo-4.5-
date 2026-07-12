## fx_burst.gd — 通用命中爆點(3D 粒子,HD-2D 特效的第一顆範本)
##
## 純 static 工具(仿 ArenaPool / NetMatch 慣例):不實例化這個類別本身,
## spawn_at() 現場組一個一次性的 GPUParticles3D,播完自己 queue_free。
## 零素材、零場景檔——粒子的臉是一片純色小四方形,亮度靠 emission 推過
## WorldEnvironment 的 glow 門檻(glow_hdr_threshold = 0.95)→ 自動泛光,
## 這就是「歧路旅人式 3D 特效 = 發光粒子 + bloom 後製」的最小可用版。
##
## 用法(已接在 Card.take_damage / Hero.take_damage,所有傷害自動觸發):
##   FxBurst.spawn_at(受擊單位)                    # 預設暖橘火花
##   FxBurst.spawn_at(目標, Color(0.5, 0.8, 1.0))  # 之後法術換色:冰藍/虛空紫…
class_name FxBurst
extends RefCounted


static func spawn_at(host: Node3D, color: Color = Color(1.0, 0.82, 0.35)) -> void:
	if host == null or not host.is_inside_tree():
		return
	var fx := GPUParticles3D.new()
	fx.one_shot = true
	fx.explosiveness = 1.0   # 1.0 = 所有粒子同一瞬間噴出(爆點);0 = 平均灑(噴泉)
	fx.amount = 24
	fx.lifetime = 0.45
	fx.emitting = false      # 先不點火,進場景樹、站好位置後再點(時序才穩)

	# ── 粒子的「物理劇本」:怎麼噴、怎麼飛、怎麼消 ──────────────
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12          # 從一顆小球面噴出,不是從一個點
	mat.spread = 180.0                         # 全方向
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0             # min/max 給範圍,每顆粒子抽籤 → 不整齊才像火花
	mat.gravity = Vector3(0.0, -3.0, 0.0)      # 微微下墜(預設 -9.8 太像石頭)
	mat.damping_min = 2.0
	mat.damping_max = 4.0                      # 空氣阻力:先快後慢,爆發感
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	# 壽命內從原尺寸縮到 0(淡出靠縮小,比改透明度便宜且不打架):
	# Curve 是「函數」,粒子系統只吃貼圖,所以包成 CurveTexture 餵進去。
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	mat.scale_curve = ct
	fx.process_material = mat

	# ── 粒子的「臉」:純色自發光小方片(程式美術,不用任何貼圖)──────
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED       # 火花自己會發光,不吃場景光
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD                # 疊加混色:重疊處更亮 = 火光感
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES       # 粒子專用 billboard,永遠面向鏡頭
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0   # 推過 glow 門檻 0.95 → 泛光(卡槽高亮同一招)
	quad.material = m
	fx.draw_pass_1 = quad

	# ── 掛樹與自毀 ──────────────────────────────────
	# 掛在「樹根」而不是受擊者身上:單位陣亡被移除時,特效才不會被一起帶走。
	# (不用 current_scene:場景切換的空窗期它可能是 null;root 永遠在,
	#  而特效壽命不到一秒,跨場景殘留不是問題。)
	host.get_tree().root.add_child(fx)
	fx.global_position = host.global_position + Vector3(0.0, 0.55, 0.0)   # 立牌胸口高度
	fx.finished.connect(fx.queue_free)   # one_shot 播完發 finished → 自己收屍,不留節點
	fx.emitting = true
