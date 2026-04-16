extends Node3D
class_name Card # 記得加上 class_name，配合我們上一篇的 Manager

# 紀錄原始縮放值，避免多次 tween 導致大小失真
var original_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	original_scale = scale

# 當滑鼠射線進入 Area3D 的碰撞框時自動觸發
func _on_area_3d_mouse_entered() -> void:
	# 建立動畫，花費 0.15 秒放大到 1.2 倍
	var tw = create_tween()
	tw.tween_property(self, "scale", original_scale * 1.2, 0.15)

# 當滑鼠射線離開 Area3D 的碰撞框時自動觸發
func _on_area_3d_mouse_exited() -> void:
	# 建立動畫，花費 0.15 秒縮小回原本的大小
	var tw = create_tween()
	tw.tween_property(self, "scale", original_scale, 0.15)
