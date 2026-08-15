extends Node
## IllusionManager（幻觉管理器）— Autoload 单例
##
## 全局存储当前幻觉场的核心参数，供玩家、幻灵方块等统一读取。
## 物理层永远不因洞察模式分支，所有虚假力计算都从这里取值。
## 双模式：剧情模式（G_TO_ACCEL=40）/ 解密模式（G_TO_ACCEL=10，文档规范）

const G_TO_ACCEL_STORY : float = 40.0
const G_TO_ACCEL_PUZZLE : float = 10.0

var g_to_accel : float = G_TO_ACCEL_STORY
var game_mode : String = "story"   # "story" 剧情 / "puzzle" 解密
var is_insight_mode : bool = false # 当前是否处于洞察模式（背景星空定格，由 Player 每帧同步）

var global_influence_strength : float = 1.0  # 0~1，控制环境物体受力比例
var current_fake_vector : Vector2 = Vector2.ZERO
var rotating_accel : Vector2 = Vector2.ZERO   # 旋转核心贡献（加速度，阶段3）
var current_g_value : float = 0.0
var current_omega : float = 0.0
var current_eta : float = 1.0
var current_damping : float = 0.5


## 切换游戏模式（剧情/解密），并切换 G→加速度 换算系数
func set_mode(mode: String) -> void:
	game_mode = mode
	g_to_accel = G_TO_ACCEL_PUZZLE if mode == "puzzle" else G_TO_ACCEL_STORY
	reset_zone_params()


func get_current_fake_vector() -> Vector2:
	return current_fake_vector + rotating_accel


## 有效幻觉强度：匀速间歇（无幻觉）时为 0
func get_current_effective_g() -> float:
	return current_fake_vector.length() / maxf(g_to_accel, 0.001)


func get_current_damping() -> float:
	return current_damping


## 由 IllusionZone 每帧调用：写入区域幻觉参数。
## fake_dir 为"幻觉力方向"（=-参考系加速方向）；ZERO 表示匀速间歇，无幻觉。
func set_zone_params(g_value: float, omega: float, eta: float, damping: float, fake_dir: Vector2) -> void:
	current_g_value = g_value
	current_omega = omega
	current_eta = eta
	current_damping = damping
	if fake_dir == Vector2.ZERO:
		current_fake_vector = Vector2.ZERO
	else:
		current_fake_vector = fake_dir.normalized() * g_value * g_to_accel


## 旋转参考系：把旋转惯性力（离心+科里奥利）作为当前幻觉场写入
## （旋转幻觉场与横向幻觉场互斥，随参考系切换）
func set_rot_inertia(inertia: Vector2) -> void:
	current_fake_vector = inertia
	rotating_accel = Vector2.ZERO


## 所有区域物体离开后调用：恢复默认参数
func reset_zone_params() -> void:
	current_g_value = 0.0
	current_omega = 0.0
	current_eta = 1.0
	current_damping = 0.5
	current_fake_vector = Vector2.ZERO



