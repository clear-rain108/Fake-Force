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
## - 决策5：坠落 > 最大次数判定失败——剧情模式触发强制休眠死亡演出（DeathSequence→回开始页），R 键仍可手动恢复最近存档点
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
@export var gravity_accel : float = 280.0  # 核心引力强度：指向核心，大小 gravity_accel×(600/r) 衰减（r=600 轨道处=280）
@export var core_gravity_enabled : bool = false  # 核心引力仅阶段3（BlackHole）启用；其他关卡保持原样
@export var sync_radius : float = 30.0     # 同步判定阈值（相对速度）
@export var safe_ring_radius : float = 0.0 # 安全环半径（0=不启用）
@export var inertia_scale : float = 0.5    # 旋转系惯性力缩放（离心+科里奥利；调小=更轻手感：G/红箭/幻灵/星空同步变弱，不影响玩家实际受力与轨道）
@export var linear_g_visual_ref : float = 1.5   # 普通参考系：幻觉强度边框满强度对应 G（1.5G 已很大）
@export var rot_g_visual_ref : float = 20.0     # 旋转参考系：幻觉强度边框满强度对应 G（十余 G 仅普通/中等，20G 才满）
@export var rot_feet_to_core : bool = false  # 真：脚(+Y)指向核心→核心恒屏显正下方、精灵头朝上、世界旋转（部分场景）；假：随盘自转角（Model B）
@export var rot_zoom_min : float = 0.35    # 旋转系滚轮缩放下限（倍率）
@export var rot_zoom_max : float = 2.5     # 旋转系滚轮缩放上限（倍率）
@export var rot_zoom_step : float = 0.1    # 滚轮每格缩放步长

enum { ROT_NONE, ROT_SWITCHING, ROT_SYNCED }
var core_ref : Node2D = null
var rot_state : int = ROT_NONE             # 0=横向 1=切换中 2=已同步
var rot_sync_lock : float = 0.0            # 同步后拒绝输入计时
var _switching : bool = false              # 切换洞察中（无时间限制）
var _last_insight_in_rot : bool = false
var _last_in_rot_range : bool = false      # 上一帧是否处于旋转核心影响范围（进入提示前沿检测）
var _ending_triggered : bool = false       # 结局演出是否已触发（防重复，r<30 靠近核心时）
var rot_switch_count : int = 0              # 累计完成旋转参考系同步次数（记事本第4页判定）
var _prev_insight : bool = false           # 上一帧洞察状态（切换扫频音前沿检测）

# 旋转参考系视觉（Model B：踩在盘上）：玩家与摄像机整体随盘旋转，转盘屏显静止、角色屏显固定
@onready var _rot_camera : Camera2D = $Camera2D
var _rot_vis_rot : float = 0.0    # 玩家自身旋转（平滑，追踪盘旋转 core_ref.rotation）
var _rot_vis_cam : float = 0.0    # 摄像机全局旋转（平滑，追踪盘旋转；局部=全局-玩家旋转）
var _rot_vis_zoom : float = 1.0   # 摄像机缩放（旋转系=0.8×滚轮倍率）
var _rot_user_zoom : float = 1.0  # 滚轮缩放倍率（仅旋转参考系内生效，脱离复位）
var _rot_cam_smooth_initial : bool = true  # 摄像机位置平滑初始值（旋转系内禁用，保证转盘屏显静止）
var _dbg_input : Vector2 = Vector2.ZERO    # 洞察：玩家输入加速度（A/D切向+W/S径向）
var _dbg_inertia : Vector2 = Vector2.ZERO  # 洞察：惯性力（离心+科里奥利）
var _dbg_system : Vector2 = Vector2.ZERO   # 洞察：系统阻力（同步态=圆盘向心力 -ω²R；横向=阻尼+空中重力）
var _dbg_net : Vector2 = Vector2.ZERO      # 洞察：合力（切换态=蓝+红）
var _dbg_target : Vector2 = Vector2.ZERO   # 切换洞察：目标向心力（=ω²r 向心）

