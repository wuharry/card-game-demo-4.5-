extends SceneTree
## 原始像素量測與並排檢視，不改寫素材。
## godot --headless --path . -s tests/audit_character_style.gd -- build/sprite-style-20260909

const PACK_01 := "res://assets/packs/tiny_rpg_characters/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/Characters(100x100 split)/"
const PACK_02 := "res://assets/packs/tiny_rpg_characters/Tiny RPG Character Asset Pack 02 -Full 20 Characters/Characters(100x100 split)/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "build/sprite-style-20260909"
	DirAccess.make_dir_recursive_absolute(out)
	var paths: Array[String] = []
	for name in ["Knight", "Soldier", "Wizard", "Necromancer", "Werebear", "Orc"]:
		paths.append(PACK_01 + "%s/%s/%s_Idle.png" % [name, name, name])
	for name in ["Warlock", "Swordsman"]:
		var path := PACK_02 + "%s/%s/%s_Idle.png" % [name, name, name]
		if FileAccess.file_exists(path):
			paths.append(path)
	var reference_count := paths.size()
	_collect_idle(args[1] if args.size() > 1 else "res://assets/characters", paths)
	var report: Array[Dictionary] = []
	var contact := Image.create(960, ceili(paths.size() / 6.0) * 240, false, Image.FORMAT_RGBA8)
	contact.fill(Color("30323c"))
	var references := Image.create(1152, 576, false, Image.FORMAT_RGBA8)
	references.fill(Color("30323c"))
	for i in paths.size():
		var source := Image.load_from_file(ProjectSettings.globalize_path(paths[i]))
		if source == null:
			push_error("Missing " + paths[i])
			quit(1)
			return
		var size := source.get_height()
		var first := source.get_region(Rect2i(0, 0, size, size))
		var bounds := first.get_used_rect()
		var colors := {}
		var partial_alpha := 0
		for y in first.get_height():
			for x in first.get_width():
				var c := first.get_pixel(x, y)
				if c.a == 0:
					continue
				colors[c.to_rgba32()] = true
				if c.a < 1.0:
					partial_alpha += 1
		var item := {"index": i, "reference": i < reference_count, "path": paths[i],
			"frames": source.get_width() / size, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"colors": colors.size(), "partial_alpha": partial_alpha}
		report.append(item)
		print(JSON.stringify(item))
		var sprite := first.get_region(bounds)
		sprite.resize(sprite.get_width() * 4, sprite.get_height() * 4, Image.INTERPOLATE_NEAREST)
		contact.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()),
			Vector2i((i % 6) * 160 + (160 - sprite.get_width()) / 2,
				int(i / 6) * 240 + 200 - sprite.get_height()))
		if i < reference_count:
			var reference := first.get_region(bounds)
			reference.resize(reference.get_width() * 8, reference.get_height() * 8, Image.INTERPOLATE_NEAREST)
			references.blend_rect(reference, Rect2i(Vector2i.ZERO, reference.get_size()),
				Vector2i((i % 4) * 288 + (288 - reference.get_width()) / 2,
					int(i / 4) * 288 + 260 - reference.get_height()))
	contact.save_png(out.path_join("before_contact.png"))
	references.save_png(out.path_join("tiny_rpg_reference.png"))
	var file := FileAccess.open(out.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit(0)


func _collect_idle(directory: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	for file in dir.get_files():
		if file.ends_with("_Idle.png"):
			paths.append(directory.path_join(file))
	for child in dir.get_directories():
		_collect_idle(directory.path_join(child), paths)
