## sfx.gd — 通用音效播放(仿 FxBurst / ArenaPool 慣例:純 static 工具,不進場景樹)
##
## 用法:Sfx.play(Sfx.HIT) 或 Sfx.play(Sfx.CLICK, -8.0) 調音量。
## 每次 play 現場組一個一次性 AudioStreamPlayer 掛在樹根、播完自毀:
## 重疊觸發各播各的不互搶;pitch 每次微抖,重複音(出牌/受擊)才不像機關槍。
## 非位置性播放:固定俯角鏡頭的牌桌,3D 空間音沒有資訊量(想過才不做)。
## 音源全是 Kenney 包(CC0),對照表與授權見 assets/audio/LICENSE.txt。
class_name Sfx
extends RefCounted

const CARD_PICKUP := preload("res://assets/audio/sfx/card_pickup.ogg")   # 從手牌抓起
const CARD_PLACE := preload("res://assets/audio/sfx/card_place.ogg")     # 入槽召喚
const CARD_DRAW := preload("res://assets/audio/sfx/card_draw.ogg")       # 回合抽牌
const CARD_SHUFFLE := preload("res://assets/audio/sfx/card_shuffle.ogg") # 開局發牌
const CARD_BURY := preload("res://assets/audio/sfx/card_bury.ogg")       # 入土落定
const HIT := preload("res://assets/audio/sfx/hit.ogg")                   # 受擊(從者/本體)
const SPELL_CAST := preload("res://assets/audio/sfx/spell_cast.ogg")     # 秘術結算
const MANA_GAIN := preload("res://assets/audio/sfx/mana_gain.ogg")       # 丟牌回魔(數錢)
const TURN_FLIP := preload("res://assets/audio/sfx/turn_flip.ogg")       # 換回合(翻頁)
const CLICK := preload("res://assets/audio/sfx/click.ogg")               # UI 按鈕
const CARD_FAN := preload("res://assets/audio/sfx/card_fan.ogg")         # 選牌面板攤牌
const VICTORY := preload("res://assets/audio/sfx/victory.ogg")
const DEFEAT := preload("res://assets/audio/sfx/defeat.ogg")


static func play(stream: AudioStream, volume_db: float = 0.0,
		pitch_jitter: float = 0.06) -> void:
	# @tool 腳本(player_hand 等)在編輯器裡也會跑到這:編輯器不出聲。
	if Engine.is_editor_hint():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	# 掛樹根不掛觸發者:發聲者(卡片)可能下一幀就被 free,聲音要活到播完(同 FxBurst)。
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
