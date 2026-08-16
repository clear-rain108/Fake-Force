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

@export_group("旋转参考系")
@export var rotating_mode : bool = false   # 关卡启用旋转参考系（3-1/3-2）
@export var start_in_rot : bool = false    # 开局即已在旋转参考系（已同步）
@export var radial_accel : float = 60.0    # W/S 径向推力（向心/离心）
@export var tang_accel : float = 60.0      # A/D 切向推力
@export var sync_radius : float = 30.0     # 同步判定阈值（相对速度）
@export var safe_ring_radius : float = 0.0 # 安全环半径（0=不启用）

enum { ROT_NONE, ROT_SWITCHING, ROT_SYNCED }
var core_ref : Node2D = null
var rot_state : int = ROT_NONE             # 0=横向 1=切换中 2=已同步
var rot_sync_lock : float = 0.0            # 同步后拒绝输入计时
var _switching : bool = false              # 切换洞察中（无时间限制）
var _last_insight_in_rot : bool = false
var _last_in_rot_range : bool = false      # 上一帧是否处于旋转核心影响范围（进入提示前沿检测）
var rot_switch_count : int = 0              # 累计完成旋转参考系同步次数（记事本第4页判定）
var _prev_insight : bool = false           # 上一帧洞察状态（切换扫频音前沿检测）

# 旋转参考系视觉：脚指向核心 / 视野 0.8 / 摄像机锁定核心（脱离回正）
@onready var _rot_camera : Camera2D = $Camera2D
var _rot_vis_rot : float = 0.0    # 玩家自身旋转（平滑）
var _rot_vis_cam : float = 0.0    # 摄像机旋转（平滑，使核心固定屏幕上方）
var _rot_vis_zoom : float = 1.0   # 摄像机缩放（旋转系=0.8）
var _dbg_input : Vector2 = Vector2.ZERO    # 洞察：玩家输入加速度（A/D切向+W/S径向）
var _dbg_inertia : Vector2 = Vector2.ZERO  # 洞察：惯性力（离心+科里奥利）
var _dbg_target : Vector2 = Vector2.ZERO   # 切换洞察：目标向心力（=ω²r 向心）

# 旋转参考系：常规灰色平台隐身（旋转系内平台渐变隐身，脱出后现身）
var _platform_polys : Array = []           # 场景中常规平台（StaticBody2D/Poly）的 Polygon2D
var _platform_alpha : float = 1.0          # 当前平台透明度（1=可见，0=隐身）
var _platform_target : float = 1.0         # 目标透明度（旋转系=0，横向=1）
const PLATFORM_FADE_SPEED : float = 0.8    # 渐变速率（alpha/秒）

@export_group("坠落判定")
@export var kill_y : float = 1000.0        # 低于此高度视为坠落
@export var max_falls : int = 3            # 超过3次坠落判定失败

@export_group("尘埃系统")
@export var eta_default : float = 1.0      # 初始惯性系数
@export var dust_eta_step : float = 0.25   # 消耗1份尘埃的 η 变化量

var player_eta : float = 1.0
var dust_count : int = 0
var dust_collected : int = 0   # 累计收集数（不含消耗，供记事本解锁判定）

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


## 由关卡根节点调用：绑定旋转核心并初始化（支持"开局即同步"）
func setup_rotating(core: Node2D) -> void:
	core_ref = core
	if start_in_rot:
		rot_state = ROT_SYNCED
		# 开局即已同步：位置随盘，速度=圆盘速度（角速度 ω + 向心力维持）
		var R : Vector2 = global_position - core_ref.global_position
		velocity = Vector2(-core_ref.omega * R.y, core_ref.omega * R.x)
		_set_platform_visibility(true)  # 开局即在旋转系：平台隐身


func _ready() -> void:
	add_to_group("IllusionGroup")
	add_to_group("Player")
	max_slides = 8
	insight_energy = energy_max
	_spawn_point = global_position
	player_eta = eta_default
	_collect_platforms()


func _physics_process(delta: float) -> void:
	if failed:
		velocity = Vector2.ZERO
		return
	# 旋转参考系：切换中 / 已同步时用旋转物理
	if rotating_mode and is_instance_valid(core_ref) and rot_state != ROT_NONE:
		_rotating_physics(delta)
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


