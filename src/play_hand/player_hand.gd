@tool

extends Node3D
class_name PlayerHand

const CARD_SCENE = preload("res://src/card/card.tscn")

@export var hand_size: int = 5
@export var fan_radius: float = 7.0        # 扇形圓弧半徑（越大越平緩）
@export var fan_spread_degrees: float = 25.0 # 扇形總張開角度
@export var card_tilt_x: float = 55.0      # 卡片向攝影機傾斜的角度
@export var card_uniform_scale: float = 0.3

var cards: Array[Node3D] = []

@onready var _card_manager = get_node("../CardManger")

func _ready() -> void:
	draw_starting_hand(hand_size)

func draw_starting_hand(count: int) -> void:
	for i in range(count):
		var card: Card = CARD_SCENE.instantiate()
		card.scale = Vector3.ONE * card_uniform_scale
		add_child(card)
		cards.append(card)
		card.card_hovered.connect(_card_manager._on_card_hovered)
		card.card_unhovered.connect(_card_manager._on_card_unhovered)
	_arrange_fan()

# 供 CardManager 呼叫，讓手牌回到扇形排列
func organize_hand() -> void:
	_arrange_fan()

func _arrange_fan() -> void:
	var count := cards.size()
	if count == 0:
		return

	var center_i := (count - 1) / 2.0
	var half_rad := deg_to_rad(fan_spread_degrees / 2.0)

	for i in range(count):
		# t 從 -1（最左）到 +1（最右）
		var t: float = (i - center_i) / max(center_i, 1.0)
		var angle_rad := t * half_rad

		# 圓弧上的位置（相對 PlayerHand 的 Local Space）
		# 圓心在 PlayerHand 正下方 fan_radius 處，卡片在圓弧頂端
		# 中央卡片 y=0，兩側卡片往下微降（cos 值減少）
		cards[i].position = Vector3(
			fan_radius * sin(angle_rad),
			fan_radius * (cos(angle_rad) - 1.0),
			0.0
		)
		cards[i].scale = Vector3.ONE * card_uniform_scale
		# rotation_z 讓卡片沿扇形切線方向傾斜，呈現展開感
		cards[i].rotation_degrees = Vector3(card_tilt_x, 0.0, -rad_to_deg(angle_rad))
