## 乾淨、可縮放的程式化奧術徽記。只畫幾何線與單色面，完全不使用噪點貼圖。
extends Control

const GOLD := Color(0.89, 0.78, 0.49, 0.72)
const GOLD_FAINT := Color(0.89, 0.78, 0.49, 0.24)
const VIOLET := Color(0.58, 0.43, 0.76, 0.55)
const VIOLET_FILL := Color(0.30, 0.18, 0.48, 0.28)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	# 四圈等距細線，外圈用短刻度建立卡牌 UI 的精密感。
	for ratio in [1.0, 0.91, 0.68, 0.36]:
		draw_circle(center, radius * ratio, GOLD_FAINT, false, 1.25, true)
	draw_circle(center, radius * 0.78, VIOLET, false, 1.5, true)
	for i in 12:
		var angle := -PI * 0.5 + TAU * float(i) / 12.0
		var ray := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-ray.y, ray.x)
		var outer := center + ray * radius
		var inner := center + ray * radius * (0.91 if i % 2 == 0 else 0.95)
		draw_line(inner, outer, GOLD, 1.4, true)
		if i % 3 == 0:
			_draw_diamond(outer, ray, tangent, 12.0, 6.0)

	# 交錯弦線保留神秘感，但密度很低，避免生成圖式的裝飾堆疊。
	for i in 4:
		var angle := PI * 0.25 + TAU * float(i) / 4.0
		var a := center + Vector2(cos(angle), sin(angle)) * radius * 0.68
		var b := center - Vector2(cos(angle), sin(angle)) * radius * 0.68
		draw_line(a, b, GOLD_FAINT, 1.0, true)

	var diamond := PackedVector2Array([
		center + Vector2(0, -34), center + Vector2(22, 0),
		center + Vector2(0, 34), center + Vector2(-22, 0),
	])
	draw_colored_polygon(diamond, VIOLET_FILL)
	diamond.append(diamond[0])
	draw_polyline(diamond, GOLD, 1.8, true)
	draw_circle(center, 4.0, Color(0.78, 0.66, 0.94, 0.78), true, -1.0, true)


func _draw_diamond(at: Vector2, axis: Vector2, tangent: Vector2,
		long_side: float, short_side: float) -> void:
	var pts := PackedVector2Array([
		at + axis * long_side, at + tangent * short_side,
		at - axis * long_side, at - tangent * short_side,
		at + axis * long_side,
	])
	draw_polyline(pts, GOLD, 1.5, true)
