extends Area2D
## 幻觉区域（IllusionZone）
##
## 策划案 v2.0 §5.5：G/η/k/ω 全部作为 Area2D 导出变量，Inspector 直接调参。
## 幻觉场（决策2）：参考系不定时向某方向加速；玩家受到的幻觉力 = -a_ref（惯性力）。
## 匀速间歇（coast）期间幻觉消失；G 值可每相位随机（g_random_enabled）。
## 进入区域的 IllusionGroup 物体（玩家/幻灵方块）受其影响。

const IllusionFieldScript := preload("res://scripts/IllusionField.gd")

@export_group("幻觉参数")
@export var g_value : float = 0.8
@export var eta : float = 1.0
@export var damping : float = 0.6
@export var omega : float = 0.0

@export_group("幻觉场")
@export var field_mode : int = 1                 # 0=CONSTANT 1=CYCLE 2=RANDOM
@export var field_directions : Array = [Vector2.LEFT, Vector2.RIGHT]  # 参考系加速方向池（幻觉力 = -方向）
@export var field_interval : float = 3.0         # 加速相位时长（秒）
@export var field_coast : float = 3.0            # 匀速间歇时长（秒，0=无间歇）
@export var field_jitter : float = 1.0           # 相位时长随机抖动（±秒）

@export_group("强度随机")
@export var g_random_enabled : bool = false
@export var g_min : float = 0.6
@export var g_max : float = 1.0

var _occupants : int = 0
var _field = IllusionFieldScript.new()
var _current_g : float = 0.8


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_current_g = g_value
	_field.setup(field_mode, field_directions, field_interval, field_coast, field_jitter)


func _physics_process(delta: float) -> void:
	if _occupants <= 0:
		return
	# 参考系加速方向 → 幻觉力方向（反向）；匀速间歇时 a_dir=ZERO → 无幻觉
	var a_dir : Vector2 = _field.update(delta)
	if _field.switched_this_frame:
		_roll_g()
	# G 值渐变：非恒定模式下加速相位内正弦缓动 0→峰值→0；匀速间歇为 0
	var g_now : float = 0.0
	if a_dir != Vector2.ZERO:
		if field_mode == 0:  # CONSTANT：恒定强度
			g_now = _current_g
		else:
			g_now = _current_g * sin(PI * clampf(_field.accel_progress, 0.0, 1.0))
	IllusionManager.set_zone_params(g_now, omega, eta, damping, -a_dir)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("IllusionGroup"):
		_occupants += 1
		_field.reset()
		if body.is_in_group("Player"):
			AudioManager.transition_zone(g_value)  # 环境音向新区域预设平滑过渡


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("IllusionGroup"):
		_occupants = maxi(_occupants - 1, 0)
		if _occupants <= 0:
			IllusionManager.reset_zone_params()


func _roll_g() -> void:
	if g_random_enabled and g_max > g_min:
		_current_g = randf_range(g_min, g_max)
	else:
		_current_g = g_value


