## app_settings.gd — 全域設定、持久化與中英文 UI 字串。
##
## 作為 Autoload，在任何場景之前載入。視窗、畫質與無障礙不綁主選單，
## 所以從對戰回主選單、重開場景或下次啟動都會沿用同一份設定。
extends Node

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const SELF_PATH := "res://src/settings/app_settings.gd"
const SECTION := "settings"

const MODE_WINDOWED := 0
const MODE_FULLSCREEN := 1
const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2

const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_LANGUAGE := "zh_TW"

var resolution: Vector2i = DEFAULT_RESOLUTION
var display_mode: int = MODE_WINDOWED
var quality: int = QUALITY_MEDIUM
var language: String = DEFAULT_LANGUAGE
var ui_scale: float = 1.0
var high_contrast: bool = false
var reduce_motion: bool = false

## 編輯器 / 沒有 autoload 的環境下的備援實例(見 current())。
static var _fallback: Node


## 取得目前的設定。**保證不回傳 null。**
##
## 遊戲中回傳 autoload 節點。但 @tool 腳本在「編輯器裡」跑時場景樹上沒有 autoload,
## 這時改回傳一個只帶預設值的備援實例——因為全專案 146 個呼叫點沒有半個做 null 檢查,
## 回傳 null 等於在每支 @tool 腳本裡埋地雷(2026-09-01 升 4.7 時 player_hand.gd
## 的扇形預覽就是踩到這個:`SETTINGS.current().motion_duration()` 打在 null 上)。
##
## 備援實例不掛在場景樹上,只供讀預設值;它不會存檔,也碰不到玩家真正的設定。
static func current() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	var node: Node = loop.root.get_node_or_null("AppSettings") if loop != null else null
	if node != null:
		return node
	if _fallback == null:
		# 這裡不能 preload 自己(會變循環引用),也不能加 class_name(會和同名 autoload 打架),
		# 所以走執行期 load——腳本早就在記憶體裡,實際上是快取命中。
		_fallback = (load(SELF_PATH) as GDScript).new()
		# Node 不是 RefCounted,放在 static var 裡沒人會回收它;
		# 掛在場景樹關閉時一起 free,才不會每次關編輯器都噴 "instances were leaked"。
		if loop != null:
			loop.root.tree_exiting.connect(_free_fallback, CONNECT_ONE_SHOT)
	return _fallback


## 釋放 current() 建出來的備援實例(場景樹關閉時觸發)。
static func _free_fallback() -> void:
	if _fallback != null:
		_fallback.free()
		_fallback = null

