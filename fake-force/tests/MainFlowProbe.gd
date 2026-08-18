extends Node2D
## Main.tscn 阶段1 重构 流程探针（验证叙事触发链）
## 0) 节点存在性 + 走廊地板 + 出生可站立
## 1) 房间5尘埃收集（queue_free 触发 tree_exiting）→ 迷宫闸门打开 + PushToMaze 启用 + 记事本第1页
## 2) MazeExitSwitch 触发 → 中控室舱门打开 + 记事本第2页
## 3) 中控室按钮 → 黑屏跃迁 → 玩家传送旋转环廊起点 + 背景切太空
## 写盘 user://main_flow_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var lines : Array[String] = []
var all_ok : bool = true


func _ready() -> void:
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		opening.queue_free()
	get_viewport().size = Vector2i(1280, 720)
	print("[MainFlowProbe] Main.tscn loaded")


func _node(name: String) -> Node:
	return level.get_node_or_null(name)


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("Player")


func _check(ok: bool, msg: String) -> void:
	lines.append(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		all_ok = false


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	match phase:
		0:  # 节点存在性 + 几何
			if phase_t > 1.5:
				_check(_node("StageBuilder") != null, "StageBuilder 存在")
				_check(_node("Dust1") != null, "Dust1（房间5尘埃）存在，pos=" + str(_node("Dust1").position if _node("Dust1") else Vector2.ZERO))
				_check(_node("MazeEntranceGate") != null, "MazeEntranceGate（迷宫闸门）存在")
				_check(_node("PushToMaze") != null, "PushToMaze 存在")
				_check(_node("ControlRoomDoor") != null or level.get_node_or_null("MazeExitSwitch/ControlRoomDoor") != null, "ControlRoomDoor 存在（MazeExitSwitch 子节点）")
				_check(_node("MazeExitSwitch") != null, "MazeExitSwitch 存在")
				_check(_node("ControlRoom/LaunchButton") != null, "LaunchButton 存在")
				_check(_node("Stage1Controller") != null, "Stage1Controller 存在")
				var push : Area2D = _node("PushToMaze")
				_check(push != null and not push.monitoring, "PushToMaze 初始 monitoring=false")
				var sw : Area2D = _node("MazeExitSwitch")
				_check(sw != null and sw.gate_path == NodePath("ControlRoomDoor"), "MazeExitSwitch.gate_path=ControlRoomDoor")
				var p : CharacterBody2D = _player()
				_check(p != null and p.is_on_floor(), "玩家出生后可站立（走廊地板）")
				# 走廊地板平台（StageBuilder 生成，x0~3200, y700）
				var floor_found : bool = false
				var sb : Node = _node("StageBuilder")
				if sb:
					for child in sb.get_children():
						if child is StaticBody2D and absf(child.position.x - 1600.0) < 50.0 and absf(child.position.y - 700.0) < 10.0:
							floor_found = true
				_check(floor_found, "走廊地板平台 (1600,700,宽3200) 已生成")
				phase = 1
				phase_t = 0.0
		1:  # 触发尘埃收集
			var dust := _node("Dust1")
			if dust:
				dust.queue_free()
				lines.append("[info] Dust1 queue_free（收集）")
				phase = 2
				phase_t = 0.0
		2:  # 验证尘埃触发结果
			if phase_t > 0.4:
				_check(_node("MazeEntranceGate") == null, "尘埃后 MazeEntranceGate 已打开（free）")
				var push : Area2D = _node("PushToMaze")
				_check(push != null and push.monitoring, "尘埃后 PushToMaze.monitoring=true")
				var nb := get_tree().get_first_node_in_group("Notebook")
				_check(nb != null and nb.unlocked >= 1, "尘埃后 记事本解锁>=1（实际 " + str(nb.unlocked if nb else -1) + "）")
				phase = 3
				phase_t = 0.0
		3:  # 触发 MazeExitSwitch
			var sw : Area2D = _node("MazeExitSwitch")
			if sw:
				var p : CharacterBody2D = _player()
				sw.body_entered.emit(p)
				lines.append("[info] MazeExitSwitch body_entered 触发")
				phase = 4
				phase_t = 0.0
		4:  # 验证开关结果
			if phase_t > 0.4:
				_check(_node("ControlRoomDoor") == null, "开关后 ControlRoomDoor 已打开（free）")
				var nb := get_tree().get_first_node_in_group("Notebook")
				_check(nb != null and nb.unlocked >= 2, "开关后 记事本解锁>=2（实际 " + str(nb.unlocked if nb else -1) + "）")
				phase = 5
				phase_t = 0.0
		5:  # 传送到中控室按钮，触发跃迁
			var p : CharacterBody2D = _player()
			if p:
				p.global_position = Vector2(5360, 300)
			phase = 6
			phase_t = 0.0
		6:  # 等待 body_entered
			if phase_t > 0.3:
				var ctrl : Node = _node("Stage1Controller")
				_check(ctrl != null and ctrl._in_button, "玩家进入按钮区域（_in_button=true）")
				if ctrl and ctrl._in_button:
					ctrl._do_launch()
					lines.append("[info] 调用 _do_launch()（模拟按 E）")
				phase = 7
				phase_t = 0.0
		7:  # 等待跃迁完成
			if phase_t > 3.0:
				var p : CharacterBody2D = _player()
				var at_ring : bool = p != null and p.global_position.distance_to(Vector2(7900, 570)) < 300.0
				_check(at_ring, "跃迁后玩家位于旋转环廊起点（pos=" + str(p.global_position if p else Vector2.ZERO) + "）")
				var bg : Node = _node("Background")
				_check(bg != null and bg.has_method("set_theme") and bg._target_ship == 0.0, "跃迁后背景切太空（_target_ship=0）")
				_print_result()
				get_tree().quit()


func _print_result() -> void:
	lines.append("========== [MainFlowProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://main_flow_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
