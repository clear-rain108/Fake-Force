extends Node2D
## F 键阅读 探针：验证真实输入分发下 剧情触发区解锁 + 记事本阅读
## 0) 玩家进入 L2 触发区 → 第一次 F（应解锁第4页）
## 1) 第二次 F（应打开记事本阅读）
## 写盘 user://fkey_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var lines : Array[String] = []
var all_ok : bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 记事本打开（暂停树）时探针仍可继续
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		get_tree().paused = false
		opening.free()
	get_viewport().size = Vector2i(1280, 720)
	print("[FKeyProbe] Main.tscn loaded")


func _node(name: String) -> Node:
	return level.get_node_or_null(name)


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("Player")


func _check(ok: bool, msg: String) -> void:
	lines.append(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		all_ok = false


func _send_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	match phase:
		0:
			if phase_t > 1.0:
				var p := _player()
				if p:
					p.global_position = Vector2(8700, 549)
					p.velocity = Vector2.ZERO
				phase = 1
				phase_t = 0.0
		1:
			if phase_t > 0.6:
				var tr : Node = _node("L2_StoryTrigger")
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				_check(tr != null and bool(tr.get("_in_zone")), "玩家在 L2 剧情触发区内")
				_check(int(nb.get("unlocked")) >= 4, "到达自动解锁第4页（无需按键，unlocked=" + str(int(nb.get("unlocked"))) + "）")
				_send_key(KEY_X)   # 真实分发 X → 改变该层方向
				phase = 2
				phase_t = 0.0
		2:
			if phase_t > 0.6:
				var zone : Area2D = _node("L2_IllusionZone")
				var dirs : Array = zone.get("field_directions") if zone else []
				_check(dirs.size() == 1 and dirs[0] == Vector2(0, 1),
					"真实输入 X：L2 方向改为 (0,1)（实际 " + str(dirs) + "）")
				var fdirs : Array = (zone.get("_field").directions as Array) if zone else []
				_check(fdirs.size() == 1 and fdirs[0] == Vector2(0, 1),
					"IllusionField.directions 同步为 (0,1)（实际 " + str(fdirs) + "）")
				_send_key(KEY_F)   # 按 F → 阅读
				phase = 3
				phase_t = 0.0
		3:
			if phase_t > 0.6:
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				_check(bool(nb.get("reading")), "按 F 后记事本打开阅读（reading=" + str(bool(nb.get("reading"))) + "）")
				_print_result()
				get_tree().quit()


func _print_result() -> void:
	lines.append("========== [FKeyProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://fkey_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
