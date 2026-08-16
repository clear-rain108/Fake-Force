extends CanvasLayer
## 黑屏淡入淡出过渡单例（Autoload）
## 用法：StageFade.fade_out_and_change("res://scenes/Stage3.tscn")
## 淡出 1s → 切换场景 → 新场景淡入 1s

var _active : bool = false
var _target : String = ""
var _t : float = 0.0
var _rect : ColorRect = null


func _ready() -> void:
	layer = 200
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func fade_out_and_change(scene_path: String) -> void:
	if _active:
		return
	_active = true
	_target = scene_path
	_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if not _target.is_empty():
		# 淡出阶段
		if _t < 1.0:
			_rect.color.a = _t
		elif _t >= 1.2:
			get_tree().change_scene_to_file(_target)
			_target = ""
			_t = 0.0
	else:
		# 淡入阶段
		if _t < 1.0:
			_rect.color.a = 1.0 - _t
		else:
			_rect.color.a = 0.0
			_active = false
			set_process(false)