const ZH := {
	"game_title": "卡牌對決",
	"menu_start": "開始遊戲",
	"menu_practice": "單人練習",
	"menu_online": "連線對戰",
	"menu_gallery": "牌庫圖鑑",
	"menu_settings": "設定",
	"menu_quit": "離開遊戲",
	"back": "返回",
	"lobby_find": "尋找對手",
	"lobby_address": "伺服器位址(本機測試 127.0.0.1)",
	"lobby_help": "按「尋找對手」連上伺服器排配對，湊到兩人就自動開局。",
	"settings_title": "遊戲設定",
	"settings_display": "顯示",
	"settings_mode": "顯示模式",
	"settings_resolution": "解析度",
	"settings_quality": "畫質",
	"settings_language": "語言",
	"settings_accessibility": "無障礙",
	"settings_ui_scale": "UI 大小",
	"settings_contrast": "高對比 UI",
	"settings_motion": "減少動態效果",
	"settings_apply": "套用",
	"settings_cancel": "取消",
	"settings_defaults": "恢復預設",
	"settings_hint": "解析度只在視窗模式下生效。設定會自動保存。",
	"mode_windowed": "視窗",
	"mode_fullscreen": "全螢幕",
	"quality_low": "低",
	"quality_medium": "中",
	"quality_high": "高",
	"language_zh": "繁體中文",
	"language_en": "English",
	"gallery_title": "牌庫圖鑑",
	"gallery_count": "共 %d 張",
	"filter_all": "全部",
	"type_minion": "從者",
	"type_arcana": "秘術",
	"type_equip": "靈裝",
	"type_quick": "瞬咒",
	"type_ward": "伏印",
	"type_domain": "領域",
	"battle_attack": "攻擊",
	"battle_skill": "技能",
	"battle_cancel": "取消",
	"battle_end_turn": "結束回合",
	"battle_leave": "離開對戰",
	"battle_victory": "勝 利",
	"battle_defeat": "敗 北",
	"battle_again": "再戰一場",
	"battle_main_menu": "回到主選單",
	"battle_counter": "發動抵銷",
	"battle_pass": "放棄反制",
	"battle_leave_title": "離開對戰？",
	"battle_stay": "繼續遊戲",
	"battle_confirm_leave": "確定離開，回到主選單",
	"battle_my_turn": "我方回合",
	"battle_enemy_turn": "對方回合",
	"battle_turn": "第 %d 回合 ‧ %s",
	"battle_enemy_hand": "對方手牌：%d 張",
	"battle_attack_desc": "普通攻擊：對目標造成等同攻擊力的傷害，並承受目標反擊（免費，每回合 1 次）。",
	"battle_cancel_desc": "收回指令。",
	"battle_stats": "攻 %d    血 %d/%d",
	"status_shield": "盾%d",
	"shield_gain": "盾+%d",
	"shield_loss": "盾-%d",
	"battlecry": "戰吼",
	"keywords": "關鍵字",
	"kind_enhanced": "強化攻擊",
	"kind_independent": "獨立攻擊",
	"kind_non_attack": "非攻擊",
	"status_burn": "灼燒",
	"status_freeze": "凍結",
	"status_poison": "中毒",
	"status_night": "夜幕",
	"status_forge": "鍛強",
	"status_weaken": "衰弱",
}

const EN := {
	"game_title": "CARD DUEL",
	"menu_start": "Local Duel",
	"menu_practice": "Solo Practice",
	"menu_online": "Online Match",
	"menu_gallery": "Card Gallery",
	"menu_settings": "Settings",
	"menu_quit": "Quit Game",
	"back": "Back",
	"lobby_find": "Find Opponent",
	"lobby_address": "Server address (local test: 127.0.0.1)",
	"lobby_help": "Connect to the server and enter matchmaking. The match starts when two players are ready.",
	"settings_title": "SETTINGS",
	"settings_display": "DISPLAY",
	"settings_mode": "Display Mode",
	"settings_resolution": "Resolution",
	"settings_quality": "Graphics Quality",
	"settings_language": "Language",
	"settings_accessibility": "ACCESSIBILITY",
	"settings_ui_scale": "UI Scale",
	"settings_contrast": "High-contrast UI",
	"settings_motion": "Reduce Motion",
	"settings_apply": "Apply",
	"settings_cancel": "Cancel",
	"settings_defaults": "Restore Defaults",
	"settings_hint": "Resolution applies in windowed mode. Settings are saved automatically.",
	"mode_windowed": "Windowed",
	"mode_fullscreen": "Fullscreen",
	"quality_low": "Low",
	"quality_medium": "Medium",
	"quality_high": "High",
	"language_zh": "繁體中文",
	"language_en": "English",
	"gallery_title": "CARD GALLERY",
	"gallery_count": "%d cards",
	"filter_all": "All",
	"type_minion": "Minion",
	"type_arcana": "Arcana",
	"type_equip": "Equipment",
	"type_quick": "Quick",
	"type_ward": "Ward",
	"type_domain": "Domain",
	"battle_attack": "Attack",
	"battle_skill": "Skill",
	"battle_cancel": "Cancel",
	"battle_end_turn": "End Turn",
	"battle_leave": "Leave Match",
	"battle_victory": "VICTORY",
	"battle_defeat": "DEFEAT",
	"battle_again": "Play Again",
	"battle_main_menu": "Main Menu",
	"battle_counter": "Counter",
	"battle_pass": "Pass",
	"battle_leave_title": "Leave match?",
	"battle_stay": "Continue",
	"battle_confirm_leave": "Leave and return to Main Menu",
	"battle_my_turn": "Your Turn",
	"battle_enemy_turn": "Opponent's Turn",
	"battle_turn": "Turn %d ‧ %s",
	"battle_enemy_hand": "Opponent's hand: %d",
	"battle_attack_desc": "Deal damage equal to this unit's Attack and take retaliation damage (free, once per turn).",
	"battle_cancel_desc": "Withdraw this command.",
	"battle_stats": "ATK %d    HP %d/%d",
	"status_shield": "Shield %d",
	"shield_gain": "Shield +%d",
	"shield_loss": "Shield -%d",
	"battlecry": "Battlecry",
	"keywords": "Keywords",
	"kind_enhanced": "Enhanced Attack",
	"kind_independent": "Independent Attack",
	"kind_non_attack": "Non-attack",
	"status_burn": "Burn",
	"status_freeze": "Freeze",
	"status_poison": "Poison",
	"status_night": "Night Veil",
	"status_forge": "Forge",
	"status_weaken": "Weaken",
}


