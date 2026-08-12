extends Node
## IllusionManager（幻觉管理器）— Autoload 单例
##
## 全局存储当前幻觉场的核心参数，供玩家、幻灵方块等统一读取。
## 物理层永远不因洞察模式分支，所有虚假力计算都从这里取值。
## 参考：策划案 v2.0 §5.1（扩展 eta/damping 传递 + 幻觉场支持）

## 1G 对应的加速度（单位/s²）。
## 文档原定 10，为让"幻觉力改变落点"在无重力环境中显著（决策2），
## 调整至 40 并在试玩后继续校准。
const G_TO_ACCEL : float = 40.0

var global_influence_strength : float = 1.0  # 0~1，控制环境物体受力比例
var current_fake_vector : Vector2 = Vector2.ZERO
var rotating_accel : Vector2 = Vector2.ZERO   # 旋转核心贡献（加速度，阶段3）
var current_g_value : float = 0.0
var current_omega : float = 0.0
var current_eta : float = 1.0
var current_damping : float = 0.5


func get_current_fake_vector() -> Vector2:
	return current_fake_vector + rotating_accel


func get_current_g() -> float:
	return current_g_value


## 有效幻觉强度：匀速间歇（无幻觉）时为 0
func get_current_effective_g() -> float:
	return current_fake_vector.length() / G_TO_ACCEL


func get_current_omega() -> float:
	return current_omega


func get_current_eta() -> float:
	return current_eta


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
		current_fake_vector = fake_dir.normalized() * g_value * G_TO_ACCEL


## 所有区域物体离开后调用：恢复默认参数
func reset_zone_params() -> void:
	current_g_value = 0.0
	current_omega = 0.0
	current_eta = 1.0
	current_damping = 0.5
	current_fake_vector = Vector2.ZERO


