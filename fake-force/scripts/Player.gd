extends CharacterBody2D
## 玩家：核心移动逻辑（速度合成）
##
## 速度合成公式（策划案 v2.0 §5.2，物理层永不因洞察模式分支）：
##   velocity += (input_dir * speed / eta + fake_force + damping_force + gravity) * delta
##
## 说明：
## - eta / damping 由所在 IllusionZone 经 IllusionManager 提供，可被马赫尘埃调整
## - 附加 max_speed / max_fall_speed 上限：阻尼=0 的"无阻力"环境下速度依然可控
## - 洞察模式只切换 Engine.time_scale 与视觉层（箭头/星空定格），不修改物理计算

@export_group("移动参数")
@export var speed : float = 800.0          # 输入推力（单位/秒²）
@export var gravity : float = 500.0        # 基础重力（非幻觉参数）
@export var max_speed : float = 500.0      # 横向 / 上升速度上限
@export var max_fall_speed : float = 900.0 # 最大下落速度

@export_group("洞察模式")
@export var insight_time_scale : float = 0.2
@export var energy_max : float = 100.0
@export var energy_drain : float = 100.0   # 每秒消耗（1 秒耗尽）
@export var energy_recovery : float = 33.3 # 每秒恢复（3 秒满格）

var insight_energy : float = 100.0
var is_insight : bool = false

var _start_position : Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("IllusionGroup")
	add_to_group("Player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	max_slides = 8
	insight_energy = energy_max
	_start_position = global_position


func _physics_process(delta: float) -> void:
	# —— 物理层：不因洞察模式做任何分支 ——
	var input_dir : Vector2 = Input.get_vector("left", "right", "up", "down")
	var eta_now : float = IllusionManager.get_current_eta()
	var fake_force : Vector2 = IllusionManager.get_current_fake_vector()
	var damping_force : Vector2 = -IllusionManager.get_current_damping() * velocity
	var gravity_vec : Vector2 = Vector2(0.0, gravity)
	velocity += (input_dir * speed / eta_now + fake_force + damping_force + gravity_vec) * delta
	# 速度上限（阻尼=0 的无阻力环境下依然可控）
	velocity.x = clampf(velocity.x, -max_speed, max_speed)
	velocity.y = clampf(velocity.y, -max_speed, max_fall_speed)
	move_and_slide()


func _process(delta: float) -> void:
	_update_insight(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# 沙盒便捷：按 R 复位到出生点
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:
		global_position = _start_position
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
		var len_px : float = clampf(fake_vec.length() * 10.0, 24.0, 120.0)
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

