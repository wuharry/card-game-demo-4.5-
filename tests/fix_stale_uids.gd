## fix_stale_uids.gd — 修復 .tres / .tscn 裡失效的 ext_resource UID
##
## 為什麼要有這支:
##   資產重新匯入時會拿到新 UID,但引用它的 .tres/.tscn 還留著舊 UID。
##   引擎載入時會警告「invalid UID ... using text path instead」,退回字串路徑比對——
##   慢,而且哪天那組舊 UID 被配給別的資源,就會默默載到錯的東西。
##
## 做法:UID 的正確值一律問引擎(ResourceLoader.get_resource_uid),
##   本腳本只負責把答案寫回檔案——不自己編造 UID。
##
## 跑法(不加 --quit,否則 _init 還沒跑完就結束):
##   godot --headless --path <專案> -s tests/fix_stale_uids.gd
##   --dry            只報告不寫入。
##   --drop-dangling  目標「完全沒有 UID」時(例:4.4 以前存的 .meshlib 沒有 .uid 邊車檔),
##                    把那個懸空的 uid= 屬性整個拿掉。留著它跟留著過期 UID 是同一種風險:
##                    路徑還在所以現在能載,但那組 ID 一旦被配給別的資源就會載錯東西。
extends SceneTree

const SKIP_DIRS: PackedStringArray = [".godot", ".git", ".claude"]

var _dry_run: bool = false
var _drop_dangling: bool = false
var _scanned: int = 0
var _fixed: int = 0
var _unresolved: int = 0


func _init() -> void:
	var argv := OS.get_cmdline_args()
	argv.append_array(OS.get_cmdline_user_args())
	_dry_run = "--dry" in argv
	_drop_dangling = "--drop-dangling" in argv

	var files: PackedStringArray = []
	_collect("res://", files)
	for path in files:
		_process_file(path)

	print("")
	print("[UID] 掃描 %d 個檔案,修正 %d 處,無法解析 %d 處%s"
		% [_scanned, _fixed, _unresolved, "(dry run,未寫入)" if _dry_run else ""])
	quit()


## 遞迴收集所有文字型資源檔(.tres / .tscn)。
func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with(".") and not (entry in SKIP_DIRS):
				_collect(full, out)
		elif entry.get_extension() in ["tres", "tscn"]:
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _process_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	_scanned += 1

	var out_lines: PackedStringArray = []
	var changed := false
	for line in text.split("\n"):
		var fixed_line := _fix_line(path, line)
		if fixed_line != line:
			changed = true
		out_lines.append(fixed_line)
	if not changed or _dry_run:
		return

	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		push_error("[UID] 無法寫入 %s" % path)
		return
	w.store_string("\n".join(out_lines))
	w.close()


## 只處理 [ext_resource 開頭的行——檔案自己的 [gd_resource/gd_scene uid=] 不能動。
func _fix_line(owner_path: String, line: String) -> String:
	if not line.begins_with("[ext_resource"):
		return line
	var old_uid := _attr(line, "uid")
	var res_path := _attr(line, "path")
	if old_uid == "" or res_path == "":
		return line

	# 正確答案問引擎要,不自己算。
	var real_id := ResourceLoader.get_resource_uid(res_path)
	if real_id == ResourceUID.INVALID_ID:
		_unresolved += 1
		if not _drop_dangling:
			print("[UID] ? %s → %s 目標沒有 UID,原樣保留" % [owner_path.get_file(), res_path.get_file()])
			return line
		print("[UID] drop %s : %s 懸空(%s 沒有 UID),改為純路徑引用"
			% [owner_path.get_file(), old_uid, res_path.get_file()])
		return line.replace(' uid="%s"' % old_uid, "")

	var real_uid := ResourceUID.id_to_text(real_id)
	if real_uid == old_uid:
		return line

	print("[UID] fix %s : %s -> %s (%s)" % [owner_path.get_file(), old_uid, real_uid, res_path.get_file()])
	_fixed += 1
	return line.replace('uid="%s"' % old_uid, 'uid="%s"' % real_uid)


## 從 [ext_resource ...] 這行取出 key="value" 的 value。
func _attr(line: String, key: String) -> String:
	var needle := '%s="' % key
	var start := line.find(needle)
	if start == -1:
		return ""
	start += needle.length()
	var end := line.find('"', start)
	return line.substr(start, end - start) if end != -1 else ""
