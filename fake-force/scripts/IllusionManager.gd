extends Node
## IllusionManager（幻觉管理器）— Autoload 单例
##
## 全局存储当前幻觉场的核心参数，供玩家、幻灵方块等统一读取。
## 物理层永远不因洞察模式分支，所有虚假力计算都从这里取值。
## 双模式统一 G→加速度 换算（剧情与解密手感完全一致）
const G_TO_ACCEL_STORY : float = 10.0
const G_TO_ACCEL_PUZZLE : float = 10.0

var g_to_accel : float = G_TO_ACCEL_STORY
var game_mode : String = "story"   # "story" 剧情 / "puzzle" 解密
var is_insight_mode : bool = false # 当前是否处于洞察模式（背景星空定格，由 Player 每帧同步）

var global_influence_strength : float = 1.0  # 0~1，控制环境物体受力比例
var current_fake_vector : Vector2 = Vector2.ZERO
var current_g_value : float = 0.0
var current_omega : float = 0.0
var current_damping : float = 0.5

## 幻觉强度边框（GrimVignette）满强度对应的 G 值——由参考系决定：
## 普通参考系 1.5G 已"很大"；旋转参考系十余 G 仅"普通"。
## Player 每帧按 rot_state 在 linear/rot 两个参考值间切换。
var vignette_g_ref : float = 1.5

var zone_count : int = 0           # 已进入的不同幻觉区域数（阶段2 记事本第4页判定）
var _zones_seen : Dictionary = {}  # zone instance_id → true
var notebook_unlocked : int = 0    # 记事本已解锁页数（跨场景持久）


## 记录玩家进入过的幻觉区域（按实例去重）
func note_zone(id: int) -> void:
	if not _zones_seen.has(id):
		_zones_seen[id] = true
		zone_count = _zones_seen.size()


## 切换游戏模式（剧情/解密），并切换 G→加速度 换算系数
func set_mode(mode: String) -> void:
	game_mode = mode
	g_to_accel = G_TO_ACCEL_PUZZLE if mode == "puzzle" else G_TO_ACCEL_STORY
	reset_zone_params()


func get_current_fake_vector() -> Vector2:
	return current_fake_vector


## 有效幻觉强度：匀速间歇（无幻觉）时为 0
func get_current_effective_g() -> float:
	return current_fake_vector.length() / maxf(g_to_accel, 0.001)


func get_current_damping() -> float:
	return current_damping


## 由 IllusionZone 每帧调用：写入区域幻觉参数。
## fake_dir 为"幻觉力方向"（=-参考系加速方向）；ZERO 表示匀速间歇，无幻觉。
## （_eta 为区域配置的惯性系数，当前无直接消费方，保留 API。）
func set_zone_params(g_value: float, omega: float, _eta: float, damping: float, fake_dir: Vector2) -> void:
	current_g_value = g_value
	current_omega = omega
	current_damping = damping
	if fake_dir == Vector2.ZERO:
		current_fake_vector = Vector2.ZERO
	else:
		current_fake_vector = fake_dir.normalized() * g_value * g_to_accel


## 旋转参考系：把旋转惯性力（离心+科里奥利）作为当前幻觉场写入
## （旋转幻觉场与横向幻觉场互斥，随参考系切换）
func set_rot_inertia(inertia: Vector2) -> void:
	current_fake_vector = inertia


## 所有区域物体离开后调用：恢复默认参数
func reset_zone_params() -> void:
	current_g_value = 0.0
	current_omega = 0.0
	current_damping = 0.5
	current_fake_vector = Vector2.ZERO



