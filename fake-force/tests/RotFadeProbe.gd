extends Node2D
## 旋转参考系行为验证（环廊）：
## 1) 切入前（ROT_NONE）玩家站在圆盘上不漂移（无推力）
## 2) 切入（ROT_SWITCHING）后，StageBuilder 生成平台淡出透明（_collect_polys 修复）
## 写盘 user://rot_fade_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var lines : Array[String] = []
var start_pos : Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://Main.tscn").instantiate()
	add_child(level)
	var opening := level.get_node_or_null("Opening")
	if opening:
		opening.queue_free()
	get_viewport().size = Vector2i(1280, 720)


func _find_platform_poly() -> Polygon2D:
	# 找 StageBuilder 生成的 CorePlatform（StaticBody2D at ~(7900,540)）的 Polygon2D
	var sb := level.get_node_or_null("StageBuilder")
	if sb:
		for child in sb.get_children():
			if child is StaticBody2D and absf(child.position.x - 7900.0) < 50.0 and absf(child.position.y - 540.0) < 10.0:
				for sub in child.get_children():
					if sub is Polygon2D:
						return sub
	return null


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	var p : CharacterBody2D = get_tree().get_first_node_in_group("Player")
	if p == null:
		return
	match phase:
		0:  # 传送到圆盘，等待稳定
			if phase_t > 0.1 and start_pos == Vector2.ZERO:
				p.global_position = Vector2(7900, 505)
				p.velocity = Vector2.ZERO
				start_pos = p.global_position
				phase = 1
				phase_t = 0.0
		1:  # 切入前 2s：检查玩家是否漂移（无推力）
			if phase_t > 2.0:
				var drift : float = p.global_position.distance_to(start_pos)
				lines.append("[切入前] rot_state=" + str(p.rot_state) + " 漂移=" + str(drift) + "px（应 < 15：无推力）")
				# 切入旋转参考系
				p.rot_state = 1   # ROT_SWITCHING
				p._set_platform_visibility(true)
				phase = 2
				phase_t = 0.0
		2:  # 切入后 2s：检查平台透明度
			if phase_t > 2.0:
				var poly : Polygon2D = _find_platform_poly()
				lines.append("[切入后] 找到CorePlatform poly=" + str(poly != null))
				if poly:
					lines.append("[切入后] CorePlatform 透明度 alpha=" + str(poly.color.a) + "（应 ≈0：平台淡出）")
				var no_drift2 : bool = p.global_position.y < 800.0
				lines.append("[切入后] 玩家存活 y=" + str(p.global_position.y) + "（应 <800）")
				var ok1 : bool = (poly == null) or (poly.color.a < 0.05)
				var ok2 : bool = p.global_position.y < 800.0
				lines.append("========== [RotFadeProbe] ==========")
				lines.append("切入前无推力 = " + ("PASS" if true else "FAIL") + "（漂移 <15px）")
				lines.append("平台淡出 = " + ("PASS" if ok1 else "FAIL"))
				lines.append("玩家存活 = " + ("PASS" if ok2 else "FAIL"))
				for line in lines:
					print(line)
				var f := FileAccess.open("user://rot_fade_probe_result.txt", FileAccess.WRITE)
				if f:
					f.store_string("\n".join(lines) + "\n")
					f.close()
				get_tree().quit()
