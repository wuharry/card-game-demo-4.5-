extends SceneTree
## 技術匯入：切 imagegen 動畫稿、移除連通底色、固定座標與像素網格、套原素材色盤。
## 原始美術由 imagegen 重繪，本工具不生成姿勢。
## godot --headless --path . -s tests/normalize_character_animation.gd -- source.png output_dir Stem 20

const CELL := 100
const COLUMNS := 6
const ROWS := 5
const BASELINE := 59
const ACTIONS := ["Idle", "Attack01", "Attack02", "Hurt", "Death"]
const REFERENCES := ["Knight", "Soldier", "Wizard", "Necromancer", "Werebear", "Orc", "Archer", "Swordsman"]
const PACK := "res://assets/packs/tiny_rpg_characters/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/Characters(100x100 split)/"
var chroma_background := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("usage: source.png output_dir Stem body_height [no_skill]")
		quit(2)
		return
	var source := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if source == null:
		quit(2)
		return
	source.convert(Image.FORMAT_RGBA8)
	var corner := source.get_pixel(0, 0)
	chroma_background = corner.r > 0.8 and corner.b > 0.8 and corner.g < 0.2
	_clear_background(source)
	var cw := float(source.get_width()) / COLUMNS
	var ch := float(source.get_height()) / ROWS
	var cells: Array[Image] = []
	var bounds: Array[Rect2i] = []
	var origins: Array[Vector2i] = []
	var row_cuts: Array[int] = [0]
	for row in range(1, ROWS):
		row_cuts.append(_find_cut(source, roundi(row * ch), roundi(ch * 0.15), 0, source.get_width(), false))
	row_cuts.append(source.get_height())
	for row in ROWS:
		var column_cuts: Array[int] = [0]
		for column in range(1, COLUMNS):
			column_cuts.append(_find_cut(source, roundi(column * cw), roundi(cw * 0.22), row_cuts[row], row_cuts[row + 1], true))
		column_cuts.append(source.get_width())
		for column in COLUMNS:
			var start := Vector2i(column_cuts[column], row_cuts[row])
			var end := Vector2i(column_cuts[column + 1], row_cuts[row + 1])
			var image := source.get_region(Rect2i(start, end - start))
			_clear_edge_fragments(image)
			if image.get_used_rect().size == Vector2i.ZERO:
				printerr("empty cell: ", row, "/", column)
				quit(2)
				return
			cells.append(image)
			bounds.append(image.get_used_rect())
			origins.append(start - Vector2i(roundi(column * cw), roundi(row * ch)))
	var scale_factor := float(args[3]) / bounds[0].size.y
	var palette := _reference_palette()
	var frost_extras := args.size() > 4 and args[4] == "frost_extras"
	if frost_extras:
		palette.clear()
		var main_action := Image.load_from_file(args[1].path_join("Frost_Witch_Attack02.png"))
		var colors := {}
		for y in main_action.get_height():
			for x in main_action.get_width():
				var c := main_action.get_pixel(x, y)
				if c.a == 1.0:
					colors[c.to_rgba32()] = c
		palette.assign(colors.values())
	var sheets: Array[Image] = []
	for row in ROWS:
		var sheet := Image.create(CELL * COLUMNS, CELL, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.TRANSPARENT)
		# 每列的起手姿勢決定座標，不逐幀置中，保留出招位移及倒地高度。
		var anchor := bounds[row * COLUMNS]
		var center := anchor.position.x + origins[row * COLUMNS].x + anchor.size.x / 2.0
		var feet := anchor.end.y + origins[row * COLUMNS].y
		for column in COLUMNS:
			var index := row * COLUMNS + column
			var b := bounds[index]
			var sprite := cells[index].get_region(b)
			sprite.resize(maxi(1, roundi(b.size.x * scale_factor)),
				maxi(1, roundi(b.size.y * scale_factor)), Image.INTERPOLATE_NEAREST)
			var offset := Vector2i(roundi(50 + (b.position.x + origins[index].x - center) * scale_factor),
				roundi(BASELINE + 1 + (b.position.y + origins[index].y - feet) * scale_factor))
			if row == 0:
				offset.y = BASELINE + 1 - sprite.get_height()
			if offset.x < 1 or offset.y < 1 or offset.x + sprite.get_width() >= CELL - 1 \
					or offset.y + sprite.get_height() >= CELL - 1:
				printerr("frame exceeds cell: ", row, "/", column)
				quit(2)
				return
			for y in sprite.get_height():
				for x in sprite.get_width():
					var color := sprite.get_pixel(x, y)
					if color.a < 0.5:
						sprite.set_pixel(x, y, Color.TRANSPARENT)
					else:
						sprite.set_pixel(x, y, _nearest(color, palette))
			sheet.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()),
				offset + Vector2i(column * CELL, 0))
		sheets.append(sheet)
	if not frost_extras:
		_reduce_palette(sheets, palette)
	# 邊界用同一個待機姿勢，避免動作切換時換臉／換裝／腳位跳動。
	var neutral := sheets[0].get_region(Rect2i(0, 0, CELL, CELL))
	if frost_extras:
		neutral = Image.load_from_file(args[1].path_join("Frost_Witch_Idle.png")).get_region(Rect2i(0, 0, CELL, CELL))
	for row in range(1, ROWS):
		sheets[row].fill_rect(Rect2i(0, 0, CELL, CELL), Color.TRANSPARENT)
		sheets[row].blit_rect(neutral, Rect2i(0, 0, CELL, CELL), Vector2i.ZERO)
		if row != 4:
			sheets[row].fill_rect(Rect2i(5 * CELL, 0, CELL, CELL), Color.TRANSPARENT)
			sheets[row].blit_rect(neutral, Rect2i(0, 0, CELL, CELL), Vector2i(5 * CELL, 0))
	DirAccess.make_dir_recursive_absolute(args[1])
	for row in ROWS:
		if frost_extras and row not in [1, 2]:
			continue
		if row == 2 and args.size() > 4 and args[4] == "no_skill":
			continue
		var action: String = ACTIONS[row]
		if frost_extras:
			action = "Walk" if row == 1 else "Summon"
		var path := args[1].path_join(args[2] + "_" + action + ".png")
		if sheets[row].save_png(path) != OK:
			quit(2)
			return
	if args[2] == "Frost_Witch" and not frost_extras:
		neutral.save_png(args[1].path_join("Frost_Witch_Idle_Static.png"))
	var preview := Image.create(1200, 1000, false, Image.FORMAT_RGBA8)
	preview.fill(Color("30323c"))
	for row in ROWS:
		for column in COLUMNS:
			var sample := sheets[row].get_region(Rect2i(column * CELL + 25, 25, 50, 50))
			sample.resize(200, 200, Image.INTERPOLATE_NEAREST)
			preview.blend_rect(sample, Rect2i(0, 0, 200, 200), Vector2i(column * 200, row * 200))
	preview.save_png(args[1].path_join(args[2] + ("_extras_preview.png" if frost_extras else "_preview.png")))
	print("saved ", args[2], " height=", args[3], " reference palette=", palette.size())
	quit(0)


