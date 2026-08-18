extends Node2D
## 剧情模式坠落过多 → 强制休眠剧情演出（v2.3）
## 渐入黑屏 → 逐段文字（如同开场动画）→ 回到开始页（MainMenu.tscn）
## 由 Player._on_fallen（剧情模式失败）挂载到 CanvasLayer(layer=60) 下（盖住 HUD/红晕）。
## 按 空格 可跳过（直接回开始页）。

const FADE_IN_TIME : float = 1.6     # 渐入黑屏（秒）
const SEG_DURATION : float = 3.0     # 每段文字时长（秒）
const FADE_TIME : float = 0.9        # 每段淡入淡出
const END_HOLD : float = 1.2         # 结尾停留（秒）

## 每项为一个数组（段内多行）
const SEGMENTS : Array = [
	["【系统】：检测到非正常情绪波动，已激活强制休眠"],
	["一股强大的睡意袭来..."],
	["在梦里，你看见那巨大的气态行星"],
	["那是木星。"],
	["红褐色的巨眼越来越大，越来越近，仿佛与千万颗陨石重叠"],
	["“已激活重启子操作系统流程，5,4,3...”"],
	["机械，冰冷的电子音在耳旁响起"],
	["如同本能地，你又一次挣扎着起身，但已于事无补"],
	["0."],
]

var _t : float = 0.0
var _font : Font = null
var _done : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	queue_redraw()
	var total : float = FADE_IN_TIME + SEGMENTS.size() * SEG_DURATION + END_HOLD
	if _t >= total:
		_done = true
		get_tree().change_scene_to_file("res://MainMenu.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font : Font = _font
	if font == null:
		font = load("res://fusion-pixel.ttf")
		_font = font
	# 渐入黑屏
	var black : float = clampf(_t / FADE_IN_TIME, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, black))
	if _t < FADE_IN_TIME:
		return
	# 逐段文字（如同开场动画）
	var seg_t : float = _t - FADE_IN_TIME
	var idx : int = int(seg_t / SEG_DURATION)
	if idx >= SEGMENTS.size():
		return
	var local : float = seg_t - float(idx) * SEG_DURATION
	var alpha : float = clampf(local / FADE_TIME, 0.0, 1.0) * clampf((SEG_DURATION - local) / FADE_TIME, 0.0, 1.0)
	var lines : Array = SEGMENTS[idx]
	var start_y : float = -18.0 * float(lines.size() - 1)
	for i in lines.size():
		draw_string(font, vp * 0.5 + Vector2(-380, start_y + float(i) * 34.0), String(lines[i]),
			HORIZONTAL_ALIGNMENT_CENTER, 760, 24, Color(0.9, 0.95, 1.0, alpha))
	# 底部跳过提示
	draw_string(font, vp * 0.5 + Vector2(-160, vp.y * 0.5 + 200), "按 空格 跳过",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 14, Color(0.5, 0.62, 0.72, 0.6))


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			_done = true
			get_tree().change_scene_to_file("res://MainMenu.tscn")
