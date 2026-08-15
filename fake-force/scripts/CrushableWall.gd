extends StaticBody2D
## 可撞碎幻灵墙：η > 1.5 撞击可粉碎开辟通路；否则被阻挡
## 自动创建碰撞体 + 距离检测（可靠触发）

var _broken : bool = false


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 40)
	col.shape = shape
	add_child(col)


func _physics_process(_delta: float) -> void:
	if _broken:
		return
	var player := get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player) and player.player_eta > 1.5:
		if global_position.distance_to(player.global_position) < 60.0:
			_broken = true
			queue_free()


func _draw() -> void:
	# 发光光晕 + 醒目边框（蓝色屏障）
	draw_rect(Rect2(-46, -26, 92, 52), Color(0.27, 0.53, 1.0, 0.14))
	draw_rect(Rect2(-40, -20, 80, 40), Color(0.27, 0.53, 1.0, 0.55))
	draw_rect(Rect2(-40, -20, 80, 40), Color(0.8, 0.95, 1.0, 1.0), false, 3.0)
	# 中间"屏障"横纹
	draw_line(Vector2(-40, 0), Vector2(40, 0), Color(0.8, 0.95, 1.0, 0.7), 2.0)

