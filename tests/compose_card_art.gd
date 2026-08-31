extends SceneTree
## 將 imagegen 的單色背景人物稿，正規化為固定比例後合成至共用卡圖背景。
## 用法：
## Godot --headless --path . -s tests/compose_card_art.gd -- \
##   /abs/subject.png /abs/background.png /abs/output.png [height] [baseline]

const DEFAULT_VISIBLE_HEIGHT := 580
const DEFAULT_BASELINE_Y := 890
const KEY_TOLERANCE := 0.34
const GLOBAL_KEY_HUE_TOLERANCE := 0.065


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: compose_card_art.gd subject background output [height] [baseline]")
		quit(2)
		return

	var target_height := int(args[3]) if args.size() > 3 else DEFAULT_VISIBLE_HEIGHT
	var baseline_y := int(args[4]) if args.size() > 4 else DEFAULT_BASELINE_Y
	var subject: Image = Image.load_from_file(args[0])
	var background: Image = Image.load_from_file(args[1])
	if subject == null or subject.is_empty() or background == null or background.is_empty():
		printerr("failed to load subject/background")
		quit(2)
		return

	var keyed: Image = _remove_connected_key_background(subject)
	var used: Rect2i = keyed.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		printerr("no foreground pixels found")
		quit(2)
		return

	var character: Image = keyed.get_region(used)
	var target_width := maxi(1, roundi(float(character.get_width()) * target_height / character.get_height()))
	character.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)

	var x := (background.get_width() - target_width) / 2
	var y := baseline_y - target_height
	if x < 0 or y < 0 or x + target_width > background.get_width() or baseline_y > background.get_height():
		printerr("normalized character does not fit output canvas")
		quit(2)
		return

	background.convert(Image.FORMAT_RGBA8)
	background.blend_rect(character, Rect2i(Vector2i.ZERO, character.get_size()), Vector2i(x, y))
	var error := background.save_png(args[2])
	if error != OK:
		printerr("failed to save output: ", error)
		quit(2)
		return
	print("saved: ", args[2], " foreground=", used, " normalized=", character.get_size(),
		" position=", Vector2i(x, y))
	quit(0)


func _remove_connected_key_background(source: Image) -> Image:
	var image := source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var key: Color = image.get_pixel(0, 0)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	queue.append(0)
	visited[0] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var x: int = index % width
		var y: int = index / width
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:
			_try_enqueue(image, key, x - 1, y, width, visited, queue)
		if x + 1 < width:
			_try_enqueue(image, key, x + 1, y, width, visited, queue)
		if y > 0:
			_try_enqueue(image, key, x, y - 1, width, visited, queue)
		if y + 1 < height:
			_try_enqueue(image, key, x, y + 1, width, visited, queue)
	# 武器與手臂之間可能形成被輪廓包住的單色洞，單靠邊緣 flood fill 進不去。
	# 再清一次與角落 key 色非常接近的像素；容差較小，避免吃掉角色本身的紫色。
	# 透明底圖的 RGB 通常也是黑色；此時不能用色相二次清理，否則會吃掉角色的實心黑色。
	if key.a >= 0.5:
		for y in height:
			for x in width:
				var color: Color = image.get_pixel(x, y)
				var hue_distance := absf(color.h - key.h)
				hue_distance = minf(hue_distance, 1.0 - hue_distance)
				if hue_distance <= GLOBAL_KEY_HUE_TOLERANCE and color.s >= 0.5 and color.v >= 0.1:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
	return image


func _try_enqueue(image: Image, key: Color, x: int, y: int, width: int,
		visited: PackedByteArray, queue: PackedInt32Array) -> void:
	var index := y * width + x
	if visited[index] != 0:
		return
	visited[index] = 1
	var color := image.get_pixel(x, y)
	var distance := maxf(absf(color.r - key.r), maxf(absf(color.g - key.g),
		maxf(absf(color.b - key.b), absf(color.a - key.a))))
	if distance <= KEY_TOLERANCE:
		queue.append(index)
