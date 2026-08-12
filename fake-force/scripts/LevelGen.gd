extends Node2D
## 沙盒关卡生成器：5层平台，无边界，每层随机缺口
## 平台 = StaticBody2D（碰撞）+ Polygon2D（可见灰色），供玩家跳上跳下

@export var floor_width : float = 1600.0
@export var platform_height : float = 30.0
@export var layers : int = 5
@export var layer_gap_y : float = 150.0
@export var top_layer_y : float = 50.0
@export var gap_count_range : Vector2i = Vector2i(1, 3)
@export var gap_width_range : Vector2 = Vector2(80.0, 180.0)
@export var min_segment : float = 100.0
@export var platform_color : Color = Color(0.4, 0.4, 0.4)


func _ready() -> void:
	randomize()
	for layer in layers:
		var y : float = top_layer_y + layer * layer_gap_y
		_generate_layer(y)


func _generate_layer(y: float) -> void:
	var gaps : Array = []
	var gap_count : int = randi_range(gap_count_range.x, gap_count_range.y)
	var attempts : int = 0
	while gaps.size() < gap_count and attempts < 50:
		attempts += 1
		var w : float = randf_range(gap_width_range.x, gap_width_range.y)
		var cx : float = randf_range(w * 0.5 + 30.0, floor_width - w * 0.5 - 30.0)
		var left : float = cx - w * 0.5
		var right : float = cx + w * 0.5
		var overlap : bool = false
		for g in gaps:
			if left < g[1] + 40.0 and right > g[0] - 40.0:
				overlap = true
				break
		if not overlap:
			gaps.append([left, right])
	gaps.sort_custom(func(a, b): return a[0] < b[0])
	var seg_start : float = 0.0
	for g in gaps:
		if g[0] - seg_start >= min_segment:
			_add_platform(seg_start, g[0], y)
		seg_start = g[1]
	if floor_width - seg_start >= min_segment:
		_add_platform(seg_start, floor_width, y)


func _add_platform(from_x: float, to_x: float, y: float) -> void:
	var w : float = to_x - from_x
	var body := StaticBody2D.new()
	body.position = Vector2((from_x + to_x) * 0.5, y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, platform_height)
	col.shape = shape
	body.add_child(col)
	var poly := Polygon2D.new()
	var hw : float = w * 0.5
	var hh : float = platform_height * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, hh), Vector2(-hw, hh)])
	poly.color = platform_color
	body.add_child(poly)
	add_child(body)
