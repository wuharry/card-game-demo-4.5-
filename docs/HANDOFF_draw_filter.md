# HANDOFF:抽牌/濾牌系統(逃生艙任務,2026-07-19)

> **給接手 agent 的施工指令書**。調查已完成、設計已定案、程式碼已寫好在本文件裡——
> 照步驟執行即可,不需要重新調查。每步開頭有「完成判定」:已成立就跳過該步。
> 全部做完後跑「驗證」節,並把「學習債」節記進 LEARNING_LEDGER。

## 已定案的設計(不要重新設計)

三張秘術卡,對標爐石/暗影詩章:

| 卡 | 費 | 效果 | 對標 |
|---|---|---|---|
| 秘傳靈感 | ◆3 | 抽 2 張 | 爐石「奧術智慧」 |
| 命運窺視 | ◆1 | 檢視牌堆頂 3 張,選 1 入手,其餘放回牌堆底 | 爐石「追蹤術」溫和版(不棄掉) |
| 以血換識 | ◆1 | 棄 1 張手牌(自選),抽 2 張;無手牌則直接抽 | 棄抽濾牌(MTG Careful Study 系) |

**關鍵架構事實**(調查結論,直接信任):
- 兩台機器牌堆帳完全同步(host 開局打包+RPC 重放),抽/濾只要廣播「選了第幾張」。
- **行動方那台的 `battle_manager` 手牌帳在回合中是「舊帳」**(出牌只移視圖節點,帳到
  `end_turn` 的 `stash_hand` 才對齊)→ 所有會讀/寫手牌帳的新結算,動帳前先
  `if _hand_view_shows_active_side(): battle_manager.stash_hand(player_hand.hand_data())`
  對帳,否則滿手燒牌判定兩台不一致 = 帳散掉。
- 秘術現行管線:點卡 → `TARGETING` 箭頭瞄準 → `_cast_arcana_at` → 連線走
  `_net_arcana_declare/_net_arcana_resolve`(反制窗口開守方那台)/熱座走 `_resolve_arcana`。
  抽濾卡**無場上目標**:點卡直接施放(跳過瞄準),反制窗口照過。
- AI(enemy_ai.gd)只出從者、不施法 → 零改動。
- `player_hand.draw_card(cd)` 現成:生卡+從牌堆飛入+抽牌聲。
- `SkillData.Effect` enum 只能**往尾巴加**(.tres 存 int,§21 教訓)。
- 選牌 UI 開著時要擋「結束回合」與「右鍵/ESC 取消」(費用已付,選擇是義務)。
- 圖示已選定(shikashi v2 表 `assets/ui/icons/shikashi/v2/icons_transparent.png`,32×32):
  卷軸 `Rect2(352, 416, 32, 32)`=秘傳靈感;望遠鏡 `Rect2(224, 320, 32, 32)`=命運窺視;
  藍色循環箭頭 `Rect2(192, 64, 32, 32)`=以血換識。

---

## Step 1|音效:解出 card_fan.ogg

完成判定:`assets/audio/sfx/card_fan.ogg` 存在。

```bash
cd "e:/Game/card-game-demo(4.5)"
unzip -j -o assets/_Raw_Imports/kenney_casino-audio.zip "Audio/card-fan-1.ogg" -d assets/audio/sfx/
mv assets/audio/sfx/card-fan-1.ogg assets/audio/sfx/card_fan.ogg
```

`assets/audio/LICENSE.txt` 對照表最後補一行:
```
  card_fan.ogg     ← card-fan-1.ogg           @ Casino Audio
```

`src/fx/sfx.gd` 常數區(CLICK 那行之後)加:
```gdscript
const CARD_FAN := preload("res://assets/audio/sfx/card_fan.ogg")         # 選牌面板攤牌
```

## Step 2|skill_data.gd:Effect 枚舉擴充

完成判定:`Effect` enum 含 `DRAW`。

