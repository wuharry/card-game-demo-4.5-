## 指定秘術的高清演出：傷害立即結算，光束／爆發在同幀開始，餘光隨後消散。
extends Node3D

const SETTINGS = preload("res://src/settings/app_settings.gd")
const PLUME = preload("res://src/fx/spell_plume.gdshader")
const WAVE = preload("res://src/fx/spell_wave.gdshader")
const SPARK = preload("res://src/fx/spell_spark.gdshader")
const PROFILES := {
	"arcana_fireblast": "fire",
	"arcana_thunder_pierce": "thunder",
	"arcana_frozen_pulse": "ice",
}
const COLORS := {"fire": Color("ff510d"), "thunder": Color("78a9ff"), "ice": Color("67ddff")}
const MAX_ACTIVE := 8
var _elapsed := 0.0
var _plumes: Array[ShaderMaterial] = []


static func play_arcana(host: Node, card: CardData, positions: Array[Vector3]) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree() or card == null:
		return
	var id := card.resource_path.get_file().get_basename()
	if not PROFILES.has(id):
		return
	for point in positions:
		if host.get_tree().get_nodes_in_group("spell_visuals").size() >= MAX_ACTIVE:
			break
		var effect := (load("res://src/fx/spell_effect.gd") as GDScript).new() as Node3D
		var parent := host.get_tree().current_scene
		if parent == null:
			parent = host.get_tree().root
		parent.add_child(effect)
		effect.add_to_group("spell_visuals")
		effect.global_position = point
		effect._build(PROFILES[id])


func _build(kind: String) -> void:
	var color: Color = COLORS[kind]
	var reduced: bool = SETTINGS.current().reduce_motion
	_wave(color, reduced)
	if not reduced:
		match kind:
			"fire": _fire(color)
			"thunder": _thunder(color)
			"ice": _ice(color)
		_sparks(color, kind)
		_light(color)
	var life := create_tween()
	life.tween_interval(0.35 if reduced else 1.1)
	life.tween_callback(queue_free)
	set_process(not _plumes.is_empty())


func _process(delta: float) -> void:
	_elapsed += delta
	for material in _plumes:
		material.set_shader_parameter("age", _elapsed)


func _wave(color: Color, reduced: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(3.6, 3.6)
	var mat := ShaderMaterial.new()
	mat.shader = WAVE
	mat.set_shader_parameter("tint", color)
	var mesh := _mesh(quad, mat)
	mesh.rotation.x = -PI / 2
	mesh.position.y = -0.48
	if reduced:
		mat.set_shader_parameter("phase", 0.55)
		_fade(mesh, 0.3)
	else:
		create_tween().tween_method(func(value: float) -> void:
			mat.set_shader_parameter("phase", value), 0.0, 1.0, 0.7)


func _fire(color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	sphere.radial_segments = 40
	sphere.rings = 24
	for i in 3:
		var mat := ShaderMaterial.new()
		mat.shader = PLUME
		mat.set_shader_parameter("tint", color)
		_plumes.append(mat)
		var plume := _mesh(sphere, mat)
		plume.position = Vector3((i - 1) * 0.3, 0.35 + i * 0.14, 0)
		plume.scale = Vector3(0.75, 1.35 + i * 0.2, 0.75)
		plume.rotation.z = (i - 1) * -0.2
		var tw := create_tween().set_parallel(true)
		tw.tween_property(plume, "scale", plume.scale * Vector3(1.3, 1.35, 1.3), 0.7)
		tw.tween_property(plume, "position:y", plume.position.y + 0.45, 0.7)
		tw.tween_method(func(value: float) -> void:
			mat.set_shader_parameter("opacity", value), 1.0, 0.0, 0.85)


func _thunder(color: Color) -> void:
	# 以帶狀三角形畫光束；亮芯與外光分開，避免只有一根粗線。
	for branch in 3:
		var points := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			var spread := 0.52 * sin(t * PI)
			points.append(Vector3(sin(i * 6.7 + branch * 2.4) * spread + (branch - 1) * 0.6 * (1.0 - t),
				(1.0 - t) * (4.5 - branch * 0.6), cos(i * 4.2 + branch) * spread))
		var glow := _ribbon(points, 0.06, Color(color, 0.28), 1.0)
		var core := _ribbon(points, 0.015, Color("d9eeff"), 1.2)
		_fade(glow, 0.48 + branch * 0.08)
		_fade(core, 0.35 + branch * 0.08)


func _ribbon(points: PackedVector3Array, width: float, color: Color, energy: float) -> MeshInstance3D:
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var camera := get_viewport().get_camera_3d()
	var view := Vector3(0, 0, 1) if camera == null else (camera.global_position - global_position).normalized()
	for i in points.size() - 1:
		var side := (points[i + 1] - points[i]).cross(view).normalized() * width
		for vertex in [points[i] - side, points[i] + side, points[i + 1] + side,
			points[i] - side, points[i + 1] + side, points[i + 1] - side]:
			geometry.surface_add_vertex(vertex)
	geometry.surface_end()
	return _mesh(geometry, _material(color, energy))


func _ice(color: Color) -> void:
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.2
	crystal.height = 1.8
	crystal.radial_segments = 5
	var mat := _material(color, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.metallic = 0.2
	mat.roughness = 0.18
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = color.darkened(0.22)
	mat.albedo_color.a = 0.78
	for i in 7:
		var angle := TAU * float(i) / 7
		var spike := _mesh(crystal, mat)
		spike.position = Vector3(cos(angle) * 0.58, 0.1, sin(angle) * 0.58)
		spike.rotation = Vector3(sin(angle) * 0.4, angle, -cos(angle) * 0.4)
		spike.scale.y = 0.65 + float(i % 3) * 0.2
		var tw := create_tween()
		tw.tween_property(spike, "position:y", 0.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fade(spike, 0.85)


func _sparks(color: Color, kind: String) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 18 if SETTINGS.current().quality == 0 else 44
	particles.lifetime = 0.65
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-3,-1,-3), Vector3(6,6,6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.45
	process.direction = Vector3.UP
	process.spread = 38.0 if kind == "fire" else 110.0
	process.initial_velocity_min = 1.3
	process.initial_velocity_max = 3.2
	process.gravity = Vector3(0, -1, 0)
	process.damping_min = 1.0
	process.damping_max = 2.0
	var curve := Curve.new()
	curve.add_point(Vector2(0,1))
	curve.add_point(Vector2(1,0))
	var texture := CurveTexture.new()
	texture.curve = curve
	process.scale_curve = texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12,0.12)
	var mat := ShaderMaterial.new()
	mat.shader = SPARK
	mat.set_shader_parameter("tint", color)
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = true


func _light(color: Color) -> void:
	if SETTINGS.current().quality == 0:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = 3.8
	light.position.y = 0.5
	light.shadow_enabled = false
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.7)


func _material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _mesh(geometry: Mesh, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _fade(mesh: MeshInstance3D, duration: float) -> void:
	var tw := create_tween()
	tw.tween_interval(duration * 0.3)
	tw.tween_property(mesh, "transparency", 1.0, duration * 0.7)
