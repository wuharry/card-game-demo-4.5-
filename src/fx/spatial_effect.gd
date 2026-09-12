## 結算後的一次性 3D 演出：世界座標光環、球殼與 GPU 粒子。
## 不碰遊戲規則；掛在場景上，宿主死亡不中斷，換場景會回收。
extends Node3D

const SETTINGS = preload("res://src/settings/app_settings.gd")
const SHELL_SHADER = preload("res://src/fx/shield_shell.gdshader")
const COLORS := {
	"hit": Color("ffc179"), "heal": Color("7effb2"),
	"shield": Color("77cfff"), "fire": Color("ff823d"),
	"ice": Color("94eaff"), "poison": Color("b2ef6b"),
	"dark": Color("b58aff"), "forge": Color("ffe29a"),
}
const MAX_ACTIVE := 24
static var _ring_mesh: TorusMesh
static var _shell_mesh: SphereMesh
static var _crystal_mesh: PrismMesh


static func play_at(host: Node3D, kind: String, tint: Color = Color.WHITE) -> Node3D:
	if not is_instance_valid(host) or not host.is_inside_tree() or not COLORS.has(kind):
		return null
	if host.get_tree().get_nodes_in_group("transient_spatial_fx").size() >= MAX_ACTIVE:
		return null
	var fx := (load("res://src/fx/spatial_effect.gd") as GDScript).new() as Node3D
	fx.name = "SpatialEffect"
	var parent: Node = host.get_tree().current_scene
	if parent == null:
		parent = host.get_tree().root
	parent.add_child(fx)
	fx.add_to_group("transient_spatial_fx")
	fx.global_position = host.global_position
	fx._build(kind, COLORS[kind] if tint == Color.WHITE else tint)
	return fx


static func status_at(host: Node3D, status: SkillData.Status) -> void:
	match status:
		SkillData.Status.BURN: play_at(host, "fire")
		SkillData.Status.FREEZE: play_at(host, "ice")
		SkillData.Status.POISON: play_at(host, "poison")
		SkillData.Status.NIGHT_VEIL, SkillData.Status.WEAKEN: play_at(host, "dark")
		SkillData.Status.FORGE: play_at(host, "forge")


func _build(kind: String, color: Color) -> void:
	var reduced: bool = SETTINGS.current().reduce_motion
	var duration := 0.3 if reduced else (0.5 if kind == "hit" else 0.95)
	var ring := _ring(color)
	ring.position.y = 0.12
	if kind == "hit":
		ring.position.y = 0.65
		ring.rotation_degrees.x = 65.0
	elif kind == "shield":
		_shell(color, reduced, duration)
	elif kind == "ice":
		_crystals(color, reduced, duration)
	elif kind == "heal" or kind == "forge":
		var upper := _ring(color)
		upper.position.y = 0.35
		upper.scale = Vector3.ONE * 0.7
		_fade(upper, duration)
		if not reduced:
			create_tween().tween_property(upper, "position:y", 1.4, duration).set_trans(Tween.TRANS_SINE)
	elif kind == "dark":
		var orbit := _ring(color)
		orbit.position.y = 0.65
		orbit.rotation_degrees.z = 70
		_fade(orbit, duration)
	if not reduced:
		ring.scale = Vector3.ONE * 0.35
		create_tween().tween_property(ring, "scale", Vector3.ONE * 1.25,
			duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_particles(color, kind == "hit", duration)
	_fade(ring, duration)
	var lifetime := create_tween()
	lifetime.tween_interval(duration + 0.1)
	lifetime.tween_callback(queue_free)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


func _ring(color: Color) -> MeshInstance3D:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.59
		_ring_mesh.outer_radius = 0.64
		_ring_mesh.rings = 40
		_ring_mesh.ring_segments = 8
	var mesh := MeshInstance3D.new()
	mesh.mesh = _ring_mesh
	mesh.material_override = _material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _shell(color: Color, reduced: bool, duration: float) -> void:
	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 0.72
		_shell_mesh.height = 1.44
		_shell_mesh.radial_segments = 32
		_shell_mesh.rings = 16
	var shell := MeshInstance3D.new()
	shell.mesh = _shell_mesh
	shell.position.y = 0.7
	shell.scale = Vector3(1.0, 1.15, 1.0)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHELL_SHADER
	material.set_shader_parameter("tint", color)
	shell.material_override = material
	add_child(shell)
	if not reduced:
		shell.scale *= 0.7
		create_tween().tween_property(shell, "scale", Vector3(1.0, 1.15, 1.0),
			0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade(shell, duration)


func _crystals(color: Color, reduced: bool, duration: float) -> void:
	if _crystal_mesh == null:
		_crystal_mesh = PrismMesh.new()
		_crystal_mesh.size = Vector3(0.18, 0.75, 0.22)
	var material := _material(color)
	for i in 5:
		var crystal := MeshInstance3D.new()
		crystal.mesh = _crystal_mesh
		crystal.material_override = material
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(i) / 5.0
		crystal.position = Vector3(cos(angle) * 0.52, 0.38, sin(angle) * 0.52)
		crystal.rotation = Vector3(0.15, angle, 0.2)
		add_child(crystal)
		if not reduced:
			crystal.scale.y = 0.1
			create_tween().tween_property(crystal, "scale:y", 1.0, 0.23)
		_fade(crystal, duration)


func _fade(mesh: MeshInstance3D, duration: float) -> void:
	var tw := create_tween()
	tw.tween_interval(duration * 0.35)
	tw.tween_property(mesh, "transparency", 1.0, duration * 0.65)


func _particles(color: Color, burst: bool, duration: float) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 10 if SETTINGS.current().quality == 0 else 20
	particles.lifetime = duration * 0.7
	particles.explosiveness = 1.0 if burst else 0.8
	particles.position.y = 0.65 if burst else 0.15
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.5
	process.emission_ring_inner_radius = 0.25
	process.emission_ring_height = 0.1
	process.direction = Vector3.UP
	process.spread = 180.0 if burst else 18.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 2.6 if burst else 2.0
	process.gravity = Vector3(0, -2.5, 0) if burst else Vector3.ZERO
	process.damping_min = 1.0
	process.damping_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var texture := CurveTexture.new()
	texture.curve = curve
	process.scale_curve = texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.065, 0.13)
	var material := _material(color)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = material
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = true
