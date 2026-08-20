extends Node2D
## 阶段3 纯旋转玩法验收探针（回归 Q5 风格）
## 验证：出生即同步滑行 / 核心引力 / 4 层 η 档位剧情触发 / GravityWell 结局。
## 写盘 user://stage3_rot_probe_result.txt 并退出。

var level : Node2D
var t : float = 0.0
var phase : int = 0
var phase_t : float = 0.0
var lines : Array[String] = []
var all_ok : bool = true
var _spawn_pos : Vector2 = Vector2.INF
var _last_dbg : int = -1

const ST_POS : Array = [Vector2(600, 0), Vector2(0, 450), Vector2(-300, 0), Vector2(0, -180)]
const ST_PAGE : Array = [9, 10, 11, 12]
const ST_ETA : Array = [0.3, 1.0, 1.7, 2.5]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = load("res://scenes/Stage3.tscn").instantiate()
	add_child(level)
	get_viewport().size = Vector2i(1280, 720)
	print("[Stage3RotProbe] Stage3.tscn loaded")


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("Player")


func _core() -> Node2D:
	return get_tree().get_first_node_in_group("RotatingCore")


func _nb() -> Node:
	return get_tree().get_first_node_in_group("Notebook")


func _check(ok: bool, msg: String) -> void:
	var tag := "[PASS] " if ok else "[FAIL] "
	lines.append(tag + msg)
	print(tag + msg)
	if not ok:
		all_ok = false


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	match phase:
		0:
			var p := _player()
			if p and _spawn_pos == Vector2.INF:
				_spawn_pos = p.global_position   # 记录出生首帧位置（随后滑行+引力移动）
			if phase_t > 1.0:
				print("[Stage3RotProbe] phase0 出生/结构检查")
				_check(p != null, "Player 存在")
				if p:
					_check(p._spawn_point.distance_to(Vector2(600, 0)) < 2.0, "玩家出生点最外圈 (600,0)，spawn_point=" + str(p._spawn_point))
					_check(p.rot_state == p.ROT_SYNCED, "出生即同步 rot_state=ROT_SYNCED（实际 %d）" % p.rot_state)
					_check(p.rot_feet_to_core, "rot_feet_to_core=true（脚指向核心）")
					_check(p.core_gravity_enabled, "core_gravity_enabled=true（引力仅阶段3）")
					_check(p.velocity != Vector2.ZERO, "出生即滑行 velocity=" + str(p.velocity))
				var bh := level.get_node_or_null("BlackHole")
				_check(bh != null and absf(bh.omega - 0.3) < 0.01, "BlackHole.omega=0.3（实际 " + str(bh.omega if bh else -1) + "）")
				var track := level.get_node_or_null("OrbitTrack")
				var seg_n : int = 0
				if track:
					for i in 12:
						if track.get_node_or_null("Seg%d" % i):
							seg_n += 1
				_check(seg_n == 12, "轨道 12 段（参考线，实际 %d）" % seg_n)
				_check(track.get_node_or_null("Seg0/CollisionShape2D") == null, "轨道段已移除碰撞（纯视觉，不站立）")
				var well := level.get_node_or_null("GravityWell")
				var wcol : Node = well.get_node_or_null("CollisionShape2D") if well else null
				_check(wcol != null and not wcol.disabled, "GravityWell 碰撞始终启用")
				for i in 4:
					var st := level.get_node_or_null("StoryTrigger_%d" % i)
					_check(st != null, "StoryTrigger_%d 存在" % i)
					if st:
						_check(absf(float(st.require_eta) - ST_ETA[i]) < 0.05, "StoryTrigger_%d 要求 η=%.1f" % [i, ST_ETA[i]])
						_check(int(st.page_number) == ST_PAGE[i], "StoryTrigger_%d 解锁第 %d 页" % [i, ST_PAGE[i]])
				phase = 1; phase_t = 0.0
				print("[Stage3RotProbe] →phase1 核心引力")
		1:  # 玩家沿轨道滑行（ROT_SYNCED 无重力），核心引力把玩家拉向核心
			if phase_t > 1.5:
				var p := _player()
				var core := _core()
				var r_now : float = p.global_position.distance_to(core.global_position) if (p and core) else 9999.0
				_check(r_now < 600.0, "核心引力生效：r 从 600 减至 %.1f（被拉向核心）" % r_now)
				phase = 2; phase_t = 0.0
				print("[Stage3RotProbe] →phase2 η 不达标判定")
		2:  # η 不达标 → 不解锁（首次进入页9 区，η=1.0 不满足 0.3）
			var p := _player()
			var nb := _nb()
			if p:
				if phase_t < 0.2:
					p.player_eta = 1.0    # 不满足页9 的 η=0.3
					p.global_position = Vector2(600, 0)
					p.velocity = Vector2.ZERO
				elif phase_t > 0.6:
					_check(nb != null and not nb.are_pages_unlocked([9]), "η 不达标（η=1.0 到页9 区）不解锁第9页")
					phase = 3; phase_t = 0.0
					print("[Stage3RotProbe] →phase3 η 剧情触发")
		3, 4, 5, 6:  # 4 个触发区：调整 η 达标 → 解锁（先离开触发区再进入，确保 body_entered 触发）
			var p := _player()
			var nb := _nb()
			if p:
				if phase_t < 0.12:
					p.player_eta = ST_ETA[phase - 3]
					p.global_position = ST_POS[phase - 3] + Vector2(0, -160)   # 触发区外（远离核心，避开 GravityWell）
					p.velocity = Vector2.ZERO
				elif phase_t < 0.24:
					p.global_position = ST_POS[phase - 3]   # 进入触发区（body_entered 立即触发）
				elif phase_t > 0.34:
					_check(nb != null and nb.are_pages_unlocked([ST_PAGE[phase - 3]]),
							"η=%.1f 到达该半径 → 解锁第 %d 页" % [ST_ETA[phase - 3], ST_PAGE[phase - 3]])
					phase += 1; phase_t = 0.0
		7:  # 剧情未读全时靠近 GravityWell：不激活、不禁用玩家物理（可自由操作/逃离）
			var p := _player()
			var nb := _nb()
			if p:
				if phase_t < 0.2:
					p.global_position = Vector2(0, 100)   # r=100 < 120（GravityWell 内）
					p.velocity = Vector2.ZERO
				elif phase_t > 0.5:
					var well := level.get_node_or_null("GravityWell")
					_check(p.is_physics_processing(), "剧情未读全时进入 GravityWell 不禁用玩家物理")
					_check(well != null and not well._active, "剧情未读全时 GravityWell 未激活（_active=false）")
					# 模拟玩家按 F 阅读页9~12（真实阅读流程：翻开→关闭；每帧 _update_unlock 会刷新 glowing）
					if nb:
						for pn in [9, 10, 11, 12]:
							nb.glowing = nb._has_unread()   # 模拟 _update_unlock 每帧刷新发光状态
							var ev := InputEventKey.new()
							ev.physical_keycode = KEY_F
							ev.pressed = true
							nb._unhandled_input(ev)   # 翻开（定位到第一个未读已解锁页）
							nb._unhandled_input(ev)   # 关闭（标记已读 + 持久化）
						_check(nb.are_pages_read([9, 10, 11, 12]), "按 F 阅读后 页9~12 已读标记生效")
						_check(IllusionManager.notebook_read_mask != 0, "已读标记已持久化（notebook_read_mask=%d）" % IllusionManager.notebook_read_mask)
					p.global_position = Vector2(0, 220)   # 移出 GravityWell（r=220 > 120）
					p.velocity = Vector2.ZERO
					phase = 8; phase_t = 0.0
		8:  # 读全后，玩家被核心引力拉入 GravityWell（真实滑行，带切向速度）→ 触发结局流程
			var p := _player()
			if p:
				if phase_t < 0.2:
					# 模拟玩家从轨道滑入：位置 r=220，速度含切向（滑行）与向心（被引力加速）分量
					p.global_position = Vector2(0, 220)
					p.velocity = Vector2(150.0, -180.0)
				else:
					# 每秒打印玩家 r / GravityWell 状态（诊断）
					var tick : int = int(phase_t * 2.0)
					if tick != _last_dbg:
						_last_dbg = tick
						var well := level.get_node_or_null("GravityWell")
						var core := _core()
						var r_now : float = p.global_position.distance_to(core.global_position) if core else 9999.0
						lines.append("[dbg] t=%.1f r=%.1f v=%s _active=%s _core_valid=%s _fade_t=%.2f" % [phase_t, r_now, str(p.velocity), str(well._active) if well else "?", is_instance_valid(well._core) if well else false, well._fade_t if well else -9])
					if phase_t > 1.5:
						var well := level.get_node_or_null("GravityWell")
						_check(not p.is_physics_processing(), "读全后玩家滑入 GravityWell → 玩家物理被禁用（触发吸附）")
						_check(well != null and well._fade_t >= 0.0, "已进入结局黑屏渐入（_fade_t≥0）")
						phase = 9; phase_t = 0.0
		9:
			if phase_t > 3.5:   # 含 2s 黑屏渐入 + 结局演出启动
				var p := _player()
				var core := _core()
				var r_now : float = p.global_position.distance_to(core.global_position) if (p and core) else 9999.0
				var ending := get_tree().get_first_node_in_group("Ending")
				var p_end : bool = bool(p._ending_triggered) if p else false
				lines.append("[info] 结局时刻：r=%.1f ending._active=%s player._ending_triggered=%s" % [r_now, ending.get("_active") if ending else -1, p_end])
				var well := level.get_node_or_null("GravityWell")
				var absorbed : bool = well != null and well._active and r_now < 120.0
				_check(absorbed or (ending != null and ending.get("_active") == true), "玩家被吸入核心区域（r=%.1f）或结局已触发" % r_now)
				_check(ending != null and ending.get("_active") == true, "EndingSequence 已触发（_active=true）")
				_print_result()
				get_tree().quit()


func _print_result() -> void:
	lines.append("========== [Stage3RotProbe] ==========")
	lines.append("总评：" + ("全部 PASS ✓" if all_ok else "存在 FAIL ✗"))
	for line in lines:
		print(line)
	var f := FileAccess.open("user://stage3_rot_probe_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