func _ready() -> void:
	load_settings()
	apply_all.call_deferred()


func text(key: String) -> String:
	var table: Dictionary = EN if language == "en" else ZH
	return str(table.get(key, ZH.get(key, key)))


func motion_duration(seconds: float) -> float:
	return 0.01 if reduce_motion else seconds


func card_name(card: Resource) -> String:
	if card == null:
		return ""
	if language != "en":
		return card.card_name
	var stem := card.resource_path.get_file().get_basename()
	for prefix in ["arcana_", "equip_", "quick_", "ward_"]:
		if stem.begins_with(prefix):
			stem = stem.trim_prefix(prefix)
	stem = stem.trim_suffix("_token")
	return stem.replace("_", " ").capitalize()


func type_name(card_type: int) -> String:
	var keys := {
		0: "type_minion", 1: "type_equip", 2: "type_arcana",
		3: "type_quick", 4: "type_ward", 5: "type_domain",
	}
	return text(keys.get(card_type, "?"))


func kind_name(kind: int) -> String:
	return text(["kind_enhanced", "kind_independent", "kind_non_attack"][int(kind)])


func status_name(status: int) -> String:
	var keys := {
		1: "status_burn", 2: "status_freeze", 3: "status_poison",
		4: "status_night", 5: "status_forge", 6: "status_weaken",
	}
	return text(keys.get(status, "?"))


func keyword_name(keyword: StringName) -> String:
	if language != "en":
		return String(keyword)
	var names := {
		&"飛行": "Flying", &"守護": "Guard", &"潛行": "Stealth",
		&"衝鋒": "Charge", &"不滅": "Undying", &"鐵壁": "Iron Wall",
	}
	return str(names.get(keyword, String(keyword)))


func skill_name(card: Resource, skill: Resource, is_battlecry: bool = false) -> String:
	if skill == null:
		return ""
	if language != "en":
		return skill.skill_name
	if is_battlecry:
		return text("battlecry")
	return "Active Skill" if card != null and int(card.card_type) == 0 \
		else card_name(card)


## 英文效果文字由規則資料生成，新卡不會因忘記補翻譯而顯示中文。
## 中文仍使用卡牌資源中經過編輯的風味文字。
func skill_description(skill: Resource) -> String:
	if skill == null:
		return ""
	if language != "en":
		return skill.description
	var target := ""
	match int(skill.effect_target):
		0: target = "self"
		1: target = "an allied unit"
		2: target = "an enemy unit"
		3: target = "adjacent allies"
		4: target = "your hero"
	var sentence := ""
	match int(skill.effect):
		1:
			sentence = "Restore %d Health to %s." % [skill.amount, target]
		7:
			sentence = "Give %s %d Shield." % [target, skill.amount]
		2:
			sentence = ""
			if skill.power > 0:
				sentence += "Deal %d damage to %s. " % [skill.power, target]
			sentence += "Apply %s for %d turn(s)." % [
				status_name(skill.status), skill.status_turns]
		3:
			var summoned: String = str(skill.summon_card).replace("_", " ").capitalize()
			sentence = "Summon %s in an empty allied slot." % summoned
		4:
			sentence = "Draw %d card(s)." % skill.amount
		5:
			sentence = "Look at the top %d cards. Keep one and put the rest on the bottom." % skill.amount
		6:
			sentence = "Discard a card, then draw %d card(s)." % skill.amount
		_:
			if skill.power > 0:
				var verb := "Gain +%d Attack for this attack" % skill.power \
					if int(skill.kind) == 0 \
					else "Deal %d damage to %s" % [skill.power, target]
				sentence = verb + "."
	if int(skill.modifier) != 0:
		var modifiers := {
			1: " Also hits adjacent lanes.",
			2: " Also hits the back unit in that lane.",
			3: " Resolve this attack twice.",
			4: " Restore Health equal to damage dealt.",
			5: " Hits all enemy units.",
		}
		sentence += str(modifiers.get(skill.modifier, ""))
	return sentence if not sentence.is_empty() else "Resolve this card's special effect."


