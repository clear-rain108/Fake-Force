extends Node2D
## 剧情系统探针：
## 0) 结构：7页记事本 + L2~L5 剧情触发区 + MazeTopCheck 存在
## 1) 剧情触发区：进入 L2 → 按 F → 解锁第4页 + L2 方向改为 (0,1)
## 2) 出口检查成功：7页全解锁后进入 MazeTopCheck → 条件平台显现 + StageTransition 激活 + 出口门解锁
## 3) 出口检查失败：页数不足进入 MazeTopCheck → 非法访问（黑幕+暂停树）
## 写盘 user://story_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var lines : Array[String] = []
var all_ok : bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 非法访问暂停树后探针仍可运行
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		get_tree().paused = false
		opening.free()
	get_viewport().size = Vector2i(1280, 720)
	print("[StoryProbe] Main.tscn loaded")


func _node(name: String) -> Node:
	return level.get_node_or_null(name)


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("Player")


func _check(ok: bool, msg: String) -> void:
	lines.append(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		all_ok = false


func _press_x_at(node: Node) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.pressed = true
	node._input(ev)


func _send_f() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	ev.pressed = true
	Input.parse_input_event(ev)


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	match phase:
		0:
			if phase_t > 1.0:
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				_check(nb != null and int(nb.get("pages").size()) == 8, "记事本共 8 页（第7段拆2页，实际 " + str(int(nb.get("pages").size()) if nb else -1) + "）")
				for sn in ["L2_StoryTrigger", "L3_StoryTrigger", "L4_StoryTrigger", "L5_StoryTrigger"]:
					_check(_node(sn) != null, sn + " 存在")
				_check(_node("MazeTopCheck") != null, "MazeTopCheck 存在")
				phase = 1
				phase_t = 0.0
		1:  # 传送玩家进入 L2 剧情触发区
			var p := _player()
			if p:
				p.global_position = Vector2(8700, 549)
				p.velocity = Vector2.ZERO
			phase = 2
			phase_t = 0.0
		2:  # 等待 body_entered（到达自动解锁）+ 悬浮提示
			if phase_t > 0.6:
				var tr : Node = _node("L2_StoryTrigger")
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				var unlocked : int = int(nb.get("unlocked")) if nb else -1
				_check(tr != null and bool(tr.get("_in_zone")), "进入 L2 剧情触发区（_in_zone=true）")
				_check(unlocked >= 4, "到达自动解锁第4页（无需按键，unlocked=" + str(unlocked) + "）")
				_check(nb != null and not String(nb.get("_floating_text")).is_empty(), "显示悬浮提示（按 F 阅读 / 按 X 改变方向）")
				_press_x_at(tr)   # 按 X → 改变该层方向
				_send_f()         # 按 F → 打开记事本阅读
				phase = 3
				phase_t = 0.0
		3:  # 校验 X 改方向 + F 阅读
			if phase_t > 0.6:
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				var zone : Area2D = _node("L2_IllusionZone")
				var dirs : Array = zone.get("field_directions") if zone else []
				_check(dirs.size() == 1 and dirs[0] == Vector2(0, 1), "按 X 后 L2 方向改为 (0,1)（实际 " + str(dirs) + "）")
				_check(bool(nb.get("reading")), "按 F 后记事本打开阅读（reading=true）")
				# 关闭记事本（解除暂停）→ 设置全 8 页 → 测试出口检查成功分支
				if nb:
					nb.set("reading", false)
				get_tree().paused = false
				if nb:
					nb.unlock_pages(8)
				phase = 4
				phase_t = 0.0
		4:  # 传送玩家进入 MazeTopCheck（7 页已解锁）
			var p := _player()
			if p:
				p.global_position = Vector2(9400, 500)
				p.velocity = Vector2.ZERO
			phase = 5
			phase_t = 0.0
		5:  # 等待检查（2s）+ 出口开启
			if phase_t > 3.2:
				var s2 : StaticBody2D = _node("Step2_Conditional")
				var tr : Area2D = _node("StageTransition")
				var gate : Area2D = _node("MazeExitGate")
				_check(s2 != null and s2.visible, "Step2_Conditional 已显现（visible=true）")
				var col : CollisionShape2D = s2.get_node_or_null("CollisionShape2D") if s2 else null
				_check(col != null and not col.disabled, "Step2_Conditional 碰撞已启用")
				_check(tr != null and bool(tr.get("monitoring")), "StageTransition 已激活（monitoring=true）")
				_check(gate != null and not bool(gate.get("locked")), "MazeExitGate 已解锁（locked=false）")
				# 重置 → 测试失败分支
				var check : Node = _node("MazeTopCheck")
				if check:
					check.set("_checked", false)
					check.set("_phase", 0)
				var nb : Node = get_tree().get_first_node_in_group("Notebook")
				if nb:
					nb.set("unlocked", 0)
				IllusionManager.notebook_unlocked = 0
				if get_tree().paused:
					get_tree().paused = false
				var p := _player()
				if p:
					p.global_position = Vector2(8500, 690)   # 先移出检查区，确保 body_exited
					p.velocity = Vector2.ZERO
				phase = 6
				phase_t = 0.0
		6:  # 重新进入 MazeTopCheck（页数不足）
			var p := _player()
			if p:
				p.global_position = Vector2(9400, 500)
				p.velocity = Vector2.ZERO
			phase = 7
			phase_t = 0.0
		7:  # 等待非法访问序列
			if phase_t > 3.0:
				var check : Node = _node("MazeTopCheck")
				var p := _player()
				_check(check != null and int(check.get("_phase")) == 3, "页数不足 → 非法访问序列启动（_phase=3）")
				_check(check != null and check.get("_black") != null, "黑幕已创建（_black）")
				_check(get_tree().paused, "游戏树已暂停（非法访问冻结）")
				_check(p != null, "玩家仍存在")
				# 阻止 3s 后的重开（避免 reload 干扰探针），直接收尾
				check.set("_phase", 0)
				_print_result()
				get_tree().quit()


func _print_result() -> void:
	lines.append("========== [StoryProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://story_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
