extends "res://scripts/IllusionZone.gd"
## 迷宫幻觉区（阶段2 五层塔专用）
##
## 在 IllusionZone 基础上增加"缓升"：玩家进入该层时启动每层附加的 Timer，
## g_value 从 0 在 ramp_time（默认 2.5s，与每层附加的 Timer 一致）内线性提升至目标值；
## 全部占用体离开后重置，下次进入重新缓升。仅物理参数，无剧情绑定。

@export var ramp_time : float = 2.5   # 缓升时长（秒）

var _target_g : float = 0.0
var _ramp : float = 0.0               # 0..1 缓升进度
var _timer : Timer = null


func _ready() -> void:
	_target_g = g_value
	super._ready()
	_timer = get_node_or_null("Timer")
	if _timer:
		_timer.wait_time = ramp_time
		_timer.one_shot = true
	_ramp = 0.0


func _physics_process(delta: float) -> void:
	if _occupants > 0:
		# 玩家在场：启动缓升计时（若未在跑）
		if _timer and _timer.is_stopped():
			_timer.start()
		# 线性缓升：0 → 目标值
		if _ramp < 1.0:
			_ramp = minf(1.0, _ramp + delta / maxf(ramp_time, 0.001))
	else:
		_ramp = 0.0
		if _timer:
			_timer.stop()
	_current_g = _target_g * _ramp
	super._physics_process(delta)
