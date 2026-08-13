extends RefCounted
## 幻觉场方向切换器（设计决策2核心）
##
## 模拟"参考系不定时向某个方向加速"：
## - CONSTANT：恒定方向
## - CYCLE：按 directions 顺序循环
## - RANDOM：每相位随机选取方向
## - coast：匀速间歇（幻觉消失）
## - interval_jitter：每相位时长的随机抖动（"不定时"）
## update(delta) 返回当前"参考系加速方向"单位矢量；匀速间歇返回 ZERO。

enum Mode { CONSTANT, CYCLE, RANDOM }

var mode : int = Mode.CYCLE
var directions : Array = []
var interval : float = 3.0
var coast_time : float = 3.0
var interval_jitter : float = 1.0

var _phase_remaining : float = 0.0
var _index : int = 0
var _accel_len : float = 1.0
var switched_this_frame : bool = false
var accel_progress : float = 0.0   # 加速相位内进度 0~1（供 G 值渐变）


func setup(p_mode: int, p_directions: Array, p_interval: float, p_coast: float, p_jitter: float) -> void:
	mode = p_mode
	directions = p_directions
	interval = maxf(p_interval, 0.05)
	coast_time = maxf(p_coast, 0.0)
	interval_jitter = maxf(p_jitter, 0.0)
	reset()


func reset() -> void:
	_index = 0
	_phase_remaining = _roll_duration()


func update(delta: float) -> Vector2:
	switched_this_frame = false
	if mode == Mode.CONSTANT:
		accel_progress = 1.0
		return _current_direction()
	if directions.is_empty():
		accel_progress = 0.0
		return Vector2.ZERO
	_phase_remaining -= delta
	if _phase_remaining <= 0.0:
		_advance_phase()
		switched_this_frame = true
	# 匀速间歇：相位末段（coast 时长）
	if coast_time > 0.0 and _phase_remaining <= coast_time:
		accel_progress = 0.0
		return Vector2.ZERO
	# 加速相位内进度
	var accel_remaining : float = _phase_remaining - coast_time
	accel_progress = clampf(1.0 - accel_remaining / _accel_len, 0.0, 1.0)
	return _current_direction()


func _advance_phase() -> void:
	if mode == Mode.CYCLE:
		_index = (_index + 1) % directions.size()
	else:  # RANDOM
		_index = randi_range(0, directions.size() - 1)
	_phase_remaining = _roll_duration()


func _roll_duration() -> float:
	# 加速段 = interval ± jitter；匀速段 = coast
	var accel : float = interval
	if interval_jitter > 0.0:
		accel += randf_range(-interval_jitter, interval_jitter)
	_accel_len = maxf(accel, 0.05)
	return _accel_len + coast_time


func _current_direction() -> Vector2:
	if directions.is_empty():
		return Vector2.ZERO
	return (directions[_index] as Vector2).normalized()

