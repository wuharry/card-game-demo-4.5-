extends Node3D
class_name Card # 記得加上 class_name，配合我們上一篇的 Manager


# 1. 定義自定義信號，並將自己 (Card) 當作參數傳遞出去
signal card_hovered(card: Card)
signal card_unhovered(card: Card)
# 紀錄原始縮放值，避免多次 tween 導致大小失真
var original_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	original_scale = scale

# 2. 觸發原生信號時，不再自己播動畫，而是「向外廣播」
func _on_area_3d_mouse_entered() -> void:
	card_hovered.emit(self)

func _on_area_3d_mouse_exited() -> void:
	card_unhovered.emit(self)

# 3. 將原本的動畫邏輯獨立成 Function，準備讓 Manager 決定何時呼叫
func animate_hover() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", original_scale * 1.2, 0.15)

func animate_unhover() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", original_scale, 0.15)

# --- 公開方法 ---
# 將卡片物理鎖死，使其無法再被滑鼠拖曳 (放進卡槽時呼叫)
func lock_interaction() -> void:
	var col_shape = $Area3D/CollisionShape3D 
	if col_shape:
		col_shape.disabled = true
		print("[狀態] 卡片已鎖定，滑鼠無法拖曳")

# 解除物理鎖定，讓卡片可以再次被玩家拖曳 (回手牌時呼叫)
func unlock_interaction() -> void:
	var col_shape = $Area3D/CollisionShape3D 
	if col_shape:
		col_shape.disabled = false
		print("[狀態] 卡片已解鎖，恢復互動能力")
