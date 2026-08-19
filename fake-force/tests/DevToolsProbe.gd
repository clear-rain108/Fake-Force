extends Node2D
## 临时开发工具探针：P 键跳转存档点 + 尖刺死亡计数/死亡演出
## 0) 结构：7 个存档点 + DebugTeleport 存在
## 1) P 键：起点 → Checkpoint1 → Checkpoint2 → MazeL1（关卡流程顺序）
## 2) 尖刺死亡：激活 Checkpoint2 后反复踩 SpikeL2_1 → fall_count 递增 → 超限触发死亡演出
## 写盘 user://dev_tools_probe_result.txt 并退出。

const SPIKE_POS := Vector2(8600, 570)
const RESPAWN := Vector2(7900, 610)   # Checkpoint2 位置

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var _spike_hits : int = 0
var lines : Array[String] = []
var all_ok : bool = true


func _ready() -> void:
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		get_tree().paused = false
		opening.free()
	get_viewport().size = Vector2i(1280, 720)
	print("[DevToolsProbe] Main.tscn loaded")


func _node(name: String) -> Node:
	return level.get_node_or_null(name)


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("Player")


func _check(ok: bool, msg: String) -> void:
	lines.append(("[PASS] " if ok else "[FAIL] ") + msg)
	if not ok:
		all_ok = false


func _press_p() -> void:
	var dbg : Node = _node("DebugTeleport")
	if dbg:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_P
		ev.pressed = true
		dbg._unhandled_input(ev)


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	match phase:
		0:
			if phase_t > 1.0:
				for cp in ["Checkpoint1", "Checkpoint2", "MazeL1_Checkpoint", "MazeL2_Checkpoint",
						"MazeL3_Checkpoint", "MazeL4_Checkpoint", "MazeL5_Checkpoint"]:
					_check(_node(cp) != null, cp + " 存在")
				_check(_node("DebugTeleport") != null, "DebugTeleport 存在")
				phase = 1
				phase_t = 0.0
		1:  # 复位玩家到起点
			var p := _player()
			if p:
				p.global_position = Vector2(500, 400)
				p.velocity = Vector2.ZERO
				p.set("fall_count", 0)
				p.set("failed", false)
			phase = 2
			phase_t = 0.0
		2, 4, 6:  # 按 P
			if phase_t > 0.4:
				_press_p()
				phase = phase + 1
				phase_t = 0.0
		3, 5, 7:  # 等待传送+存档激活，校验位置
			if phase_t > 0.8:
				var expected := Vector2(2700, 660) if phase == 3 else (Vector2(7900, 610) if phase == 5 else Vector2(8700, 669))
				var p := _player()
				_check(p != null and p.global_position.distance_to(expected) < 30.0,
					"P 传送到存档点（期望 " + str(expected) + "，实际 " + str(p.global_position if p else Vector2.ZERO) + "）")
				if phase == 7:
					# 直接设定复活点并重置死亡计数，然后踩尖刺开始死亡测试
					if p:
						p.set("_spawn_point", RESPAWN)
						p.set("fall_count", 0)
						p.global_position = SPIKE_POS
						p.velocity = Vector2.ZERO
					phase = 8
				else:
					phase = phase + 1
				phase_t = 0.0
		8:  # 第一次尖刺死亡
			if phase_t > 0.8:
				var p := _player()
				_check(p != null and int(p.get("fall_count")) == 1 and p.global_position.distance_to(RESPAWN) < 60.0,
					"尖刺死亡#1：fall_count=1 且重生回存档点（pos=" + str(p.global_position if p else Vector2.ZERO) + "）")
				_spike_hits = 1
				phase = 9
				phase_t = 0.0
		9, 11, 13:  # 第2/3/4次踩尖刺
			if phase_t > 0.3:
				var p := _player()
				if p:
					p.global_position = SPIKE_POS
					p.velocity = Vector2.ZERO
				phase = phase + 1
				phase_t = 0.0
		10, 12, 14:  # 等待命中校验
			if phase_t > 0.8:
				var expected : int = _spike_hits + 1
				var p := _player()
				if expected <= 3:
					_check(p != null and int(p.get("fall_count")) == expected and p.global_position.distance_to(RESPAWN) < 60.0,
						"尖刺死亡#" + str(expected) + "：fall_count=" + str(expected) + " 重生回存档点")
					_spike_hits = expected
					phase = phase + 1
				else:
					_check(p != null and bool(p.get("failed")), "尖刺死亡#4：超限触发死亡演出（failed=true）")
					var death_found := false
					for child in get_tree().current_scene.get_children():
						if child is CanvasLayer and child.layer == 60:
							death_found = true
					_check(death_found, "死亡演出 CanvasLayer(60) 已挂载")
					_print_result()
					get_tree().quit()
				phase_t = 0.0


func _print_result() -> void:
	lines.append("========== [DevToolsProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://dev_tools_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