func _find_cut(source: Image, expected: int, radius: int, start: int, end: int, vertical: bool) -> int:
	# 生成稿的特效可能超過名義格線；在格線附近找真正的透明間隙。
	var best := expected
	var best_score := INF
	for cut in range(expected - radius, expected + radius + 1):
		var occupied := 0
		for p in range(start, end):
			var color := source.get_pixel(cut, p) if vertical else source.get_pixel(p, cut)
			if color.a >= 0.5:
				occupied += 1
		var score := occupied * 1000.0 + absi(cut - expected)
		if score < best_score:
			best_score = score
			best = cut
	return best


func _clear_edge_fragments(image: Image) -> void:
	# 只清除碰到切格邊界的小型孤立殘片，保留格內飛行物和特效。
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var components: Array[PackedInt32Array] = []
	var edges: Array[bool] = []
	var largest := 0
	for seed in w * h:
		if seen[seed] or image.get_pixel(seed % w, int(seed / w)).a < 0.5:
			continue
		var pixels := PackedInt32Array([seed])
		seen[seed] = 1
		var head := 0
		var edge := false
		while head < pixels.size():
			var index := pixels[head]
			head += 1
			var x := index % w
			var y := int(index / w)
			edge = edge or x < 3 or y < 3 or x >= w - 3 or y >= h - 3
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var neighbor := ny * w + nx
					if not seen[neighbor] and image.get_pixel(nx, ny).a >= 0.5:
						seen[neighbor] = 1
						pixels.append(neighbor)
		components.append(pixels)
		edges.append(edge)
		largest = maxi(largest, pixels.size())
	for i in components.size():
		if edges[i] and components[i].size() < largest * 0.15:
			for index in components[i]:
				image.set_pixel(index % w, int(index / w), Color.TRANSPARENT)


