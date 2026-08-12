extends Node2D
## 结局演出（v3.0 §4.5）
## 时间轴：白闪 → 黑洞特写（旋转光晕+吸积粒子）→ 角色滑入黑洞 → 老人面孔 →
##         老人台词 → 主题双行字 → Demo 结束
## 挂载于 CanvasLayer(layer=100) 下，坐标为视口坐标。

var _active : bool = false
var _t : float = 0.0


func _ready() -> void:
	add_to_group("Ending")
	visible = false


func start_ending() -> void:
	if _active:
		return
	_active = true
	visible = true
	_t = 0.0
	get_tree().paused = true


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _active and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var center : Vector2 = vp * 0.5
	# 黑底
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0))
	# 0~1.5s 屏幕白闪
	if _t < 1.5:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 1.0, 1.0, 1.0 - _t / 1.5))

	# 黑洞本体（持续）
	var pulse : float = 0.5 + 0.5 * sin(_t * 0.7)
	var radius : float = 80.0 + pulse * 16.0
	draw_circle(center, radius, Color(0.02, 0.03, 0.06))
	var glow : float = radius + 40.0 + pulse * 24.0
	# 苍蓝光晕
	draw_arc(center, glow, 0.0, TAU, 64, Color(0.4, 0.72, 1.0, 0.45), 3.0)
	# 光晕上的旋转亮弧（体现旋转）
	var arc_start : float = _t * 0.8
	draw_arc(center, glow, arc_start, arc_start + 0.7, 64, Color(0.7, 0.9, 1.0, 0.85), 4.0)
	# 吸积盘粒子（绕黑洞公转）
	for i in 6:
		var a : float = _t * 1.2 + TAU * float(i) / 6.0
		var r2 : float = glow + 26.0 + 14.0 * sin(_t * 0.5 + float(i))
		draw_circle(center + Vector2.from_angle(a) * r2, 3.0, Color(0.8, 0.95, 1.0, 0.7))

	# 2~5.5s：角色（光点）滑入黑洞
	if _t >= 2.0 and _t < 5.5:
		var k : float = (_t - 2.0) / 3.5
		var ship : Vector2 = center + Vector2(320.0 * (1.0 - k), 60.0 - 60.0 * k)
		var ship_r : float = 12.0 * (1.0 - k * 0.8)
		draw_circle(ship, ship_r, Color(0.85, 0.95, 1.0, 1.0 - k * 0.6))
		draw_line(ship, center, Color(0.5, 0.8, 1.0, 0.3 * (1.0 - k)), 1.0)

	# 5.5s~：黑洞内部——老人面孔（白线勾勒）
	if _t >= 5.5:
		var face_a : float = minf((_t - 5.5) * 0.8, 1.0)
		var fc : Color = Color(0.95, 0.97, 1.0, face_a)
		draw_arc(center, 46.0, 0.0, TAU, 40, fc, 3.0)
		draw_line(center + Vector2(-18, -8), center + Vector2(-6, -8), fc, 3.0)
		draw_line(center + Vector2(6, -8), center + Vector2(18, -8), fc, 3.0)
		draw_arc(center + Vector2(0, 10), 12.0, 0.3, TAU - 0.3, 24, fc, 2.5)

	# 7s~：老人台词
	if _t >= 7.0:
		draw_string(font, center + Vector2(-280, 110), \
			"你们不是先驱者的回声。你们是我留给宇宙的一个问题。", \
			HORIZONTAL_ALIGNMENT_CENTER, 560, 20, Color(0.85, 0.92, 1.0))

	# 9.5s~：主题双行字
	if _t >= 9.5:
		draw_string(font, center + Vector2(-300, 190), \
			"所谓力，不过是参考系中加速度的幻觉。", \
			HORIZONTAL_ALIGNMENT_CENTER, 600, 24, Color(0.7, 0.85, 1.0))
		draw_string(font, center + Vector2(-300, 230), \
			"所谓使命，不过是参照系里捡到的愿望。", \
			HORIZONTAL_ALIGNMENT_CENTER, 600, 24, Color(0.7, 0.85, 1.0))

	# 13s~：Demo 结束
	if _t >= 13.0:
		draw_string(font, center + Vector2(-200, 300), "—— Demo 结束 · 按 Esc 退出 ——", \
			HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(0.5, 0.6, 0.7))