## 旋转参考系物理：玩家以旋转核心为静止参考系
## - 圆盘速度 disk_v = (-ω·R.y, ω·R.x)（随盘转）
## - 相对速度 v_rel = velocity − disk_v
## - 惯性力（虚假力，幻觉场）：离心 ω²·R + 科里奥利 (2ω·v_rel.y, −2ω·v_rel.x)
## - 输入：W 向心（靠近核心，屏幕上方）/ S 离心（远离核心，屏幕下方）；A 逆时针 / D 顺时针（绕核心）
func _rotating_physics(delta: float) -> void:
	var core_pos : Vector2 = core_ref.global_position
	var R : Vector2 = global_position - core_pos
	var r : float = maxf(R.length(), 1.0)
	var omega : float = core_ref.omega
	var disk_v : Vector2 = Vector2(-omega * R.y, omega * R.x)  # 圆盘切向速度
	var v_rel : Vector2 = velocity - disk_v
	# 玩家输入（切向/径向，相对核心）
	var input := Input.get_vector("left", "right", "up", "down")
	var r_hat : Vector2 = R / r
	var t_hat : Vector2 = r_hat.orthogonal()
	var a_input : Vector2 = (r_hat * input.y * radial_accel + t_hat * input.x * tang_accel) / player_eta  # η 影响旋转输入推力（尘埃调重玩法）
	# 旋转虚假力（幻觉场）：离心 + 科里奥利
	var a_cent : Vector2 = omega * omega * R
	var a_cor : Vector2 = Vector2(2.0 * omega * v_rel.y, -2.0 * omega * v_rel.x)
	IllusionManager.set_rot_inertia(a_cent + a_cor)
	# 绝对加速度：
	# - 切换中：无向心力 → 输入直接作用（直线/惯性，旋转参考系中表现为"被甩"）
	# - 已同步：向心加速度 -ω²R（圆盘提供）维持圆周运动 → 无输入也随盘转；输入叠加
	var a_abs : Vector2
	if rot_state == ROT_SWITCHING:
		a_abs = a_input
	else:  # ROT_SYNCED
		a_abs = a_input - omega * omega * R
		# 安全环：额外恢复力（稳定在安全环半径）
		if safe_ring_radius > 0.0:
			a_abs += -r_hat * (r - safe_ring_radius) * 3.0
	# 同步锁定：拒绝输入 1s（只保持向心圆周运动）
	if rot_sync_lock > 0.0:
		a_abs = -omega * omega * R if rot_state == ROT_SYNCED else Vector2.ZERO
	velocity += a_abs * delta
	global_position += velocity * delta
	# 缓存力（洞察显示：玩家输入 + 惯性力 + 目标向心力）
	_dbg_input = a_input
	_dbg_inertia = a_cent + a_cor
	_dbg_target = -r_hat * (omega * omega * r)
	# 同步锁定计时
	if rot_sync_lock > 0.0:
		rot_sync_lock -= delta
	# 同步检测（切换中）：相对速度≈0 → 同步成功
	if rot_state == ROT_SWITCHING and v_rel.length() < sync_radius:
		_on_synced()
	# 脱离圆盘
	if r > core_ref.influence_radius:
		_exit_rotating()


func _process(delta: float) -> void:
	IllusionManager.is_insight_mode = is_insight  # 同步洞察状态（背景星空定格）
	if is_insight != _prev_insight:
		_prev_insight = is_insight
		AudioManager.transition_insight_mode(is_insight)  # 洞察进入/退出扫频音
	_update_insight(delta)
	_update_rot_visual(delta)  # 旋转参考系视觉（脚指向核心/视野0.8/摄像机锁定）
	_update_platform_fade(delta)
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
	_reset_rot_state()


func add_dust(n: int) -> void:
	dust_count += n
	dust_collected += n


func _consume_dust(delta_eta: float) -> void:
	if dust_count <= 0:
		return
	dust_count -= 1
	player_eta = clampf(player_eta + delta_eta, 0.3, 2.5)


## 危险入口（尖刺/旋转障碍等调用）：解密=即时重生+系统提示；剧情=坠落计数
func on_hazard() -> void:
	if IllusionManager.game_mode == "puzzle":
		_instant_respawn()
	else:
		_on_fallen()


func _instant_respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_reset_rot_state()
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：发现子操作系统异常，已自动恢复初始状态。（报告已收录）")


func _on_fallen() -> void:
	if IllusionManager.game_mode == "puzzle":
		_instant_respawn()
		return
	# 剧情模式：坠落计数（>max_falls 失败）
	fall_count += 1
	if fall_count > max_falls:
		failed = true
		velocity = Vector2.ZERO
	else:
		global_position = _spawn_point
		velocity = Vector2.ZERO
		_reset_rot_state()


