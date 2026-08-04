extends SceneTree
## 值型別 vs 參考型別:GDScript 與 TS 的異同對照探針

func _initialize() -> void:
	# ── A) Object(Resource):== 比身分,和 TS 的 === 同構 ──
	var r1 := Resource.new()
	var r2 := Resource.new()
	print("A) 兩個新 Resource:r1 == r2 → ", r1 == r2)

	# ── B) Array:TS 裡 [1,2] === [1,2] 是 false。GDScript 呢? ──
	var a1: Array = [1, 2]
	var a2: Array = [1, 2]
	print("B) [1,2] == [1,2] → ", a1 == a2)

	# ── C) Dictionary ──
	var d1: Dictionary = {"hp": 6}
	var d2: Dictionary = {"hp": 6}
	print("C) {hp:6} == {hp:6} → ", d1 == d2)

	# ── D) Array 是參考型別嗎?(改一邊看另一邊) ──
	var a3 := a1
	a3.append(3)
	print("D) a3 = a1 後 a3.append(3),a1 = ", a1, "  → 參考共享?")

	# ── E) Vector3:TS 沒有的「值語意複合型別」 ──
	var v1 := Vector3(1, 0, 0)
	var v2 := v1
	v2.x = 99
	print("E) v2 = v1 後改 v2.x=99,v1.x = ", v1.x, "  (值型別=拷貝)")

	# ── F) String ──
	var s1 := "騎士"
	var s2 := "騎士"
	print("F) 兩個相同字面 String:s1 == s2 → ", s1 == s2)

	quit()