func _reference_palette() -> Array[Color]:
	var colors := {}
	for name in REFERENCES:
		var path := ProjectSettings.globalize_path(PACK + "%s/%s/%s_Idle.png" % [name, name, name])
		var image := Image.load_from_file(path)
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a == 1.0:
					colors[c.to_rgba32()] = c
	var palette: Array[Color] = []
	palette.assign(colors.values())
	return palette


func _reduce_palette(sheets: Array[Image], _reference: Array[Color]) -> void:
	var histogram := {}
	for sheet in sheets:
		for y in sheet.get_height():
			for x in sheet.get_width():
				var c := sheet.get_pixel(x, y)
				if c.a == 1.0:
					var key := c.to_rgba32()
					histogram[key] = histogram.get(key, 0) + 1
	var selected: Array[Color] = [Color("101018")]
	while selected.size() < mini(28, histogram.size()):
		var best_key: int = 0
		var best_score := -1.0
		for key: int in histogram:
			var color := Color.hex(key)
			var nearest := _nearest(color, selected)
			var delta := Vector3(color.r - nearest.r, color.g - nearest.g, color.b - nearest.b)
			var score := delta.length_squared() * sqrt(float(histogram[key]))
			if score > best_score:
				best_key = key
				best_score = score
		selected.append(Color.hex(best_key))
	for sheet in sheets:
		for y in sheet.get_height():
			for x in sheet.get_width():
				var c := sheet.get_pixel(x, y)
				if c.a == 1.0:
					sheet.set_pixel(x, y, _nearest(c, selected))


func _nearest(c: Color, palette: Array[Color]) -> Color:
	var best := INF
	var result := Color.BLACK
	for p in palette:
		var d := pow(c.r - p.r, 2) + pow(c.g - p.g, 2) + pow(c.b - p.b, 2)
		if d < best:
			best = d
			result = p
	return result


func _background(c: Color) -> bool:
	if chroma_background:
		return c.a < 0.5 or (c.r > 0.65 and c.b > 0.65 and c.g < 0.35)
	var hi := maxf(c.r, maxf(c.g, c.b))
	var lo := minf(c.r, minf(c.g, c.b))
	return c.a < 0.5 or (lo > 0.70 and hi - lo < 0.045)


func _clear_background(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	if chroma_background:
		for y in h:
			for x in w:
				if _background(image.get_pixel(x, y)):
					image.set_pixel(x, y, Color.TRANSPARENT)
		return
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := PackedInt32Array()
	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		if seen[index]:
			continue
		seen[index] = 1
		var x := index % w
		var y := int(index / w)
		if not _background(image.get_pixel(x, y)):
			continue
		image.set_pixel(x, y, Color.TRANSPARENT)
		if x > 0:
			queue.append(index - 1)
		if x < w - 1:
			queue.append(index + 1)
		if y > 0:
			queue.append(index - w)
		if y < h - 1:
			queue.append(index + w)