# —— 洞察箭头：按参考系单位化长度 ——
# 玩家身位 = 32px（精灵尺寸/碰撞直径）。单位化：普通参考系 1G、旋转参考系 10G，
# 各自对应箭头长度 = 3 个玩家身位（96px）。旋转系 G 值动辄十余，用 10G 归一避免箭头过长。
const BODY_SIZE : float = 32.0
const ARROW_UNIT_BODY : float = 3.0
const ARROW_UNIT_G_LINEAR : float = 1.0   # 普通参考系：1G → 3 身位
const ARROW_UNIT_G_ROT : float = 10.0     # 旋转参考系：10G → 3 身位
const ARROW_MIN_LEN := 8.0    # 最短箭长（过小不可见）
const ARROW_MAX_LEN := 150.0  # 最长箭长（极端值防占屏）
const ARROW_GOLD_MIN := 20.0  # 金色目标箭头最小长度（始终可见作引导）
const ARROW_WIDTH : float = 2.0   # 箭头线宽（更细；箭头头部约半个玩家身位）
const SYSTEM_ARROW_SCALE : float = 0.6  # 系统阻力绿箭：空中重力部分的显示缩放（阻尼物理已由 get_current_damping×0.6）

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
@export var insight_duration_base : float = 5.0   # 洞察最长持续秒数（每收集1枚马赫尘埃 +1s）
@export var energy_recovery : float = 100.0       # 每秒恢复（1秒满格）

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


## 切换"脚指向核心"视角模式（Stage3 轨道入口/出口触发器调用）：
## 跳上轨道（OrbitEntryTrigger）→ true（脚指向核心）；跳下轨道（OrbitExitTrigger）→ false（立即切回横板视角）。
## 仅切换视角姿态，不改变物理参考系。
func set_feet_to_core(enable: bool) -> void:
	rot_feet_to_core = enable
	if not enable:
		# 立即复位摄像机旋转（切回横板视角）
		_rot_vis_rot = 0.0
		_rot_vis_cam = 0.0
		if is_instance_valid(_rot_camera):
			_rot_camera.rotation = 0.0
			_rot_camera.zoom = Vector2(1.0, 1.0)


