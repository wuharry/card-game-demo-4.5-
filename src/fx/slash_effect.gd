## 刀光只供持刃角色使用；命中結算時建立，不自行計時扣血。
extends Node3D
const SETTINGS = preload("res://src/settings/app_settings.gd")
const BLADE_USERS := ["swordsman", "knight", "knight_templar", "greatsword_skeleton",
	"pirate_captain", "demon_c", "tf_scarlet_duelist", "tf_dawn_paladin"]


static func supports(card: CardData) -> bool:
	return card != null and card.resource_path.get_file().get_basename() in BLADE_USERS


static func play_at(target: Node3D, blocked: bool = false, reverse: bool = false) -> void:
	if NetMatch.is_dedicated_server or SETTINGS.current().reduce_motion \
			or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var tree := target.get_tree()
	if tree.get_nodes_in_group("slash_visuals").size() >= 12:
		return
	var effect := (load("res://src/fx/slash_effect.gd") as GDScript).new() as Node3D
	var parent := tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(effect)
	effect.add_to_group("slash_visuals")
	effect.global_position = preload("res://src/fx/actor_feedback.gd").origin_of(target) + Vector3.UP * 0.85
	var camera := target.get_viewport().get_camera_3d()
	if camera != null:
		effect.global_basis = camera.global_basis
	effect.rotate_object_local(Vector3.FORWARD, -0.65 if reverse else 0.65)
	effect._build(Color("8cdeff") if blocked else Color("ffcd77"))


func _build(color: Color) -> void:
	for layer in 2:
		var geometry := ImmediateMesh.new()
		geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 32:
			var vertices: Array[Vector3] = []
			for edge in 2:
				var t := float(i + edge) / 32.0
				var angle := lerpf(-2.3, 1.45, t)
				var radius := 0.98
				var width := sin(t * PI) * (0.18 if layer == 0 else 0.045)
				vertices.append(Vector3(cos(angle), sin(angle), 0) * radius)
				vertices.append(Vector3(cos(angle), sin(angle), 0) * (radius - width))
			for index in [0, 1, 2, 1, 3, 2]:
				geometry.surface_add_vertex(vertices[index])
		geometry.surface_end()
		var mesh := MeshInstance3D.new()
		mesh.mesh = geometry
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(color, 0.65) if layer == 0 else Color("fff5df")
		material.emission_enabled = true
		material.emission = color if layer == 0 else Color.WHITE
		material.emission_energy_multiplier = 1.5
		mesh.material_override = material
		add_child(mesh)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mesh, "scale", Vector3(1.15, 1.05, 1), 0.2)
		tween.tween_property(mesh, "rotation:z", -0.35, 0.2)
		tween.tween_property(mesh, "transparency", 1.0, 0.17).set_delay(0.05)
	var life := create_tween()
	life.tween_interval(0.25)
	life.tween_callback(queue_free)
