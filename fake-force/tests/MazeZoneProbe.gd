extends Node2D
## 阶段2 迷宫（Main.tscn）结构 + G 缓升 探针
## 0) 结构检查：围墙/5层平台/侧墙/IllusionZone+Timer/方块/尖刺/出口门/条件平台
## 1) 逐层进入 L1~L5：验证 g 从 0 在 ramp_time 内缓升（中段采样 + 完成值）
## 2) 离开迷宫后迷宫区域归零
## 写盘 user://maze_zone_probe_result.txt 并退出。

const TOL : float = 0.25
const LAYERS := [
	["L1_IllusionZone", 1.0, Vector2(9000, 660)],
	["L2_IllusionZone", 2.0, Vector2(8800, 550)],
	["L3_IllusionZone", 4.0, Vector2(9000, 430)],
	["L4_IllusionZone", 5.0, Vector2(8800, 310)],
	["L5_IllusionZone", 6.0, Vector2(9000, 175)],
]

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var li : int = -1
var _measuring : bool = false
var _mid_sampled : bool = false
var _mid_val : float = 0.0
var _entered_verified : bool = false
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
	print("[MazeZoneProbe] Main.tscn loaded")


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
		0:
			if phase_t > 1.0:
				_run_structure_checks()
				phase = 1
				phase_t = 0.0
		1:  # 入口下落测试：从顶墙缺口（x~8300）落下
			var p := _player()
			if p:
				p.global_position = Vector2(8300, 140)
				p.velocity = Vector2.ZERO
			phase = 2
			phase_t = 0.0
		2:  # 入口链路：① 从顶墙缺口落入迷宫区域 → ② 承台右缘下落到迷宫底部（L1 入口地面）
			if not _entered_verified:
				if phase_t > 3.5:
					var p := _player()
					var inside : bool = p != null and p.global_position.x > 8210.0 and p.global_position.x < 8650.0 \
						and p.global_position.y > 580.0 and p.global_position.y < 740.0
					_check(inside, "从顶墙缺口落入迷宫区域（pos=" + str(p.global_position if p else Vector2.ZERO) + "）")
					if p:
						p.global_position = Vector2(8360, 620)
						p.velocity = Vector2.ZERO
					_entered_verified = true
					phase_t = 0.0
			else:
				if phase_t > 2.5:
					var p := _player()
					var on_floor : bool = p != null and p.global_position.x > 8350.0 and p.global_position.x < 8650.0 \
						and p.global_position.y > 650.0 and p.global_position.y < 740.0
					_check(on_floor, "继续下落到迷宫底部（L1 入口地面，pos=" + str(p.global_position if p else Vector2.ZERO) + "）")
					li = 0
					phase = 3
					phase_t = 0.0
		3:
			var p := _player()
			if p:
				p.global_position = LAYERS[li][2]
				p.velocity = Vector2.ZERO
			_measuring = false
			_mid_sampled = false
			_mid_val = 0.0
			phase = 4
			phase_t = 0.0
		4:
			var zone : Area2D = _node(LAYERS[li][0])
			var occ : int = int(zone.get("_occupants")) if zone else 0
			if occ >= 1 and not _measuring:
				_measuring = true
				phase_t = 0.0
			if _measuring:
				var ramp : float = float(zone.get("_ramp"))
				if not _mid_sampled and ramp >= 0.3 and ramp <= 0.7:
					_mid_sampled = true
					_mid_val = IllusionManager.current_g_value
				if ramp >= 1.0:
					var target : float = LAYERS[li][1]
					var zname : String = LAYERS[li][0]
					_check(_mid_sampled, "进入" + zname + " 缓升被采样（非瞬跳）")
					if _mid_sampled:
						_check(_mid_val > 0.05 and _mid_val < target - 0.05,
							"进入" + zname + " 缓升中段 G 正确（mid=" + str(snappedf(_mid_val, 0.01)) + " 目标" + str(target) + "）")
					_check(absf(IllusionManager.current_g_value - target) < TOL,
						"进入" + zname + " 缓升完成 G≈" + str(target) + "（实际 " + str(snappedf(IllusionManager.current_g_value, 0.01)) + "）")
					li += 1
					_measuring = false
					_mid_sampled = false
					phase = 3 if li < LAYERS.size() else 5
					phase_t = 0.0
			elif phase_t > 8.0:
				_check(false, "进入" + LAYERS[li][0] + " 超时未进入（occupants=" + str(occ) + "）")
				li += 1
				phase = 3 if li < LAYERS.size() else 5
				phase_t = 0.0
		5:
			var p := _player()
			if p:
				p.global_position = Vector2(3400, 120)
				p.velocity = Vector2.ZERO
			phase = 6
			phase_t = 0.0
		6:
			var any_occ : int = 0
			for i in range(LAYERS.size()):
				var z := _node(LAYERS[i][0])
				if z and int(z.get("_occupants")) > 0:
					any_occ += 1
			if any_occ == 0:
				_check(IllusionManager.current_g_value < 0.05,
					"离开迷宫后 G 归零（实际 " + str(snappedf(IllusionManager.current_g_value, 0.01)) + "）")
				_print_result()
				get_tree().quit()
			elif phase_t > 6.0:
				_check(false, "离开迷宫后区域仍被占用（" + str(any_occ) + " 个）")
				_print_result()
				get_tree().quit()