func _ready() -> void:
	add_to_group("IllusionGroup")
	add_to_group("Player")
	max_slides = 8
	insight_energy = energy_max
	_spawn_point = global_position
	player_eta = eta_default
	if is_instance_valid(_rot_camera):
		_rot_cam_smooth_initial = _rot_camera.position_smoothing_enabled
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
	# 旋转虚假力（幻觉场）：离心 + 科里奥利，乘以惯性力缩放（inertia_scale）调手感
	# （仅写入幻觉显示系统：G 值/洞察红箭/幻灵/星空；不影响玩家实际受力 a_abs 与轨道）
	var a_cent : Vector2 = omega * omega * R
	var a_cor : Vector2 = Vector2(2.0 * omega * v_rel.y, -2.0 * omega * v_rel.x)
	var a_inertia : Vector2 = (a_cent + a_cor) * inertia_scale
	IllusionManager.set_rot_inertia(a_inertia)
	# 核心引力：指向核心（-r_hat），大小 gravity_accel×(600/r) 随距离衰减。
	# 仅阶段3（core_gravity_enabled）且旋转参考系内生效；r≥influence_radius 或 r≤120（核心边缘/GravityWell 区）时无引力，
	# 保证玩家靠近黑洞后仍可自由操作/逃离，不会被巨大引力压住。
	var gravity_force : Vector2 = Vector2.ZERO
	if core_gravity_enabled and r > 120.0 and r < float(core_ref.influence_radius):
		gravity_force = -r_hat * gravity_accel * (600.0 / r)
	# 绝对加速度：
	# - 切换中：无向心力 → 输入+引力直接作用（直线/惯性，旋转参考系中表现为"被甩"）
	# - 已同步：向心加速度 -ω²R（圆盘提供）维持圆周运动 → 无输入也随盘转；输入+引力叠加
	var a_abs : Vector2
	if rot_state == ROT_SWITCHING:
		a_abs = a_input + gravity_force
	else:  # ROT_SYNCED
		a_abs = a_input - omega * omega * R + gravity_force
		# 安全环：额外恢复力（稳定在安全环半径）
		if safe_ring_radius > 0.0:
			a_abs += -r_hat * (r - safe_ring_radius) * 3.0
	# 同步锁定：拒绝输入 1s（只保持向心圆周运动）
	if rot_sync_lock > 0.0:
		a_abs = -omega * omega * R if rot_state == ROT_SYNCED else Vector2.ZERO
	velocity += a_abs * delta
	global_position += velocity * delta
	# 缓存力（洞察显示：输入 + 惯性力 + 系统阻力 + 合力 + 目标向心力）
	_dbg_input = a_input
	_dbg_inertia = a_inertia
	_dbg_target = -r_hat * (omega * omega * r)
	# 系统阻力：同步态 = 圆盘提供的向心力 -ω²R（+安全环弹簧）；切换态无向心力 → ZERO
	var a_system : Vector2 = Vector2.ZERO
	if rot_state == ROT_SYNCED:
		a_system = -omega * omega * R
		if safe_ring_radius > 0.0:
			a_system += -r_hat * (r - safe_ring_radius) * 3.0
	_dbg_system = a_system
	# 合力（旋转系内观测）：切换态 = 蓝 + 红（无向心力抵消）
	_dbg_net = a_input + a_inertia
	# 同步锁定计时
	if rot_sync_lock > 0.0:
		rot_sync_lock -= delta
	# 同步检测（切换中）：相对速度≈0 → 同步成功
	if rot_state == ROT_SWITCHING and v_rel.length() < sync_radius:
		_on_synced()
	# 脱离圆盘
	if r > core_ref.influence_radius:
		_exit_rotating()
	# 结局触发：靠近核心（r<30，旋转参考系内）且剧情（第9~12页）全部已读 → 启动结局演出并禁用玩家输入。
	# 未读全时即使靠近核心也不触发，避免玩家被永久禁用物理。
	if rot_state != ROT_NONE and r < 30.0 and not _ending_triggered:
		var nb := get_tree().get_first_node_in_group("Notebook")
		var story_done : bool = nb != null and nb.has_method("are_pages_read") \
				and nb.are_pages_read([9, 10, 11, 12])
		if story_done:
			_ending_triggered = true
			set_physics_process(false)   # 禁用玩家输入/物理（结局演出接管）
			var ending := get_tree().get_first_node_in_group("Ending")
			if ending and ending.has_method("start_ending"):
				ending.start_ending()


