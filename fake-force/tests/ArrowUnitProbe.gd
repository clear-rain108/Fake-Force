extends Node2D
## 洞察箭头验证（v3.8 定稿）：加载真实 Q1（横向参考系），检查
## ① 普通参考系 _arrow_scale() ≈ 9.6（1G → 3 身位 = 96px）
## ② 旋转参考系 _arrow_scale() ≈ 0.96（10G → 3 身位 = 96px）
## ③ 物理阻尼 ×0.6（get_current_damping()==0.3，系统阻力物理手感降低）
## ④ 空中重力显示 ×0.6（SYSTEM_ARROW_SCALE）
## ⑤ ARROW_WIDTH=2（箭头更细）
## 写盘 user://arrow_unit_probe.txt 并退出。

var t : float = 0.0
var lines : Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level : Node = load("res://levels/Q1.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)


func _process(delta: float) -> void:
	t += delta
	if t < 1.5:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		lines.append("FAIL: 未找到 Player")
		_write_and_quit()
		return
	var g2a : float = IllusionManager.g_to_accel
	# ① 普通参考系
	player.rot_state = player.ROT_NONE
	var lin : float = player._arrow_scale()
	# ② 旋转参考系
	player.rot_state = player.ROT_SYNCED
	var rot : float = player._arrow_scale()
	player.rot_state = player.ROT_NONE
	var lin_ok : bool = absf(lin - player.ARROW_UNIT_BODY * player.BODY_SIZE \
			/ (player.ARROW_UNIT_G_LINEAR * g2a)) < 0.001
	var rot_ok : bool = absf(rot - player.ARROW_UNIT_BODY * player.BODY_SIZE \
			/ (player.ARROW_UNIT_G_ROT * g2a)) < 0.001
	lines.append("[check] g_to_accel=" + str(g2a))
	lines.append("[check] 普通系 _arrow_scale()=" + str(lin) \
			+ " → 1G=" + str(lin * g2a * player.ARROW_UNIT_G_LINEAR) + "px（应≈96px=3身位）")
	lines.append("[check] 旋转系 _arrow_scale()=" + str(rot) \
			+ " → 10G=" + str(rot * g2a * player.ARROW_UNIT_G_ROT) + "px（应≈96px=3身位）")
	lines.append("[check] ARROW_WIDTH=" + str(player.ARROW_WIDTH) + "（应=2：更细；头部8px≈半个身位）")
	# ③ 物理阻尼 ×0.6（系统阻力物理手感降低）
	IllusionManager.current_damping = 0.5
	var d_eff : float = IllusionManager.get_current_damping()
	var phys_ok : bool = absf(d_eff - 0.3) < 0.001
	lines.append("[check] 物理阻尼：current_damping=0.5 → get_current_damping()=" + str(d_eff) \
			+ "（应=0.3=0.6×：系统阻力物理层已降低）")
	# ④ 空中重力显示 ×0.6（跳跃重力物理不变）
	var sys_scale : float = player.SYSTEM_ARROW_SCALE
	var sys_ok : bool = absf(sys_scale - 0.6) < 0.001
	lines.append("[check] SYSTEM_ARROW_SCALE=" + str(sys_scale) \
			+ "（应=0.6：空中重力显示缩放；阻尼物理已在 get_current_damping×0.6）")
	lines.append("========== [ArrowUnitProbe] ==========")
	lines.append("普通系 1G → 3 身位 = " + ("PASS" if lin_ok else "FAIL"))
	lines.append("旋转系 10G → 3 身位 = " + ("PASS" if rot_ok else "FAIL"))
	lines.append("物理阻尼 ×0.6（手感降低） = " + ("PASS" if phys_ok else "FAIL"))
	lines.append("空中重力显示 ×0.6 = " + ("PASS" if sys_ok else "FAIL"))
	lines.append("箭头更细（线宽2 / 头8） = " + ("PASS" if absf(player.ARROW_WIDTH - 2.0) < 0.001 else "FAIL"))
	_write_and_quit()


func _write_and_quit() -> void:
	for line in lines:
		print(line)
	var f := FileAccess.open("user://arrow_unit_probe.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit()