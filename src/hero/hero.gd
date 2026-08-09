## hero.gd — 本體(玩家/敵方的「臉」):打倒它就分勝負(Gameplay Spec §1)
##
## 呈現方式與卡牌角色一致(像素立牌 + 待機動畫),但沒有卡槽、不佔路線,
## 站在己方棋盤後方、比從者高一截。造型「借」一張 CardData 的動畫表
## (standee / get_anim_sheet),HP 固定 20、與該卡面數值無關。
## 由 CardManager 程式生成(main.tscn 零改動);點擊偵測走第 3 碰撞層。
extends Node3D
class_name Hero

signal hero_hovered(hero: Hero)
signal hero_unhovered(hero: Hero)
signal died(hero: Hero)

const CHAR_HEIGHT := 1.45   # 從者立牌 1.3;本體略高一點(1.7 在新構圖裡太佔畫面,2026-07-14 縮)

var side: String = "player"
var max_hp: int = 20   # §1:玩家初始 HP 20
var hp: int = 20
var data: CardData = null   # 只當造型來源(動畫表),數值不吃它的

var _sprite: Sprite3D = null
var _anim: Tween = null
var _hp_label: Label3D = null
var _base_scale: Vector3 = Vector3.ONE


## 由 CardManager 在生成後呼叫(不用 _ready:要先拿到參數才蓋得出外觀)。
func setup(hero_side: String, appearance: CardData) -> void:
	side = hero_side
	data = appearance
	_base_scale = scale
	_build_collision()
	_build_sprite()
	_build_hp_label()


## ── 血量(由 BattleManager 呼叫;打臉不吃反擊,§4.2)──────
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	_refresh_hp()
	if amount > 0:
		_popup_number("-%d" % amount, Color(1.0, 0.3, 0.25))
		# 命中爆點(同 card.gd:preload 引用避開 class_name 快取時序,§19)。
		preload("res://src/fx/fx_burst.gd").spawn_at(self)
		Sfx.play(Sfx.HIT, -3.0)
	if hp <= 0:
		_die()
	else:
		_play_one_shot("Hurt")


## 治療本體(戰吼的「恢復己方英雄 N 點生命」、治療系秘術/技能)。
## 和 Card.heal() 同規矩:先算「實際回了多少」(不超上限),數字報實帳不報帳面量。
func heal(amount: int) -> void:
	var healed := mini(max_hp, hp + amount) - hp
	hp += healed
	_refresh_hp()
	if healed > 0:
		_popup_number("+%d" % healed, Color(0.45, 1.0, 0.5))


func _die() -> void:
	# 死亡表定格(不回待機);死靈法師的表名全大寫 DEATH,備案再試一次。
	if not _play_one_shot("Death", false):
		_play_one_shot("DEATH", false)
	died.emit(self)


## ── 指定目標的高亮(借卡片同一套手感)─────────────────
func animate_hover(zoom: float = 1.15) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * zoom, 0.15)


func animate_unhover() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale, 0.15)


## ── 組裝 ─────────────────────────────────────────────
func _build_collision() -> void:
	var area := Area3D.new()
	area.collision_layer = 4   # 第 3 層 = 本體(卡片 1、卡槽 2,見 card_manager 常數)
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, CHAR_HEIGHT + 0.2, 0.6)
	shape.shape = box
	shape.position = Vector3(0.0, (CHAR_HEIGHT + 0.2) * 0.5, 0.0)   # 箱底貼地
	area.add_child(shape)
	add_child(area)
	area.mouse_entered.connect(func() -> void: hero_hovered.emit(self))
	area.mouse_exited.connect(func() -> void: hero_unhovered.emit(self))


