extends SceneTree
## 將 imagegen 的 3×2 六格角色稿轉成遊戲既有的橫排 100×100 動畫表。
## 上排三格 = Idle,下排三格 = 指定動作（預設 Attack02；無技能從者傳 Attack01）。
##
## imagegen 偶爾把「透明棋盤」烤進 PNG。這裡只清除從畫布外緣能連通到的
## 近白灰像素,角色內部被黑線包住的白色高光會留下。
## 用法:
##   godot --headless --path . --script res://tests/process_generated_sprite_sheet.gd -- \
##     source.png output_dir CharacterName

const COLUMNS := 3
const ROWS := 2
const CELL_SIZE := 100
const VISIBLE_HEIGHT := 32
const FEET_ROW := 65


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: source.png output_dir CharacterName")
		quit(2)
		return
	var source := Image.load_from_file(args[0])
	if source == null or source.is_empty():
		printerr("failed to load source: ", args[0])
		quit(2)
		return
	source.convert(Image.FORMAT_RGBA8)
	_clear_connected_checkerboard(source)
	var cell_w := source.get_width() / COLUMNS
	var cell_h := source.get_height() / ROWS
	if cell_w <= 0 or cell_h <= 0:
		printerr("invalid grid size")
		quit(2)
		return

	# 所有影格共用第 0 格的身高尺,動作特效變寬時角色不會突然縮小。
	var idle0 := source.get_region(Rect2i(0, 0, cell_w, cell_h))
	var idle_bounds := idle0.get_used_rect()
	if idle_bounds.size.y <= 0:
		printerr("first idle cell is empty")
		quit(2)
		return
	var common_scale := float(VISIBLE_HEIGHT) / float(idle_bounds.size.y)

	DirAccess.make_dir_recursive_absolute(args[1])
	var idle_sheet := Image.create(CELL_SIZE * COLUMNS, CELL_SIZE, false, Image.FORMAT_RGBA8)
	var attack_sheet := Image.create(CELL_SIZE * COLUMNS, CELL_SIZE, false, Image.FORMAT_RGBA8)
	idle_sheet.fill(Color.TRANSPARENT)
	attack_sheet.fill(Color.TRANSPARENT)
	for row in ROWS:
		var dst_sheet := idle_sheet if row == 0 else attack_sheet
		for column in COLUMNS:
			var cell := source.get_region(Rect2i(column * cell_w, row * cell_h, cell_w, cell_h))
			var used := cell.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				continue
			var sprite := cell.get_region(used)
			var out_w := maxi(1, roundi(sprite.get_width() * common_scale))
			var out_h := maxi(1, roundi(sprite.get_height() * common_scale))
			# 極端橫向特效仍要留在單格內;通常不會觸發這條保險。
			if out_w > 92:
				var fit := 92.0 / float(out_w)
				out_w = 92
				out_h = maxi(1, roundi(out_h * fit))
			sprite.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
			var x := column * CELL_SIZE + (CELL_SIZE - out_w) / 2
			var y := FEET_ROW - out_h + 1
			dst_sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(x, y))

	var idle_path := args[1].path_join(args[2] + "_Idle.png")
	var action_suffix := args[3] if args.size() >= 4 else "Attack02"
	var attack_path := args[1].path_join(args[2] + "_" + action_suffix + ".png")
	var idle_err := idle_sheet.save_png(idle_path)
	var attack_err := attack_sheet.save_png(attack_path)
	if idle_err != OK or attack_err != OK:
		printerr("failed to save sheets: ", idle_err, " / ", attack_err)
		quit(2)
		return
	print("saved: ", idle_path, " and ", attack_path,
		" source=", source.get_size(), " cell=", Vector2i(cell_w, cell_h),
		" scale=", common_scale)
	quit(0)


func _is_checker_pixel(color: Color) -> bool:
	var hi := maxf(color.r, maxf(color.g, color.b))
	var lo := minf(color.r, minf(color.g, color.b))
	var light_checker := lo >= 0.91 and hi - lo <= 0.035
	# Imagegen 常把「透明」輸出成邊緣連通的黑色柔光底；0.18 可吃掉這層底，
	# 但角色外框被較亮像素包住，不會從畫布邊緣一路灌進角色內部。
	var generated_dark_fill := hi <= 0.18
	return color.a > 0.0 and (light_checker or generated_dark_fill)


func _clear_connected_checkerboard(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()

	for x in width:
		var top_index := x
		if visited[top_index] == 0:
			visited[top_index] = 1
			if _is_checker_pixel(image.get_pixel(x, 0)):
				queue.append(top_index)
		var bottom_index := (height - 1) * width + x
		if visited[bottom_index] == 0:
			visited[bottom_index] = 1
			if _is_checker_pixel(image.get_pixel(x, height - 1)):
				queue.append(bottom_index)
	for y in height:
		var left_index := y * width
		if visited[left_index] == 0:
			visited[left_index] = 1
			if _is_checker_pixel(image.get_pixel(0, y)):
				queue.append(left_index)
		var right_index := y * width + width - 1
		if visited[right_index] == 0:
			visited[right_index] = 1
			if _is_checker_pixel(image.get_pixel(width - 1, y)):
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
			if _is_checker_pixel(image.get_pixel(next.x, next.y)):
				queue.append(next_index)
