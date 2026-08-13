extends Area2D
## 尖刺陷阱：η < 0.6 可"飘过"免疫；否则接触触发重生

func _ready() -> void:
	# 自动创建检测碰撞体
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.player_eta < 0.6:
			return  # 轻状态飘过
		body.on_hazard()


func _draw() -> void:
	# 红色倒三角形排列
	var pts := PackedVector2Array([Vector2(0.0, -14.0), Vector2(13.0, 14.0), Vector2(-13.0, 14.0)])
	draw_colored_polygon(pts, Color(1.0, 0.22, 0.22))
	draw_polyline(pts, Color(1.0, 0.4, 0.4), 1.0)
