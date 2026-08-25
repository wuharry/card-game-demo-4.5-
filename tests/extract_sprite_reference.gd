extends SceneTree
## 從橫排動畫表擷取指定影格人物，最近鄰放大成 imagegen 可清楚辨識的參考圖。
## Godot --headless --path . -s tests/extract_sprite_reference.gd -- sheet.png out.png

const CANVAS_SIZE := 512
const TARGET_HEIGHT := 430


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: extract_sprite_reference.gd sheet.png out.png")
		quit(2)
		return
	var sheet: Image = Image.load_from_file(args[0])
	if sheet == null or sheet.is_empty():
		printerr("failed to load sprite sheet")
		quit(2)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var frame_index := int(args[2]) if args.size() > 2 else 0
	var cell_size := sheet.get_height()
	var frame_count := sheet.get_width() / cell_size
	if frame_index < 0 or frame_index >= frame_count:
		printerr("frame index out of range: ", frame_index, " / ", frame_count)
		quit(2)
		return
	var frame := sheet.get_region(Rect2i(frame_index * cell_size, 0, cell_size, cell_size))
	var used := frame.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		printerr("frame 0 has no visible pixels")
		quit(2)
		return
	var character := frame.get_region(used)
	var scale := minf(float(TARGET_HEIGHT) / character.get_height(),
		float(TARGET_HEIGHT) / character.get_width())
	var width := maxi(1, roundi(character.get_width() * scale))
	var height := maxi(1, roundi(character.get_height() * scale))
	character.resize(width, height, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.08, 0.08, 0.08, 1.0))
	var pos := Vector2i((CANVAS_SIZE - width) / 2, (CANVAS_SIZE - height) / 2)
	canvas.blend_rect(character, Rect2i(Vector2i.ZERO, character.get_size()), pos)
	var error := canvas.save_png(args[1])
	if error != OK:
		printerr("failed to save reference: ", error)
		quit(2)
		return
	print("saved: ", args[1], " frame=", frame_index, " source=", used,
		" enlarged=", character.get_size())
	quit(0)
