extends SceneTree
## 檢查正式角色圖的透明背景、像素色數、完整影格與動作銜接。

var failures: Array[String] = []
var checked := 0


func _initialize() -> void:
	var directories: Array[String] = ["res://assets/characters/frost_witch"]
	for child in DirAccess.get_directories_at("res://assets/characters/generated"):
		directories.append("res://assets/characters/generated/" + child)
	for directory in directories:
		_check_character(directory)
	for failure in failures:
		printerr(failure)
	print("%s: %d characters, %d sheets, %d failures" % [
		"PASS" if failures.is_empty() else "FAIL", directories.size(), checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_character(directory: String) -> void:
	var idle: Image = null
	var stem := ""
	for file in DirAccess.get_files_at(directory):
		if file.ends_with("_Idle.png"):
			idle = Image.load_from_file(ProjectSettings.globalize_path(directory.path_join(file)))
			stem = file.trim_suffix("_Idle.png")
	if idle == null:
		failures.append(directory + ": missing Idle")
		return
	for suffix in ["Idle", "Attack01", "Hurt", "Death"]:
		if not FileAccess.file_exists(directory.path_join(stem + "_" + suffix + ".png")):
			failures.append(directory + ": missing " + suffix)
	var neutral := idle.get_region(Rect2i(0, 0, 100, 100))
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".png"):
			continue
		checked += 1
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(directory.path_join(file)))
		var frames := 1 if file.ends_with("_Static.png") else 6
		if sheet == null or sheet.get_size() != Vector2i(frames * 100, 100):
			failures.append(file + ": wrong dimensions")
			continue
		var palette := {}
		var partial := false
		for y in sheet.get_height():
			for x in sheet.get_width():
				var color := sheet.get_pixel(x, y)
				if color.a > 0:
					palette[color.to_rgba32()] = true
					partial = partial or color.a < 1.0
		if palette.size() > 28 or partial:
			failures.append("%s: %d colors, partial alpha=%s" % [file, palette.size(), partial])
		var distinct := {}
		for f in frames:
			var frame := sheet.get_region(Rect2i(f * 100, 0, 100, 100))
			var bounds := frame.get_used_rect()
			distinct[frame.get_data().hex_encode().sha256_text()] = true
			if bounds.size == Vector2i.ZERO or bounds.position.x < 2 or bounds.position.y < 2 \
					or bounds.end.x > 98 or bounds.end.y > 98:
				failures.append("%s frame %d: empty/clipped/opaque background" % [file, f])
		if frames > 1 and distinct.size() < 2:
			failures.append(file + ": animation contains only one pose")
		if file.ends_with("_Attack01.png") or file.ends_with("_Attack02.png") or file.ends_with("_Hurt.png"):
			if sheet.get_region(Rect2i(0, 0, 100, 100)).get_data() != neutral.get_data() \
					or sheet.get_region(Rect2i(500, 0, 100, 100)).get_data() != neutral.get_data():
				failures.append(file + ": neutral boundary does not match Idle")
		if file.ends_with("_Death.png"):
			var last := sheet.get_region(Rect2i(500, 0, 100, 100)).get_used_rect()
			if last.size.y >= neutral.get_used_rect().size.y:
				failures.append(file + ": final pose has not collapsed")