把 `enum Effect { NONE, HEAL, APPLY_STATUS, SUMMON }` 改成(**只能尾巴加,順序不能動**):
```gdscript
## 附加效果(非攻擊技的主體;攻擊型技能則是「命中後」附帶觸發)。
## 抽濾系(§抽濾):DRAW=抽 amount 張;SCRY=看頂 amount 張選 1 入手餘放堆底;
## DISCARD_DRAW=自選棄 1 張再抽 amount 張。只能往尾巴加(.tres 存 int,§21)。
enum Effect { NONE, HEAL, APPLY_STATUS, SUMMON, DRAW, SCRY, DISCARD_DRAW }
```
`amount` 欄位的註解改為:`# HEAL 治療量;DRAW/DISCARD_DRAW 抽幾張;SCRY 看幾張`

## Step 3|battle_manager.gd:帳房新結算

完成判定:存在 `func draw_cards`。

3a. `end_turn()` 裡的抽牌段(「# 抽牌階段(§5,資料層)…」註解起、到 `_emit_state()` 前)
整段換成(爆牌規則收斂到單一入口):
```gdscript
	# 抽牌階段(§5):走 draw_cards 單一入口——爆牌規則只寫一份,法術抽牌同款。
	var d := draw_cards(active_side, 1)
	var result := {"drawn": null, "burned": d.burned > 0}
	if not d.drawn.is_empty():
		result.drawn = d.drawn[0]
```
(原本的 `_emit_state()` 與 `return result` 保留。)

3b. 在 `end_turn()` 之後新增四個函式:
```gdscript
## ── 抽牌/濾牌(§抽濾;法術與回合抽共用的單一入口)──────────


## 抽 n 張:滿手燒牌(§1 爆牌)、牌堆空了就抽不到(本作無疲勞傷害)。
## 回傳 {"drawn": Array[CardData] 實際入手, "burned": int 燒掉幾張}。
func draw_cards(side: String, n: int) -> Dictionary:
	var st := sides[side] as SideState
	var drawn: Array[CardData] = []
	var burned := 0
	for i in range(n):
		if st.deck.is_empty():
			break
		if st.hand.size() >= MAX_HAND:
			bury(side, st.deck.pop_back())
			burned += 1
		else:
			var cd: CardData = st.deck.pop_back()
			st.hand.append(cd)
			drawn.append(cd)
	_emit_state()
	return {"drawn": drawn, "burned": burned}


## 看牌堆頂 n 張(不動帳,只讀;回傳 [0] = 最頂)。
func peek_deck_top(side: String, n: int) -> Array[CardData]:
	var deck: Array[CardData] = (sides[side] as SideState).deck
	var out: Array[CardData] = []
	for i in range(mini(n, deck.size())):
		out.append(deck[deck.size() - 1 - i])
	return out


## 濾牌結算(命運窺視):頂 look_n 張取第 pick_i 張入手,其餘放回牌堆底。
## pick_i 對齊 peek_deck_top 的順序([0]=最頂)。兩台各自重放同款參數,結果一致。
func scry_pick(side: String, look_n: int, pick_i: int) -> Dictionary:
	var st := sides[side] as SideState
	var popped: Array[CardData] = []
	for i in range(mini(look_n, st.deck.size())):
		popped.append(st.deck.pop_back())
	if popped.is_empty():
		return {"picked": null, "burned": false}
	pick_i = clampi(pick_i, 0, popped.size() - 1)
	var picked: CardData = popped[pick_i]
	popped.remove_at(pick_i)
	for cd in popped:
		st.deck.insert(0, cd)   # 其餘放牌堆底(對手只知道張數沒變,不知內容)
	var burned := false
	if st.hand.size() >= MAX_HAND:   # 防呆:施法後手牌 ≤7,正常到不了這
		bury(side, picked)
		burned = true
	else:
		st.hand.append(picked)
	_emit_state()
	return {"picked": picked, "burned": burned}


## 棄掉手牌第 idx 張入墓(以血換識的「換」;不觸發丟牌回魔、不吃冷卻)。
func discard_from_hand(side: String, idx: int) -> CardData:
	var st := sides[side] as SideState
	if idx < 0 or idx >= st.hand.size():
		return null
	var cd: CardData = st.hand[idx]
	st.hand.remove_at(idx)
	bury(side, cd)
	_emit_state()
	return cd
```

## Step 4|battle_ui.gd:選牌面板

完成判定:存在 `signal card_picked`。

4a. 信號區(`reaction_decided` 之後)加:
```gdscript
## 選牌面板(§抽濾)的回答:選了第幾張(索引對齊 show_card_picker 傳入的陣列)。
signal card_picked(idx: int)
```

4b. 成員變數(勝負畫面那組之後)加:
```gdscript
## 選牌面板(§抽濾:看頂選一/換牌共用;第一次用到才組裝)。
var _pick_dim: ColorRect = null
var _pick_panel: PanelContainer = null
var _pick_title: Label = null
var _pick_hint: Label = null
var _pick_row: HBoxContainer = null
```

4c. 檔尾(`update_opp_count` 之後)加整組函式:
```gdscript
## ── 選牌面板(§抽濾)──────────────────────────────
## 沒有取消鈕:費用在宣告時已付,選擇是義務(同爐石「發現」,防免費偷看)。
## 開著時 CardManager 用 _picking 旗標擋掉取消/結束回合。
func show_card_picker(title_text: String, hint_text: String,
		cards: Array[CardData]) -> void:
	if _pick_panel == null:
		_build_picker()
	_pick_title.text = title_text
	_pick_hint.text = hint_text
	for child in _pick_row.get_children():
		_pick_row.remove_child(child)   # 先摘再 free:queue_free 的殘影會撐壞本幀排版
		child.queue_free()
	for i in range(cards.size()):
		_pick_row.add_child(_make_pick_tile(cards[i], i))
	_pick_dim.visible = true
	_pick_panel.visible = true
	Sfx.play(Sfx.CARD_FAN, -4.0)
	_pick_panel.reset_size()
	_pick_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _build_picker() -> void:
	_pick_dim = ColorRect.new()
	_pick_dim.color = Color(0.0, 0.0, 0.0, 0.62)
	add_child(_pick_dim)
	_pick_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_pick_panel = PanelContainer.new()
	_pick_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_pick_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_pick_panel.add_child(col)

	_pick_title = Label.new()
	_pick_title.add_theme_font_override("font", FONT_TITLE)
	_pick_title.add_theme_font_size_override("font_size", 26)
	_pick_title.add_theme_color_override("font_color", GOLD)
	_pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pick_title)
	col.add_child(_make_gold_line())

	_pick_hint = Label.new()
	_pick_hint.add_theme_font_override("font", FONT_BODY)
	_pick_hint.add_theme_font_size_override("font_size", 16)
	_pick_hint.add_theme_color_override("font_color", GOLD_DIM)
	_pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pick_hint)

	_pick_row = HBoxContainer.new()
	_pick_row.add_theme_constant_override("separation", 14)
	_pick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_pick_row)


## 一張可點選的卡面磚:圖+名+費+一句話。整塊都是按鈕(hover 微亮)。
func _make_pick_tile(d: CardData, idx: int) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _make_panel_style())
	tile.custom_minimum_size = Vector2(190, 0)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	tile.add_child(col)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 96)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素圖放大要銳利
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = _cardface_art(d)
	col.add_child(art)

	var name_l := Label.new()
	name_l.add_theme_font_override("font", FONT_TITLE)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", GOLD)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text = "%s ◆%d" % [d.card_name, d.cost]
	col.add_child(name_l)

	var info := Label.new()
	info.add_theme_font_override("font", FONT_BODY)
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", GOLD_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(170, 0)
	if d.card_type == CardData.CardType.MINION:
		info.text = "從者  攻 %d / 血 %d" % [d.atk, d.hp]
	elif d.active_skill != null:
		info.text = d.active_skill.description
	else:
		info.text = TYPE_NAMES.get(d.card_type, "")
	col.add_child(info)

	tile.mouse_entered.connect(func() -> void: tile.modulate = Color(1.25, 1.2, 1.0))
	tile.mouse_exited.connect(func() -> void: tile.modulate = Color.WHITE)
	tile.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton \
				and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_answer_pick(idx))
	return tile


## 卡面圖:從者=立牌第 0 幀裁可見範圍;法術=圖示(和 hover 預覽同一把尺)。
func _cardface_art(d: CardData) -> Texture2D:
	if d.standee != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = d.standee
		atlas.region = Card.visible_bounds_of_frame0(d.standee)
		return atlas
	return d.art


func _answer_pick(idx: int) -> void:
	_pick_dim.visible = false
	_pick_panel.visible = false
	Sfx.play(Sfx.CLICK, -6.0)
	card_picked.emit(idx)
```

## Step 5|card_manager.gd:施放分流+效果結算+連線同步

完成判定:存在 `func _apply_draw`。

5a. 成員變數:`var _hint_pile: GravePile = null` 那行之後加:
```gdscript
var _picking := false   # 選牌面板開著:費用已付、選擇是義務(擋取消/結束回合)
```

5b. `_input` 的右鍵/ESC 取消段,條件加一道 `not _picking`:
```gdscript
	if (is_rmb or is_esc) and not _picking \
			and (ui_state == UiState.MENU_OPEN or ui_state == UiState.TARGETING):
		_cancel_command()
		return
```

5c. `_on_end_turn()` 開頭 `GAME_OVER` 檢查之後加:
```gdscript
	if _picking:
		battle_ui.flash_message("請先完成選牌")
		return
```

5d. `_on_left_pressed_idle` 的 ARCANA 分支(「# ── 秘術:改走…」那段),
在 `_begin_spell_targeting(card)` 前插入抽濾分流:
```gdscript
		# 抽濾系秘術(§抽濾)沒有場上目標:點卡即施放,不走箭頭瞄準。
		if _is_effect_spell(card.data):
			if battle_manager.deck_count(battle_manager.active_side) == 0:
				battle_ui.flash_message("牌堆已空,無牌可抽")
				return
			if NetMatch.is_online:
				_pending_play_card = card
				var idx := player_hand.cards.find(card)
				_net_arcana_declare.rpc(idx, card.data.resource_path, NodePath())
			else:
				_resolve_effect_arcana(card)
			return
```

5e. `_resolve_arcana` 整個函式**重寫**成(反制窗口抽成共用 `_ask_counter_hotseat`,
行為與原版逐行等價——AI 自動抵銷、宣告即付費、被抵銷不退費、末尾入土):
```gdscript
## 秘術結算(§5.1 的 STEP 1→2→4):宣告即付費 → 守方瞬咒窗口 → 未被抵銷才落地。
func _resolve_arcana(card: Card, target: Card) -> void:
	battle_manager.spend(card.data.cost)   # STEP 1:宣告就支付,被抵銷不退費
	Sfx.play(Sfx.SPELL_CAST, -2.0)
	var countered: bool = await _ask_counter_hotseat(card.data.card_name)
	if not countered and is_instance_valid(target):
		# STEP 4:結算(秘術傷害不吃反擊)。
		battle_manager.cast_arcana(card.data, target)
		battle_ui.flash_message("【%s】對【%s】造成 %d 點傷害" % [
			card.data.card_name, target.data.card_name, card.data.active_skill.power])
	# 秘術結算後離場(§7):不管有沒有被抵銷,牌都用掉了 → 入土。
	# (queue_free 掉的是「節點」,card.data 是 Resource、進墓地照樣活著。)
	battle_manager.bury(battle_manager.active_side, card.data)
	player_hand.play_card(card)
	card.queue_free()


## 守方反制窗口(熱座/單機共用;§5.1 STEP 2):有付得起的瞬咒就問,AI 自動抵銷。
## 抵銷成立時瞬咒的消耗與提示都在這裡做完;回傳「是否被抵銷」。
func _ask_counter_hotseat(spell_name: String) -> bool:
	var defender := "enemy" if battle_manager.active_side == "player" else "player"
	var quick: CardData = battle_manager.quick_candidate(defender)
	if quick == null:
		return false
	var used := false
	if MatchMode.is_vs_ai():
		# 單人:守方是 AI,自動決策(有付得起的瞬咒就抵銷),不開人類面板——
		# 面板一開等於把 AI 的手牌資訊攤給玩家,還得由玩家替 AI 按鈕。
		used = true
	else:
		# 熱座把螢幕轉給守方回答;await = 整條流程停在這裡等面板的信號。
		ui_state = UiState.MENU_OPEN   # 鎖住其他 3D 互動,別讓玩家邊回答邊拖卡
		battle_ui.show_reaction("守方反制窗口",
			"對方施放【%s】→ 發動【%s】抵銷?(◆%d)" % [
				spell_name, quick.card_name, quick.cost])
		used = await battle_ui.reaction_decided
		ui_state = UiState.IDLE
	if used:
		battle_manager.consume_quick(defender, quick)
		battle_ui.flash_message("【%s】被【%s】抵銷了!" % [spell_name, quick.card_name])
	return used
```

5f. `_resolve_arcana` 之後新增熱座版效果秘術結算+分流器:
```gdscript
## 抽濾系秘術的熱座/單機結算:付費 → 反制窗口 → 牌離手入墓 → 效果落地。
## 和 _resolve_arcana 的差別:無場上目標,且效果(可能開選牌面板)在牌離手「後」跑。
func _resolve_effect_arcana(card: Card) -> void:
	battle_manager.spend(card.data.cost)
	Sfx.play(Sfx.SPELL_CAST, -2.0)
	var cd := card.data
	var countered: bool = await _ask_counter_hotseat(cd.card_name)
	battle_manager.bury(battle_manager.active_side, cd)   # 用掉即入土(被抵銷也一樣)
	player_hand.play_card(card)
	card.queue_free()
	if not countered:
		_dispatch_spell_effect(cd)


## 抽濾系秘術判定:效果掛在 active_skill.effect 上、無場上目標。
func _is_effect_spell(cd: CardData) -> bool:
	return cd.active_skill != null and cd.active_skill.effect in [
		SkillData.Effect.DRAW, SkillData.Effect.SCRY, SkillData.Effect.DISCARD_DRAW]


## 效果分流(熱座與連線結算端共用的出口;SCRY/換牌會再開選牌面板)。
func _dispatch_spell_effect(cd: CardData) -> void:
	match cd.active_skill.effect:
		SkillData.Effect.DRAW:
			_apply_draw(cd.active_skill.amount)
			battle_ui.flash_message("【%s】:抽 %d 張" % [
				cd.card_name, cd.active_skill.amount])
		SkillData.Effect.SCRY:
			if _acting_locally():
				_begin_scry_flow(cd)
			else:
				battle_ui.flash_message("對方正在檢視牌堆頂的牌…")
		SkillData.Effect.DISCARD_DRAW:
			if _acting_locally():
				_begin_swap_flow(cd)
			else:
				battle_ui.flash_message("對方正在抉擇要換掉哪張牌…")


## 抽 n 張的「帳+視圖」一次做完(兩台各自跑;牌堆同步 → 抽到同一批)。
## 動帳前先 stash 對帳:行動方那台的手牌帳在回合中是舊的(出過的牌還掛在帳上),
## 不對帳就抽,滿手燒牌判定會兩台不一致——一台燒、一台入手,帳就散了(§28 同款地雷)。
func _apply_draw(n: int) -> void:
	if _hand_view_shows_active_side():
		battle_manager.stash_hand(player_hand.hand_data())
	var res: Dictionary = battle_manager.draw_cards(battle_manager.active_side, n)
	if _hand_view_shows_active_side():
		for cd in res.drawn:
			player_hand.draw_card(cd)   # 逐張從牌堆飛入,自帶抽牌聲
	_update_deck_labels()
	_refresh_opp_hud()
	if res.burned > 0:
		battle_ui.flash_message("手牌已滿,%d 張牌燒掉了!" % res.burned)


## 命運窺視:行動方那台開選牌面板(牌堆兩台同步,選完只廣播「第幾張」)。
func _begin_scry_flow(cd: CardData) -> void:
	var look_n: int = cd.active_skill.amount
	var opts := battle_manager.peek_deck_top(battle_manager.active_side, look_n)
	if opts.is_empty():
		return
	ui_state = UiState.MENU_OPEN
	_picking = true
	battle_ui.show_card_picker("命運窺視",
		"選 1 張加入手牌,其餘 %d 張放回牌堆底" % maxi(opts.size() - 1, 0), opts)
	var pick_i: int = await battle_ui.card_picked
	_picking = false
	ui_state = UiState.IDLE
	if NetMatch.is_online:
		_net_scry_pick.rpc(look_n, pick_i)
	else:
		_net_scry_pick(look_n, pick_i)


@rpc("any_peer", "call_local", "reliable")
func _net_scry_pick(look_n: int, pick_i: int) -> void:
	if _hand_view_shows_active_side():
		battle_manager.stash_hand(player_hand.hand_data())   # 動手牌帳前先對帳
	var res: Dictionary = battle_manager.scry_pick(
		battle_manager.active_side, look_n, pick_i)
	var picked: CardData = res.picked
	if picked == null:
		return
	if res.burned:
		battle_ui.flash_message("手牌已滿,拿取的牌燒掉了!")
	elif _hand_view_shows_active_side():
		player_hand.draw_card(picked)
	# 拿了哪張是手牌隱私:自己看名字,對面只看到「拿走 1 張」。
	if _acting_locally():
		battle_ui.flash_message("將【%s】收入手中" % picked.card_name)
	else:
		battle_ui.flash_message("對方檢視牌堆後拿取了 1 張牌")
	_update_deck_labels()
	_refresh_opp_hud()


## 以血換識:選一張手牌棄掉(手牌在自己機器上,視圖即真相;廣播手牌位置)。
func _begin_swap_flow(cd: CardData) -> void:
	var draw_n: int = cd.active_skill.amount
	var hand_cards := player_hand.hand_data()
	if hand_cards.is_empty():
		# 沒有其他手牌:不棄,直接抽(卡面寫明;別讓玩家卡死在選不了的面板)
		if NetMatch.is_online:
			_net_swap_pick.rpc(-1, draw_n)
		else:
			_net_swap_pick(-1, draw_n)
		return
	ui_state = UiState.MENU_OPEN
	_picking = true
	battle_ui.show_card_picker("以血換識",
		"選 1 張棄掉(入墓),然後抽 %d 張" % draw_n, hand_cards)
	var idx: int = await battle_ui.card_picked
	_picking = false
	ui_state = UiState.IDLE
	if NetMatch.is_online:
		_net_swap_pick.rpc(idx, draw_n)
	else:
		_net_swap_pick(idx, draw_n)


@rpc("any_peer", "call_local", "reliable")
func _net_swap_pick(hand_idx: int, draw_n: int) -> void:
	if hand_idx >= 0:
		if _hand_view_shows_active_side():
			battle_manager.stash_hand(player_hand.hand_data())   # 先對帳,idx 才對得上
			if hand_idx < player_hand.cards.size():
				var node: Card = player_hand.cards[hand_idx]
				player_hand.play_card(node)   # 視圖:棄那張的節點收掉(帳在下一行棄)
				node.queue_free()
		var dumped: CardData = battle_manager.discard_from_hand(
			battle_manager.active_side, hand_idx)
		if dumped != null:
			Sfx.play(Sfx.CARD_BURY, -6.0)
			battle_ui.flash_message("換掉【%s】" % dumped.card_name)   # 入墓=公開資訊
	_apply_draw(draw_n)
```

5g. `_net_arcana_resolve` 尾段改寫。原本:
```
	if countered: …
	else:
		var target := _unit_at(_pending_arcana_target)
		if target != null: …cast_arcana+flash…
	if _acting_locally(): …IDLE+收視圖節點…
	_refresh_opp_hud()
```
改成(效果落地移到「牌離手之後」,選牌面板/抽牌動畫接手時畫面已乾淨):
```gdscript
	if countered:
		# 兩台的帳同步,quick_candidate 的「第一張付得起」在兩台挑到同一張。
		var quick: CardData = battle_manager.quick_candidate(defender)
		if quick != null:
			battle_manager.consume_quick(defender, quick)
		battle_ui.flash_message("【%s】被抵銷了!" % cd.card_name)
	elif not _is_effect_spell(cd):
		var target := _unit_at(_pending_arcana_target)
		if target != null:
			battle_manager.cast_arcana(cd, target)
			battle_ui.flash_message("【%s】造成 %d 點傷害" % [
				cd.card_name, cd.active_skill.power])
	if _acting_locally():
		ui_state = UiState.IDLE
		var card := _take_pending_card()
		if card != null:
			player_hand.play_card(card)
			card.queue_free()
	if not countered and _is_effect_spell(cd):
		_dispatch_spell_effect(cd)   # 效果在牌離手後落地(SCRY/換牌會開選牌面板)
	_refresh_opp_hud()
```

## Step 6|三張卡 .tres(新檔,格式仿 arcana_fireblast.tres)

完成判定:`data/cards/arcana_insight.tres` 存在。

`data/cards/arcana_insight.tres`:
```
[gd_resource type="Resource" script_class="CardData" load_steps=6 format=3]

[ext_resource type="Script" path="res://src/card/card_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/ui/icons/shikashi/v2/icons_transparent.png" id="2_sheet"]
[ext_resource type="Script" path="res://src/card/skill_data.gd" id="3_skill"]

[sub_resource type="AtlasTexture" id="AtlasTexture_art"]
atlas = ExtResource("2_sheet")
region = Rect2(352, 416, 32, 32)

[sub_resource type="Resource" id="Skill_main"]
script = ExtResource("3_skill")
skill_name = "秘傳靈感"
description = "抽 2 張牌。"
effect = 4
amount = 2
cost = 3

[resource]
script = ExtResource("1_script")
card_type = 2
card_name = "秘傳靈感"
cost = 3
atk = 0
hp = 0
art = SubResource("AtlasTexture_art")
active_skill = SubResource("Skill_main")
```

`data/cards/arcana_fate_scry.tres`:同上骨架,差異——
region `Rect2(224, 320, 32, 32)`;skill_name/card_name「命運窺視」;
description「檢視牌堆頂 3 張:選 1 張加入手牌,其餘放回牌堆底。」;
effect = 5;amount = 3;cost 兩處都是 1。

`data/cards/arcana_blood_swap.tres`:同上骨架,差異——
region `Rect2(192, 64, 32, 32)`;skill_name/card_name「以血換識」;
description「棄掉 1 張手牌,抽 2 張。(沒有其他手牌時直接抽)」;
effect = 6;amount = 2;cost 兩處都是 1。

## 驗證(告訴 Harvey 在 Godot 按 ▶ 跑 main.tscn)

1. 單機:出「秘傳靈感」→ 不出瞄準箭頭、直接結算,兩張牌從牌堆飛入手,牌堆數字 -2。
2. 出「命運窺視」→ 暗幕+三張卡面攤開(有攤牌聲)、點一張入手;牌堆數字 -1;
   期間按右鍵/ESC/結束回合都被擋(「請先完成選牌」)。
3. 出「以血換識」→ 面板列出手牌,點一張 → 那張入墓(墓地視覺+1)、抽 2 張。
4. 手牌 7 張時抽 2 → 第 2 張燒掉(墓地 +1、提示「手牌已滿」)。
5. vs AI:玩家施放時若 AI 有付得起的瞬咒 → 自動抵銷、效果不發動、卡照樣入墓。
6. 連線(可後補):雙開對戰,一台施放命運窺視,另一台顯示「對方正在檢視牌堆…」,
   選完兩台牌堆數字一致;換牌的棄牌在兩台墓地都出現。

## 學習債記帳(LEARNING_LEDGER 新 §41,格式仿 §40;等級全「初階/未驗(逃生艙)」)

觀念五條:
1. 帳與視圖的「對帳點」:行動方那台手牌帳回合中是舊帳,動帳前 stash_hand 對帳,
   否則滿手判定兩台不一致 → 帳散(考:為什麼回合抽牌不用先 stash?——end_turn 開頭本來就 stash)。
2. 「選擇」的連線同步:牌堆兩台同步 → 只廣播「選了第幾張」(索引),不廣播卡本身;
   選牌面板只開在行動方那台(考:如果廣播卡路徑而非索引,哪裡會出賣手牌隱私/出 bug?)。
3. 付費後的選擇是義務:選牌面板無取消鈕+_picking 擋取消/換頁——不然「免費偷看頂三張」
   (考:_picking 不擋 _net_end_turn 而擋 _on_end_turn,為什麼擋在入口就夠?)。
4. enum 只能尾巴加:.tres 把 enum 存成 int(§21 同族)。
5. 效果落地的時序:bury/牌離手在前、效果(面板/動畫)在後——畫面乾淨+滿手判定正確
   (施法那張已離手才數手牌)。

## 收尾

- commit(feature/battle-core):`feat: 抽濾系統上線——三張秘術(抽2/看頂3選1/棄1抽2)+選牌面板+帳視圖對帳點(§41)`
- 回報 Harvey:新卡已進卡池自動入輪替;選牌面板寬度在 8 張手牌+小視窗時可能偏擠(v1 已知限制);
  人物包(劍士+史萊姆)這次沒用上——是橫向動作素材,適合之後做「戰吼:抽一張」的從者時再入庫。