func _process(delta: float) -> void:
	IllusionManager.is_insight_mode = is_insight  # 同步洞察状态（背景星空定格）
	# 幻觉强度边框参考由参考系决定：普通=1.5G 已很大；旋转=rot_g_visual_ref 十余G 仅普通
	IllusionManager.vignette_g_ref = rot_g_visual_ref if rot_state != ROT_NONE else linear_g_visual_ref
	if is_insight != _prev_insight:
		_prev_insight = is_insight
		AudioManager.transition_insight_mode(is_insight)  # 洞察进入/退出扫频音
	_update_insight(delta)
	_update_rot_visual(delta)  # 旋转参考系视觉（Model B：随盘旋转/转盘屏显静止/滚轮缩放）
	_update_platform_fade(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# 旋转参考系：鼠标滚轮缩放视野（0.8 基准 × 用户倍率）
	if event is InputEventMouseButton and event.pressed:
		if rotating_mode and is_instance_valid(core_ref) and rot_state != ROT_NONE:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_rot_user_zoom = clampf(_rot_user_zoom + rot_zoom_step, rot_zoom_min, rot_zoom_max)
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_rot_user_zoom = clampf(_rot_user_zoom - rot_zoom_step, rot_zoom_min, rot_zoom_max)
				return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			if IllusionManager.game_mode == "story":
				reset_level()     # 剧情模式：恢复最近存档点
			else:
				restart_level()   # 解密模式：重开当前关卡
		KEY_Q:
			_consume_dust(dust_eta_step)   # 消耗1份尘埃：变重（η+）
		KEY_Z:
			_consume_dust(-dust_eta_step)  # 消耗1份尘埃：变轻（η-）


## 存档点（后续阶段可调用）；到达存档点重置死亡计数（尖刺/坠落统一计数后避免整关累计过快）
func set_checkpoint(pos: Vector2) -> void:
	_spawn_point = pos
	fall_count = 0


func reset_level() -> void:
	fall_count = 0
	failed = false
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_reset_rot_state()


## 重开当前关卡：完整重置（重载场景，回到关卡起点，清空尘埃/η/能量等）
func restart_level() -> void:
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func add_dust(n: int) -> void:
	dust_count += n
	dust_collected += n


func _consume_dust(delta_eta: float) -> void:
	if dust_count <= 0:
		return
	dust_count -= 1
	player_eta = clampf(player_eta + delta_eta, 0.3, 2.5)


## 危险入口（尖刺/旋转障碍等调用）：
## 解密模式保持即时重生；剧情模式计入死亡计数（>max_falls 触发强制休眠死亡演出，与坠落一致）
func on_hazard() -> void:
	if IllusionManager.game_mode == "puzzle":
		_instant_respawn()
		return
	fall_count += 1
	if fall_count > max_falls:
		_fail_death()
	else:
		_instant_respawn()


func _instant_respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	_reset_rot_state()
	var hud := get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_system_message"):
		hud.show_system_message("【系统】：发现子操作系统异常，已自动恢复初始状态。（报告已收录）")


func _on_fallen() -> void:
	if failed:
		return   # 已触发死亡演出：一次性保护（避免每物理帧重触发、黑屏无法淡入）
	if IllusionManager.game_mode == "puzzle":
		_instant_respawn()
		return
	# 剧情模式：坠落计数（>max_falls 失败 → 强制休眠剧情演出，不再提示按 R 重开）
	fall_count += 1
	if fall_count > max_falls:
		_fail_death()
	else:
		global_position = _spawn_point
		velocity = Vector2.ZERO
		_reset_rot_state()


## 触发强制休眠死亡演出（剧情模式死亡超限；一次性保护由 failed 保证）
func _fail_death() -> void:
	failed = true
	velocity = Vector2.ZERO
	Engine.time_scale = 1.0
	var layer := CanvasLayer.new()
	layer.layer = 60
	var seq : Node2D = load("res://scripts/DeathSequence.gd").new()
	layer.add_child(seq)
	get_tree().current_scene.add_child(layer)


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
		# 普通洞察最长持续 = 5s 基础 + 本关累计收集的马赫尘埃数 ×1s → 动态消耗速率
		var max_duration : float = insight_duration_base + float(dust_collected)
		var drain : float = energy_max / maxf(max_duration, 0.1)
		insight_energy = maxf(insight_energy - drain * real_delta, 0.0)
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
	_rot_user_zoom = 1.0   # 滚轮缩放复位（下次进入旋转系从默认视野开始）
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
	_rot_user_zoom = 1.0   # 滚轮缩放复位
	_last_insight_in_rot = false
	_set_platform_visibility(false)  # 圆盘外重生：平台现身
	IllusionManager.reset_zone_params()


## —— 旋转参考系：常规灰色平台隐身 ——
## 进入旋转参考系后，关卡中的常规灰色平台（StaticBody2D/Poly）渐变隐身，
## 脱出旋转参考系后重新显现。对所有旋转参考系关卡统一生效。

## 收集关卡中所有常规平台（StaticBody2D 下的 Polygon2D 子节点）。
## 兼容场景定义（子节点名 "Poly"）与 StageBuilder 程序生成（Polygon2D 默认名）两种平台。
## 幻灵/绝对方块、可撞碎墙、隐藏平台等使用 _draw 绘制，不受影响。
func _collect_platforms() -> void:
	_platform_polys.clear()
	_collect_polys(get_tree().current_scene)


func _collect_polys(n: Node) -> void:
	for c in n.get_children():
		if c is StaticBody2D:
			for child in c.get_children():
				# 标记 no_rot_fade 的平台（如 Stage3 环形轨道）不随旋转参考系隐身
				if child is Polygon2D and not child.get_meta("no_rot_fade", false):
					_platform_polys.append(child)
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


## 旋转参考系视觉表现（Model B：踩在盘上）：
## - 玩家与摄像机整体追踪圆盘旋转（core_ref.rotation）：
##   同步后转盘屏显静止、角色屏显固定（不再因公转而自转）；
## - 视野 = 0.8 基准 × 滚轮用户倍率（rot_zoom_min~rot_zoom_max）；
## - 旋转系内禁用摄像机位置平滑（保证转盘/核心屏显精确静止）；
## - 脱离旋转系后自动回正（rotation=0 / zoom=1），全部平滑过渡。
func _update_rot_visual(delta: float) -> void:
	var target_rot : float = 0.0
	var target_cam : float = 0.0
	var target_zoom : float = 1.0
	if rotating_mode and is_instance_valid(core_ref) and rot_state != ROT_NONE:
		if rot_feet_to_core:
			# 脚（局部 +Y）指向核心：target = 玩家→核心方向 − π/2。
			# 摄像机全局取同一值（局部≈0），使精灵屏显头朝上、核心恒屏显正下方、世界旋转。
			# 注意：绝不在摄像机局部叠加 ang+π/2（会沿父链相加成 2·ang，重新引入 2 倍角速度 bug）。
			var dir : Vector2 = core_ref.global_position - global_position
			if dir.length_squared() > 0.001:
				var ang : float = dir.angle()
				target_rot = ang - PI / 2.0
				target_cam = ang - PI / 2.0
			else:
				# 玩家恰在核心中心（退化）：回退为随盘自转角
				target_rot = core_ref.rotation
				target_cam = core_ref.rotation
		else:
			target_rot = core_ref.rotation   # 角色随盘旋转（盘内屏显静止）
			target_cam = core_ref.rotation   # 摄像机全局旋转 = 盘旋转（核心/转盘屏显静止）
		target_zoom = 0.8 * _rot_user_zoom
	# 旋转跟踪速率：脚指向核心模式需更紧的朝向跟踪（指数平滑恒滞后 ≈ω/rate，
	# rate 6 → ~7.6°（核心偏离脚下 ~28px@R200）；rate 20 → ~2°），
	# 同时保持平滑过渡；非脚指核心（Model B）沿用原 rate 6。
	var track_rate : float = 20.0 if rot_feet_to_core else 6.0
	_rot_vis_rot = lerp_angle(_rot_vis_rot, target_rot, minf(delta * track_rate, 1.0))
	_rot_vis_cam = lerp_angle(_rot_vis_cam, target_cam, minf(delta * track_rate, 1.0))
	_rot_vis_zoom = lerpf(_rot_vis_zoom, target_zoom, minf(delta * 5.0, 1.0))
	rotation = _rot_vis_rot
	if is_instance_valid(_rot_camera):
		# 摄像机是玩家子节点，2D 旋转沿父链相加：局部 = 目标全局 − 玩家自身旋转
		_rot_camera.rotation = _rot_vis_cam - _rot_vis_rot
		_rot_camera.zoom = Vector2(_rot_vis_zoom, _rot_vis_zoom)
		var in_rot : bool = rotating_mode and is_instance_valid(core_ref) and rot_state != ROT_NONE
		_rot_camera.position_smoothing_enabled = false if in_rot else _rot_cam_smooth_initial


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
	# 切换洞察（参考系切换）：目标向心力(金) + 玩家输入(蓝) + 惯性力(红) + 合力(紫)
	# 蓝=你按的方向（A顺时针/D逆时针/W向心/S离心）；红=惯性力；金=同步后需维持的向心力；紫=合力（蓝+红）
	if _switching or rot_state == ROT_SWITCHING:
		_draw_arrow(center, _scaled_arrow(_dbg_target, ARROW_GOLD_MIN).rotated(inv_rot), Color(1.0, 0.84, 0.0), false, ARROW_WIDTH)
		_draw_arrow(center, _scaled_arrow(_dbg_input).rotated(inv_rot), Color(0.25, 0.6, 1.0), false, ARROW_WIDTH)
		_draw_arrow(center, _scaled_arrow(_dbg_inertia).rotated(inv_rot), Color(1.0, 0.3, 0.25), true, ARROW_WIDTH)
		_draw_arrow(center, _scaled_arrow(_dbg_net).rotated(inv_rot), Color(0.7, 0.35, 0.95), false, ARROW_WIDTH)
		return
	# 旋转参考系洞察：蓝=输入、红=惯性力（离心+科里奥利）、绿=系统阻力（圆盘向心力 -ω²R）
	if rot_state != ROT_NONE:
		_draw_arrow(center, _scaled_arrow(_dbg_input).rotated(inv_rot), Color(0.25, 0.6, 1.0), false, ARROW_WIDTH)
		_draw_arrow(center, _scaled_arrow(_dbg_inertia).rotated(inv_rot), Color(1.0, 0.3, 0.25), true, ARROW_WIDTH)
		_draw_arrow(center, _scaled_arrow(_dbg_system).rotated(inv_rot), Color(0.3, 1.0, 0.4), false, ARROW_WIDTH)
		return
	# 横向参考系洞察：蓝=输入、红=虚假力、绿=系统阻力（阻尼+空中重力）
	# 系统阻力绿箭：阻尼物理已 ×0.6（get_current_damping）；空中重力不动物理、显示层 ×SYSTEM_ARROW_SCALE
	var input_dir : Vector2 = Input.get_vector("left", "right", "up", "down")
	var input_force : Vector2 = input_dir * speed / maxf(player_eta, 0.001)
	if input_force.length_squared() > 0.001:
		_draw_arrow(center, _scaled_arrow(input_force).rotated(inv_rot), Color(0.25, 0.6, 1.0), false, ARROW_WIDTH)
	var fake_vec : Vector2 = IllusionManager.get_current_fake_vector()
	if fake_vec.length_squared() > 0.001:
		_draw_arrow(center, _scaled_arrow(fake_vec).rotated(inv_rot), Color(1.0, 0.3, 0.25), true, ARROW_WIDTH)
	var system_vec : Vector2 = -IllusionManager.get_current_damping() * velocity
	if not is_on_floor():
		system_vec += Vector2(0.0, jump_gravity * SYSTEM_ARROW_SCALE)
	if system_vec.length_squared() > 0.001:
		_draw_arrow(center, _scaled_arrow(system_vec).rotated(inv_rot), Color(0.3, 1.0, 0.4), false, ARROW_WIDTH)


## 当前参考系的箭头单位化比例（px / (px·s⁻²)）：
## 普通参考系 1G、旋转参考系 10G → 箭头长 = 3 玩家身位（各自参考系内仍同比例，合力=运动可验证）
func _arrow_scale() -> float:
	var unit_g : float = ARROW_UNIT_G_ROT if rot_state != ROT_NONE else ARROW_UNIT_G_LINEAR
	return ARROW_UNIT_BODY * BODY_SIZE / (unit_g * IllusionManager.g_to_accel)


## 单位化箭头：长度 = |v| × _arrow_scale()，截断到 [min_len, ARROW_MAX_LEN]
func _scaled_arrow(v: Vector2, min_len: float = ARROW_MIN_LEN) -> Vector2:
	var L : float = v.length()
	if L < 0.001:
		return Vector2.ZERO
	var scaled : float = clampf(L * _arrow_scale(), min_len, ARROW_MAX_LEN)
	return v * (scaled / L)


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
	# 箭头头部（≈半个玩家身位大小）
	if vec.length() > 6.0:
		var dir_n : Vector2 = vec.normalized()
		var head_len : float = 8.0
		var head_base : Vector2 = to - dir_n * head_len
		var perp : Vector2 = dir_n.orthogonal() * head_len * 0.5
		draw_line(to, head_base + perp, color, width)
		draw_line(to, head_base - perp, color, width)