func defaults() -> Dictionary:
	return {
		"resolution": DEFAULT_RESOLUTION,
		"display_mode": MODE_WINDOWED,
		"quality": QUALITY_MEDIUM,
		"language": DEFAULT_LANGUAGE,
		"ui_scale": 1.0,
		"high_contrast": false,
		"reduce_motion": false,
	}


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution = _valid_resolution(cfg.get_value(SECTION, "resolution", DEFAULT_RESOLUTION))
	display_mode = clampi(int(cfg.get_value(SECTION, "display_mode", MODE_WINDOWED)), 0, 1)
	quality = clampi(int(cfg.get_value(SECTION, "quality", QUALITY_MEDIUM)), 0, 2)
	language = str(cfg.get_value(SECTION, "language", DEFAULT_LANGUAGE))
	if language not in ["zh_TW", "en"]:
		language = DEFAULT_LANGUAGE
	ui_scale = _valid_ui_scale(float(cfg.get_value(SECTION, "ui_scale", 1.0)))
	high_contrast = bool(cfg.get_value(SECTION, "high_contrast", false))
	reduce_motion = bool(cfg.get_value(SECTION, "reduce_motion", false))


func apply_values(values: Dictionary) -> void:
	resolution = _valid_resolution(values.get("resolution", resolution))
	display_mode = clampi(int(values.get("display_mode", display_mode)), 0, 1)
	quality = clampi(int(values.get("quality", quality)), 0, 2)
	language = str(values.get("language", language))
	if language not in ["zh_TW", "en"]:
		language = DEFAULT_LANGUAGE
	ui_scale = _valid_ui_scale(float(values.get("ui_scale", ui_scale)))
	high_contrast = bool(values.get("high_contrast", high_contrast))
	reduce_motion = bool(values.get("reduce_motion", reduce_motion))
	save_settings()
	apply_all()
	settings_changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "resolution", resolution)
	cfg.set_value(SECTION, "display_mode", display_mode)
	cfg.set_value(SECTION, "quality", quality)
	cfg.set_value(SECTION, "language", language)
	cfg.set_value(SECTION, "ui_scale", ui_scale)
	cfg.set_value(SECTION, "high_contrast", high_contrast)
	cfg.set_value(SECTION, "reduce_motion", reduce_motion)
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("無法保存設定：%s" % error_string(err))


func apply_all() -> void:
	TranslationServer.set_locale(language)
	apply_display()
	apply_quality()
	get_tree().root.content_scale_factor = ui_scale


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if display_mode == MODE_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var centered := usable.position + (usable.size - resolution) / 2
		DisplayServer.window_set_position(centered)


func apply_quality() -> void:
	var viewport := get_tree().root
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	match quality:
		QUALITY_LOW:
			viewport.scaling_3d_scale = 0.75
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.positional_shadow_atlas_size = 2048
		QUALITY_HIGH:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 8192
		_:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.positional_shadow_atlas_size = 4096


func _valid_resolution(value: Variant) -> Vector2i:
	var out := Vector2i(value) if value is Vector2i or value is Vector2 else DEFAULT_RESOLUTION
	return Vector2i(clampi(out.x, 960, 7680), clampi(out.y, 540, 4320))


func _valid_ui_scale(value: float) -> float:
	var choices := [1.0, 1.25, 1.5]
	var best: float = choices[0]
	for choice in choices:
		if absf(value - choice) < absf(value - best):
			best = choice
	return best