func _run_structure_checks() -> void:
	_check_pos("MazeWallLeft", Vector2(8200, 440))
	_check_pos("MazeWallRight", Vector2(9800, 440))
	_check_pos("MazeWallTop", Vector2(9145, 160))
	_check_pos("MazeWallBottom", Vector2(9000, 720))
	# —— 顶墙入口缺口（x8500..9790；左上留入口天井 x8210..8500）——
	var topw : StaticBody2D = _node("MazeWallTop")
	if topw:
		var tcol := topw.get_node_or_null("CollisionShape2D")
		if tcol is CollisionShape2D and (tcol as CollisionShape2D).shape is RectangleShape2D:
			var tw : float = ((tcol as CollisionShape2D).shape as RectangleShape2D).size.x
			_check(absf(tw - 1290.0) < 0.01, "顶墙宽度=1290（覆盖 x8500..9790）")
			_check(topw.position.x - tw * 0.5 > 8300.0, "顶墙左缘在 x=8300 右侧 → 入口天井无顶墙遮挡")
	_check_pos("L1_Platform", Vector2(9000, 700))
	_check_pos("L2_Platform", Vector2(8975, 580))
	_check_pos("L3_Platform", Vector2(9025, 460))
	_check_pos("L4_Platform", Vector2(8975, 340))
	_check_pos("L5_Platform", Vector2(9025, 220))
	# —— L2~L5 平台收窄至 0.9 并左右错位（阶梯式）——
	for i in range(2, 6):
		var plat : Node2D = _node("L%d_Platform" % i)
		if plat:
			_check(absf(plat.scale.x - 0.9) < 0.01, "L%d_Platform scale.x=0.9（收窄）" % i)
	_check_pos("L2_SideWallL", Vector2(8650, 560))
	_check_pos("L2_SideWallR", Vector2(9350, 580))
	_check_pos("L3_SideWallL", Vector2(8650, 460))
	_check_pos("L3_SideWallR", Vector2(9350, 460))
	_check_pos("L4_SideWallL", Vector2(8650, 340))
	_check_pos("L4_SideWallR", Vector2(9350, 340))
	_check_pos("L5_SideWallL", Vector2(8650, 220))
	_check_pos("L5_SideWallR", Vector2(9350, 265))
	for i in range(1, 6):
		var zname : String = "L%d_IllusionZone" % i
		var zone : Area2D = _node(zname)
		_check(zone != null, zname + " 存在")
		if zone:
			_check(absf(zone.g_value - LAYERS[i - 1][1]) < 0.001,
				zname + " g_value=" + str(LAYERS[i - 1][1]))
			var timer := zone.get_node_or_null("Timer")
			_check(timer is Timer and absf((timer as Timer).wait_time - 2.5) < 0.001,
				zname + " 附带 Timer(2.5s)")
	# —— 幻觉覆盖层与平台对齐校准（以实际平台为准）——
	for i in range(1, 6):
		var plat : Node2D = _node("L%d_Platform" % i)
		var zone : Node2D = _node("L%d_IllusionZone" % i)
		if plat and zone:
			var pw : float = 700.0 * plat.scale.x   # 平台实际宽度（含缩放）
			_check(absf(zone.position.x - plat.position.x) < 0.01,
				"L" + str(i) + " 幻觉区 x 与平台对齐（区 " + str(zone.position.x) + " / 平台 " + str(plat.position.x) + "）")
			var zcol := zone.get_node_or_null("CollisionShape2D")
			if zcol is CollisionShape2D and (zcol as CollisionShape2D).shape is RectangleShape2D:
				var zw : float = ((zcol as CollisionShape2D).shape as RectangleShape2D).size.x
				_check(absf(zw - pw) < 0.01,
					"L" + str(i) + " 幻觉区宽与平台一致（区 " + str(zw) + " / 平台 " + str(pw) + "）")
				var zh : float = ((zcol as CollisionShape2D).shape as RectangleShape2D).size.y
				var z_bottom : float = zone.position.y + zh * 0.5
				var p_bottom : float = plat.position.y + 15.0   # 平台底面
				_check(absf(z_bottom - p_bottom) < 0.01,
					"L" + str(i) + " 幻觉区下缘=平台底面（区下缘 " + str(z_bottom) + " / 平台底 " + str(p_bottom) + "）")
	_check_block("MazePB_L1a", 8500.0, true)
	_check_block("MazePB_L1b", 8800.0, true)
	_check_block("MazePB_L2", 8900.0, true)
	_check_block("MazePB_L4", 8700.0, true)
	_check_block("MazeAB_L3b", 9200.0, false)
	_check_block("MazeAB_L4", 9200.0, false)
	_check(_node("MazeAB_L3a") == null, "MazeAB_L3a 已被移除（仅保留 L3 右侧绝对方块）")
	for s in ["SpikeL2_1", "SpikeL2_2", "SpikeL2_3", "SpikeL3_1", "SpikeL3_2",
			"SpikeL4_1", "SpikeL4_2", "SpikeL4_3"]:
		var sp : Area2D = _node(s)
		_check(sp != null and sp.script != null, s + " 尖刺存在且带 Spikes 脚本")
	_check(_node("SpikeL4_4") == null, "SpikeL4_4 已被移除（L4 尖刺带收短为 9000~9067）")
	var gate : Area2D = _node("MazeExitGate")
	_check(gate != null, "MazeExitGate 存在")
	if gate:
		_check(not gate.monitoring, "MazeExitGate 初始 monitoring=false")
		_check(gate.position.distance_to(Vector2(9553, 465)) < 1.0, "MazeExitGate 位置=(9553,465)（覆盖迷宫全高）")
		_check(absf(gate.scale.y - 4.0) < 0.01, "MazeExitGate scale.y=4（纵向4倍）")
		var gcol := gate.get_node_or_null("CollisionShape2D")
		_check(gcol is CollisionShape2D and (gcol as CollisionShape2D).disabled,
			"MazeExitGate CollisionShape2D 初始 disabled")
	_check_cond("Step2_Conditional", Vector2(8250, 360))
	_check_cond("Step3_Conditional", Vector2(8600, 260))
	_check_cond("Transition_Conditional", Vector2(8900, 180))
	var sb := _node("StageBuilder")
	var found_old := false
	if sb:
		for child in sb.get_children():
			if child is StaticBody2D and absf(child.position.x - 8900.0) < 50.0 and absf(child.position.y - 180.0) < 20.0:
				found_old = true
	_check(not found_old, "StageBuilder 已不再生成旧 Transition 平台")
	var step1_found := false
	var step1_y : float = -999.0
	if sb:
		for child in sb.get_children():
			if child is StaticBody2D and absf(child.position.x - 7900.0) < 50.0 and child.position.y >= 95.0 and child.position.y <= 160.0:
				step1_found = true
				step1_y = child.position.y
	_check(step1_found, "Step1（7900,~100~150,宽400）由 StageBuilder 生成（旋转圆盘上部，实际y=" + str(step1_y) + "）")