func _update_insight(delta: float) -> void:
	# 参考系切换判定：本次按下 Shift 与上次按下时处于不同参考系影响范围 → 触发切换
	var in_rot_now : bool = rotating_mode and is_instance_valid(core_ref) \
		and (global_position - core_ref.global_position).length() < core_ref.influence_radius
	# 由加速度参考系首次进入旋转参考系影响范围：提示"建议切换参考系"（仅横向状态下进入时）
	if rotating_mode and in_rot_now and not _last_in_rot_range and rot_state == ROT_NONE:
		var hud := get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_system_message"):
			hud.show_system_message("【系统】：检测到参考系出现较大偏差，建议切换参考系")
	_last_in_rot_range = in_rot_now
	if Input.is_action_just_pressed("insight"):
		if rotating_mode and in_rot_now and not _last_insight_in_rot and rot_state == ROT_NONE:
			_switching = true
			rot_state = ROT_SWITCHING
			is_insight = true
			Engine.time_scale = insight_time_scale
			_set_platform_visibility(true)  # 进入旋转参考系：平台开始隐身
		# 仅在按下洞察时记录"本次所在参考系"（供下次按下比对）。
		# 原实现每帧刷新，导致进入圆盘后 last 恒为 true、永远无法触发切换。
		_last_insight_in_rot = in_rot_now

	# 切换洞察：无时间限制，直到同步完成
	if _switching:
		is_insight = true
		Engine.time_scale = insight_time_scale
		return

	# 普通洞察：能量限制
	var want_insight : bool = Input.is_action_pressed("insight") and insight_energy > 0.0
	if want_insight and not is_insight:
		is_insight = true
		Engine.time_scale = insight_time_scale
	elif not want_insight and is_insight:
		_exit_insight()

	if is_insight:
		var real_delta : float = delta / maxf(Engine.time_scale, 0.001)
		insight_energy = maxf(insight_energy - energy_drain * real_delta, 0.0)
		if insight_energy <= 0.0:
			_exit_insight()
	else:
		insight_energy = minf(insight_energy + energy_recovery * delta, energy_max)


func _exit_insight() -> void:
	is_insight = false
	Engine.time_scale = 1.0
	_switching = false


func _on_synced() -> void:
	rot_state = ROT_SYNCED
	rot_switch_count += 1
	rot_sync_lock = 1.0
	_switching = false
	_set_platform_visibility(true)  # 同步完成：平台完全隐身
	is_insight = false
	Engine.time_scale = 1.0
	# 贴盘速度（随盘转）
	if is_instance_valid(core_ref):
		var R : Vector2 = global_position - core_ref.global_position
		velocity = Vector2(-core_ref.omega * R.y, core_ref.omega * R.x)
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：达到参考系对应强度，参考系切换完成，已自动退出解析模式。")


func _exit_rotating() -> void:
	rot_state = ROT_NONE
	_switching = false
	is_insight = false
	Engine.time_scale = 1.0
	_last_insight_in_rot = false   # 脱离后重新进入圆盘可再次触发切换
	_set_platform_visibility(false)  # 脱离旋转参考系：平台重新现身
	IllusionManager.reset_zone_params()  # 恢复横向参考系幻觉场
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：检测到当前参考系偏差较大，已自动恢复原参考系")


## 重置旋转参考系状态（死亡/重试/坠落重生时统一调用）：
## 重生点在旋转核心影响范围内 → 直接恢复为"已同步"（随盘转，无需重新切换）；
## 否则 → 回到横向参考系，并允许下次进入圆盘时再次切换。
func _reset_rot_state() -> void:
	if rotating_mode and is_instance_valid(core_ref):
		var in_rot : bool = (global_position - core_ref.global_position).length() < core_ref.influence_radius
		if in_rot:
			rot_state = ROT_SYNCED
			_switching = false
			is_insight = false
			Engine.time_scale = 1.0
			var R : Vector2 = global_position - core_ref.global_position
			velocity = Vector2(-core_ref.omega * R.y, core_ref.omega * R.x)
			_last_insight_in_rot = true
			_set_platform_visibility(true)  # 圆盘上重生：平台保持隐身
			return
	rot_state = ROT_NONE
	_switching = false
	is_insight = false
	Engine.time_scale = 1.0
	_last_insight_in_rot = false
	_set_platform_visibility(false)  # 圆盘外重生：平台现身
	IllusionManager.reset_zone_params()


## —— 旋转参考系：常规灰色平台隐身 ——
## 进入旋转参考系后，关卡中的常规灰色平台（StaticBody2D/Poly）渐变隐身，
## 脱出旋转参考系后重新显现。对所有旋转参考系关卡统一生效。

## 收集关卡中所有常规平台（StaticBody2D 下名为 "Poly" 的 Polygon2D）。
## 幻灵/绝对方块、可撞碎墙、隐藏平台等使用 _draw 绘制，不受影响。
func _collect_platforms() -> void:
	_platform_polys.clear()
	_collect_polys(get_tree().current_scene)


func _collect_polys(n: Node) -> void:
	for c in n.get_children():
		if c is StaticBody2D:
			var poly : Node = c.get_node_or_null("Poly")
			if poly is Polygon2D:
				_platform_polys.append(poly)
		_collect_polys(c)


