extends SceneTree
## 將 imagegen 的 3×1 單排動作稿轉成遊戲既有的 300×100 三格動畫表。
## 用法：
##   godot --headless --path . --script res://tests/process_generated_action_sheet.gd -- \
##     source.png output_dir CharacterName Attack01

const COLUMNS := 3
const CELL_SIZE := 100
const VISIBLE_HEIGHT := 32
const FEET_ROW := 65


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("usage: source.png output_dir CharacterName ActionSuffix")
		quit(2)
		return
	var source := Image.load_from_file(args[0])
	if source == null or source.is_empty():
		printerr("failed to load source: ", args[0])
		quit(2)
		return
	source.convert(Image.FORMAT_RGBA8)
	_clear_connected_generated_background(source)
	var cell_w := source.get_width() / COLUMNS
	var cell_h := source.get_height()
	if cell_w <= 0 or cell_h <= 0:
		printerr("invalid grid size")
		quit(2)
		return

	# 第一格只決定共同角色身高；後續影格即使武器或特效較寬，也不會忽大忽小。
	var first := source.get_region(Rect2i(0, 0, cell_w, cell_h))
	var first_bounds := first.get_used_rect()
	if first_bounds.size.y <= 0:
		printerr("first action cell is empty")
		quit(2)
		return
	var common_scale := float(VISIBLE_HEIGHT) / float(first_bounds.size.y)

	DirAccess.make_dir_recursive_absolute(args[1])
	var sheet := Image.create(CELL_SIZE * COLUMNS, CELL_SIZE, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for column in COLUMNS:
		var cell := source.get_region(Rect2i(column * cell_w, 0, cell_w, cell_h))
		var used := cell.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var sprite := cell.get_region(used)
		var out_w := maxi(1, roundi(sprite.get_width() * common_scale))
		var out_h := maxi(1, roundi(sprite.get_height() * common_scale))
		if out_w > 92:
			var fit := 92.0 / float(out_w)
			out_w = 92
			out_h = maxi(1, roundi(out_h * fit))
		sprite.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
		var x := column * CELL_SIZE + (CELL_SIZE - out_w) / 2
		var y := FEET_ROW - out_h + 1
		sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(x, y))

	var output_path := args[1].path_join(args[2] + "_" + args[3] + ".png")
	var error := sheet.save_png(output_path)
	if error != OK:
		printerr("failed to save sheet: ", error)
		quit(2)
		return
	print("saved: ", output_path, " source=", source.get_size(),
		" cell=", Vector2i(cell_w, cell_h), " scale=", common_scale)
	quit(0)


func _is_generated_background_pixel(color: Color) -> bool:
	var hi := maxf(color.r, maxf(color.g, color.b))
	var lo := minf(color.r, minf(color.g, color.b))
	var is_light_checker := lo >= 0.91 and hi - lo <= 0.035
	var is_dark_fill := hi <= 0.18
	return color.a > 0.0 and (is_light_checker or is_dark_fill)


func _clear_connected_generated_background(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()

	for x in width:
		var top_index := x
		if visited[top_index] == 0:
			visited[top_index] = 1
			if _is_generated_background_pixel(image.get_pixel(x, 0)):
				queue.append(top_index)
		var bottom_index := (height - 1) * width + x
		if visited[bottom_index] == 0:
			visited[bottom_index] = 1
			if _is_generated_background_pixel(image.get_pixel(x, height - 1)):
				queue.append(bottom_index)
	for y in height:
		var left_index := y * width
		if visited[left_index] == 0:
			visited[left_index] = 1
			if _is_generated_background_pixel(image.get_pixel(0, y)):
				queue.append(left_index)
		var right_index := y * width + width - 1
		if visited[right_index] == 0:
			visited[right_index] = 1
			if _is_generated_background_pixel(image.get_pixel(width - 1, y)):
				queue.append(right_index)

	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % width
		var y := int(index / width)
		image.set_pixel(x, y, Color.TRANSPARENT)
		for next: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y),
				Vector2i(x, y - 1), Vector2i(x, y + 1)]:
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			var next_index: int = next.y * width + next.x
			if visited[next_index] != 0:
				continue
			visited[next_index] = 1
			if _is_generated_background_pixel(image.get_pixel(next.x, next.y)):
				queue.append(next_index)
