extends SceneTree
## Verify imported assets and execute all twelve skills through the real battle resolver.
## Optional archive argument additionally verifies every packed frame against its original pixels.

const MANIFEST := "res://assets/characters/time_fantasy/cards.json"
var checks := 0
var failures := 0
var archive: ZIPReader


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)


func find_battle(node: Node) -> BattleManager:
	if node is BattleManager:
		return node
	for child in node.get_children():
		var found := find_battle(child)
		if found != null:
			return found
	return null


func slots(group: String) -> Array[Node]:
	var row := get_nodes_in_group(group)
	row.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	return row


func verify_assets(entry: Dictionary, card: CardData) -> void:
	check(Deck.load_pool().has(card), entry.id + " present in playable pool")
	check(card.use_dedicated_art and card.art.get_size() == Vector2(320, 170), entry.id + " portrait")
	check(not card.art.get_image().detect_alpha(), entry.id + " opaque portrait hides terrain")
	var actions := {"Idle": "idle1", "Attack01": entry.attack, "Attack02": entry.special,
		"Hurt": "hit", "Walk": "walk", "Summon": "cheer", "Block": "crouch", "Death": "death"}
	for action: String in actions:
		var texture := card.get_anim_sheet(action)
		check(texture != null, entry.id + " " + action + " loads")
		if texture == null:
			continue
		check(texture.get_size() == Vector2(288, 48), entry.id + " " + action + " six square cells")
		# Compare PNG source bytes; the texture importer fills RGB under alpha=0 to prevent fringes.
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
		sheet.convert(Image.FORMAT_RGBA8)
		for i in 6:
			var frame := sheet.get_region(Rect2i(i * 48, 0, 48, 48))
			check(frame.get_used_rect().has_area(), entry.id + " " + action + " nonempty frame")
			if archive == null:
				continue
			var source: String = entry.source.replace("idle1 (1)", "%s (%d)" % [actions[action], i / 2 + 1])
			if action == "Death":
				source = entry.death_source if i >= 3 else entry.source.replace("idle1 (1)", "crouch (%d)" % (i + 1))
			var original := Image.new()
			original.load_png_from_buffer(archive.read_file(source))
			original.convert(Image.FORMAT_RGBA8)
			check(frame.get_data() == original.get_data(), entry.id + " " + action + " original pixels")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		archive = ZIPReader.new()
		if archive.open(args[0]) != OK:
			push_error("Cannot open source archive")
			quit(1)
			return
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(entries.size() == 12, "twelve distinct characters")
	ArenaPool.next_arena_path = ArenaPool.DEFAULT_ARENA
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	var bm := find_battle(scene)
	check(bm != null, "real BattleManager available")
	if bm == null:
		quit(1)
		return
	bm.active_side = "player"
	bm.sides["enemy"].hand.clear()
	bm.sides["player"].hand.clear()
	var player := slots("player_front")
	var enemy := slots("enemy_front")
	for entry: Dictionary in entries:
		var cd := load("res://data/cards/tf_%s.tres" % entry.id) as CardData
		check(cd != null, entry.id + " loads")
		if cd == null:
			continue
		verify_assets(entry, cd)
		for group in ["player_front", "enemy_front", "player_back", "enemy_back"]:
			for slot: CardSlot in slots(group):
				if slot.card_in_slot != null:
					var old := slot.card_in_slot
					slot.on_unit_died()
					old.queue_free()
		await process_frame
		var dummy := (load("res://data/cards/orc.tres") as CardData).duplicate() as CardData
		dummy.hp = 30
		dummy.atk = 0
		var caster := bm.spawn_unit(cd, player[1])
		var ally := bm.spawn_unit(dummy, player[0])
		var victim := bm.spawn_unit(dummy, enemy[1])
		var neighbor := bm.spawn_unit(dummy, enemy[0])
		ally.current_hp = 20
		caster.current_hp = maxi(1, cd.hp - 2)
		bm.player_hero.take_damage(5)
		var hero_before: int = bm.player_hero.hp
		bm.mark_summoned(caster)
		if entry.id == "crimson_captain":
			check(ally.has_status(SkillData.Status.FORGE), "captain battlecry buffs adjacent ally")
		if entry.id == "dawn_paladin":
			check(bm.player_hero.hp == hero_before + 3, "paladin battlecry heals hero")
		bm.sides["player"].mana = 10
		var sk := cd.active_skill
		var target: Card = victim
		if sk.effect_target == SkillData.Target.SELF:
			target = caster
		elif sk.effect_target == SkillData.Target.ALLY:
			target = ally
		await bm.on_action_performed(caster, sk, target)
		check(bm.sides["player"].mana == 10 - sk.cost, entry.id + " pays skill cost")
		check(caster.skill_used_this_turn, entry.id + " spends skill action")
		check(caster.attacked_this_turn == (sk.kind == SkillData.Kind.ENHANCED_ATTACK), entry.id + " correct attack budget")
		match entry.id:
			"verdant_guard": check(caster.shield == 2, "guard gains shield")
			"crimson_captain": check(victim.current_hp == 25, "captain enhanced attack")
			"azure_adventurer": check(victim.current_hp == 25, "adventurer enhanced attack")
			"scarlet_duelist": check(victim.current_hp == 24, "duelist hits twice")
			"dusk_mage": check(victim.current_hp == 27 and victim.has_status(SkillData.Status.BURN), "mage damage and burn")
			"tide_healer": check(ally.current_hp == 23, "priest heals selected ally")
			"sun_monk": check(victim.current_hp == 26 and caster.current_hp == cd.hp, "monk damage and lifesteal")
			"wild_champion": check(victim.current_hp == 25 and neighbor.current_hp == 25, "champion hits adjacent lane")
			"veil_warlock": check(victim.has_status(SkillData.Status.WEAKEN) and victim.current_hp == 30, "warlock weakens without damage")
			"dawn_paladin": check(ally.shield == 3, "paladin shields selected ally")
			"feather_bard": check(ally.atk_total() == 2, "bard buffs selected ally")
			"grove_ranger": check(victim.current_hp == 28 and victim.has_status(SkillData.Status.POISON), "ranger damage and poison")
	if archive != null:
		archive.close()
	# Let damage/status/death coroutines finish before removing their scene.
	await create_timer(1.0).timeout
	scene.queue_free()
	await process_frame
	print("%s Time Fantasy: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)
