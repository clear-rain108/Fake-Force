extends CharacterBody2D
## 玩家：核心移动逻辑（回归策划案 v2.0 §5.2，无重力）
##
## velocity += (input_dir * speed / η + fake_force + damping_force) * delta
##
## 设计决策落实：
## - 决策1：不保留重力，所有力由幻觉区提供
## - 决策2：幻觉力 = 系统不定时向某方向加速产生的惯性力（IllusionZone 驱动）
## - 决策3：瞬时起跳——平台上轻点 W 触发一次跳跃（无持续喷气）
## - 决策4：物理层永不因洞察模式分支
## - 决策5：坠落 > 最大次数判定失败，按 R 重新挑战（可设存档点）
## - 已确认：空中微重力（跳跃/悬空时小幅下落，落地即停）

@export_group("移动参数")
@export var speed : float = 200.0          # 输入推力（单位/秒²）
@export var jump_velocity : float = 380.0  # 瞬时起跳初速（向上）
@export var jump_gravity : float = 500.0   # 空中微重力（向下，落地即停）
@export var max_speed_x : float = 300.0    # 横向速度上限
@export var jump_cap : float = 500.0       # 上升速度上限
@export var max_fall_speed : float = 600.0 # 最大下落速度

@export_group("坠落判定")
@export var kill_y : float = 1000.0        # 低于此高度视为坠落
@export var max_falls : int = 3            # 超过3次坠落判定失败

@export_group("尘埃系统")
@export var eta_default : float = 1.0      # 初始惯性系数
@export var dust_eta_step : float = 0.25   # 消耗1份尘埃的 η 变化量

var player_eta : float = 1.0
var dust_count : int = 0

@export_group("洞察模式")
@export var insight_time_scale : float = 0.2
@export var energy_max : float = 100.0
@export var energy_drain : float = 100.0   # 每秒消耗（1秒耗尽）
@export var energy_recovery : float = 33.3 # 每秒恢复（3秒满格）

var insight_energy : float = 100.0
var is_insight : bool = false

var fall_count : int = 0
var failed : bool = false

var _spawn_point : Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("IllusionGroup")
	add_to_group("Player")
	max_slides = 8
	insight_energy = energy_max
	_spawn_point = global_position
	player_eta = eta_default


func _physics_process(delta: float) -> void:
	if failed:
		velocity = Vector2.ZERO
		return

	# —— 物理层：不因洞察模式做任何分支 ——
	var input_dir : Vector2 = Input.get_vector("left", "right", "up", "down")
	var eta_now : float = player_eta
	var fake_force : Vector2 = IllusionManager.get_current_fake_vector()
	var damping_force : Vector2 = -IllusionManager.get_current_damping() * velocity

	# 瞬时起跳（决策3）：平台上轻点 W
	if Input.is_action_just_pressed("up") and is_on_floor():
		# 跳跃高度随 η：越轻（η 小）跳得越高越远，越重（η 大）跳得越低
		velocity.y = -jump_velocity / sqrt(player_eta)

	# 空中微重力（已确认）：非落地时小幅下落
	if not is_on_floor():
		velocity.y += jump_gravity * delta

	# 文档 §5.2 速度合成（无重力）
	velocity += (input_dir * speed / eta_now + fake_force + damping_force) * delta
	velocity.x = clampf(velocity.x, -max_speed_x, max_speed_x)
	velocity.y = clampf(velocity.y, -jump_cap, max_fall_speed)
	move_and_slide()

	# 坠落检测（决策5）
	if global_position.y > kill_y:
		_on_fallen()


func _process(delta: float) -> void:
	_update_insight(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			reset_level()
		KEY_Q:
			_consume_dust(dust_eta_step)   # 消耗1份尘埃：变重（η+）
		KEY_Z:
			_consume_dust(-dust_eta_step)  # 消耗1份尘埃：变轻（η-）


## 存档点（后续阶段可调用）
func set_checkpoint(pos: Vector2) -> void:
	_spawn_point = pos


func reset_level() -> void:
	fall_count = 0
	failed = false
	global_position = _spawn_point
	velocity = Vector2.ZERO


func add_dust(n: int) -> void:
	dust_count += n


func _consume_dust(delta_eta: float) -> void:
	if dust_count <= 0:
		return
	dust_count -= 1
	player_eta = clampf(player_eta + delta_eta, 0.3, 2.5)


func _on_fallen() -> void:
	fall_count += 1
	if fall_count > max_falls:
		failed = true
		velocity = Vector2.ZERO
	else:
		global_position = _spawn_point
		velocity = Vector2.ZERO


func _update_insight(delta: float) -> void:
	var want_insight : bool = Input.is_action_pressed("insight") and insight_energy > 0.0
	if want_insight and not is_insight:
		is_insight = true
		Engine.time_scale = insight_time_scale
	elif not want_insight and is_insight:
		_exit_insight()

	if is_insight:
		# 能量按真实时间消耗（避免 0.2 倍速下被无限延长）
		var real_delta : float = delta / maxf(Engine.time_scale, 0.001)
		insight_energy = maxf(insight_energy - energy_drain * real_delta, 0.0)
		if insight_energy <= 0.0:
			_exit_insight()
	else:
		insight_energy = minf(insight_energy + energy_recovery * delta, energy_max)


func _exit_insight() -> void:
	is_insight = false
	Engine.time_scale = 1.0


func _draw() -> void:
	# η 光晕反馈：仅在 η≠1 时出现（重=红 / 轻=蓝），范围较小
	var eta_r : float = clampf((player_eta - 1.0) / 0.5, -1.0, 1.0)
	if absf(eta_r) > 0.02:
		var glow_c : Color
		if eta_r > 0.0:
			glow_c = Color(1.0, 0.3, 0.25, 0.28 * eta_r)
		else:
			glow_c = Color(0.25, 0.6, 1.0, -0.28 * eta_r)
		draw_circle(Vector2.ZERO, 20.0, glow_c)

	if not is_insight:
		return
	var center : Vector2 = Vector2.ZERO
	# 蓝色实线箭头：玩家意图
	var input_dir : Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_dir.length_squared() > 0.01:
		_draw_arrow(center, input_dir.normalized() * 60.0, Color(0.25, 0.6, 1.0), false, 4.0)
	# 红色虚线箭头：虚假力
	var fake_vec : Vector2 = IllusionManager.get_current_fake_vector()
	if fake_vec.length_squared() > 0.01:
		var len_px : float = clampf(fake_vec.length() * 2.5, 20.0, 140.0)
		_draw_arrow(center, fake_vec.normalized() * len_px, Color(1.0, 0.3, 0.25), true, 4.0)


func _draw_arrow(from: Vector2, vec: Vector2, color: Color, dashed: bool, width: float) -> void:
	var to : Vector2 = from + vec
	if dashed:
		var dir_n : Vector2 = vec.normalized()
		var dash_len : float = 8.0
		var gap_len : float = 5.0
		var total : float = vec.length()
		var dist : float = 0.0
		while dist < total:
			var seg_end : float = minf(dist + dash_len, total)
			draw_line(from + dir_n * dist, from + dir_n * seg_end, color, width)
			dist = seg_end + gap_len
	else:
		draw_line(from, to, color, width)
	# 箭头头部
	if vec.length() > 6.0:
		var dir_n : Vector2 = vec.normalized()
		var head_len : float = 12.0
		var head_base : Vector2 = to - dir_n * head_len
		var perp : Vector2 = dir_n.orthogonal() * head_len * 0.5
		draw_line(to, head_base + perp, color, width)
		draw_line(to, head_base - perp, color, width)


