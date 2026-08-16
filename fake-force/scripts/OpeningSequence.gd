extends Node2D
## 开场导言（v3.0 叙事入口）
## 逐段淡入淡出展示导言文字（每段支持多行）；按任意键立即进入游戏
## 挂载于 CanvasLayer(layer=50) 下

const SEG_DURATION : float = 3.5
const FADE_TIME : float = 0.9

## 每项为一个数组（段内多行）
const SEGMENTS : Array = [
	["你是“深空”号空间探索船的一名船员。"],
	["你和成员们早已忘却为何离开地球——", "在星图上，找不到那个炽热的光点和蓝色的摇篮。"],
	["系统日复一日展示着“先驱者”的肖像。", "你不知道他们是谁，但有一点可以确定：你们是他们带领来的。"],
	["“探索未知的深空，不要问归途何方。”"],
	["这似乎，就是你们一生的使命。"],
	["偶然一日，你发现了一位停止呼吸的老人。", "他的身边，有一本发着苍蓝光芒的记事本。"],
	["航路图上只有一条简单的航线——", "指向离你们最近的黑洞。"],
	["那就去吧。"],
]

var _t : float = 0.0
var _done : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	queue_redraw()
	if _t >= SEGMENTS.size() * SEG_DURATION:
		_done = true
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed:
		_done = true
		queue_free()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font : Font = load("res://fusion-pixel.ttf")
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.96))
	var idx : int = int(_t / SEG_DURATION)
	if idx >= SEGMENTS.size():
		return
	var local : float = _t - float(idx) * SEG_DURATION
	var alpha : float = clampf(local / FADE_TIME, 0.0, 1.0) * clampf((SEG_DURATION - local) / FADE_TIME, 0.0, 1.0)
	var lines : Array = SEGMENTS[idx]
	var start_y : float = -18.0 * float(lines.size() - 1)
	for i in lines.size():
		draw_string(font, vp * 0.5 + Vector2(-380, start_y + float(i) * 34.0), String(lines[i]), \
			HORIZONTAL_ALIGNMENT_CENTER, 760, 24, Color(0.9, 0.95, 1.0, alpha))