func _check_pos(name: String, expected: Vector2) -> void:
	var n := _node(name)
	if n is Node2D:
		var p : Vector2 = (n as Node2D).position
		_check(p.distance_to(expected) < 0.01, name + " 位置=" + str(expected) + "（实际 " + str(p) + "）")
	else:
		_check(false, name + " 节点存在")


func _check_block(name: String, x: float, phantom: bool) -> void:
	var b := _node(name)
	_check(b is RigidBody2D, name + " 方块存在")
	if b is RigidBody2D:
		var tol : float = 40.0 if phantom else 0.01
		_check(absf((b as RigidBody2D).position.x - x) < tol, name + " x≈" + str(x))
		_check(b.is_phantom == phantom, name + (" 幻灵" if phantom else " 绝对") + "属性正确")


func _check_cond(name: String, expected: Vector2) -> void:
	var n := _node(name)
	_check(n is StaticBody2D, name + " 条件平台存在")
	if n:
		_check(not n.visible, name + " 初始 visible=false")
		_check((n as StaticBody2D).position.distance_to(expected) < 0.01, name + " 位置=" + str(expected))
		var col := n.get_node_or_null("CollisionShape2D")
		_check(col is CollisionShape2D and (col as CollisionShape2D).disabled, name + " 碰撞初始禁用")


func _print_result() -> void:
	lines.append("========== [MazeZoneProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://maze_zone_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()

