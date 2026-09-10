extends SceneTree
## Lossless packing of the purchased Time Fantasy singleframes; no palette/pose repainting.
## godot --headless --path . -s tests/import_time_fantasy.gd -- /path/to/tf_svbattle.zip

const MANIFEST := "res://assets/characters/time_fantasy/cards.json"
const OUTPUT := "res://assets/characters/time_fantasy"
var archive := ZIPReader.new()
var failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source := args[0] if not args.is_empty() else "res://assets/tf_svbattle.zip"
	if archive.open(source) != OK:
		push_error("Cannot open Time Fantasy archive: " + source)
		quit(1)
		return
	var cards: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for card: Dictionary in cards:
		pack_card(card)
	archive.close()
	print("Time Fantasy: packed %d characters from original pixels." % cards.size())
	quit(1 if failed else 0)


func source_frame(path: String) -> Image:
	var img := Image.new()
	if not archive.file_exists(path) or img.load_png_from_buffer(archive.read_file(path)) != OK:
		push_error("Missing or invalid source frame: " + path)
		failed = true
		return Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != Vector2i(48, 48):
		push_error("Unexpected source frame size: " + path)
		failed = true
	return img


func pack_card(card: Dictionary) -> void:
	var folder := OUTPUT.path_join(card.id)
	DirAccess.make_dir_recursive_absolute(folder)
	var actions := {
		"Idle": "idle1", "Attack01": card.attack, "Attack02": card.special,
		"Hurt": "hit", "Walk": "walk", "Summon": "cheer", "Block": "crouch",
	}
	for action: String in actions:
		var sheet := Image.create(288, 48, false, Image.FORMAT_RGBA8)
		# Each authored pose lasts two frames: the strike is still visible at damage time (0.35s).
		for i in 6:
			var pose := "%s (%d)" % [actions[action], i / 2 + 1]
			var path: String = card.source.replace("idle1 (1)", pose)
			sheet.blit_rect(source_frame(path), Rect2i(0, 0, 48, 48), Vector2i(i * 48, 0))
		save_image(sheet, folder.path_join("TF_%s_%s.png" % [card.id, action]))
	var death := Image.create(288, 48, false, Image.FORMAT_RGBA8)
	for i in 6:
		var path: String = card.death_source if i >= 3 else card.source.replace(
			"idle1 (1)", "crouch (%d)" % (i + 1))
		death.blit_rect(source_frame(path), Rect2i(0, 0, 48, 48), Vector2i(i * 48, 0))
	save_image(death, folder.path_join("TF_%s_Death.png" % card.id))
	# A separate, exact-aspect portrait per card. Crop/pad and integer nearest scaling only.
	var portrait := source_frame(card.source)
	portrait = portrait.get_region(portrait.get_used_rect())
	portrait.resize(portrait.get_width() * 4, portrait.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var art := Image.create(320, 170, false, Image.FORMAT_RGBA8)
	# The card frame has a transparent window: art must be opaque to hide the terrain behind it.
	art.fill(Color("11111a"))
	art.blend_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()),
		(art.get_size() - portrait.get_size()) / 2)
	save_image(art, "res://assets/ui/card_art/time_fantasy/tf_%s.png" % card.id)


func save_image(img: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) != OK:
		failed = true
		push_error("Cannot write " + path)