func _build_sprite() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # 立牌:面向鏡頭、保持直立
	# 透明物件預設不寫深度緩衝,DOF 後製會拿「身後森林」的深度來糊它——
	# OPAQUE_PREPASS 讓不透明像素寫深度,立牌在對焦區就保持銳利(像素硬邊零損失)。
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	add_child(_sprite)
	# 大小與腳位用「可見範圍」量(借 Card 的靜態掃描器,同一把尺):
	# 本體是站直的,腳底抬到節點原點走 +Y——卡上立牌躺平走 +Z,只差軸向。
	var bounds := Card.visible_bounds_of_frame0(data.standee)
	var sheet_h := maxf(1.0, float(data.standee.get_height()))
	var feet_row := bounds.end.y - 1.0
	var visible_px := maxf(1.0, bounds.size.y)
	var px := CHAR_HEIGHT / visible_px
	_sprite.pixel_size = px
	_sprite.position = Vector3(0.0, (feet_row + 1.0 - sheet_h * 0.5) * px + 0.02, 0.0)
	_play_idle()


func _build_hp_label() -> void:
	# 深度錨定板:HP 字浮在半空、背景是遠景森林——透明的字不寫深度,
	# DOF 會拿森林的深度把字糊掉;字自己掛 alpha_cut 又會讓外框蓋掉字身
	# (字身/外框共面,靠 render_priority 排序,而 priority 只在透明管線有效)。
	# 所以墊一塊「會寫深度」的不透明底板:字的像素被釘在本體的對焦距離,
	# 順便解決白字壓在雜亂背景上的可讀性。
	var plate := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 0.48)
	plate.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.09, 0.08, 0.11)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	plate.material_override = mat
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 半空的板子別在地上投影
	plate.position = Vector3(0.0, CHAR_HEIGHT + 0.5, 0.0)
	add_child(plate)
	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 72
	_hp_label.outline_size = 16
	_hp_label.no_depth_test = true   # 本體血量是勝負條件,永遠要讀得到
	_hp_label.render_priority = 2
	_hp_label.position = Vector3(0.0, CHAR_HEIGHT + 0.5, 0.0)
	add_child(_hp_label)
	_refresh_hp()


func _refresh_hp() -> void:
	_hp_label.text = "HP %d" % hp
	_hp_label.modulate = Color(1.0, 0.42, 0.4) if hp < max_hp else Color.WHITE


## 飄浮傷害數字(與 card.gd 同語彙;本體站直,往 +Y 飄)。
func _popup_number(text_value: String, color: Color) -> void:
	var lb := Label3D.new()
	lb.text = text_value
	lb.font_size = 64
	lb.modulate = color
	lb.outline_size = 14
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.render_priority = 2
	add_child(lb)
	lb.position = Vector3(0.0, CHAR_HEIGHT * 0.7, 0.0)
	var tw := lb.create_tween().set_parallel(true)
	tw.tween_property(lb, "position:y", CHAR_HEIGHT * 0.7 + 0.9, 0.8)
	tw.tween_property(lb, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lb.queue_free)


## ── 動畫表播放(與 card.gd 立牌同一套邏輯,軸心是自己的 _sprite)──
func _play_idle() -> void:
	var frames := _apply_sheet(data.standee)
	if _anim != null:
		_anim.kill()
	_anim = _sprite.create_tween().set_loops()
	for f in range(frames):
		_anim.tween_callback(func() -> void: _sprite.frame = f).set_delay(0.12)


func _apply_sheet(tex: Texture2D) -> int:
	var h := maxf(1.0, float(tex.get_height()))
	var frames := maxi(1, int(float(tex.get_width()) / h))
	_sprite.texture = tex
	_sprite.hframes = frames
	_sprite.frame = 0
	return frames


func _play_one_shot(suffix: String, back_to_idle: bool = true) -> bool:
	var tex := data.get_anim_sheet(suffix)
	if tex == null:
		return false
	var frames := _apply_sheet(tex)
	if _anim != null:
		_anim.kill()
	_anim = _sprite.create_tween()
	for f in range(frames):
		_anim.tween_callback(func() -> void: _sprite.frame = f).set_delay(0.1)
	if back_to_idle:
		_anim.tween_callback(_play_idle)
	return true
