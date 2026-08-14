extends StaticBody2D
## 可撞碎幻灵墙：η > 1.5 撞击可粉碎开辟通路；否则被阻挡
## 自动创建碰撞体 + 接触检测区

var _broken : bool = false


func _ready() -> void:
	# 碰撞体（阻挡）
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 40)
	col.shape = shape
	add_child(col)
	# 接触检测区
	var area := Area2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(80, 40)
	var acol := CollisionShape2D.new()
	acol.shape = ashape
	area.add_child(acol)
	add_child(area)
	area.body_entered.connect(_on_touch)


func _on_touch(body: Node2D) -> void:
	if _broken:
		return
	if body.is_in_group("Player") and body.player_eta > 1.5:
		_broken = true
		queue_free()


func _draw() -> void:
	# 发光光晕 + 醒目边框（蓝色屏障）
	draw_rect(Rect2(-46, -26, 92, 52), Color(0.27, 0.53, 1.0, 0.14))
	draw_rect(Rect2(-40, -20, 80, 40), Color(0.27, 0.53, 1.0, 0.55))
	draw_rect(Rect2(-40, -20, 80, 40), Color(0.8, 0.95, 1.0, 1.0), false, 3.0)
	# 中间"屏障"横纹
	draw_line(Vector2(-40, 0), Vector2(40, 0), Color(0.8, 0.95, 1.0, 0.7), 2.0)

