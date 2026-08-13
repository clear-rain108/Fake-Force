extends Node2D
## 屏幕边缘红晕（G 值视觉反馈，策划案 §3.1）
## 有效幻觉强度 0~0.8G 连续渐变；沿屏幕边缘的破碎光带（一体、不交叠）
## 挂载于 CanvasLayer(layer=40) 下，坐标为视口坐标

var _t : float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var g : float = IllusionManager.get_current_effective_g()
	var ratio : float = clampf(g / 0.8, 0.0, 1.0)  # 0~0.8G 渐变
	if ratio <= 0.02:
		return
	var vp := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 3.0)  # 每帧流动
	# 四条边，法线指向屏幕内侧
	_edge(rng, Vector2(0.0, 0.0), Vector2(vp.x, 0.0), Vector2(0.0, 1.0), ratio)      # 顶
	_edge(rng, Vector2(0.0, vp.y), Vector2(vp.x, vp.y), Vector2(0.0, -1.0), ratio)   # 底
	_edge(rng, Vector2(0.0, 0.0), Vector2(0.0, vp.y), Vector2(1.0, 0.0), ratio)      # 左
	_edge(rng, Vector2(vp.x, 0.0), Vector2(vp.x, vp.y), Vector2(-1.0, 0.0), ratio)   # 右


func _edge(rng: RandomNumberGenerator, a: Vector2, b: Vector2, inward: Vector2, ratio: float) -> void:
	var edge_len : float = a.distance_to(b)
	var dir : Vector2 = (b - a) / maxf(edge_len, 0.001)
	var horizontal : bool = absf(dir.x) > 0.5
	var count : int = int(8.0 + ratio * 16.0)
	var max_thick : float = 16.0 + ratio * 46.0
	for i in count:
		var t0 : float = float(i) / float(count)
		var t1 : float = clampf((float(i) + 1.0 + rng.randf() * 0.7) / float(count), 0.0, 1.0)
		var p0 : Vector2 = a + dir * edge_len * t0
		var p1 : Vector2 = a + dir * edge_len * t1
		var seg_len : float = p0.distance_to(p1)
		var thick : float = max_thick * (0.35 + rng.randf() * 0.65)
		var center : Vector2 = (p0 + p1) * 0.5 + inward * thick * 0.5
		var sz : Vector2 = Vector2(seg_len, thick) if horizontal else Vector2(thick, seg_len)
		var alpha : float = (0.05 + ratio * 0.22) * (0.7 + rng.randf() * 0.3)
		draw_rect(Rect2(center - sz * 0.5, sz), Color(1.0, 0.12, 0.08, alpha))

