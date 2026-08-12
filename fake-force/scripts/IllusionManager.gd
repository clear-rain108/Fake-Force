extends Node
## IllusionManager（幻觉管理器）— Autoload 单例
##
## 全局存储当前幻觉场的核心参数，供玩家、幻灵方块等统一读取。
## 物理层永远不因洞察模式分支，所有虚假力计算都从这里取值。
## 参考：策划案 v2.0 §5.1（已扩展 eta / damping 的全局传递）

const G_TO_ACCEL : float = 10.0  # 1G = 10 游戏单位/秒²（策划案 §3.1）

var global_influence_strength : float = 1.0  # 0~1，控制环境物体受力比例
var current_fake_vector : Vector2 = Vector2.ZERO
var current_g_value : float = 0.0
var current_omega : float = 0.0
var current_eta : float = 1.0
var current_damping : float = 0.5


func get_current_fake_vector() -> Vector2:
	return current_fake_vector


func get_current_g() -> float:
	return current_g_value


func get_current_omega() -> float:
	return current_omega


func get_current_eta() -> float:
	return current_eta


func get_current_damping() -> float:
	return current_damping


## 由 IllusionZone 进入时调用：写入区域幻觉参数
func set_zone_params(g_value: float, omega: float, eta: float, damping: float, direction: Vector2) -> void:
	current_g_value = g_value
	current_omega = omega
	current_eta = eta
	current_damping = damping
	current_fake_vector = direction.normalized() * g_value * G_TO_ACCEL


## 所有区域物体离开后调用：恢复默认参数
func reset_zone_params() -> void:
	current_g_value = 0.0
	current_omega = 0.0
	current_eta = 1.0
	current_damping = 0.5
	current_fake_vector = Vector2.ZERO