func _update_platform_fade(delta: float) -> void:
	if _platform_polys.is_empty():
		return
	if absf(_platform_alpha - _platform_target) < 0.002:
		_platform_alpha = _platform_target
	else:
		_platform_alpha = move_toward(_platform_alpha, _platform_target, PLATFORM_FADE_SPEED * delta)
	for poly in _platform_polys:
		if is_instance_valid(poly):
			var c : Color = (poly as Polygon2D).color
			if absf(c.a - _platform_alpha) > 0.002:
				c.a = _platform_alpha
				(poly as Polygon2D).color = c


## 设置平台显隐目标：进入旋转参考系 → 隐身（target=0）；脱出 → 现身（target=1）
func _set_platform_visibility(visible_in_rot: bool) -> void:
	_platform_target = 0.0 if visible_in_rot else 1.0


## 旋转参考系视觉表现：
## - 切换至旋转系时，玩家"脚"（素材正下方）转向旋转核心方向；
## - 视野范围缩小至 0.8（camera.zoom）；
## - 摄像机随玩家绕核心公转而旋转，使核心始终固定在屏幕正上方（相对位置不变）；
## - 脱离旋转系后自动回正（rotation=0 / zoom=1），全部平滑过渡。
func _update_rot_visual(delta: float) -> void:
	var target_rot : float = 0.0
	var target_cam : float = 0.0
	var target_zoom : float = 1.0
	if rotating_mode and is_instance_valid(core_ref) and rot_state != ROT_NONE:
		var dir : Vector2 = core_ref.global_position - global_position
		if dir.length_squared() > 0.001:
			var ang : float = dir.angle()
			target_rot = ang - PI / 2.0   # 脚（默认朝 +Y）指向核心
			target_cam = ang + PI / 2.0   # 核心映射到屏幕正上方
		target_zoom = 0.8
	_rot_vis_rot = lerp_angle(_rot_vis_rot, target_rot, minf(delta * 6.0, 1.0))
	_rot_vis_cam = lerp_angle(_rot_vis_cam, target_cam, minf(delta * 6.0, 1.0))
	_rot_vis_zoom = lerpf(_rot_vis_zoom, target_zoom, minf(delta * 5.0, 1.0))
	rotation = _rot_vis_rot
	if is_instance_valid(_rot_camera):
		_rot_camera.rotation = _rot_vis_cam
		_rot_camera.zoom = Vector2(_rot_vis_zoom, _rot_vis_zoom)


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
	var inv_rot : float = -rotation   # 世界方向 → 局部坐标（玩家自身旋转时箭头不跟着转错）
	# 切换洞察（参考系切换）：目标向心力(金) + 玩家输入(蓝) + 惯性力(红)
	# 蓝=你按的方向（A逆时针/D顺时针/W向心/S离心）；红=惯性力；金=同步后需维持的向心力
	if _switching or rot_state == ROT_SWITCHING:
		if _dbg_target.length_squared() > 0.01:
			_draw_arrow(center, _dbg_target.rotated(inv_rot).normalized() * 55.0, Color(1.0, 0.84, 0.0), false, 4.0)
		if _dbg_input.length_squared() > 0.01:
			_draw_arrow(center, _dbg_input.rotated(inv_rot).normalized() * 50.0, Color(0.25, 0.6, 1.0), false, 4.0)
		if _dbg_inertia.length_squared() > 0.01:
			_draw_arrow(center, _dbg_inertia.rotated(inv_rot).normalized() * 50.0, Color(1.0, 0.3, 0.25), true, 4.0)
		return
	# 旋转参考系洞察：蓝=玩家输入、红=惯性力（离心+科里奥利）
	if rot_state != ROT_NONE:
		if _dbg_input.length_squared() > 0.01:
			_draw_arrow(center, _dbg_input.rotated(inv_rot).normalized() * 50.0, Color(0.25, 0.6, 1.0), false, 4.0)
		if _dbg_inertia.length_squared() > 0.01:
			_draw_arrow(center, _dbg_inertia.rotated(inv_rot).normalized() * 50.0, Color(1.0, 0.3, 0.25), true, 4.0)
		return
	# 横向参考系洞察：蓝=输入、红=虚假力（幻觉场）、绿=重力
	var input_dir : Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_dir.length_squared() > 0.01:
		_draw_arrow(center, input_dir.rotated(inv_rot).normalized() * 60.0, Color(0.25, 0.6, 1.0), false, 4.0)
	var fake_vec : Vector2 = IllusionManager.get_current_fake_vector()
	if fake_vec.length_squared() > 0.01:
		var len_px : float = clampf(fake_vec.length() * 2.5, 20.0, 140.0)
		_draw_arrow(center, fake_vec.rotated(inv_rot).normalized() * len_px, Color(1.0, 0.3, 0.25), true, 4.0)
	if rot_state == ROT_NONE:
		_draw_arrow(center, Vector2(0.0, 40.0).rotated(inv_rot), Color(0.3, 1.0, 0.4), false, 3.0)


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


